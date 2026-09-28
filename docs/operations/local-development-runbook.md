# Local administrator UI preview

Use this setup to preview the Flutter app against a local backend and an isolated local MongoDB database. Run each section in its own PowerShell terminal. Docker, Node dependencies, and Flutter dependencies must already be installed.

The backend configures MongoDB as `VitaLink_codex_local`, allows the Flutter origin on localhost port 7357, and disables Firebase, Redis, notification delivery, and malware scanning. These process-level values override `backend/.env`; do not start this preview against the shared database values in that file.

## 1. Start the local MongoDB replica set

The existing container keeps its local data across stop/start. Start it if it is stopped, then wait for its replica set to become primary:

```powershell
if ((docker inspect -f '{{.State.Running}}' vitalink-codex-mongo 2>$null) -ne 'true') {
  docker start vitalink-codex-mongo
}

$state = ''
for ($i = 0; $i -lt 20; $i++) {
  $state = (docker exec vitalink-codex-mongo mongosh --quiet --eval "try { rs.status().myState } catch(e) { 0 }" 2>$null).Trim()
  if ($state -eq '1') { break }
  Start-Sleep -Seconds 2
}
if ($state -ne '1') { throw 'Local MongoDB replica set is not ready' }
```

If the container was removed, recreate and initialize it before continuing:

```powershell
docker run -d --name vitalink-codex-mongo --publish 127.0.0.1:27017:27017 mongo:7.0 --replSet rs0 --bind_ip_all
Start-Sleep -Seconds 3
docker exec vitalink-codex-mongo mongosh --quiet --eval "rs.initiate({_id:'rs0',members:[{_id:0,host:'127.0.0.1:27017'}]})"
```

Removing the container can leave its anonymous data volumes detached; a replacement container will usually start with a new empty database. Recreate the local demo accounts and role policies before trying to log in to that fresh database.

## 2. Build and start the backend

```powershell
cd C:\Projects\vitalink_ip_lab\backend

$env:NODE_ENV = 'development'
$env:PORT = '3000'
$env:MONGO_URI = 'mongodb://127.0.0.1:27017/VitaLink_codex_local?replicaSet=rs0'
$env:JWT_SECRET = 'codex-local-development-only-secret'
$env:ADMIN_TOTP_ENCRYPTION_KEY = 'codex-local-admin-totp-encryption-key-32b'
$env:API_DOCS_ENABLED = 'false'
$env:CORS_ALLOWED_ORIGINS = 'http://127.0.0.1:7357,http://localhost:7357'
$env:FCM_ENABLED = 'false'
$env:FIREBASE_SERVICE_ACCOUNT = ''
$env:REDIS_URL = ''
$env:NOTIFICATION_DELIVERY_ENABLED = 'false'
$env:MALWARE_SCAN_ENABLED = 'false'
$env:ACCESS_KEY_ID = ''
$env:SECRET_ACCESS_KEY = ''
$env:S3_BUCKET_NAME = ''
$env:TWILIO_ACCOUNT_SID = ''
$env:TWILIO_AUTH_TOKEN = ''
$env:TWILIO_VERIFY_SERVICE_SID = ''
$env:LOKI_URL = ''

npm.cmd run build
if ($LASTEXITCODE -ne 0) { throw 'Backend build failed' }
npm.cmd start
```

Use the compiled `build`/`start` path. In this workspace, `npm run dev` failed in `ts-node` while loading Express request type augmentations.

In another PowerShell terminal, check that the backend is live:

```powershell
Invoke-RestMethod http://127.0.0.1:3000/health/live
```

## 3. Start the Flutter web app

```powershell
cd C:\Projects\vitalink_ip_lab\frontend

flutter.bat run -d web-server `
  --web-hostname 127.0.0.1 `
  --web-port 7357 `
  --dart-define=API_BASE_URL=http://127.0.0.1:3000 `
  --dart-define=API_PATH_PREFIX=/api/v1
```

Open <http://127.0.0.1:7357>. Keep the backend and Flutter terminals running while using the app. Press Ctrl+C in those terminals to stop the processes. The MongoDB container can stay running; `docker stop vitalink-codex-mongo` stops it while preserving its data.

## Demo accounts

The local credentials are in the per-machine ignored file `LOCAL_DEV_CREDENTIALS.md` at the repository root. The App Admin can open Analytics, Access Control, and Platform Configuration. The Hospital Admin can open Hospital Operations Health. Platform Health is displayed directly on the Administrator Dashboard. Broadcast notifications support targeting all users, user roles (doctors, patients), or specific individual doctors and patients. A fresh database starts without analytics or operations records, so those screens initially show empty values.
