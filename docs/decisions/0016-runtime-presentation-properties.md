# ADR-0016: Publish versioned runtime presentation properties

## Status

Accepted for local implementation on 2026-10-27. Production rollout is not verified.

## Context and problem statement

Flutter bundled hospital artwork and embedded screen copy in widgets. Routine branding and wording changes therefore needed a new client build. Existing SystemConfig manages clinical thresholds and operational/security settings, which must not become public presentation configuration.

## Decision drivers

- Update supported display properties without requiring another client installation.
- Preserve offline startup, active forms, stable navigation identifiers, and backend policy enforcement.
- Keep drafts private and provide publication history, rollback, and concurrency control.
- Keep public branding uploads separate from private clinical files.

## Considered options

- Centralize Dart constants only. This simplifies source maintenance but still requires rebuilding clients.
- Download an unvalidated static file. This lacks scoped editing, concurrency protection, and publication history.
- Publish a validated JSON document through the existing backend and administrator capabilities.

## Decision outcome

Choose the backend publication approach. A separate AppProperties singleton stores draft/published overrides and the latest 20 publication history entries. One version-conditioned MongoDB update changes the draft or publication and increments the edit version atomically. Restoring an earlier publication creates a new revision. Existing global configuration capabilities and mutation auditing guard management routes.

The reviewed JSON default catalogue generates identical backend defaults and a bundled Dart map. Flutter caches compatible snapshots, refreshes at startup/resume, and retains defaults or the last working snapshot on failures. Image uploads use public, content-addressed BrandAsset documents with explicit byte/dimension bounds. Existing patient FileAsset storage/access rules are unchanged.

### Consequences

- A first client release is necessary; future supported property changes can be published independently.
- Published configuration and uploaded brand artwork are public. Secrets and clinical policy remain outside this layer.
- Global configuration is implemented first. Hospital-specific overrides require a later design and authorization review.
- Adding or removing consumers still needs code and compatibility handling. Internal identifiers remain stable code contracts.
- MongoDB holds small branding images, avoiding a new storage service, but unreferenced asset retention needs operational monitoring.
- Property editing does not construct arbitrary widgets, execute downloaded code, or introduce new workflows.

## Links

- [Application properties runbook](../operations/application-properties.md)
- [Open questions](../reference/open-questions.md)
