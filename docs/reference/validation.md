# Documentation validation report

This page records the reproducible validation contract and the results observed against source commit `b73965c` on 2026-08-04.

## Commands

From the repository root:

```powershell
python -m pip install -r requirements-docs.txt
python scripts/docs/validate_docs.py
python scripts/docs/extract_mermaid.py --output build/mermaid-validation.md
npx.cmd -y puppeteer browsers install chrome-headless-shell
npx.cmd -y @mermaid-js/mermaid-cli -p scripts/docs/puppeteer-config.json -i build/mermaid-validation.md -o build/mermaid-rendered.md
docker run --rm -v "${PWD}/docs/architecture:/usr/local/structurizr" structurizr/cli:2025.11.09 validate -workspace /usr/local/structurizr/workspace.dsl
mkdocs build --strict
```

OpenAPI is additionally linted with the backend's pinned dependency tree:

```powershell
cd backend
npm.cmd run lint:openapi
```

## What `validate_docs.py` checks

- local Markdown targets and section anchors;
- MkDocs navigation target existence;
- OpenAPI parsing, version, response presence, and exact duplicate-copy equality;
- exact canonical route parity with all Express router declarations plus the API version index;
- exact entity-marker parity with all Mongoose model declarations under `backend/src/models/`;
- non-empty Structurizr workspace and required view keys;
- required documentation files and the root `AGENTS.md` contract;
- YAML syntax for every checked-in GitHub Actions workflow.

## Observed results

| Check | Result | Evidence |
| --- | --- | --- |
| MkDocs strict build | Pass | Material site built successfully; the CLI emitted only its upstream MkDocs 2.0 advisory |
| Local link validation | Pass | 41 local targets/anchors checked; MkDocs emitted no unresolved-link messages after correction |
| OpenAPI parse/lint | Pass with warnings | Redocly reports a valid description and 104 non-blocking quality warnings, principally missing `operationId` and standard 4xx responses |
| API route comparison | Pass | 114 implemented canonical operations = 114 OpenAPI operations |
| Entity comparison | Pass | 18 discovered Mongoose models = 18 documented model markers |
| Mermaid parse/render | Pass | All 23 Mermaid fences extracted and rendered by Mermaid CLI |
| Structurizr validation | Pass | `workspace.dsl` validated with the pinned `structurizr/cli:2025.11.09` image |
| Backend documentation copy parity | Pass | `docs/api/openapi.yaml` is byte-for-byte identical to `backend/docs/api/openapi.yaml` |
| GitHub Actions YAML syntax | Pass | All 6 workflow YAML files parsed |

Runtime application tests are reported separately from documentation validators. A documentation build does not prove a live deployment, provider account, backup, or clinical end-to-end path.

## Administrator lifecycle and audit fixes, 2026-09-28

Validated local working-tree changes for findings B1-B5. Database tests used disposable Docker MongoDB instances, including a real replica set for transaction rollback and concurrency checks. No shared deployment or database was changed.

| Check | Result | Evidence |
| --- | --- | --- |
| Backend TypeScript build | Pass | `npm.cmd run build --prefix backend` |
| Admin, authentication, and new critical regression suites | Pass | 167 tests passed with `npm.cmd test --prefix backend -- --runInBand admin-critical-regressions admincontroller authcontroller` |
| Final hospital security-version regression and admin routes | Pass | 118 tests passed with `npm.cmd test --prefix backend -- --runInBand admin-critical-regressions admincontroller` after preserving suspension security-version bumps |
| Final transactional guard writes and related checks | Pass across runs | The six-suite run covering critical regressions, runtime configuration, lifecycle enforcement, RBAC, admin access, and protected surfaces passed 62/63 tests. The sole failure was an idle HTTP socket reset in the RBAC probe after source compilation. Its test client now disables keep-alive; all 6 RBAC tests passed on rerun. The remaining 5 suites passed, including all 11 critical regressions after the final transaction guard change |
| Flutter access, permission UI, and confirmation tests | Pass | 34 tests passed with `flutter.bat test test/features/admin/admin_access_controller_test.dart test/features/admin/admin_permission_ux_test.dart test/core/widgets/admin/admin_action_confirmation_test.dart` from `frontend/` |
| Documentation contract | Pass | `python scripts/docs/validate_docs.py`: 53 local links, 114 implemented/documented operations, 18 implemented/documented models, identical OpenAPI copies, 6 workflow YAML files |
| MkDocs strict build | Pass | `mkdocs build --strict` |
| OpenAPI lint | Pass with warnings | `npm.cmd run lint:openapi --prefix backend`: valid description, 104 non-blocking warnings |
| Mermaid | Pass | Extracted and rendered all 27 diagrams using the commands above |
| Structurizr | Pass | Pinned `structurizr/cli:2025.11.09` validated the workspace |
| Whitespace/diff integrity | Pass | `git diff --check` |

