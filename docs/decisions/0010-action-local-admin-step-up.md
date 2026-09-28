# ADR-0010: Verify sensitive administrator writes in the action request

## Status

Accepted.

## Context and problem statement

A valid unlocked administrator session could reset another administrator's MFA or change account scope and role policy. Session owners also had no inventory of their active devices.

## Decision drivers

- Require fresh server verification for high-impact writes.
- Bind verification to the intended write without reusable grants.
- Retain the existing revocable session model.

## Considered options

- Require only an authenticated session.
- Issue a short-lived reusable step-up token.
- Verify password and TOTP in each sensitive mutation request.

## Decision outcome

Selected the request-local check. The server verifies the current password and atomically consumes an unused authenticator time step before executing account updates, MFA resets, and role-policy writes. The client holds credentials only for that request. The session inventory exposes caller-owned active sessions and permits selective revocation.

### Consequences

- One TOTP time step approves at most one write, so a second immediate write may need the next code.
- Administrators without an enrolled authenticator must enroll before these mutations.
- The two verification headers carry secrets over TLS and must be redacted by any request logging or gateway outside this repository.
- Session list results are capped at 100 entries and expire with the existing session TTL.

## Links

- [Authentication design](../security/authentication-and-authorization.md)
- [API contract](../api/openapi.yaml)
