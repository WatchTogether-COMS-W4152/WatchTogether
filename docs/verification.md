# Verification record

This record applies to the web group-management implementation on `group-management`, based on the merged Rails/Inertia scaffold. It does not reuse the previous Expo/API iteration's test counts or deployment claims.

## Automated checks

The checks below passed on November 8, 2026, in local Docker environments using Ruby 4.0.9 and Node 24.16.0. The RSpec suite passed against both SQLite and PostgreSQL 17 (with CI eager loading). RSpec enforces a 90% minimum Rails application line-coverage threshold. Commands are in [README.md](../README.md).

| Check                               | Result                                                          |
| ----------------------------------- | --------------------------------------------------------------- |
| RSpec model/request examples        | 63 examples passed on each database engine.                     |
| Rails application line coverage     | 100% (160/160 lines); branch coverage 97.36% (37/38).           |
| Cucumber stories/scenarios          | 28 scenarios / 186 steps passed, covering eight tagged stories. |
| Frontend tests                      | 17 Vitest / React Testing Library tests passed.                 |
| TypeScript, frontend lint/format    | Passed.                                                         |
| RuboCop, Brakeman, dependency audit | Passed; no reported security warnings or vulnerable Ruby gems.  |
| Production web asset build          | Production Docker build and Vite compilation passed.            |

## Browser verification

The documented `docker compose up --build -d web` workflow passed: dependency installation, database preparation, Puma startup, sign-in and health responses, and frontend asset delivery. The browser also opened and refreshed the group page through this Compose service at `http://localhost:3000` with no console warnings or errors. The development service was left running for local review.

The development browser journey passed on November 8, 2026: registration with automatic sign-in, empty group lists, invalid sign-in and group-name errors, private group creation, invitation copying and reset, profile editing, logout, and returning-user sign-in. A second account was denied access before joining, could not join with the replaced code, and successfully joined with the current code. Its member page showed two display names and no invitation controls or other members' emails. Refresh preserved membership and the updated profile name.

The production Docker image was also started with its default entrypoint against four isolated PostgreSQL databases. Database preparation, health and sign-in pages, and JavaScript/CSS/icon requests passed. A real CSRF-protected registration persisted an account and opened its groups page. The session cookie had Secure, HttpOnly, and SameSite=Lax flags, and private responses used Cache-Control: no-store. This was local production-mode verification, not a Heroku deployment.

The [two-user demonstration](user-stories.md#two-user-demonstration) remains the repeatable manual check for future changes. Local logs and screenshots from this run are in the ignored `tmp/web-group-management/` directory.

## Deployment status

This change is intended to remain in a local commit for the team to push. No new remote GitHub Actions result or Heroku release is claimed. Record a deployment URL only after this branch has actually been deployed and verified.
