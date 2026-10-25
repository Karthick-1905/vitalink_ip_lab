# Open questions and assumptions

No implementation claim in this site depends on the following unknowns. Each item records inspected evidence and what is missing.

## OQ-01: What is the live production topology?

**Assumption used in diagrams:** the EC2/Docker topology is labeled “repository-defined production,” not “currently live.”

**Inspected:** `.github/workflows/backend-cd.yml`, `deploy/*`, `.github/workflows/deploy_web.yml`, `frontend/vercel.json`, `frontend/web/vercel.json`, `frontend/lib/core/constants/strings.dart`, APK workflow.

**Missing evidence:** deployment inventory or provider console state showing the live frontend origin, backend origin, TLS terminator, MongoDB/Redis hosts, regions, and active release.

## OQ-02: What backup, restore, RPO, and RTO policy applies?

**Assumption:** runbooks require an externally verified restore point but cannot create one.

**Inspected:** deployment scripts/README, Docker Compose volumes, GitHub Actions, models/migrations, existing environment documentation.

**Missing evidence:** scheduled backup configuration, retention, encryption, restore command, restore drill, ownership, RPO, RTO, and last successful test.

## OQ-03: Who owns support, incidents, security, privacy, and clinical governance?

**Assumption:** these stakeholder functions are implied but unnamed.

**Inspected:** product guidance, audit/access/security code, workflows, runbooks, repository documentation.

**Missing evidence:** contact/rota, escalation path, severity policy, breach notification process, clinical approval authority, data controller/processor roles, and regulator/customer obligations.

## OQ-04: What SLOs, capacity limits, and alert thresholds are approved?

**Assumption:** none are stated; monitoring recommendations are target state.

**Inspected:** health endpoints, logger/Loki transport, notification metrics, rate limits, timeouts, worker concurrency, Docker/Nginx limits, CI.

**Missing evidence:** availability/latency targets, load model, tenant/user/SSE/queue/storage capacity, dashboards, alert rules, paging response, and error budget.

## OQ-05: What retention/deletion policy applies to clinical, audit, billing, and account data?

**Assumption:** only schema TTLs are described as implemented.

**Inspected:** every model, patient file purge, notification delivery retention, challenge/session TTLs, environment examples.

**Missing evidence:** approved retention schedule, legal holds, audit/invoice/profile deletion rules, object-storage lifecycle, backup deletion, and patient data-subject workflow.

## OQ-06: Which payment provider and reconciliation process are used?

**Assumption:** the integration is provider-neutral.

**Inspected:** checkout and webhook services/controllers/routes, invoice model, environment example, OpenAPI.

**Missing evidence:** provider identity, production API contract, currency policy, refund/dispute/reconciliation jobs, key rotation, settlement reporting, and PCI scope.

## OQ-07: Is malware scanning required in each environment?

**Implemented behavior:** scanning defaults on in production/staging, and readiness requires the enabled flag and an HTTPS scanner URL. Development/test defaults off; when enabled, upload failures fail closed.

**Inspected:** `malware-scan.service.ts`, file upload/asset services, config and environment examples, tests.

**Missing evidence:** approved scanner product, service ownership, signature/update process, latency/availability target, quarantine procedure, and production flag state.

## OQ-08: What compliance and encryption controls exist outside the application?

**Assumption:** provider/storage encryption and certification are not claimed.

**Inspected:** application crypto/logging/file/session code, deployment and environment files.

**Missing evidence:** MongoDB/Redis/S3/backups encryption settings, KMS/secret manager, key rotation, access reviews, vulnerability management, penetration tests, and healthcare/privacy certification.

## OQ-09: What is the intended status of ML artifacts?

**Assumption:** ML is excluded from runtime architecture.

**Inspected:** all tracked `ml-service` and `ml_pipeline` files, backend/frontend dependency/import/URL searches.

**Missing evidence:** serving source, API contract, deployment configuration, model governance, validation, monitoring, approval, and any call from the application.

