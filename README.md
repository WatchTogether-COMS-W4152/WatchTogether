# WatchTogether

A Rails 8 app with a React + TypeScript frontend, connected by
[Inertia](https://inertia-rails.dev). Rails controllers render React page
components and pass them data as props, so there's no separate JSON API.

```
app/controllers/      Rails controllers (inherit from InertiaController)
app/frontend/
  entrypoints/        Vite entrypoints (inertia.tsx boots the React app)
  pages/              Inertia page components, e.g. pages/home/index.tsx
  styles/             Global CSS
  types/              Shared TypeScript types (shared props, flash)
spec/                 RSpec tests
```

**Stack:** Rails 8.1, Inertia, React 19, Vite (via `vite_rails`), TypeScript, RSpec,
SQLite (dev/test), PostgreSQL (production), oxlint + oxfmt, RuboCop.

## Requirements

- Ruby (version in `.ruby-version`)
- Node.js (version in `.nvmrc`)

## Getting started

```sh
bin/setup   # install gems + npm packages, prepare the database, start the app
bin/dev     # start Rails (:3000) and the Vite dev server together
```

Open http://localhost:3000.

## Adding a page

1. Add a route and a controller action that calls `render inertia: { ...props }`.
   By convention, `UsersController#show` renders `app/frontend/pages/users/show.tsx`.
2. Create that component. It receives the props.

See the [Inertia Rails guide](https://inertia-rails.dev/guide) for forms,
shared data, redirects and validation errors.

## Checks

```sh
bin/rspec               # tests
bin/rubocop             # Ruby lint
bin/brakeman            # security scan
npm run typecheck       # TypeScript
npm run lint            # oxlint, type-aware (lint:fix to autofix)
npm run fmt             # oxfmt (fmt:check in CI)
bin/ci                  # run everything, as CI does
```

Lint config is in `.oxlintrc.json`. Format config is in `.oxfmtrc.json`; it uses
oxfmt defaults with import sorting turned on. In VS Code, install the
recommended extensions to format on save.

## Production

The `Dockerfile` builds a production image. `rails assets:precompile` builds
the frontend with Vite.

Production uses PostgreSQL. Development and test use SQLite, so there's
nothing to install locally. Production has four databases: the app's primary
database plus one each for Solid Cache, Solid Queue and Solid Cable. They can
share one Postgres server. Point the app at them with:

```
DATABASE_URL=postgres://user:pass@host:5432/watch_together_production
CACHE_DATABASE_URL=postgres://user:pass@host:5432/watch_together_production_cache
QUEUE_DATABASE_URL=postgres://user:pass@host:5432/watch_together_production_queue
CABLE_DATABASE_URL=postgres://user:pass@host:5432/watch_together_production_cable
RAILS_MASTER_KEY=<contents of config/master.key>
```

The Docker entrypoint runs `bin/rails db:prepare` on boot.
