# ADR-0009: Atomic account transitions and event-scoped audit history

## Status

Accepted, 2026-09-28.

## Context and Problem Statement

Independent account/profile/security writes can leave contradictory lifecycle state. Hospital suspension previously disabled individual accounts without retaining their prior state. Tenant audit reads inferred event ownership from current actor membership, causing history to move when administrators transferred.

## Decision Drivers

- Commit account and patient status consistently under concurrent changes and faults.
- Restore hospital access without reconstructing individual account decisions.
- Preserve historical tenant boundaries when actors or resources move.
- Keep committed mutations distinguishable from failed cleanup.

## Considered Options

- Independent writes with compensation and cascading hospital deactivation.
- Transactions for account transitions, an independent hospital access gate, and immutable event scope.
- A suspension snapshot and resumable account-by-account restoration workflow.

## Decision Outcome

Use the shared transactional account transition for individual and batch status changes. Include security generation in the commit and retain hospital/doctor guards and patient expected-state checks. Require transaction-capable MongoDB; do not fall back to independent writes.

Hospital suspension preserves individual status and relies on the existing hospital access checks. Member security versions invalidate in-flight login snapshots and existing sessions are revoked. Previously disabled accounts remain disabled on reactivation.

Audit rows store event hospital independently of the actor's current membership. Tenant queries match only this immutable field. Historical rows without trustworthy scope remain platform-only. For administrator transfers, the source hospital owns the event and the resulting hospital is recorded as resource scope. This replaces membership-derived audit visibility without reclassifying historical rows.

### Consequences

- Account/profile failure rolls back the whole lifecycle commit.
- Physical session cleanup can fail without weakening security-generation enforcement; responses expose cleanup status.
- Hospital reactivation restores eligible accounts without activating independently disabled accounts.
- Tenant readers cannot see unscoped historical rows until an independently evidenced migration exists.
- General administrative audit persistence remains post-mutation and reports `audit_recorded: false` on failure.

## Links

- [Lifecycle workflows](../workflows/features.md)
- [Schema evolution](../data/schema-evolution.md)
- [Validation evidence](../reference/validation.md)
