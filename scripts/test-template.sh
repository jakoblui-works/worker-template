#!/usr/bin/env bash
# Render the template and check the generated project: lint, types, tests, and the image as a worker.
# Usage: scripts/test-template.sh <use_s3: true|false>
# Needs Postgres and Redis on localhost, with DATABASE__*, REDIS__* (and S3__* for true) in the environment.
set -euo pipefail

if [[ $# -ne 1 || ! $1 =~ ^(true|false)$ ]]; then
    echo "usage: $0 <use_s3: true|false>" >&2
    exit 2
fi
use_s3=$1

# A caller's virtualenv would make uv use it instead of the rendered project's.
unset VIRTUAL_ENV

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
service=example-service
tmp=$(mktemp -d)
project="$tmp/$service"
image="$service:test-template-$$"
container="$service-test-template-$$"

cleanup() {
    docker rm -f "$container" >/dev/null 2>&1 || true
    docker rmi -f "$image" >/dev/null 2>&1 || true
    rm -rf "$tmp"
}
trap cleanup EXIT

step() { printf '\n==> %s\n' "$*"; }

step "Render (use_s3=$use_s3)"
copier copy --trust --defaults --vcs-ref HEAD -d service_name="$service" -d use_s3="$use_s3" "$repo" "$project"
cd "$project"

# Before anything else runs, so tool caches don't end up in the search.
step "No unrendered Jinja"
jinja='\{\{|\{%|\{#'
bad_names=$(find . -path ./.venv -prune -o -path ./.git -prune -o -print | grep -E "$jinja" || true)
# Strip GitHub Actions expressions (${{ ... }}) before matching; print the original line.
bad_lines=$(grep -rnIE "$jinja" --exclude-dir=.venv --exclude-dir=.git --exclude=uv.lock . \
    | awk '{ line = $0; gsub(/\$\{\{[^}]*\}\}/, "", line); if (line ~ /\{\{|\{%|\{#/) print $0 }' || true)
if [[ -n $bad_names || -n $bad_lines ]]; then
    [[ -n $bad_names ]] && printf 'Unrendered Jinja in file names:\n%s\n' "$bad_names" >&2
    [[ -n $bad_lines ]] && printf 'Unrendered Jinja in files:\n%s\n' "$bad_lines" >&2
    exit 1
fi

step "uv sync --locked"
uv sync --locked
step "ruff check"
uv run ruff check
step "ruff format --check"
uv run ruff format --check
step "mypy"
uv run mypy
step "pytest"
uv run pytest

step "Docker image"
docker build -t "$image" .

env_args=(-e REDIS__HOST -e REDIS__PORT -e REDIS__PASSWORD -e DATABASE__PASSWORD=dummy)
if [[ $use_s3 == true ]]; then
    env_args+=(-e S3__ENDPOINT_URL -e S3__ACCESS_KEY_ID -e S3__SECRET_ACCESS_KEY -e S3__BUCKET)
fi

# The image has no dev dependencies, so a module that imports one (e.g. type stubs) fails only here.
# taskiq's --fs-discover skips task modules that fail to import, so the worker would still start.
step "Every app module imports in the image"
import_check='
import importlib, pkgutil, sys, traceback
import app
names = [m.name for m in pkgutil.walk_packages(app.__path__, "app.", onerror=lambda name: None)]
failed = []
for name in names:
    try:
        importlib.import_module(name)
    except Exception:
        failed.append(name)
        print(f"FAILED to import {name}:", file=sys.stderr)
        traceback.print_exc()
if not names:
    sys.exit("No modules found under app")
if failed:
    sys.exit(f"{len(failed)} of {len(names)} app modules failed to import: " + ", ".join(failed))
print(f"All {len(names)} app modules import")
'
docker run --rm "${env_args[@]}" "$image" python -c "$import_check"

step "Worker answers a ping"
docker run -d --name "$container" --network host "${env_args[@]}" "$image" >/dev/null

# Retry until the worker is up: a ping sent before it has joined the stream may go unanswered.
attempts=6
for ((i = 1; i <= attempts; i++)); do
    if [[ $(docker inspect -f '{{.State.Running}}' "$container") != true ]]; then
        echo "Worker container exited:" >&2
        docker logs "$container" >&2
        exit 1
    fi
    if reply=$(uv run python -m scripts.send_ping); then
        echo "Reply: $reply"
        break
    fi
    if ((i == attempts)); then
        echo "No reply from the worker after $attempts attempts. Logs:" >&2
        docker logs "$container" >&2
        exit 1
    fi
    sleep 2
done

step "All checks passed (use_s3=$use_s3)"
