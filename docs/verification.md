# Verification record

## Streaming availability — November 23, 2026

The `feature/streaming-availability` branch starts from `main` commit `073d25b`. The feature was developed and verified locally on macOS with Ruby 4.0.10, Node 24.22.2, and SQLite.

| Check | Result |
| --- | --- |
| RSpec | 312 examples passed; 99.85% line coverage (667/668), 96.90% branch coverage (219/226). |
| Cucumber | 95 scenarios and 1222 steps passed, including four new scenarios tagged US31. |
| Cucumber coverage | 95.80% line coverage (640/668), 79.20% branch coverage (179/226). |
| Vitest / React Testing Library | 91 tests passed, including seven new streaming availability component tests. |
| TypeScript / frontend lint | Passed; no warnings or errors. |
| RuboCop | All modified Ruby files passed with no offenses. |
| Git diff | No whitespace errors in committed changes. |

Streaming availability adds six service tests, five request tests, seven frontend tests, and four Cucumber scenarios. All existing automated tests continued to pass.

The tests cover US-specific provider results, caching, duplicate and malformed provider entries, empty availability, manually added titles, upstream failures, private group access, and frontend fallback messages. Automated tests use deterministic responses and do not require a live TMDB credential.

Live API verification returned provider information for both a movie and a TV show. Local browser verification confirmed that Dexter displayed streaming subscription and purchase providers, the United States region label, and JustWatch attribution. Empty categories were hidden, and existing episode progress remained accessible.

No database migration, new dependency, or additional API credential is required. The existing TMDB configuration is reused. These results apply to local verification before integration with the redesign branch; final CI and deployment verification are separate.

## TMDB integration — November 15, 2026

`tmdb-integration` starts from remote `main` commit `234f8a4`. The integration was checked locally in Docker with Ruby 4.0.9, Node 24.16.0, and SQLite before publication. No deployment was performed; PostgreSQL was not exercised for this change.

| Check                          | Result                                                                                                                                               |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| RSpec                          | 226 examples passed; 99.77% controller/model/service line coverage (441/442), 99.30% branch coverage (143/144).                                      |
| React Testing Library / Vitest | 66 tests passed, including debounce, stale search/detail responses, keyboard selection, whitespace edits, metadata, and voting-to-watchlist actions. |
| TypeScript / frontend lint     | Passed; no lint warnings or errors.                                                                                                                  |
| RuboCop                        | 89 files inspected; no offenses.                                                                                                                     |
| Brakeman                       | No errors or security warnings.                                                                                                                      |
| Bundler audit                  | No vulnerabilities after updating Puma from 8.0.2 to 8.0.3 for newly published advisories.                                                           |

The final Cucumber run passed **79 scenarios and 945 steps**, including 16 TMDB scenarios tagged US19–US22. Coverage is 95.92% controller/model/service lines (424/442) and 81.94% branches (118/144). Acceptance tests use deterministic HTTP fixtures, never real credentials, and exercise the actual TMDB client, controllers, and models. They cover both movie and TV selection, canonical metadata replacing forged fields, remakes and duplicate identities, manual titles, missing metadata, no matches, upstream outages, private group access, and offline suggestion copying with votes preserved. RSpec additionally covers the duplicate-validation race during concurrent watchlist additions.

Coverage now explicitly includes services as well as controllers and models; the earlier 99.46% RSpec / 95.41% Cucumber figures excluded services. Each suite still independently enforces a 90% line minimum. The TMDB client itself has **100% RSpec line and branch coverage** (71/71 lines, 56/56 branches), and **98.59% Cucumber line coverage** (70/71; 43/56 branches). The suites run with `TMDB_API_KEY` empty and stub only the external TMDB HTTP boundary where integration behavior is tested.

The expanded tests found and fixed two defects: an empty successful TMDB response could expose a parser exception, and SQLite's suggestion-table rebuild could cascade-delete existing votes. The migration now controls the transaction boundary so SQLite foreign keys are disabled before rebuilding tables, validates all foreign keys before commit, and restores enforcement. Two isolated tests exercise the actual Rails migrator against populated data and a late injected failure; both preservation and complete rollback pass. PostgreSQL retains transactional DDL with foreign keys enabled, but has not been rerun for this branch. The two affected older local-development votes were restored from their committed SQL-log values after taking an ignored database backup; newer activity was preserved.

The production asset build passed with `TMDB_API_KEY` explicitly empty during the preceding integration check. The frontend is unchanged by this test expansion. Repository-wide frontend formatting, RuboCop, and `git diff --check` passed after the additions. The earlier credential scan checked 394 source, generated asset, and log files with zero matches.

Live browser verification used a separate **TMDB Integration Preview** group in the development database. Keyboard search/selection added _Interstellar_ to voting with a poster, description, 2014 release year, TMDB score, and US PG-13 certification. Rating it and transferring it to the watchlist preserved the suggestion and +2 score; the button changed to **On watchlist**. Watchlist search distinguished the _Severance_ TV series from same-named movies and saved its US TV-MA certification. Updated pages loaded without browser warning/error logs. A narrow viewport check found no horizontal overflow. The preview group remains available locally for review.

The supplied credential is stored only in ignored local `.env` and injected into the Rails runtime. Source files, generated browser assets, and application logs were scanned for the actual value without printing it. The official TMDB logo is bundled unmodified with its source recorded in `public/tmdb-logo-source.txt`.

## Earlier watchlist verification

The historical results below apply to `feature/watchlist`, based on commit `26a61f2` plus the watchlist test, story, and coverage improvements. Earlier browser and deployment checks are identified separately.

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
