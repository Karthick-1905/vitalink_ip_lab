# Backend Gap Analysis and Remediation Plan

## Scope
This document captures backend gaps found across:
- Security and configuration
- API/controller correctness and authorization
- Data model integrity
- Testing and operational readiness

Assessment was produced via parallel code audits over `backend/src`, `backend/tests`, and deployment assets.

## Executive Summary
Top risks are concentrated in:
1. Broken doctor-patient ownership data mapping (`assigned_doctor_id`) causing authorization and functional inconsistencies.
2. Known/default credentials and non-failing secret configuration paths in production-critical settings.
3. Missing authorization guards and incomplete validation on multiple doctor/patient/statistics endpoints.
4. Large coverage blind spots (admin/statistics routes) and integration tests coupled to real S3 credentials.

Recommended rollout:
1. Immediate risk containment (P0): credentials/secrets, ownership checks, null guards.
2. Data consistency and contract fixes (P1): schema-validator alignment and migration.
3. Quality and operability hardening (P2): tests, Docker/CI, observability.

---

## Detailed Gaps

## P0 (Critical - Fix First)

### 1) Default credentials and weak secret enforcement
- Severity: High
- Impact:
  - Production may boot with known admin credentials or weak defaults.
  - Password reset may assign predictable defaults.
- Evidence:
  - `backend/src/config/index.ts:30`
  - `backend/.env.example:1`
  - `backend/src/services/password.service.ts:6`
- Actions:
  - Remove fallback defaults for `DEFAULT_ADMIN_EMAIL`, `DEFAULT_ADMIN_PASSWORD`, `JWT_SECRET`, `MONGO_URI`.
  - Add mandatory env validation on startup; fail fast in non-local environments.
  - Replace default reset password with cryptographically random temporary password.
  - Add forced password change flag/workflow on next login.
- Acceptance criteria:
  - App exits at startup when required secrets are missing in non-dev env.
  - No hard-coded credentials remain in config or reset flows.
  - Reset returns one-time temporary credential path with forced rotation.

### 2) Doctor authorization and patient ownership checks incomplete
- Severity: High
- Impact:
  - Doctors may access patients not assigned to them.
  - Potential data exposure and unauthorized report modifications.
- Evidence:
  - `backend/src/controllers/doctor.controller.ts:37`
  - `backend/src/controllers/doctor.controller.ts:154`
  - `backend/src/controllers/doctor.controller.ts:183`
- Actions:
  - Enforce ownership checks for every doctor endpoint that reads/updates patient data.
  - Validate that `patient` and `patientProfile` exist before dereferencing.
  - Return explicit unauthorized/not-found responses with existing API error model.
- Acceptance criteria:
  - Access to non-assigned patient data is consistently denied.
  - No null dereference path remains in doctor patient/report flows.
  - Regression tests cover authorized and unauthorized access cases.

### 3) `assigned_doctor_id` reference model inconsistency
- Severity: High
- Impact:
  - Data relationship corruption between `User` and `DoctorProfile`.
  - Broken patient assignment queries, population, and statistics rollups.
- Evidence:
  - `backend/src/models/patientprofile.model.ts:5`
  - `backend/src/controllers/doctor.controller.ts:11`
  - `backend/src/scripts/assignPatientToDoctor.ts:27`
  - `backend/src/services/admin.service.ts:169`
  - `backend/src/services/statistics.service.ts:110`
- Actions:
  - Choose canonical reference type (recommended: doctor `User._id`).
  - Update doctor controller + assignment script to write/query canonical key only.
  - Add schema-level validation that assigned doctor resolves to a doctor user.
  - Run data migration to translate legacy stored IDs.
- Acceptance criteria:
  - All reads/writes use one doctor ID standard.
  - Existing records migrated and verified.
  - Doctor dashboard/list and stats agree on patient ownership.

### 4) Missing null guards in patient controllers
- Severity: High
- Impact:
  - Stale/deleted users can trigger server errors (500) instead of controlled 404/403.
- Evidence:
  - `backend/src/controllers/patient.controller.ts:60`
  - `backend/src/controllers/patient.controller.ts:108`
  - `backend/src/controllers/patient.controller.ts:152`
  - `backend/src/controllers/patient.controller.ts:192`
  - `backend/src/controllers/patient.controller.ts:274`
  - `backend/src/controllers/patient.controller.ts:320`
- Actions:
  - Add shared guard helper to assert user existence and type before `profile_id` access.
  - Reuse across all patient endpoints.
- Acceptance criteria:
  - Missing/stale user context returns deterministic 404/403 responses.
  - No patient endpoint throws on `profile_id` dereference.

