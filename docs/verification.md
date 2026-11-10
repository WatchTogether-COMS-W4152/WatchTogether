# Verification record

This record applies to the web group-management implementation on `group-management`, based on the merged Rails/Inertia scaffold. It does not reuse the previous Expo/API iteration's test counts or deployment claims.

## Automated checks

The checks below passed on November 8, 2026, in local Docker environments using Ruby 4.0.9 and Node 24.16.0. The RSpec suite passed against both SQLite and PostgreSQL 17 (with CI eager loading). RSpec enforces a 90% minimum Rails application line-coverage threshold. Commands are in [README.md](../README.md).

| Check                                  | Result                                                           |
| -------------------------------------- | ---------------------------------------------------------------- |
| RSpec model/request/migration examples | 89 examples passed on each database engine.                      |
| Rails application line coverage        | 100% (193/193 lines); branch coverage 97.82% (45/46).            |
| Cucumber stories/scenarios             | 41 scenarios / 367 steps passed, covering eleven tagged stories. |
| Frontend tests                         | 29 Vitest / React Testing Library tests passed.                  |
| TypeScript, frontend lint/format       | Passed.                                                          |
| RuboCop, Brakeman, dependency audit    | Passed; no reported security warnings or vulnerable Ruby gems.   |
| Production web asset build             | Production Docker build and Vite compilation passed.             |

The shared-ownership/member-management follow-up reran RSpec on both databases, Cucumber, frontend tests, TypeScript, lint/format checks, Brakeman, and production asset compilation. The dependency audit and full production Docker build passed during the initial implementation; dependency lockfiles are unchanged. The production asset task reinstalls Node dependencies, so it must run separately from tests that build or load frontend assets in the same container.

The ownership migration ran successfully on development SQLite and test PostgreSQL. Before migrating development, a local database backup and ownership baseline were saved; the verification script confirmed existing owners, groups, memberships, and user accounts were preserved. A regression spec also exercises the actual migration against an isolated legacy SQLite schema, including repair of a missing owner membership. RSpec covers promotion, equal owner privileges, authorization rechecked under the group lock, self-removal protection, invitation replacement on removal, rollback on replacement failure, and retained accounts/unrelated memberships.

## Browser verification

The documented `docker compose up --build -d web` workflow passed: dependency installation, database preparation, Puma startup, sign-in and health responses, and frontend asset delivery. The browser also opened and refreshed the group page through this Compose service at `http://localhost:3000` with no console warnings or errors. The development service was left running for local review.

The development browser journey passed on November 8, 2026: registration with automatic sign-in, empty group lists, invalid sign-in and group-name errors, private group creation, invitation copying and reset, profile editing, logout, and returning-user sign-in. A second account was denied access before joining, could not join with the replaced code, and successfully joined with the current code. Its member page showed two display names and no invitation controls or other members' emails. Refresh preserved membership and the updated profile name.

The owner-deletion follow-up verified the owner-only deletion section, confirmation wording, and cancellation in the browser. Refresh after cancellation preserved the group and the browser reported no console errors. Actual deletion, authorization, membership cleanup, invalidation of the old invitation, and retention of user accounts and unrelated groups passed in isolated RSpec and Cucumber tests. Frontend tests cover confirmation, cancellation, disabled controls during submission, hidden controls for ordinary members, and recovery from a network error.

The member-management follow-up checked the **Manage** disclosure, promotion permissions, removal consequences, and cancellation in the browser at 1280px and 390px widths. The narrow layout had no horizontal overflow; cancellation restored focus to the member's Manage button and left membership unchanged. No browser console warnings or errors were reported after the migrated server restarted. Promotion and removal requests themselves were exercised through isolated Rails request/acceptance tests; the browser checks stopped at confirmation/cancellation. Frontend tests also verify co-owner controls, no self-management or ordinary-member controls, Escape dismissal, focus when switching confirmations, duplicate-submission prevention, and retry after network errors. Screenshots are in the ignored `artifacts/member-management.png` and `artifacts/member-removal-mobile.png` files.

Before the deletion follow-up, the production Docker image was also started with its default entrypoint against four isolated PostgreSQL databases. Database preparation, health and sign-in pages, and JavaScript/CSS/icon requests passed. A real CSRF-protected registration persisted an account and opened its groups page. The session cookie had Secure, HttpOnly, and SameSite=Lax flags, and private responses used Cache-Control: no-store. This was local production-mode verification, not a Heroku deployment.

The [two-user demonstration](user-stories.md#two-user-demonstration) remains the repeatable manual check for future changes. Local logs and screenshots from this run are in the ignored `tmp/web-group-management/` directory.

## Deployment status

Deployed to Heroku on November 9, 2026, at https://watchtogether-w4152-0a83ade2e0ae.herokuapp.com/ (release v5, Heroku-24 stack, one Basic dyno, Heroku Postgres `essential-0`). The build installed dependencies, compiled the frontend with Vite, and ran `db:prepare` in the release phase without errors. `/up` returned HTTP 200, and the sign-in page and its JavaScript and CSS loaded.

A browser check on the deployed app then registered a temporary account, created a group, suggested a title, and rated it. The ranking showed the expected score (+2 for Love it). The temporary account and group were then deleted from production.
