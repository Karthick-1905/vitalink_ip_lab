# ADR-0012: Run Redis alongside the standalone backend in Compose

## Status

Accepted. Supersedes the external-Redis placement and disabled-delivery starter configuration in ADR-0011. The shared backend image, hosted Atlas database, and existing EC2 blue-green path are retained.

## Context and problem statement

The supplied backend configuration enabled notification delivery but used a Render internal Redis hostname that does not resolve from this development host. The user explicitly requested Docker Compose with Redis as a container, keeping MongoDB on hosted Atlas.

## Decision drivers

- Start backend and Redis through one Compose command.
- Provide a reachable Redis service for BullMQ, counters, tickets, and pub/sub.
- Preserve Redis state across container replacement.
- Keep MongoDB and frontend outside the Compose stack.

## Considered options

- Obtain and configure an external hosted Redis URL.
- Disable notification delivery and use process-local fallbacks.
- Run a persistent Redis service alongside the backend in Compose.

## Decision outcome

Selected the local Redis service. `backend/compose.yaml` runs `redis:7-alpine`, enables append-only persistence with once-per-second fsync and `noeviction`, and mounts the named `redis-data` volume at `/data`. Redis has no published host port. Backend startup waits for the Redis ping healthcheck and Compose overrides `REDIS_URL` with `redis://redis:6379`, including when an environment file still contains a hosted Redis URL.

The starter template enables notification delivery; FCM remains separately configurable. The ignored development runtime file uses the container Redis URL and retains the supplied hosted Atlas settings. No application API or persistence schema changes are required.

### Consequences

- One Compose stack supplies a Redis address reachable by the backend.
- Redis is part of the deployment host's failure domain; the named volume is persistence, not a backup or high-availability service.
- Existing hosted Redis keys, jobs, and pub/sub subscribers are not migrated or shared with this stack. The durable notification outbox remains in Atlas.
- Normal Compose shutdown retains the Redis volume; explicitly deleting volumes removes the local Redis state.
- Redis must become healthy before backend startup. Container execution remains unverified while Docker daemon access is unavailable.

## Links

- [ADR-0011](0011-backend-only-atlas-compose.md)
- [Backend Docker runbook](../operations/backend-docker-runbook.md)
- [Deployment architecture](../architecture/deployment.md)
- [Compose dependency healthchecks](https://docs.docker.com/compose/how-tos/startup-order/)
- [Redis persistence](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/)