---

## P1 (High - Next Sprint)

### 5) Validation gaps in doctor/statistics routes
- Severity: Medium-High
- Impact:
  - Malformed input can cause runtime errors or inconsistent behavior.
- Evidence:
  - `backend/src/routes/doctor.routes.ts:29`
  - `backend/src/routes/doctor.routes.ts:30`
  - `backend/src/routes/doctor.routes.ts:38`
  - `backend/src/controllers/statistics.controller.ts:10`
- Actions:
  - Add Zod schemas + `validate` middleware for all doctor mutating routes lacking validation.
  - Validate statistics query params (`period`, `start_date`, `end_date`) and reject invalid values early.
- Acceptance criteria:
  - Every mutating route is validation-protected.
  - Stats endpoints reject invalid queries with clear 4xx errors.

### 6) Data contract mismatch: `medical_config.diagnosis` not persisted
- Severity: High
- Impact:
  - Admin APIs accept diagnosis but Mongoose schema drops it (silent data loss).
- Evidence:
  - `backend/src/validators/admin.validator.ts:81`
  - `backend/src/services/admin.service.ts:201`
  - `backend/src/models/patientprofile.model.ts:24`
- Actions:
  - Align validator, service mapping, and schema:
    - Either add `diagnosis` field in schema or move it to `medical_history`.
  - Add test confirming diagnosis persists and is returned.
- Acceptance criteria:
  - Submitted diagnosis survives save/reload cycle.
  - No silent dropping of validated fields.

### 7) Unhandled promise rejection risk in upload endpoints
- Severity: Medium
- Impact:
  - Async upload errors can bypass centralized error handling.
- Evidence:
  - `backend/src/controllers/patient.controller.ts:342`
  - `backend/src/controllers/doctor.controller.ts:384`
  - Related route wrappers in `backend/src/routes/patient.routes.ts:29`, `backend/src/routes/doctor.routes.ts:38`
- Actions:
  - Wrap async handlers with `asyncHandler` or explicit `next(err)` forwarding.
  - Add tests simulating upload failure path.
- Acceptance criteria:
  - Upload failures return standardized API error responses.
  - No unhandled promise rejection in logs for upload paths.

### 8) Admin audit middleware exists but is not mounted
- Severity: Medium
- Impact:
  - Missing auditability for privileged actions.
- Evidence:
  - `backend/src/middlewares/audit.middleware.ts:1`
- Actions:
  - Mount `auditLogger` on admin mutation routes after auth middleware.
  - Define minimum audit fields and retention policy.
- Acceptance criteria:
  - Admin create/update/delete flows emit audit records with actor and action context.

### 9) CORS policy too permissive for production
- Severity: Medium
- Impact:
  - Increased exposure to cross-origin abuse and token misuse patterns.
- Evidence:
  - `backend/src/app.ts:25`
- Actions:
  - Replace wildcard origin with env-driven allowlist.
  - Tune headers/methods/credentials by environment.
- Acceptance criteria:
  - Only trusted origins are allowed in production.
  - CORS behavior is testable by environment config.

### 10) File upload guardrails missing
- Severity: Medium
- Impact:
  - Large or malformed uploads can stress server/disk and increase abuse risk.
- Evidence:
  - `backend/src/routes/patient.routes.ts:17`
  - `backend/src/routes/doctor.routes.ts:19`
- Actions:
  - Set strict multer limits (`fileSize`, count, fields).
  - Enforce MIME/type allowlist and reject invalid extensions.
  - Prefer memory/streaming path to S3 with bounded buffers.
- Acceptance criteria:
  - Oversized and disallowed uploads are rejected with 4xx.
  - No uncontrolled growth under `backend/uploads`.

---

## P2 (Quality and Operations Hardening)

### 11) Test suite over-coupled to real S3 credentials
- Severity: Medium
- Impact:
  - Local/CI fragility; external dependency and network latency in core test runs.
- Evidence:
  - `backend/tests/doctorcontroller.test.ts:1`
  - `backend/tests/patient_file_upload.test.ts:1`
  - `backend/src/config/index.ts:1`
- Actions:
  - Mock/stub S3 client and presigned URL flows in tests.
  - Keep Mongo testcontainer integration but isolate external cloud dependencies.
  - Split tests into unit/integration categories.
- Acceptance criteria:
  - Default `npm test` runs without real S3 credentials.
  - CI runtime and flakiness reduced.

### 12) Coverage gap for admin/statistics endpoints
- Severity: Medium
- Impact:
  - Regressions can ship undetected in critical admin and analytics APIs.
