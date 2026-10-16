# ADR-0011: Add a standalone backend container using MongoDB Atlas

## Status

Accepted. Applies to the standalone Compose path; ADR-0007 continues to describe the EC2 blue-green path.

The external-Redis placement and disabled-delivery starter configuration are superseded by [ADR-0012](0012-containerized-redis-for-standalone-backend.md). The original decision below is retained as history.

## Context and problem statement

The user needs to containerize the backend alone while retaining the hosted MongoDB Atlas database. The existing deployment Compose file starts Redis, two API slots, and Nginx, which is unnecessary for this workflow. The previous Node 20 image also does not satisfy the locked Firebase Admin dependency's Node >=22 requirement.

## Decision drivers

- Run one backend service with externally supplied Atlas credentials.
- Keep secrets outside image layers and source control.
- Retain application readiness and production configuration requirements.
- Use a supported runtime compatible with the locked dependencies.

## Considered options

- Reuse the full EC2 blue-green stack.
- Replace EC2 deployment with a single backend service everywhere.
- Add a separate backend-only Compose path sharing the backend image.

## Decision outcome

Selected the separate `backend/compose.yaml` path. It builds the existing multi-stage backend image, loads an ignored `.env.docker` file in raw format, and publishes localhost HTTP on port 3000 by default. `MONGO_URI` points to hosted Atlas. Optional integrations remain external. The starter configuration disables notification delivery and FCM so it does not require a Redis container.

The shared image and backend CI use Node 24. The image healthcheck uses `/health/ready`, and Node runs directly to receive graceful shutdown signals. The standalone Compose service adds an init process and a 30-second stop grace period.

### Consequences

- Backend container startup is independent of the frontend and local database services.
- Atlas networking, database credentials, HTTPS termination, and enabled provider integrations require external configuration.
- Production readiness still requires storage, Twilio, MFA, and malware-scanner configuration.
- Single-container replacement has downtime; blue-green switching and rollback remain specific to the EC2 path.
- Delivery is opt-in and requires externally reachable Redis; multiple replicas also require shared Redis for distributed application behavior.
- The shared runtime update also applies to future builds of the existing EC2 slots; live rollout is unverified.

## Links

- [Backend Docker runbook](../operations/backend-docker-runbook.md)
- [Deployment architecture](../architecture/deployment.md)
- [ADR-0007](0007-blue-green-deployment.md)
- [Node release support](https://nodejs.org/en/about/previous-releases)
