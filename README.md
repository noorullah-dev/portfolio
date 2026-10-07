# QistManager

Rails 8.1 / Ruby 3.4.5 application for multi-business sales, inventory,
installment collections and accounting with PostgreSQL.

## Local Docker

No `.env` file is needed. Compose starts a bundled PostgreSQL and points Rails
at it; the server creates/migrates the database on startup (never demo data):

```sh
docker compose up -d --build --wait
docker compose exec web ./bin/rails app:create_owner
```

Open http://127.0.0.1:3000/login. Uploads persist in local named volumes, and
plain HTTP is the default locally (`RAILS_FORCE_SSL=false`,
`RAILS_ASSUME_SSL=false`). To use your own database, secret or port, export
`DATABASE_URL`, `SECRET_KEY_BASE` or `APP_PORT`, or put overrides in an
optional `.env` file (see `.env.example`).

## Test

```sh
docker compose --profile test run --build --rm test
```

The test profile starts an isolated local PostgreSQL database and never uses the
hosted application database. It migrates, checks autoloading, and runs Minitest.

## Vercel

See [VERCEL_DEPLOYMENT.md](VERCEL_DEPLOYMENT.md) for importing the repository,
environment variables, migrations, domains, and upload persistence limitations.
Vercel uses `Dockerfile.vercel`, which starts Puma without automatic migrations.

See [DOCKER_REVIEW.md](DOCKER_REVIEW.md) for review findings and verification limits.
