# Deploy QistManager on Vercel

Vercel supports Rails HTTP servers using container images (currently Beta).
This repository supplies `Dockerfile.vercel` and an explicit `vercel.json`
container service with a catch-all rewrite to Rails.
The separate `Dockerfile` and `compose.yaml` remain available for local Docker.

## Import and configure

1. Push this repository to GitHub and sign in to Vercel.
2. Choose **Add New → Project**, import `zaheerh793/mobileManagmentSys`, and use
   the repository root (`.`). Choose **Other** if a framework selection is required.
3. Disable build, install and output directory overrides. Do not set the output
   directory to `public`: that publishes static error pages instead of running
   Rails. `vercel.json` selects the container runtime and `Dockerfile.vercel`.
4. Set environment variables in **Project Settings → Environment Variables**:

   - `DATABASE_URL` — **required.** The full PostgreSQL connection string,
     including the database name, e.g.
     `postgresql://USER:PASSWORD@HOST:5432/DATABASE?sslmode=require`. The app
     fails fast at boot with a clear error if it is missing. Production and
     preview deployments should use separate databases.
   - `SECRET_KEY_BASE` — recommended. The image generates a random session key
     during its build, so the app boots without this variable, but the key
     changes on every rebuild and signs out all sessions. Set it explicitly for
     stable sessions across rebuilds (`openssl rand -hex 64`); the application
     gives this variable precedence.
   - Optional overrides: `PORT` (the image defaults to `80`; remove any old
     `PORT=3000` override so Vercel and Puma agree), `RAILS_ENV=production`,
     `RAILS_FORCE_SSL=true`, `RAILS_ASSUME_SSL=true`, `RAILS_LOG_LEVEL=info`,
     `RAILS_MAX_THREADS=3`, `WEB_CONCURRENCY=0`.

   `config/database.yml` no longer contains any connection string; production
   reads only `DATABASE_URL`. A password used in earlier commits remains in Git
   history, so rotate that database password before public use.

5. Deploy. Runtime logs appear in the Vercel dashboard.
6. Open `https://YOUR-DEPLOYMENT.vercel.app/up`, then `/login`.
7. Under **Project Settings → Domains**, add your domain and apply the DNS
   records Vercel displays.

## Diagnose the deployed 404

On 2026-10-07, read-only checks of `https://nooruallah.vercel.app/`, `/login`
and `/up` returned identical cached 404 responses with
`content-disposition: inline; filename="404.html"`. The Rails routes exist in
this checkout. This indicates the deployment is serving static error files
instead of forwarding requests to the Rails container. The deployment-specific
URL is protected by Vercel Authentication, so its runtime logs are not publicly
accessible.

The added `vercel.json` explicitly declares a `container` service rooted at `.`
with entrypoint `Dockerfile.vercel` and routes all paths to that service.
After publishing this file:

1. Open **Project Settings → Build and Deployment**.
2. Set the project root to the directory containing `vercel.json` and
   `Dockerfile.vercel` (this repository's root).
3. Disable any **Output Directory** override, especially `public`. Clear custom
   install/build commands. Choose **Other** for the framework if needed.
4. Remove conflicting runtime overrides, especially `PORT=3000`. The image uses
   port 80 by default.
5. Deploy the new commit without reusing the previous build cache.
6. Build logs should show the Docker stages and `bundle install`. Runtime logs
   should show Puma listening on port 80. If only static files are uploaded,
   the container has not been selected correctly.
7. Request `/up`: it should return HTTP 200. Then request `/login`. If `/up`
   works and `/login` fails, inspect Rails runtime logs for a database/schema
   error, and complete the separate migration step below.

Do not add a static rewrite to `index.html`: this is a server-rendered Rails app.
This configuration change has been validated locally as JSON but is not yet
published or verified on the live deployment from this workspace.

## Database initialization

The Vercel image deliberately does not migrate on startup. Cold starts and preview
instances must not race to migrate a shared business database. Run migrations
once from a trusted machine before deployment:

```sh
docker compose build web
DATABASE_URL='postgresql://USER:PASSWORD@HOST:5432/DATABASE?sslmode=require' \
  docker compose run --rm --no-deps web ./bin/rails db:migrate
DATABASE_URL='postgresql://USER:PASSWORD@HOST:5432/DATABASE?sslmode=require' \
  docker compose run --rm --no-deps web ./bin/rails app:create_owner
```

Compose defaults `DATABASE_URL` to its bundled local database, so always pass
the real connection string explicitly (inline as above, or via `.env`). Do not
run demo seeds against a live business database. Use separate preview and
production credentials/databases before enabling automatic preview
deployments.

## No .env file involved

Vercel never reads a `.env` file. Everything Vercel needs lives in the
dashboard (step 4), so pushing to GitHub deploys directly once those variables
are set. `.env` is only an optional convenience for local Docker overrides.

## Upload persistence limitation

The current app writes customer photos and company logos to `public/uploads` and
uses local Active Storage. Vercel instances are replaceable and do not supply
Compose named volumes. Local uploads are not durable or shared across instances.
Move both custom uploads and Active Storage to object storage before using those
features in production. This deployment configuration does not implement that
storage migration. If retaining filesystem uploads is required, use a host with
persistent disks instead.

The current cache/jobs/Action Cable configuration is in memory. Do not rely on it
for durable jobs or shared broadcasts across Vercel instances.

## Validation status

Verified locally (2026-10-07) with Docker:

- `Dockerfile.vercel` builds and starts Puma on `PORT` (80 default, 8080
  override) and binds `0.0.0.0`.
- `vercel.json` conforms to the published Vercel schema (`container` service,
  `runtime: "container"`, `entrypoint: "Dockerfile.vercel"`, catch-all rewrite).
- Production migrations and seeds run from the production image against a fresh
  PostgreSQL container (`db:migrate` + `db:seed`, exit 0).
- Asset precompilation passes with no warnings; 18 assets compiled.
- Minitest suite: 110 runs, 924 assertions, 0 failures, 0 errors, 0 skips;
  `zeitwerk:check` and `bundler-audit` clean.
- Full authenticated end-to-end run against the container behind an HTTPS
  proxy (mimicking Vercel's TLS termination): login, forced password change,
  shop open, `/`, `/dashboard`, `/sales`, `/products`, `/purchases`,
  `/expenses`, `/reports`, `/users`, `/settings/business` all 200; CSRF
  enforced (422 without token); wrong password rejected; unknown path returns
  the Rails public 404 page, not the static file alone.
- Boots without `DATABASE_URL` only to raise a clear configuration error.

Not verified from this workspace: an actual Vercel deployment. Importing the
repository requires access to your Vercel account, so the deployment-specific
checklist above (container selected, Puma on port 80, `/up` → 200) must be
confirmed in the Vercel dashboard after the first deploy.

References:
- https://vercel.com/docs/functions/container-images
- https://vercel.com/kb/guide/does-vercel-support-ruby-on-rails-applications
