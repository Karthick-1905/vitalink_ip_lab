# ADR-0013: Bound the unpatched development dependency audit exception

## Status

Accepted for the Backend CI gate on 2026-10-11. The exception expires at 2026-11-10 00:00 UTC.

## Context and problem statement

PR #50's Backend CI job fails at `npm audit --audit-level=high`, before compilation or tests. Local reproduction with Node 24 confirmed high/critical findings in runtime packages and a high-severity stack-exhaustion advisory in `braces`. Compatible updates resolve the runtime findings. The `braces` advisory affects all published versions through 3.0.3 and has no upstream patch as of this review. It propagates through Jest 29, nodemon, and tsc-alias; forcibly changing Jest versions or downgrading development tools is not a reliable remediation for the affected parser.

## Decision drivers

- Keep every high/critical production finding blocking.
- Apply available compatible package fixes instead of suppressing patchable vulnerabilities.
- Keep auditing development dependencies for new high/critical advisories.
- Make the residual risk explicit, narrowly scoped, and time limited.
- Avoid an unrelated test-framework migration in a deployment change.

## Considered options

- Leave Backend CI blocked until upstream publishes a fix.
- Audit only production dependencies or disable audit failures.
- Force dependency downgrades or a test-framework migration.
- Update patchable packages and allow a time-limited exception for reviewed development paths.

## Decision outcome

Select the last option. `npm run audit:dependencies` runs an unconditional production high/critical audit, then a pinned `audit-ci` full-tree high/critical audit. `backend/audit-ci.json` allows only the enumerated paths for GHSA-vfj7-8cjw-p6xm until 2026-11-10 00:00 UTC. The production audit has no exceptions; moving `nodemon`, used only by the development command, into `devDependencies` removes it and its parser from the runtime installation.

The development glob inputs are controlled by repository files and developer commands. This bounds the exposure being accepted; it does not fix the parser. A malicious repository change or developer-supplied pattern can still crash development/build tooling. CI already executes repository code and is not treated as a sandbox for hostile pull requests by this decision.

Regression tests exercise the real audit-ci parser and verify rejection of other high/critical advisories, new paths, direct vulnerable-package dependencies, expired exceptions, and registry errors. They also verify that the existing moderate threshold behavior is preserved.

### Consequences

- Backend CI can proceed past the reviewed advisory while production dependencies have no reported vulnerabilities at the time of local validation.
- The raw full-tree `npm audit --audit-level=high` remains nonzero until upstream fixes `braces`; this is an explicit risk exception, not a claim of remediation.
- Exact path changes require review and may block CI even for the same advisory.
- Expiry makes the existing finding block again. Removing the exception is preferred to extending it; any extension requires a new review and configuration change.
- This changes Backend CI only; APK secret requirements and Backend CD behavior are unaffected.

## Links

- [Dependency audit policy](../architecture/ci-cd.md#backend-dependency-audit-policy)
- [Remaining verification questions](../reference/open-questions.md#backend-ci-audit-follow-up-2026-10-11)
- [Upstream braces advisory](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm)
- [audit-ci allowlist records and expiration](https://github.com/IBM/audit-ci#allowlists)
