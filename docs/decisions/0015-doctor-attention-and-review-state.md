# ADR-0015: Explainable doctor attention and explicit report review

## Status

Accepted for the local implementation, 2026-10-25. Hosted deployment is unverified.

## Context

The doctor landing screen exposed a demographic directory, while reports, review dates, and dose records were available only inside individual records. Global INR thresholds cannot establish urgency for an individual patient. Report notes and notification read state do not prove clinical review. Historical weekly prescription versions are not stored.

## Decision

Compute a bounded summary per assigned active patient on the existing roster route. Order by pending report work, due reviews, other follow-up, and then no outstanding work, with waiting-time and stable-ID tie-breakers. INR target comparison is patient-specific context, never an urgency score. New submissions are pending and are not automatically marked critical. Retain legacy/manual critical fields for compatibility without using them in the overview or shared report cards.

Store optional review status, server-owned reviewing User reference, and timestamp on each embedded INR entry. Historical entries remain unknown until explicitly reviewed. Saving notes alone does not mark review complete. No new collection or index is required.

Add server-calculated dose recording history to authorized doctor detail responses for the current and two previous months. Default the client to the current month. Derive past scheduling from the current weekly prescription and disclose that limitation. Missing taken entries are not confirmed missed medication. Keep the existing Flutter portal layout, components, and theme.

## Consequences

Doctors can find and complete review work with an explanation for ordering. Additional review metadata is persisted without an invented historical backfill. The roster response now provides `attention` rather than embedded INR history; the updated client must be rolled out with this API contract. Dose history is an estimate where past prescriptions changed. The existing unpaginated roster remains a scaling limitation. Clinical governance, historical prescription snapshots, and symptom triage remain separate work.
