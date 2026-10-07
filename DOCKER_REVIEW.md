# Docker readiness review — 2026-10-07

This review covers runtime configuration, dependencies, routes, uploads, seeds
and existing test infrastructure. It does not certify every financial workflow
or close every item in the historical project audit.

## Addressed

- Added a multi-stage Dockerfile with pinned Ruby/Bundler, native PostgreSQL build
  dependencies, libvips, precompiled assets and a non-root runtime. A separate
  target includes test dependencies.
- Added Compose with hosted PostgreSQL via the hardcoded development/production URL, web health
  checks and persistent storage/upload volumes. A separate test profile uses a
  local PostgreSQL service with readiness checks and an isolated database.
- Added `.dockerignore` and `.gitignore` to exclude environment secrets, keys,
  machine configuration, logs, storage files and generated artifacts.
- Development and production use the requested hardcoded PostgreSQL URL with
  SSL required. The test environment retains separate database settings.
- Added `/up` and an unauthenticated health-check regression test.
- Enabled the Rails test railtie so the existing Minitest suite has its standard
  test tasks available.
- Made SSL configurable for local Docker HTTP while retaining secure defaults
  outside Compose. Health checks bypass SSL redirects.
- Replaced the Redis Action Cable configuration, whose gem was missing, with
  async. No application broadcasts currently exist; use one Puma process.
- Startup migrates without seeding. An interactive bootstrap task creates a
  platform owner without sample transactions or known passwords.

## Remaining considerations

- Demo seeds contain predictable passwords, print credentials and reset seeded
  passwords. Use only for disposable evaluation databases.
- Custom uploads in `public/uploads` and Active Storage in `storage` both need
  backups alongside PostgreSQL.
- In-memory caching, jobs and Action Cable cannot share state across processes
  or provide durable job delivery. Add shared adapters when needed.
- Active Storage variants need an image-processing gem; libvips alone is insufficient.
- Public deployment needs an HTTPS proxy and appropriate network access controls.

## Validation — 2026-10-07

- Compose configuration (`docker compose --profile test config --quiet`),
  entrypoint shell syntax and Git whitespace checks passed.
- A read-only `psql` connection to the configured hosted database succeeded as
  `postgres` on `mobile_management`. Client connection info confirmed TLS 1.3.
- The hosted database's public schema currently contains zero tables. Rails
  migrations have not run during this validation.
- Attempted `docker compose --profile test run --build --rm test` and
  `docker compose up -d --build --wait`; both failed because the current account
  cannot access `/var/run/docker.sock`. Elevated execution also lacked socket
  access, and `sudo -n docker info` failed because sudo requires a password.
- Startup was initially rejected by automatic approval review due to migrations;
  retrying with the verified empty-schema evidence passed review, but still failed
  on Docker socket permissions.
- Ruby/Bundler are absent on this host. Image builds, Rails tests, migrations and
  HTTP checks remain unverified. Historical audit results are not new test results.

To complete verification from a terminal with Docker access:

```sh
sudo docker compose --profile test run --build --rm test
sudo docker compose up -d --build --wait
curl --fail http://localhost:3000/up
sudo docker compose exec web ./bin/rails app:create_owner
```

The startup command initializes the hosted application schema. The test command
uses its isolated local PostgreSQL database.
