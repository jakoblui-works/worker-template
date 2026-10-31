# worker-template

A [Copier](https://copier.readthedocs.io/) template for a Taskiq worker on Redis Streams that owns its own Postgres schema: uv, ruff, mypy strict, pytest + Hypothesis, pydantic-settings, Alembic, a Dockerfile, and CI that builds an image, pushes it to GHCR and triggers the infra deploy.

## Make a worker
```sh
uv tool install copier
copier copy --trust gh:jakoblui-works/worker-template my-service
```
`--trust` lets the template run its one task, `uv lock`, so the generated CI's `uv sync --locked` works.

Questions:
- `service_name`: repo, image and app name (`cv-service`).
- `domain`: schema, queue, result prefix and task name prefix (`cv`); defaults to the name without `-service`.
- `description`: one line for `pyproject.toml` and the README.
- `use_s3`: adds S3 settings, an `aioboto3` client and the CI env.

The new repo still needs:
- access to the `DEPLOY_REPO_DISPATCH_TOKEN` org secret, which `deploy.yml` uses to trigger the infra deploy;
- a place on the `DEPLOY_STATUS_TOKEN` token's repository list, or infra can't report the deploy on its commits and they stay `pending`;
- its GHCR package made public after the first push (new org packages start private);
- its infra side (compose service, env, deploy steps) and its place in the site-web x-ray. The full list is in `platform-docs/new-service.md`.

## Update a worker
```sh
copier update --trust
```
Run it in the generated repo with everything committed. Copier applies the template's changes since the version in `.copier-answers.yml` and keeps your own edits; conflicts show up as in a git merge. `README.md` and `CLAUDE.md` are written once and then left alone, since they become the repo's own.

## Layout
- `copier.yml`: the questions.
- `template/`: what gets rendered. Files ending in `.jinja` are templated; the rest are copied as they are.
- `scripts/test-template.sh`: renders the template and checks the result (CI runs it for each `use_s3`).