The new regressions cover patient-write rollback, expected-state rejection, shared individual/batch transitions, doctor security-version changes, cleanup failure after commit, tenant audit visibility after actor transfer, immutable event scope, platform hospital and administrator-transfer events, suspension/reactivation without restoring independently disabled accounts, stale login snapshot rejection, authenticated maintenance recovery, and omission of patient searches/identifiers from real HTTP access logs.

Maintenance was verified through HTTP enable, fresh login, authenticated bootstrap, configuration read, disable, and normal route recovery. Flutter access/navigation tests passed separately. A complete browser reload through the deployed portal and production index/migration rollout remain unverified; see [open questions](open-questions.md#lifecycle-and-audit-rollout-verification-2026-09-28).

## Backend dependency compatibility, 2026-09-28

After pinning Mongoose 8.24.4, `npm.cmd run build` and six focused unit suites passed (51 tests). `npm.cmd audit --omit=dev --audit-level=high` reported zero vulnerabilities. Documentation validation, the strict MkDocs build, and OpenAPI lint passed; OpenAPI lint retained 104 pre-existing warnings. The full backend suite could not complete because Docker Desktop's Linux engine was unavailable to Testcontainers. Database-backed runtime compatibility remains unverified in this run. Mermaid and Structurizr inputs did not change.

With Docker Desktop's Linux engine available, the full backend suite passed: 42 suites and 649 tests using `npm.cmd test -- --runInBand` from `backend/`. The backend TypeScript build also passed. The follow-up fixes made audit middleware tolerate a response without `locals` and made the challenge-retention test assert the TTL index contract without depending on Mongoose's default `background` option.

## Account mutation dialogs, 2026-09-29

The administrator account edit and invitation dialogs, doctor registration, and patient onboarding were checked in the local Flutter tree. The focused administrator permission UI suite passed 21 tests, and the new one-time credential acknowledgment widget test passed. `dart analyze` reported no issues for the changed widgets and test. The Impeccable detector returned no findings for the changed Flutter widgets. `python scripts/docs/validate_docs.py` passed with 53 local links, 115 matching API operations, 18 matching models, and identical OpenAPI copies. `mkdocs build --strict` passed. OpenAPI lint reported a valid description with 104 existing warnings. Structurizr validation passed. Mermaid extraction and CLI rendering passed for all 27 diagrams. These are local checks; no live administrator, doctor, or patient account was created.

## Patient directory projection, 2026-09-29

The admin patient directory now returns a field-allowlisted profile. The focused database-backed `admincontroller` pagination and projection test passed (1 test), as did the backend TypeScript build, `python scripts/docs/validate_docs.py` (115 routes, 18 models, identical OpenAPI copies), `mkdocs build --strict`, OpenAPI lint (valid, 104 warnings), Mermaid extraction and rendering (27 diagrams), Structurizr validation, and `git diff --check`. The broader backend suite was not run for this scoped change.

## Session inventory and administrator step-up, 2026-09-29

The local backend build passed. The final full backend run passed 42 suites and 651 tests. The database-backed regression tests include missing or incorrect step-up rejection, single-use TOTP for account transfers, denial of MFA reset and policy writes without verification, caller-owned session inventory, and selective revocation. The Flutter administrator permission suite passed 22 tests, including the verification prompt and session list/revoke flow. The administrator repository, login repository, and patient repository suites passed another 22 tests, including verification-header forwarding. Dart analysis reported no issues in the changed application and administrator test files. The Impeccable detector returned no findings for the changed administrator UI files.

Documentation checks passed: `python scripts/docs/validate_docs.py` found 117 matching implemented and documented operations, 18 matching models, and byte-identical OpenAPI copies; `mkdocs build --strict` succeeded; OpenAPI lint found a valid contract with 106 non-blocking quality warnings; Mermaid extraction and rendering completed for 27 diagrams; Structurizr validation succeeded; `git diff --check` found no whitespace errors. Production gateway header redaction and live multi-device behavior remain unverified; see [open questions](open-questions.md#session-visibility-and-step-up-rollout-verification-2026-09-29).

## Backend-only Docker with Atlas, 2026-10-07

Initially validated the standalone Compose path before the Redis-container follow-up below, shared image configuration, Node 24 CI/CD runtime, and affected deployment documentation locally. No Atlas application startup, shared migration, or administrator seeding was performed.

| Check | Result | Evidence |
| --- | --- | --- |
| Compose configuration | Pass | Docker Compose 5.5.1 rendered the template with synthetic values: exactly one backend service, Atlas URI, raw dollar signs/quotes/Firebase JSON retained in the generated configuration, fixed container port 3000, localhost host ports 3000 and 3001, init process and 30-second stop grace period. Missing `.env.docker` was rejected. Temporary synthetic runtime files were removed |
| Backend build | Pass | `npm run build --prefix backend`; TypeScript and alias rewriting also passed under Node 24.21.0 using `npx --package=node@24` |
| Focused configuration tests | Pass | Node 24 Jest run: `fileassetconfig`, `firebaseconfig`, and `twilioconfig`; 3 suites, 16 tests |
| Runtime dependency smoke check | Pass | Node 24 imported Firebase Admin, MongoDB, Mongoose, Express, and native bcrypt; bcrypt hash/compare succeeded on the local Linux host |
| Image health command | Pass locally | The exact Dockerfile probe was executed under Node 24 against a disposable local HTTP server: `/health/ready` HTTP 200 exited 0, HTTP 503 exited 1, and refused connection exited 1 |
| Documentation contract | Pass | `python scripts/docs/validate_docs.py`: 71 local links, 117 matching API operations, 18 matching models, identical OpenAPI copies, 6 workflow YAML files |
| MkDocs strict build | Pass | `mkdocs build --strict` using the repository documentation requirements in an isolated temporary virtual environment |
| OpenAPI lint | Pass with warnings | `npm run lint:openapi --prefix backend`: valid contract, 106 existing quality warnings |
| Mermaid | Pass | All 27 diagrams extracted and rendered with Mermaid CLI 12.0.0 and local Chromium using the repository headless flags |
| Structurizr | Pass | Structurizr CLI 2025.11.09 `validate -workspace docs/architecture/workspace.dsl`; downloaded release CLI used directly with a checksum-verified temporary Java 21 runtime because Docker access was unavailable |
| Whitespace integrity | Pass | `git diff --check` |
| Docker image build and live Atlas readiness | Unverified | `docker build --target runtime -t vitalink-backend:validation backend` failed before building because this session cannot access `/var/run/docker.sock`. No populated backend/deployment environment file was present at this initial check |

Local dependency imports do not validate Alpine native binaries or actual container shutdown. Those checks require building and running the image with the intended Atlas and provider settings; see [open questions](open-questions.md#standalone-docker-and-atlas-verification-2026-10-07) and the [backend Docker runbook](../operations/backend-docker-runbook.md).

### Supplied development configuration follow-up

User-supplied environment values were saved only to the ignored `backend/.env.docker` file with mode 0600. Development mode, administrator MFA flag, FCM, and notification-delivery flags were preserved. The JWT inline comment was removed for raw env-file compatibility; a CORS origin's trailing slash was removed to match browser origins; `TRUST_PROXY=false` was selected for direct localhost HTTP access.

`docker compose -f backend/compose.yaml config --quiet` passed with the populated file. Under Node 24, the compiled backend configuration loaded with no missing development requirements; Firebase JSON/private-key parsing and local messaging initialization passed. The native MongoDB client authenticated and executed only `{ping: 1}` against the configured Atlas database, then closed. Atlas SRV lookup returned three records. No application server, schedulers, migrations, seeds, or push deliveries were run. The supplied Render-style Redis internal hostname failed local DNS lookup; no external URL has been supplied or verified. Docker daemon access remains denied, so container runtime verification is still pending.

The documentation contract and strict MkDocs build passed again after adding environment-conversion and Render Redis guidance. OpenAPI, Mermaid, and Structurizr inputs did not change in this follow-up.

### Container Redis follow-up

The user requested Redis as a container. The standalone stack now defines `backend` and `redis`, with Redis append-only data on a named volume and backend startup gated on Redis health. Compose overrides `REDIS_URL` with `redis://redis:6379`. Only the Redis URL and notification-delivery setting were updated in the ignored development runtime file; Atlas/provider credentials and mode 0600 were retained. ADR-0012 supersedes the earlier external-Redis placement without rewriting ADR-0011's history.

| Check | Result | Evidence |
| --- | --- | --- |
| Compose configuration | Pass | Docker Compose 5.5.1 rendered exactly `backend` and `redis`; verified internal Redis URL, preserved Atlas/development/FCM settings, enabled delivery, `service_healthy` dependency, Redis ping probe, append-only/every-second fsync/noeviction command, named `/data` volume, common network, no published Redis port, no backend secrets injected into Redis, and API host ports 3000/3001 |
| Hosted Redis override | Pass | A temporary env-file override supplied a stale hosted Redis URL; Compose still selected the container URL. Temporary files were removed |
| Runtime file isolation | Pass | `backend/.env.docker` remains Git-ignored, uses container Redis, enables delivery, and has mode 0600 |
| Documentation contract | Pass | `python scripts/docs/validate_docs.py`: 77 local links, 117 matching API operations, 18 matching models, identical OpenAPI copies, 6 workflow YAML files |
| MkDocs strict build | Pass | `mkdocs build --strict` |
| OpenAPI lint | Pass with warnings | Valid contract; 106 existing warnings. API inputs unchanged |
| Mermaid | Pass | All 28 diagrams extracted and rendered, including the standalone backend/Redis/Atlas deployment |
| Structurizr | Pass | Structurizr CLI 2025.11.09 validated the updated standalone Redis deployment model using the temporary Java 21 runtime |
| Whitespace integrity | Pass | `git diff --check` |
| Stack startup | Unverified | `docker compose -f backend/compose.yaml up --build -d --wait --wait-timeout 120` failed before container creation because `/var/run/docker.sock` access is denied. Non-interactive sudo also requires a password |

No application source, API payload, model schema, or index changed. Redis runtime connectivity/persistence, actual queue processing, container-to-Atlas connectivity, and full readiness remain unverified. No shared Redis state or Atlas data was migrated, and no background delivery was started by these local checks.

## PR #50 Backend CI dependency audit, 2026-10-11

Reproduced the failing `backend` job before edits with Node 24.21.0 and npm 11.19.0, matching the hosted job runtime. `npm audit --audit-level=high` exited 1 locally with 47 vulnerability entries (6 moderate, 39 high, 2 critical). The hosted log failed at that same step before build/tests; advisory counts changed since the 2026-10-07 run.

Compatible lockfile updates cover axios, proxy-addr, undici, gRPC, busboy, handlebars, ip-address, and the brace-expansion override; tsc-alias also updates within its declared range. Nodemon moves to development dependencies. The new gate preserves a strict production audit and a full-tree high/critical audit with the exact-path, expiring exception described in [ADR-0013](../decisions/0013-time-limited-development-audit-exception.md). The raw full-tree audit still reports 39 entries (5 moderate, 34 high); all high entries derive from the one unpatched development `braces` advisory.

| Check | Result | Evidence |
| --- | --- | --- |
| Clean dependency installation | Pass | `npm ci` under Node 24.21.0 / npm 11.19.0, using the refreshed lockfile |
| Production dependency audit | Pass | `npm audit --omit=dev --audit-level=high`: zero vulnerabilities |
| Combined dependency gate | Pass | `npm run audit:dependencies`; without the exception the full-tree branch exited 1, and with the reviewed policy it passed |
| Backend build | Pass | `npm run build`: TypeScript and tsc-alias |
| Tests independent of containers | Pass | `node node_modules/jest/bin/jest.js --runInBand --runTestsByPath` with the 31 test files that import neither Testcontainers nor the replica-set helper: 243 tests passed |
| Audit policy regressions | Pass | Included 8 tests using synthetic npm reports and the real audit-ci parser: allowed path before expiry; rejection of different high/critical advisories, unreviewed paths, a direct vulnerable dependency, the deadline, and registry errors; moderate threshold preserved |
| Documentation contract | Pass | `python scripts/docs/validate_docs.py`: 83 local links, 117 matching API operations, 18 matching models, identical OpenAPI copies, 6 workflow YAML files |
| MkDocs strict build | Pass | `mkdocs build --strict` in a temporary environment using `requirements-docs.txt` |
| OpenAPI lint | Pass with warnings | `npm run lint:openapi`: valid contract, 106 existing quality warnings |
| Whitespace integrity | Pass | `git diff --check` |
| Full Jest coverage / container tests | Unverified | `docker ps` was denied access to `/var/run/docker.sock`; the 12 container-dependent suites were not rerun and the full CI coverage threshold was not established locally |
| Hosted Backend CI rerun | Unverified | Local results establish the gate fix, not a new hosted run |

OpenAPI, Mermaid fences, and Structurizr inputs did not change. No application startup, shared database access, migrations, or provider deliveries were performed. The APK missing-secret failure is outside this backend fix. Follow-up requirements are recorded in [open questions](open-questions.md#backend-ci-audit-follow-up-2026-10-11).

## Administrator self-service password entry, 2026-10-21

The Personal Security page now links to the existing authenticated password-change screen independently of MFA loading. The focused Flutter administrator permission UI suite passed all 22 tests. The Impeccable detector reported no findings. Documentation validation passed with 90 links, 117 matching operations, 18 matching models, and identical OpenAPI copies; the strict MkDocs build and diff whitespace check passed. No API, model, Mermaid, or Structurizr inputs changed. No account password was changed. Browser rendering and hosted deployment are unverified.

## Administrator security navigation repair, 2026-10-21

A Zen browser check of the deployed dashboard reproduced the missing Personal Security sidebar item. The previous password-button change left its page unreachable. The dashboard now registers Personal Security for every administrator role without requiring platform or tenant management capabilities. All 25 administrator permission UI tests passed, including three regressions that select the sidebar item and follow Change password to its named route for App Admin, Hospital Admin, and Auditor. Documentation validation, strict MkDocs build, and the Impeccable detector passed. API, model, Mermaid, and Structurizr inputs did not change. No password was submitted. Post-deployment sidebar verification is pending.

## Doctor attention and monthly dose history, 2026-10-25

- Backend TypeScript build passed. Six attention/date/recording unit tests passed with `npm.cmd test --prefix backend -- --runInBand doctor-attention`.
- All 157 Flutter tests passed, including new month-default, day-selection, range-navigation, unavailable-history, review-sheet exit-animation, and failed-save retry tests. Focused Dart analysis of the changed doctor screens, models, widgets, and shared report card passed with no issues.
- Real HTTP acceptance against an isolated native local MongoDB replica set passed: roster summary projection, patient-specific targets, complete monthly history, explicit review and queue clearing, rejection of client-supplied reviewer IDs, unknown historical review state, cross-hospital read/write rejection, and new uploads pending without automatic critical classification. Acceptance used fictional local patients and restored their sample report state afterward.
- Docker Desktop could not start because its inference listener failed. The full Docker/Testcontainers backend suite was not run in this task. The native MongoDB preview is a separate disposable local database; no hosted/shared database or deployment was modified.
- Documentation contract passed with 117 matching API operations, 18 model markers, and byte-identical OpenAPI copies. Strict MkDocs build and OpenAPI lint passed; lint retained 106 warnings. All 28 Mermaid diagrams rendered. Structurizr inputs did not change, so its Docker validator was not rerun. `git diff --check` passed.
- The running Flutter web app was inspected with the local doctor account: attention categories, individual target context within patient records, monthly dose states, and calendar navigation were verified. The final overview shows only attention labels, and the calendar footer text is removed. Hospital acceptance and production rollout remain unverified.