## OQ-10: What client/platform support and accessibility target is required?

**Assumption:** Flutter targets web/Android/iOS and product guidance aims for WCAG AA, but formal conformance is not claimed.

**Inspected:** Flutter platforms, routes/components, `PRODUCT.md`, analyzer/test configuration, build workflows.

**Missing evidence:** supported OS/browser/device matrix, assistive-technology test plan, audit results, localization policy, and conformance statement.

## Lifecycle and audit rollout verification, 2026-09-28

The fixes are local source changes. Live deployment, creation of the audit scope index in production, and recovery of accounts disabled by historical hospital suspensions have not been verified. No shared database migration was run. Historical audit hospital scope cannot be established from current membership and remains unclassified. The maintenance HTTP regression exercises fresh login and bootstrap; a browser reload through the Flutter portal remains a separate end-to-end check.

## Session visibility and step-up rollout verification, 2026-09-29

The local backend tests cover session revocation and request-local verification. Production gateway and observability configuration have not been inspected for redaction of `X-Step-Up-Password` and `X-Step-Up-Totp`. A deployed Flutter web flow with CORS, real authenticator devices, and multi-device sign-out remains unverified.

## Standalone Docker and Atlas verification, 2026-10-07

The standalone backend Compose path is source configuration. After the initial checks, user-supplied development settings were saved to ignored `backend/.env.docker` with mode 0600. An authenticated Atlas read-only ping succeeded from the local host; Firebase JSON/private-key parsing and local messaging initialization also succeeded without sending notifications. The supplied Render-style internal Redis hostname did not resolve from this host. The user subsequently requested a Redis container; Compose now defines persistent Redis, gates backend startup on its healthcheck, and overrides `REDIS_URL` with `redis://redis:6379`. The ignored runtime file was also updated to that URL with notification delivery enabled. No shared database migration, seeding, or application startup against Atlas was performed. Docker daemon access is denied to this session; image build, actual Redis startup/persistence, container-to-Atlas connectivity, runtime readiness, and graceful container shutdown remain unverified. Hosted Redis state was not migrated. The Node 24 image also affects future EC2 blue-green builds; no live rollout was performed.

## Backend CI audit follow-up, 2026-10-11

The development-only `braces` stack-exhaustion advisory has no upstream fix at this review. Recheck upstream and remove the exact-path exception before its 2026-11-10 00:00 UTC expiry; do not treat the exception as a patched dependency. Local production audit success does not prove the absence of undisclosed vulnerabilities. Docker daemon access is still denied, so the database-backed tests and runtime image compatibility for the refreshed lockfile remain unverified locally. A successful hosted Backend CI rerun must also be established separately from the local audit/build/unit checks. The unrelated APK job's missing `GOOGLE_SERVICES_JSON` secret remains outside this fix.

## Administrator password control rollout, 2026-10-21

The Personal Security password entry is implemented locally. A live browser check and deployment of this frontend change remain unverified. ADM01 has not been changed or checked against a shared database; the account owner will submit the current and new passwords through the UI after rollout.

## Administrator security sidebar follow-up, 2026-10-21

Zen reproduced that Personal Security was absent from the deployed dashboard sidebar. The sidebar destination is now registered locally for all administrator roles; role-by-role navigation tests pass. Hosted verification of this follow-up remains pending. The account owner must enter and submit passwords personally.

## Doctor attention workflow, 2026-10-25

The source implements an explainable review queue and monthly recording calendar. Live deployment and hospital acceptance are not established. Historical report review cannot be inferred from notes; older entries remain unknown. Historical weekly prescription versions are absent, so old schedule gaps are estimates under the current plan. Reminder jobs retain their existing delivery eligibility and may differ from the overview for profiles missing therapy start. Global INR threshold configuration and the legacy/manual critical update field remain for compatibility; new upload classification and doctor overview do not use them. No historical critical-flag migration was run. The existing roster API is unpaginated; production-scale performance and queue acceptance need separate verification. Structured health-report review and symptom severity are outside this change.
