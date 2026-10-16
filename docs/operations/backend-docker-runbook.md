# Backend and Redis Docker with MongoDB Atlas

`backend/compose.yaml` runs one Express backend container and one Redis container. MongoDB Atlas remains hosted; the frontend and Nginx are outside this Compose stack. The existing EC2 blue-green path is described separately in the [deployment runbook](deployment-runbook.md).

## Configure runtime values

Use Docker Engine and Docker Compose 2.30.0 or newer. From the repository root:

```bash
cp backend/.env.docker.example backend/.env.docker
chmod 600 backend/.env.docker
```

Edit `backend/.env.docker` locally. This ignored file is excluded from the image build. Do not commit secrets. Compose uses [raw env-file format](https://docs.docker.com/reference/compose-file/services/#format): use unquoted `KEY=value` lines with no inline comments. Dollar signs and single-line Firebase JSON are passed literally. `PORT` is fixed to 3000 inside the container by Compose.

Compose also sets `REDIS_URL=redis://redis:6379`, overriding any Redis URL in the environment file so the backend uses this stack's Redis service. The template and configured development file enable notification delivery. FCM remains a separate flag and requires Firebase credentials when enabled.

When adapting an existing dotenv file, remove inline comments from values before copying them into the raw file; otherwise the comment becomes part of the value, including for `JWT_SECRET`. Browser CORS entries must be origins without paths or trailing slashes, for example `https://app.example.com`. Preserve the intended `NODE_ENV`; using the production template does not require changing an existing development profile to production.

Set `MONGO_URI` to the Atlas application's connection string, including the intended database name:

```dotenv
MONGO_URI=mongodb+srv://USERNAME:URL_ENCODED_PASSWORD@YOUR_CLUSTER.mongodb.net/VitaLink?retryWrites=true&w=majority
```

Use an Atlas database user with access to that database. Percent-encode reserved characters in the username/password. Add the Docker host's public egress IP to the Atlas project IP access list and allow outbound DNS and cluster connections; the container's private bridge address is not the public source IP Atlas sees. Follow [Atlas connection setup](https://www.mongodb.com/docs/atlas/driver-connection/) for your public or private networking arrangement. An authenticated read-only ping succeeded from this development host with the supplied settings; connectivity from the actual backend container remains unverified.

The template defaults to `NODE_ENV=production`. Populate `JWT_SECRET`, `ADMIN_TOTP_ENCRYPTION_KEY`, the S3-compatible storage keys/bucket, Twilio Verify credentials, and an HTTPS `MALWARE_SCAN_URL`. Set `FILE_ASSET_LEGACY_CUTOFF_AT` to the coordinated legacy-writer migration instant in ISO 8601 format. Set `CORS_ALLOWED_ORIGINS` to the actual Flutter web origins. The full inventory is in `backend/.env.example` and [environment configuration](../environments.md). Existing production requirements remain enforced by the application; an Atlas URI alone is insufficient for production readiness.

For local development against a dedicated non-production Atlas database, set `NODE_ENV=development` and `MALWARE_SCAN_ENABLED=false`; optional provider values may then be left empty. Leave `FILE_ASSET_LEGACY_CUTOFF_AT` empty to use the existing development default. Use developer JWT/MFA keys and enable only the integrations needed for that work.

`TRUST_PROXY=false` matches direct access to the published port. If an existing trusted reverse proxy terminates HTTPS, set the appropriate trusted hop count. The port binds to `127.0.0.1`, so an existing host proxy or local client can reach it. Public access needs an HTTPS edge configured outside this Compose file.

## Build, start, and inspect

From the repository root:

```bash
docker compose -f backend/compose.yaml config --quiet
docker compose -f backend/compose.yaml up --build -d --wait --wait-timeout 120
docker compose -f backend/compose.yaml ps
docker compose -f backend/compose.yaml exec redis redis-cli ping
curl -fsS http://127.0.0.1:3000/health/live
curl -fsS http://127.0.0.1:3000/health/ready
docker compose -f backend/compose.yaml logs --tail 100 backend
```

Redis must pass its `redis-cli ping` healthcheck before Compose starts the backend. The backend image builds TypeScript using the committed npm lockfile, installs only production dependencies in the final Node 24 Alpine stage, includes backend API documentation, and runs as the `node` user. Node starts directly so stop signals reach the existing graceful shutdown handler; Compose provides an init process and a 30-second shutdown window. The image healthcheck calls `/health/ready` and requires HTTP 200.

To use another host port without changing the container's port:

```bash
BACKEND_HOST_PORT=3001 docker compose -f backend/compose.yaml up --build -d --wait --wait-timeout 120
curl -fsS http://127.0.0.1:3001/health/ready
```

Keep that host-port value consistent on later Compose commands. Flutter can run separately with `API_BASE_URL=http://localhost:3000` and `API_PATH_PREFIX=/api/v1`; a phone or remote browser needs a reachable HTTPS API origin.

## Redis persistence and push delivery

The `redis:7-alpine` container stores data under `/data` in the named `redis-data` volume. It enables append-only persistence with a once-per-second fsync policy and uses `noeviction` for queue compatibility. Both services share the Compose network. Redis has no published host port; the backend reaches it at `redis:6379`. The Redis container receives no backend provider secrets.

`NOTIFICATION_DELIVERY_ENABLED=true` enables the BullMQ worker and recovery poller. To send push notifications, also set `FCM_ENABLED=true` and provide the JSON `FIREBASE_SERVICE_ACCOUNT`, plus the existing device-token migration. The template defaults FCM off; the supplied development file preserves the user's enabled FCM setting. Clinical schedulers continue to run in the backend. Use one backend instance for this standalone setup.

The standalone stack now uses its own Redis data rather than the previous hosted Render Redis. Existing Render queue keys, counters, tickets, and pub/sub subscribers are not copied or shared. The durable notification outbox remains in the configured Atlas database. See [ADR-0012](../decisions/0012-containerized-redis-for-standalone-backend.md).

## Upgrade and stop

After changing code or runtime values, recreate the container:

```bash
docker compose -f backend/compose.yaml up --build -d --wait --wait-timeout 120
```

Replacing the single backend instance has downtime and no automatic rollback slot. It does not use `deploy/deploy.sh` or switch blue-green traffic. Atlas and object-storage data live outside the container. Redis state is persisted in the local named volume.

Migrations and administrator seeding remain explicit operational commands. Follow the [migration checkpoint](deployment-runbook.md#migration-checkpoint) before running an applicable script against Atlas. The equivalent command target for this setup is:

```bash
docker compose -f backend/compose.yaml exec backend node build/src/scripts/migrateAuthSchemaDefaults.js
```

Stop and remove both containers and the network:

```bash
docker compose -f backend/compose.yaml down
```

This command retains the Redis named volume for the next startup. Adding `--volumes` would also delete that stack's Redis data.

## Troubleshooting

- Build failure: check dependency installation and TypeScript output in the build logs; the Docker daemon must be accessible to the calling user.
- Startup database failure: verify the intended Atlas database user, encoded URI, host egress IP access-list entry, and DNS/outbound connectivity.
- Redis fails startup or healthcheck: inspect `docker compose -f backend/compose.yaml logs --tail 100 redis` and the volume/disk state. Redis must be healthy before backend startup.
- Readiness 503: inspect `/health/ready` and the logs. Missing production variables, Firebase initialization failure, or enabled delivery without Redis prevent readiness.
- Port conflict: use `BACKEND_HOST_PORT` as shown above.
- Docker marks a running container unhealthy: inspect readiness; Docker's restart policy restarts exited containers, not containers that are merely unhealthy.
