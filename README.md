# WatchTogether

WatchTogether helps friends organize what they watch together. This web-first iteration implements **group management**: email/password accounts, editable display names, private groups, shared ownership, member management, reusable invitation codes, and owner-only group deletion. It also implements **group voting**: members suggest titles, privately rate each one, and see a ranking of what the whole group is happiest to watch. Watchlists, progress tracking, and spoiler-free discussion are not part of this branch.

## Team

| Name    | UNI     |
| ------- | ------- |
| Alex    | amf2346 |
| David   | dn2620  |
| Larissa | ls4270  |
| Yuqi    | yl6408  |

**Live app:** https://watchtogether-w4152-0a83ade2e0ae.herokuapp.com/

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

The implementation uses ordinary Rails controllers, Inertia pages, and six models:

| Model        | Responsibility                                                                                     |
| ------------ | -------------------------------------------------------------------------------------------------- |
| `User`       | Display name, normalized unique email, and bcrypt password digest.                                 |
| `Session`    | A hashed opaque session token, user, and 30-day expiry. Logout revokes the server session.         |
| `Group`      | Name and cryptographically random reusable invitation code.                                        |
| `Membership` | User/group relationship and member/owner role, with foreign keys and a unique pair constraint.     |
| `Suggestion` | A title suggested to one group, unique per group ignoring case and spacing, and its suggester.     |
| `Vote`       | One member's private rating of a suggestion: `love`, `maybe`, or `not_interested`, one per member. |

The browser receives its session token in a signed, HttpOnly, SameSite cookie, with the Secure flag in production. Rails protects form submissions against CSRF. Authentication and invitation attempts are throttled. Passwords and tokens are filtered from logs.

Group creation and the creator's owner membership are one transaction. Only members can view a group. Member lists contain display names and roles, not email addresses. All owners can see or reset the invitation code. Resetting invalidates the previous code while preserving existing members. Joining repeatedly, including joining your own group, does not duplicate membership or change an existing role. New members always join as ordinary members.

Owners can make existing members owners. Ownership is shared: the original owner remains an owner, and every owner has the same permissions to invite friends, manage members, and delete the group. Each other member's **Manage** control opens the available actions; promotion asks for confirmation and explains these permissions.

Owners can remove another member, including another owner. Removal asks for confirmation, removes access to that group, and replaces its invitation code in the same transaction so a saved code cannot restore access. Existing members stay in the group; member accounts and memberships in other groups are kept. An owner cannot remove themselves, so these actions always leave at least one owner. Removal is not a permanent ban: someone with a newly shared invitation can join again as an ordinary member.

An owner can delete a group after confirming in the web interface. Deletion removes the group and all its memberships, invalidates its invitation code, and returns the owner to their group list. Member accounts and unrelated groups are kept. Ordinary members and outsiders cannot delete the group.

### Voting

Any member can suggest a title to their group from **What should we watch?** on the group page. Blank titles and duplicates (ignoring letter case and extra spaces) are rejected. Each member privately rates each title with exactly one of three options: **Love it** (+2), **Maybe** (+1), or **Not interested** (−2). A member can change their rating at any time; there is no way to clear it.

The group ranking orders titles by total score, then by number of Love it ratings, then by the oldest suggestion. Unrated titles score 0, so one dislike cancels one Love without acting as a veto. Only current members' ratings count: when someone is removed from the group, their ratings stop affecting the ranking. Members see each title's total score, how many members have rated it, and their own rating, but never who chose which rating. The suggester or any owner can remove a title, which deletes its ratings. Deleting a group deletes its suggestions and ratings; deleting an account deletes that person's ratings and keeps their suggestions.

There is no separate mobile client or public JSON API in this branch. A future mobile client can share these models and rules through additional API controllers. Avatars, social login, email verification, password-reset delivery, group editing, leaving groups, owner demotion, and exclusive ownership transfer are outside this iteration.

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

- [Fifteen user stories](docs/user-stories.md) map to tagged executable Cucumber scenarios. Run a story with `bundle exec cucumber --tags @US10`, or run just the voting stories with `bundle exec cucumber features/voting.feature`.
- RSpec checks models, constraints, authentication, permissions, privacy, and failure paths. SimpleCov enforces at least **90% Rails application line coverage** and writes `coverage/index.html`.
- Cucumber uses real Rails/Inertia requests and separate browser cookie jars against the test database. These are service acceptance tests; they do not execute React in a browser.
- React Testing Library tests cover web forms and controls. TypeScript, linting, security scans, and the production asset build complement the behavioral suites.
- GitHub Actions is configured to run the checks when the branch is pushed or opened as a pull request. A local run does not imply a remote workflow has run.

Measured results and their scope are recorded in [verification.md](docs/verification.md).

## Main web routes

| Route                                       | Purpose                                                   |
| ------------------------------------------- | --------------------------------------------------------- |
| `GET/POST /sign-up`                         | Registration; automatically signs in.                     |
| `GET/POST /sign-in`                         | Sign-in form and authentication.                          |
| `DELETE /session`                           | Revoke the current session and sign out.                  |
| `GET/PATCH /profile`                        | Read profile and update display name.                     |
| `GET /`, `GET /groups`                      | List the current user's groups.                           |
| `GET /groups/new`, `POST /groups`           | Create a private group.                                   |
| `GET/POST /groups/join`                     | Paste an invitation code and join.                        |
| `GET /groups/:id`                           | Member-only details, with owner-only invitation controls. |
| `DELETE /groups/:id`                        | Owner-only deletion of the group and its memberships.     |
| `POST /groups/:id/invitation/reset`         | Replace the owner's invitation code.                      |
| `POST /groups/:id/members/:user_id/promote` | Make an existing member another owner.                    |
| `DELETE /groups/:id/members/:user_id`       | Remove another member and replace the invitation code.    |
| `GET /groups/:id/suggestions`               | Member-only ranked suggestions with the viewer's ratings. |
| `POST /groups/:id/suggestions`              | Suggest a title to the group.                             |
| `DELETE /groups/:id/suggestions/:id`        | Remove a title (its suggester or any owner).              |
| `PUT /groups/:id/suggestions/:id/vote`      | Set or change your rating for a title.                    |
| `GET /up`                                   | Public Rails health endpoint.                             |

Successful form submissions redirect to a page. Validation errors return through Inertia to their form fields. Signed-out or expired sessions return to sign-in, inaccessible groups return 404, and a member attempting an owner-only action receives 403.

The shared-ownership migration preserves existing data: each group's previous owner becomes an owner-role member before the old single-owner column is removed. Run `bin/rails db:prepare` when updating an existing checkout, then `bin/rails restart` if the development server is already running so it reloads the schema. Docker startup and the production release phase already run database preparation.

## Production

The [deployment guide](docs/deployment.md) covers the production Docker image and Heroku configuration. The frontend is compiled during Rails asset precompilation, and Puma serves the application.

The app is live at **https://watchtogether-w4152-0a83ade2e0ae.herokuapp.com/**.
