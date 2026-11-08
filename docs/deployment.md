# Deploying the web application

This branch serves a Rails/Inertia/React web app. Vite builds browser assets during `rails assets:precompile`; Puma serves the application. A separate React Native app and public JSON API are future work.

The implementation is being left in a local commit at the team's request. No remote push or new Heroku deployment is part of this change. The earlier Expo/API deployment is a different iteration and should not be presented as this branch's deployment.

## Before deployment

Run the checks in [README.md](../README.md) and review the [verification record](verification.md). Use the Ruby/Node versions and lockfiles committed on this branch. Keep secrets and local `.env` files out of Git. Preserve LF line endings for Ruby lockfiles and Linux entrypoint scripts; the repository's attributes make checkout behavior explicit.

## Production Docker image

The checked-in `Dockerfile` builds the production image, installs Ruby and JavaScript dependencies, and precompiles assets. Build it from the repository root:

```sh
docker build -t watchtogether-web .
```

Provide database connections and a production `SECRET_KEY_BASE` when running the image. If using encrypted Rails credentials, provide the matching `RAILS_MASTER_KEY` as well. Never bake either secret into the image. The default entrypoint runs `bin/rails db:prepare` before starting Rails.

Production preserves the scaffold's four PostgreSQL connections:

| Environment variable | Database purpose                          |
| -------------------- | ----------------------------------------- |
| `DATABASE_URL`       | Users, sessions, groups, and memberships. |
| `CACHE_DATABASE_URL` | Solid Cache.                              |
| `QUEUE_DATABASE_URL` | Solid Queue.                              |
| `CABLE_DATABASE_URL` | Solid Cable.                              |

Provision each connection before starting the app. These are four configured databases, not four schemas created automatically inside a single Heroku Postgres add-on. The Solid components are inherited infrastructure; group management does not enqueue background work or use realtime channels.

## Heroku configuration

Use the **Node buildpack before Ruby** so JavaScript dependencies are available to Vite during Rails asset precompilation. Keep Vite build dependencies installed during that step, for example with `NPM_CONFIG_INCLUDE=dev`. Pin the versions using the repository's configuration.

The `Procfile` declares the web process and a release-phase database preparation command. Set the four database URL variables and production secrets in Heroku configuration. Provision databases appropriate for that configuration before releasing. `Procfile.dev` is for local development and is not the production process definition.

The team should choose the target app and database arrangement deliberately before deployment. Replacing the prior Expo/API deployment with this branch is an application migration, not merely changing the frontend assets; review its database migration history and existing data first. Do not reset or drop an existing production database to make a release pass.

## Verify the deployed release

After the team deploys, record the actual URL, release identifier, date, and results in [verification.md](verification.md):

1. Confirm dependency installation, Vite compilation, and release database preparation finish successfully.
2. Open the app, refresh it, and verify JavaScript/CSS/icons load with no browser console errors.
3. Request `/up` and confirm HTTP 200. This only proves application health; continue with database-backed checks.
4. Complete the [two-user demonstration](user-stories.md#two-user-demonstration), including invalid forms, owner-only code controls, reset-code rejection, profile updates, and logout.
5. Confirm users and memberships remain after refresh and application restart.
6. Confirm production session cookies are Secure and HttpOnly and that unauthorized group access exposes no private details.
7. Check application logs for unexpected errors. Avoid copying credentials, cookie values, or private user data into the verification record.

A successful local production build is useful evidence, but it does not replace checking the deployed URL.
