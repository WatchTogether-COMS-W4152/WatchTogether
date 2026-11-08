# WatchTogether

WatchTogether helps friends organize what they watch together. This web-first iteration implements **group management**: email/password accounts, editable display names, private groups, member lists, reusable invitation codes, and owner-only group deletion. Watchlists, voting, progress tracking, and spoiler-free discussion are future iterations.

Rails serves React + TypeScript pages through [Inertia](https://inertia-rails.dev). Vite builds the frontend. The application uses Ruby 4.0.9, Rails 8.1, Node 24, SQLite for development/tests, and PostgreSQL in production. Ruby and JavaScript dependencies have committed lockfiles.

## Run locally

With Ruby and Node installed at the versions in `.ruby-version` and `.nvmrc`:

```sh
bin/setup
```

This installs dependencies, prepares the database, and starts Rails and Vite. On subsequent runs, use `bin/dev`. Open [localhost:3000](http://localhost:3000).

For Windows, or to avoid installing Ruby locally, start Docker Desktop and run:

```sh
docker compose up --build
```

Open [localhost:3000](http://localhost:3000). The container installs dependencies and prepares SQLite automatically. Rails builds Vite assets on request in this workflow; the native `bin/dev` workflow also provides Vite hot reloading. Stop the container with `docker compose down`.

Create an account, create a group, and copy its invitation code. Use a second browser profile or private window to register a friend and join. See the [complete two-user demonstration](docs/user-stories.md#two-user-demonstration).

## Design and scope

The implementation uses ordinary Rails controllers, Inertia pages, and four models:

| Model        | Responsibility                                                                             |
| ------------ | ------------------------------------------------------------------------------------------ |
| `User`       | Display name, normalized unique email, and bcrypt password digest.                         |
| `Session`    | A hashed opaque session token, user, and 30-day expiry. Logout revokes the server session. |
| `Group`      | Name, owner, and cryptographically random reusable invitation code.                        |
| `Membership` | User/group relationship with foreign keys and a unique pair constraint.                    |

The browser receives its session token in a signed, HttpOnly, SameSite cookie, with the Secure flag in production. Rails protects form submissions against CSRF. Authentication and invitation attempts are throttled. Passwords and tokens are filtered from logs.

Group creation and the owner's membership are one transaction. Only members can view a group. Member lists contain display names, not email addresses. Only the owner sees or resets its invitation code. Resetting invalidates the previous code while preserving existing members. Joining repeatedly, including joining your own group, does not duplicate membership.

An owner can delete a group after confirming in the web interface. Deletion removes the group and all its memberships, invalidates its invitation code, and returns the owner to their group list. Member accounts and unrelated groups are kept. Ordinary members and outsiders cannot delete the group.

There is no separate mobile client or public JSON API in this branch. A future mobile client can share these models and rules through additional API controllers. Avatars, social login, email verification, password-reset delivery, group editing, leaving/removing members, and ownership transfer are outside this iteration.

## Tests and grading

Prepare the test database, then run the checks:

```sh
RAILS_ENV=test bin/rails db:prepare
bin/rspec
bundle exec cucumber
npm test
npm run typecheck
npm run lint
npm run fmt:check
bin/rubocop
bin/brakeman
bin/bundler-audit
```

On Windows with Docker Compose:

```sh
docker compose exec -e RAILS_ENV=test web bin/rails db:prepare
docker compose exec -e RAILS_ENV=test web bundle exec rspec
docker compose exec -e RAILS_ENV=test web bundle exec cucumber
docker compose exec web npm test
docker compose exec web npm run typecheck
docker compose exec web npm run lint
docker compose exec web npm run fmt:check
docker compose exec web bin/rubocop
docker compose exec web bin/brakeman
docker compose exec web bin/bundler-audit
```

- [Nine user stories](docs/user-stories.md) map to tagged executable Cucumber scenarios. Run a story with `bundle exec cucumber --tags @US09`.
- RSpec checks models, constraints, authentication, permissions, privacy, and failure paths. SimpleCov enforces at least **90% Rails application line coverage** and writes `coverage/index.html`.
- Cucumber uses real Rails/Inertia requests and separate browser cookie jars against the test database. These are service acceptance tests; they do not execute React in a browser.
- React Testing Library tests cover web forms and controls. TypeScript, linting, security scans, and the production asset build complement the behavioral suites.
- GitHub Actions is configured to run the checks when the branch is pushed or opened as a pull request. A local run does not imply a remote workflow has run.

Measured results and their scope are recorded in [verification.md](docs/verification.md).

## Main web routes

| Route                               | Purpose                                                   |
| ----------------------------------- | --------------------------------------------------------- |
| `GET/POST /sign-up`                 | Registration; automatically signs in.                     |
| `GET/POST /sign-in`                 | Sign-in form and authentication.                          |
| `DELETE /session`                   | Revoke the current session and sign out.                  |
| `GET/PATCH /profile`                | Read profile and update display name.                     |
| `GET /`, `GET /groups`              | List the current user's groups.                           |
| `GET /groups/new`, `POST /groups`   | Create a private group.                                   |
| `GET/POST /groups/join`             | Paste an invitation code and join.                        |
| `GET /groups/:id`                   | Member-only details, with owner-only invitation controls. |
| `DELETE /groups/:id`                | Owner-only deletion of the group and its memberships.     |
| `POST /groups/:id/invitation/reset` | Replace the owner's invitation code.                      |
| `GET /up`                           | Public Rails health endpoint.                             |

Successful form submissions redirect to a page. Validation errors return through Inertia to their form fields. Signed-out or expired sessions return to sign-in, inaccessible groups return 404, and a member attempting an owner-only action receives 403.

## Production

The [deployment guide](docs/deployment.md) covers the production Docker image and Heroku configuration. The frontend is compiled during Rails asset precompilation, and Puma serves the application.

This web implementation is committed locally for the team to review and push. It has not replaced the earlier Expo/API deployment. An existing URL from that earlier iteration is not evidence that this branch has been deployed.