- Evidence:
  - `backend/src/routes/admin.routes.ts:1`
  - `backend/src/routes/statistics.routes.ts:1`
  - Existing tests: `backend/tests/authcontroller.test.ts:1`, `backend/tests/doctorcontroller.test.ts:1`, `backend/tests/patientcontroller.test.ts:1`
- Actions:
  - Add targeted tests for admin onboarding, updates, notifications, audit logs, and statistics queries.
  - Introduce coverage thresholds in Jest config.
- Acceptance criteria:
  - Admin/statistics route behaviors covered with success + failure cases.
  - Coverage gates enforced in CI.

### 13) Observability underused (Loki dependency unused, no health metrics)
- Severity: Medium
- Impact:
  - Slower incident diagnosis and limited production insight.
- Evidence:
  - `backend/src/utils/logger.ts:1`
  - `backend/package.json:17`
  - `backend/src/app.ts:1`
- Actions:
  - Wire structured logging transport (Loki or equivalent) by env.
  - Add health/readiness endpoint and core request/error metrics.
  - Standardize correlation IDs through middleware and logs.
- Acceptance criteria:
  - Logs carry traceable metadata (request ID, user, route, status, latency).
  - Health endpoint usable by orchestration and monitoring.

### 14) Deployment/automation hardening (Docker/scripts/CI)
- Severity: Medium
- Impact:
  - Build reproducibility and runtime behavior are not hardened for automated environments.
- Evidence:
  - `backend/Dockerfile:4`
  - `backend/package.json:6`
  - `backend/fix_therapy_date.js:1`
  - `backend/src/scripts/createAdminUser.ts:1`
  - `backend/src/scripts/assignPatientToDoctor.ts:1`
- Actions:
  - Improve Docker layering and production runtime config; add container healthcheck.
  - Add CI script/workflow (`build` + `test` + coverage gate).
  - Remove hard-coded script constants; validate required inputs.
- Acceptance criteria:
  - Deterministic container build and startup behavior.
  - CI blocks merges on failing build/tests/coverage.

---

## Implementation Roadmap

## Phase 0 (Week 1): Containment
- Remove credential defaults and enforce required env vars.
- Patch doctor authorization + patient null guards.
- Define canonical doctor reference strategy (`User._id`) and implement write-path changes.
- Deliverables:
  - Security patch PR
  - Authorization patch PR
  - Data-model decision ADR (short)

## Phase 1 (Week 2): Consistency and Contracts
- Complete `assigned_doctor_id` migration and regression coverage.
- Fix `diagnosis` schema-validator mismatch.
- Add missing route validations and async error wrappers.
- Mount admin audit middleware.
- Deliverables:
  - Data migration script + verification report
  - Validation and controller hardening PR

## Phase 2 (Week 3): Test and Ops Hardening
- Decouple tests from real S3, add admin/statistics tests, set coverage thresholds.
- Harden Dockerfile and CI pipeline.
- Add structured logging transport and health/readiness checks.
- Deliverables:
  - CI workflow updates
  - Observability baseline rollout

---

## Ownership Model (Suggested)
- Security/Platform engineer:
  - Env validation, credentials policy, CORS, upload limits, Docker hardening.
- Backend API engineer:
  - Controller guards, authorization checks, validation middleware, async error flow.
- Data engineer/backend engineer:
  - Schema alignment, ID migration, integrity checks.
- QA/automation engineer:
  - Coverage expansion, CI thresholds, test dependency isolation.

---

## Tracking Checklist
- [ ] P0.1 Remove default credentials and enforce required env vars
- [ ] P0.2 Add doctor ownership checks on all patient-facing doctor endpoints
- [ ] P0.3 Fix patient null guard paths and error contracts
- [ ] P0.4 Canonicalize `assigned_doctor_id` + migrate data
- [ ] P1.1 Add missing Zod validations for doctor/statistics routes
- [ ] P1.2 Align `diagnosis` across validator/service/schema
- [ ] P1.3 Wrap upload handlers for centralized async error handling
- [ ] P1.4 Mount admin audit middleware and verify events
- [ ] P1.5 Restrict CORS by environment allowlist
- [ ] P1.6 Add upload limits and type checks
- [ ] P2.1 Mock S3 in tests; keep DB integration deterministic
- [ ] P2.2 Add admin/statistics test suites + coverage gates
- [ ] P2.3 Wire structured logging + health/readiness endpoints
- [ ] P2.4 Harden Docker and CI scripts/workflows

---

## Notes
- This plan intentionally prioritizes risk reduction and data correctness before broader observability and build optimization.
- Run migration in staging first and validate patient-doctor ownership counts before production rollout.
