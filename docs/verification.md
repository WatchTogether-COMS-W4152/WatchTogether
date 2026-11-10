# Verification record

The current automated results below apply to `feature/watchlist`, based on commit `26a61f2` plus the watchlist test, story, and coverage improvements. This branch contains group management, voting, and the shared watchlist. Earlier browser and deployment checks are identified separately; they do not imply that the watchlist has been merged or deployed.

## Automated checks

The test and lint checks below passed on November 9, 2026, in local Docker using Ruby 4.0.9, Node 24.16.0, and SQLite. These current suites were not rerun against PostgreSQL. Commands are in [README.md](../README.md).

| Check                                  | Result                                                                                                                                                  |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RSpec model/request/migration examples | 172 examples passed, including 34 watchlist examples.                                                                                                   |
| RSpec application coverage             | 100% lines (300/300); 98.57% branches (69/70).                                                                                                          |
| Cucumber stories/scenarios             | 63 scenarios / 703 steps passed, covering eighteen tagged stories; 10 scenarios cover the watchlist.                                                    |
| Cucumber application coverage          | 96.33% lines (289/300); 84.28% branches (59/70), measured independently of RSpec.                                                                       |
| Frontend tests                         | 54 Vitest / React Testing Library tests passed, including 11 watchlist tests.                                                                           |
| TypeScript, frontend lint/format       | Passed.                                                                                                                                                 |
| RuboCop                                | 77 files inspected; no offenses.                                                                                                                        |
| Brakeman, dependency audit             | Passed during the November 9 rubric review; no warnings or vulnerable gems reported. Application code and dependencies are unchanged since that review. |
| Production web asset build             | Passed during the November 9 rubric review, including the watchlist frontend. Only tests, coverage setup, and documentation changed afterward.          |

SimpleCov starts explicitly before Rails in each test entrypoint and tracks all application controller/model files, including unloaded files. Each suite has its own 90% line-coverage minimum and report: `coverage/rspec/index.html` and `coverage/cucumber/index.html`. The reports each contain all 19 controller/model files and only their own suite's results. RSpec coverage cannot mask a Cucumber gap. These percentages cover Rails application code, not React; frontend behavior is verified separately by component tests.

Watchlist coverage includes the valid 120-character boundary and a title-specific error at 121 characters, blank/missing titles, database constraints, owner and ordinary-member actions, both watched states, private fields, forged attributes, denied access for visitors/outsiders/removed members, cross-group item IDs, CSRF, and group-deletion cleanup. Cucumber exercises shared persistence and permissions through real Rails requests. Frontend tests exercise navigation, submission and pending state, validation and retry, watched/unwatched requests, network-error feedback, and removal confirmation/cancellation.

The production asset task reinstalls Node dependencies, so run it separately from tests that build or load frontend assets in the same container. A local test run does not establish a GitHub Actions run or a deployment.

## Earlier group-management verification

On November 8, 2026, the earlier group-management suite passed against both SQLite and PostgreSQL 17 with CI eager loading. That earlier work also passed a full production Docker build. Those checks establish the historical baseline, not a PostgreSQL run of the current watchlist suite.

The ownership migration ran successfully on development SQLite and test PostgreSQL. Before migrating development, a local database backup and ownership baseline were saved; the verification script confirmed existing owners, groups, memberships, and user accounts were preserved. A regression spec also exercises the actual migration against an isolated legacy SQLite schema, including repair of a missing owner membership. RSpec covers promotion, equal owner privileges, authorization rechecked under the group lock, self-removal protection, invitation replacement on removal, rollback on replacement failure, and retained accounts/unrelated memberships.

## Browser verification

During the November 9 rubric review, the local group and watchlist pages rendered without browser console warnings or errors. The local health/sign-in pages and frontend assets returned HTTP 200. This smoke check did not mutate the existing group's watchlist; watchlist actions were exercised in isolated request/acceptance tests and frontend component tests. The expanded [two-user demonstration](user-stories.md#two-user-demonstration) includes watchlist add, watched/unwatched, cancellation/removal, and group cleanup for a full manual walkthrough.

### Earlier group-management browser checks

The documented `docker compose up --build -d web` workflow passed: dependency installation, database preparation, Puma startup, sign-in and health responses, and frontend asset delivery. The browser also opened and refreshed the group page through this Compose service at `http://localhost:3000` with no console warnings or errors. The development service was left running for local review.

The development browser journey passed on November 8, 2026: registration with automatic sign-in, empty group lists, invalid sign-in and group-name errors, private group creation, invitation copying and reset, profile editing, logout, and returning-user sign-in. A second account was denied access before joining, could not join with the replaced code, and successfully joined with the current code. Its member page showed two display names and no invitation controls or other members' emails. Refresh preserved membership and the updated profile name.

The owner-deletion follow-up verified the owner-only deletion section, confirmation wording, and cancellation in the browser. Refresh after cancellation preserved the group and the browser reported no console errors. Actual deletion, authorization, membership cleanup, invalidation of the old invitation, and retention of user accounts and unrelated groups passed in isolated RSpec and Cucumber tests. Frontend tests cover confirmation, cancellation, disabled controls during submission, hidden controls for ordinary members, and recovery from a network error.

The member-management follow-up checked the **Manage** disclosure, promotion permissions, removal consequences, and cancellation in the browser at 1280px and 390px widths. The narrow layout had no horizontal overflow; cancellation restored focus to the member's Manage button and left membership unchanged. No browser console warnings or errors were reported after the migrated server restarted. Promotion and removal requests themselves were exercised through isolated Rails request/acceptance tests; the browser checks stopped at confirmation/cancellation. Frontend tests also verify co-owner controls, no self-management or ordinary-member controls, Escape dismissal, focus when switching confirmations, duplicate-submission prevention, and retry after network errors. Screenshots are in the ignored `artifacts/member-management.png` and `artifacts/member-removal-mobile.png` files.

Before the deletion follow-up, the production Docker image was also started with its default entrypoint against four isolated PostgreSQL databases. Database preparation, health and sign-in pages, and JavaScript/CSS/icon requests passed. A real CSRF-protected registration persisted an account and opened its groups page. The session cookie had Secure, HttpOnly, and SameSite=Lax flags, and private responses used Cache-Control: no-store. This was local production-mode verification, not a Heroku deployment.

The [two-user demonstration](user-stories.md#two-user-demonstration) remains the repeatable manual check for future changes. Local logs and screenshots from this run are in the ignored `tmp/web-group-management/` directory.

## Deployment status

The deployed app follows `main`. The watchlist is currently on `feature/watchlist` and has not been merged or deployed; its absence in production is expected. These test/story improvements do not change the deployment.

The existing deployment record is Heroku release v5 on November 9, 2026, at https://watchtogether-w4152-0a83ade2e0ae.herokuapp.com/ (Heroku-24 stack, one Basic dyno, Heroku Postgres `essential-0`). The build installed dependencies, compiled the frontend with Vite, and ran `db:prepare` in the release phase without errors. `/up` returned HTTP 200, and the sign-in page and its JavaScript and CSS loaded. The November 9 rubric review reconfirmed those public responses and checked sign-in/registration rendering without console errors; it did not repeat the authenticated production walkthrough.

A browser check on the deployed app then registered a temporary account, created a group, suggested a title, and rated it. The ranking showed the expected score (+2 for Love it). The temporary account and group were then deleted from production.
