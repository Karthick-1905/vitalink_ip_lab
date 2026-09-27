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
