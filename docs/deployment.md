# Deploying the web application

This branch serves a Rails/Inertia/React web app. Vite builds browser assets during `rails assets:precompile`; Puma serves the application. A separate React Native app and public JSON API are future work.

The `main` version is deployed on Heroku at **https://watchtogether-w4152-0a83ade2e0ae.herokuapp.com/** (app name `watchtogether-w4152`). The watchlist is currently on `feature/watchlist`, has not been merged into `main`, and is available for local review. Its absence from the deployed app is expected until the team merges and deploys it.

## Before deployment

Run the checks in [README.md](../README.md) and review the [verification record](verification.md). Use the Ruby/Node versions and lockfiles committed on this branch. Keep secrets and local `.env` files out of Git. Preserve LF line endings for Ruby lockfiles and Linux entrypoint scripts; the repository's attributes make checkout behavior explicit.

The shared-ownership migration backfills owner roles on memberships and removes the single `groups.owner_id` column. Back up existing data before applying it. This migration cannot be automatically rolled back to one owner per group; rolling back to the old application version requires restoring a compatible database backup.

## Production Docker image

The checked-in `Dockerfile` builds the production image, installs Ruby and JavaScript dependencies, and precompiles assets. Build it from the repository root:

```sh
docker build -t watchtogether-web .
```

Provide database connections and a production `SECRET_KEY_BASE` when running the image. If using encrypted Rails credentials, provide the matching `RAILS_MASTER_KEY` as well. Never bake either secret into the image. The default entrypoint runs `bin/rails db:prepare` before starting Rails.

Production uses a single PostgreSQL database, read from `DATABASE_URL`. The app doesn't use the Rails cache, background jobs, or Action Cable yet, so in production they run in-process (memory cache, async jobs, async cable). Move them to Solid Cache, Solid Queue, and Solid Cable when a feature needs them to be durable or shared across processes.

## Heroku

The app runs on one Basic web dyno with a Heroku Postgres `essential-0` database, which sets `DATABASE_URL`. Buildpacks run **Node before Ruby**, so Node is available when Rails asset precompilation builds the frontend with Vite. The `Procfile` runs `rails db:prepare` in the release phase, so migrations apply on every deploy, and then starts Puma.

The setup, for reference or for recreating the app:

```sh
heroku create watchtogether-w4152 --stack heroku-24
heroku buildpacks:add heroku/nodejs -a watchtogether-w4152
heroku buildpacks:add heroku/ruby -a watchtogether-w4152
heroku addons:create heroku-postgresql:essential-0 -a watchtogether-w4152
heroku config:set SECRET_KEY_BASE=$(openssl rand -hex 64) -a watchtogether-w4152
```

To deploy, push `main` to Heroku. Ask the app owner to add you as a collaborator first:

```sh
git remote add heroku https://git.heroku.com/watchtogether-w4152.git
git push heroku main
```

Useful commands: `heroku logs --tail -a watchtogether-w4152`, `heroku run bin/rails console -a watchtogether-w4152`, and `heroku releases -a watchtogether-w4152`. Do not reset or drop the production database to make a release pass.

`Procfile.dev` is for local development and is not the production process definition.

## Verify the deployed release

After the team deploys, record the actual URL, release identifier, date, and results in [verification.md](verification.md):

1. Confirm dependency installation, Vite compilation, and release database preparation finish successfully.
2. Open the app, refresh it, and verify JavaScript/CSS/icons load with no browser console errors.
3. Request `/up` and confirm HTTP 200. This only proves application health; continue with database-backed checks.
4. Complete the [two-user demonstration](user-stories.md#two-user-demonstration), including invalid forms, owner-only code controls, reset-code rejection, profile updates, logout, shared ownership, member removal with invitation replacement, and deletion of a temporary group by an owner.
5. Confirm users and memberships remain after refresh and application restart.
6. Confirm production session cookies are Secure and HttpOnly and that unauthorized group access exposes no private details.
7. Check application logs for unexpected errors. Avoid copying credentials, cookie values, or private user data into the verification record.

A successful local production build is useful evidence, but it does not replace checking the deployed URL.
