# worker-template

Copier template for Taskiq workers. Everything under `template/` is rendered into new repos; the rest (this file, the README, `scripts/`, `.github/`) belongs to the template repo itself.

## Commands
```sh
uv tool install copier
scripts/test-template.sh false   # render with use_s3=false and check it; `true` for S3
```
The script needs Postgres and Redis reachable with `DATABASE__*` and `REDIS__*` in the environment (locally, the api repo's `compose.dev.yml` stack and its `.env`).

## Rules
- `.jinja` only on files that use template variables, with one exception: the generated `.gitignore` is `template/.gitignore.jinja`, because as a plain `.gitignore` git would apply it to the template itself (its `.env.*` line hid `.env.example.jinja` from every render).
- In templated GitHub workflows, wrap `${{ … }}` in `{% raw %}…{% endraw %}`.
- `scripts/test-template.sh` renders with `--vcs-ref HEAD`: without it, Copier renders the latest tag and ignores the working tree.
- Conditional files and folders use a name that renders empty when off (`app/{% if use_s3 %}storage{% endif %}/`).
- Releases are git tags (`v0.1.0`); `copier update` moves between them. Tag after merging, not on a branch.
- Changes the generated repos should get go here first, then reach them through `copier update`.
- `README.md` and `CLAUDE.md` are `_skip_if_exists`: rendered for a new repo, never touched by updates. A change to them only reaches new repos; tell existing ones by hand if it matters.
