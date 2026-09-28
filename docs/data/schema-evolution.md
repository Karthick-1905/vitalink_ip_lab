# Schema evolution and migrations

Mongoose schema declarations are the current model source of truth. Existing MongoDB documents are not automatically rewritten when a TypeScript default changes, so compatibility and explicit migrations matter.

The backend pins Mongoose 8.24.4. The previous 9.10.2 dependency did not compile against the repository's model and test types; the older 9.1.6 release compiled but carried a known security advisory. This dependency change does not alter stored document shapes or require a data migration. Run the backend build and database-backed test suites before deploying a dependency upgrade.

## Tracked migration commands

| Command | Script | Purpose/notes from source |
| --- | --- | --- |
| `migrate:assigned-doctor-ids` | `migrateAssignedDoctorIds.ts` | Normalize patient assignments to doctor `User._id` |
| `migrate:patient-hospital-ids` | `backfillPatientHospitalIds.ts` | Backfill tenant ownership; supports dry run and `--execute` |
| `migrate:inr-critical-flags` | `migrateInrCriticalFlags.ts` | Materialize INR critical flags |
| `migrate:auth-schema-defaults` | `migrateAuthSchemaDefaults.ts` | Required exact-match security generations and auth indexes; documented as idempotent |
| `migrate:doctor-update-notifications` | `migrateDoctorChangeEventsToNotifications.ts` | Convert legacy doctor change events into notifications |
| `migrate:file-assets` | `backfillFileAssets.ts` | Build/attach tenant file metadata; dry-run by default, `--execute` writes |
| `migrate:device-tokens` | `migrateDeviceTokenOwnership.ts` | Enforce one current owner per physical FCM token |
| `migrate:admin-rbac-v2` | `migrateAdminRbacV2.ts` | Seed fixed V2 policies and translate legacy permissions transactionally |

Production variants use the compiled `:prod` npm scripts. `purge:patient-files` is an irreversible, separately authorized operational workflow, not a normal migration.

## Safe change workflow

1. Back up or establish a verified restore point; the repository cannot perform or prove this step.
2. Deploy code compatible with both old and new shapes where rolling deployment requires it.
3. Run the migration in dry-run mode when supported and retain its summary.
4. Apply against the intended environment once, from the active application image or a controlled job.
5. Verify matched/modified/skipped/failed counts, uniqueness/index state, tenant ownership, and representative records.
6. Run authentication, clinical, file, notification, and administrator smoke checks affected by the migration.
7. Remove legacy compatibility only in a later release after every environment is verified.

## Required deployment ordering

- Run `migrateAuthSchemaDefaults` before relying on login, OTP, administrator MFA, or exact security-generation predicates after upgrading legacy data.
- Complete patient hospital and assigned-doctor backfills before relying on strict tenant/assignment enforcement for legacy records.
- Complete file-asset and device-token migrations before enabling their stricter ownership paths for an existing deployment.
- Complete the RBAC V2 migration before depending on persisted administrator capability policy.

The exact per-environment sequence depends on existing schema state and is an operator decision. No deployment workflow automatically runs these scripts.

## Rollback posture

Application rollback does not automatically reverse a data migration. A migration that adds compatible fields can usually remain in place while code rolls back; destructive or semantic rewrites require a separately designed reverse/restore plan. The checked-in scripts do not collectively provide a universal database rollback mechanism.

## Event-scoped audit rollout

New audit rows carry immutable scope where the writer has reliable event context. Tenant queries require an exact `event_hospital_id` match, including when filtering by actor. Actor transfers cannot move older events between tenants. Platform readers retain access to unscoped rows. Successful tenant administrative mutations use their authorized request scope; hospital management uses the affected hospital. Administrator transfers retain the source hospital as event scope and record the resulting resource hospital separately. New tenant administrator creation uses the server-returned hospital identity. Authentication writers snapshot the actor's persisted profile when writing the event. Failed administrative attempts without verified resource scope remain platform-only.

Deploy all audit writers and readers together and ensure the new `{ event_hospital_id: 1, createdAt: -1, _id: -1 }` index exists. Do not infer historical scope from current profiles. This change deliberately leaves old rows unscoped; a future evidence-backed migration needs independent historical records and separate review. Rolling back to membership-based readers would restore the original disclosure risk.
