# VitaLink High-Level Diagram: Detailed Excalidraw Instructions

## Purpose
Create one high-level architecture diagram for the VitaLink application that shows:

- who uses the system
- the frontend application surfaces
- the backend API and its internal responsibilities
- the primary data stores and external services
- realtime notification flow
- deployment/runtime topology
- the separate ML pipeline that exists in the repository but is not wired into the live patient-monitoring app

This diagram should be accurate to the current repository, not aspirational.

## Diagram title
Use this exact title at the top:

`VitaLink High-Level Architecture`

Optional subtitle:

`Flutter client + Express/Mongo backend + realtime notifications + blue-green deployment + separate ML research pipeline`

## Recommended canvas layout
Use a wide landscape canvas.

Split the canvas into 4 vertical zones from left to right:

1. Users
2. Client layer
3. Backend and data layer
4. Deployment / ML side systems

Do not scatter boxes randomly. Keep the main app path visually dominant in the center.

## Recommended visual language
Use consistent shapes:

- Rounded rectangles for applications/services
- Cylinders for databases/storage
- Small person icons or labeled actor boxes for users
- Dashed-border group containers for logical groupings
- Solid arrows for synchronous request/response traffic
- Dashed arrows for background, async, or operational flows
- A distinct color for realtime/SSE flows

Suggested color grouping:

- Users: muted gray
- Frontend: blue
- Backend: green
- Data stores: amber
- External services: purple or violet
- Deployment/ops: dark gray
- ML pipeline: orange

## Main top-level boxes to draw
Draw these major blocks first.

### 1. User actors column
Place three actor boxes stacked vertically on the far left:

- `Patient`
- `Doctor`
- `Admin`

Add a note under them:

`All roles authenticate with login_id + password`

### 2. Client application column
To the right of the users, draw one large group container:

`Flutter Frontend App`

Inside it draw 4 sub-boxes:

- `Session + Routing Layer`
- `Patient UI`
- `Doctor UI`
- `Admin UI`

Inside or near the Flutter container add a small technical note box listing:

- `Flutter`
- `Dio API client`
- `flutter_secure_storage`
- `flutter_tanstack_query`
- `Role-based route guards`
- `SSE notification client`

### 3. Backend application column
To the right of the frontend, draw one large central group container:

`Node.js / Express Backend API`

Inside it draw these sub-boxes:

- `Auth + JWT`
- `Patient APIs`
- `Doctor APIs`
- `Admin APIs`
- `Statistics APIs`
- `Validation + Middleware`
- `Realtime Notification Service (SSE)`
- `Notification / Config / Admin Services`

Also add a small note inside this backend container:

- `Express 5 + TypeScript`
- `Mongoose`
- `Zod validation`
- `Morgan/Winston logging`
- `Helmet + CORS`
- `Multer file upload`

### 4. Data and external services column
To the right of the backend, draw these storage/service boxes stacked or clustered:

- `MongoDB`
- `Filebase S3-Compatible Object Storage`
- `Connected SSE Clients`
- `Optional Loki Logging Sink`

Use database cylinder shapes for:

- `MongoDB`
- `Filebase S3-Compatible Object Storage`

Use a service box for:

- `Optional Loki Logging Sink`

### 5. Deployment/ops group
In the upper-right or lower-right area, draw another dashed group container:

`Production Deployment Topology`

Inside it draw:

- `Nginx Reverse Proxy`
- `Backend Container: Blue`
- `Backend Container: Green`
- `EC2 Host`

Label the group:

`Blue-Green zero-downtime deployment`

### 6. ML pipeline group
Place this separately so it is clearly not part of the live request path.

Draw a dashed group container titled:

`Offline ML / Research Pipeline`

Inside it draw:

- `Synthetic / IWPC Data Inputs`
- `Training + Tuning Scripts`
- `Evaluation + Visualization`
- `Generated Models + Reports`

Add a prominent note:

`Repository-local analytics pipeline; not integrated into backend runtime APIs`

## Exact relationships and arrows to draw

### User to frontend arrows
Draw solid arrows:

- `Patient -> Flutter Frontend App`
- `Doctor -> Flutter Frontend App`
- `Admin -> Flutter Frontend App`

Label each arrow:

`Web/mobile app usage`

### Frontend internal role mapping
Inside the frontend container:

- `Session + Routing Layer -> Patient UI`
- `Session + Routing Layer -> Doctor UI`
- `Session + Routing Layer -> Admin UI`

Label near the routing layer:

- `SessionBootstrapPage`
- `SessionRouteGuard`
- `Role-based landing routes`

### Frontend to backend main API arrow
Draw one thick solid arrow from `Flutter Frontend App` to `Node.js / Express Backend API`.

Label it:

`HTTPS REST API (/api/*) + Bearer JWT`

Add a smaller note near the arrow:

- `Login`
- `Profile fetch`
- `Patient/doctor/admin operations`
- `Notifications`
- `Statistics`

### Frontend realtime arrow
Draw a separate distinct dashed or highlighted arrow from `Flutter Frontend App` to `Realtime Notification Service (SSE)` inside backend.

Label it:

`Server-Sent Events`

Under that, add:

- `/api/patient/notifications/stream`
- `/api/doctors/notifications/stream`

### Backend to MongoDB
Draw a strong solid arrow from `Node.js / Express Backend API` to `MongoDB`.

Label it:

`Mongoose read/write`

### Backend to Filebase storage
Draw a solid arrow from backend to `Filebase S3-Compatible Object Storage`.

Label it:

`Upload report files + profile pictures`

Draw a return arrow from Filebase back toward backend/frontends, labeled:

`Presigned download URLs`

### Backend to Loki
Draw a dashed arrow from backend to `Optional Loki Logging Sink`.

Label it:

`Structured logs if configured`

### Realtime notification service to connected clients
Draw arrows from `Realtime Notification Service (SSE)` to a small box labeled `Connected Patient/Doctor Clients`.

Label:

`Push notification events`

Optional sublabels:

- `doctor_update`
- `notification`
- `heartbeat / keepalive`

### Nginx deployment topology
In the deployment group:

- Draw arrow `Internet / Browser -> Nginx Reverse Proxy`
- Draw arrow `Nginx Reverse Proxy -> Backend Container: Blue`
- Draw arrow `Nginx Reverse Proxy -> Backend Container: Green`

But visually emphasize that only one is active at a time.

Add a note between Nginx and the two backend containers:

`upstream.conf points to active slot`

Draw a note arrow from `deploy.sh` conceptually to the deployment group if you want an operational annotation:

`Build inactive slot -> health check -> switch upstream -> stop old slot`

### Backend containers to shared resources
Draw arrows from both backend container boxes to:

- `MongoDB`
- `Filebase S3-Compatible Object Storage`

This communicates that both blue and green app instances use the same backing services.

### Frontend hosting note
Near the Flutter frontend box, add a small note:

`Vercel rewrites /api/* to backend`

Optional second note:

`Current repo contains Render / EC2 / raw IP rewrite variants`

## Internal backend substructure to show
Inside the backend group, connect sub-boxes like this.

### Auth flow
`Auth + JWT`

Responsibilities note:

- `/api/auth/login`
- `/api/auth/logout`
- `/api/auth/me`
- `/api/auth/change-password`
- `JWT generation/verification`
- `Role from token`

Draw arrow:

`Auth + JWT -> MongoDB`

Label:

`User lookup + password hash verification`

### Middleware / validation
`Validation + Middleware`

Responsibilities note:

- `authenticate`
- `authorize`
- `AllowPatient / AllowDoctor / AllowAdmin`
- `Zod request validation`
- `error handler`
- `audit middleware for admin mutations`

Draw it visually before the role-specific APIs inside the backend box.

### Patient APIs
`Patient APIs`

List these responsibilities inside or beside the box:

- `Profile`
- `Submit INR report`
- `Get reports`
- `Missed doses`
- `Dosage calendar`
- `Mark dose taken`
- `Health logs`
- `Notifications`
- `Doctor updates`
- `Profile picture upload`

Draw arrows:

- `Patient APIs -> MongoDB`
- `Patient APIs -> Filebase S3-Compatible Object Storage`
- `Patient APIs -> Realtime Notification Service (SSE)` indirectly through notification service

### Doctor APIs
`Doctor APIs`

List:

- `Get assigned patients`
- `View patient`
- `Add patient`
- `Edit weekly dosage`
- `Update report notes / critical flag`
- `Update next review date`
- `Update care instructions`
- `Reassign patient`
- `Doctor profile`
- `Doctor notifications`
- `Profile picture upload`

Draw arrows:

- `Doctor APIs -> MongoDB`
- `Doctor APIs -> Filebase S3-Compatible Object Storage`
- `Doctor APIs -> Notification / Config / Admin Services`

### Admin APIs
`Admin APIs`

List:

- `Create/update/deactivate doctor`
- `Create/update/deactivate patient`
- `Reassign patient`
- `Audit logs`
- `System config`
- `Broadcast notifications`
- `Batch operations`
- `Reset user password`
- `System health`

Draw arrows:

- `Admin APIs -> MongoDB`
- `Admin APIs -> Notification / Config / Admin Services`

### Statistics APIs
`Statistics APIs`

List:

- `Admin dashboard counts`
- `Registration trends`
- `INR compliance`
- `Doctor workload`
- `Period stats`

Draw arrow:

- `Statistics APIs -> MongoDB`

### Service box
`Notification / Config / Admin Services`

Inside note:

- `Notification creation`
- `Broadcast announcements`
- `Doctor update notifications`
- `SystemConfig management`
- `Password reset / temp passwords`
- `Admin service orchestration`

Draw arrows:

- `Notification / Config / Admin Services -> MongoDB`
- `Notification / Config / Admin Services -> Realtime Notification Service (SSE)`

### Realtime Notification Service
`Realtime Notification Service (SSE)`

Inside note:

- `Registers user streams`
- `Pushes doctor_update / notification events`
- `Heartbeats every ~25s`
- `Patient and doctor channels`

## Data model boxes to include
Do not draw every field. Draw one compact grouped box near MongoDB titled:

`Core MongoDB Collections`

Inside list these collection/model names:

- `User`
- `AdminProfile`
- `DoctorProfile`
- `PatientProfile`
- `Notification`
- `AuditLog`
- `SystemConfig`

Under `PatientProfile`, add compact sub-bullets in the box:

- `demographics`
- `medical_config`
- `medical_history`
- `weekly_dosage`
- `inr_history`
- `health_logs`

Under `Notification`, add:

- `DOCTOR_UPDATE`
- `SYSTEM_ANNOUNCEMENT`
- `read/unread`
- `TTL expiry`

Under `User`, add:

- `login_id`
- `user_type`
- `profile_id`
- `must_change_password`

## Frontend role areas to show
Inside the frontend container, give each role area a small bullet list.

### Patient UI
Show:

- `Dashboard shell`
- `Update INR`
- `Dosage management`
- `Records / health reports`
- `Profile`
- `Notification center`
- `Doctor update popups`

Also add note:

`Uses polling + SSE invalidation for unread counts`

### Doctor UI
Show:

- `Dashboard`
- `Patient list`
- `Add patient`
- `View patient`
- `Report review`
- `Dosage / instructions / reassignment`
- `Notification center`
- `Doctor profile`

### Admin UI
Show:

- `Dashboard`
- `Doctor management`
- `Patient management`
- `Analytics dashboard`
- `Notification broadcast`
- `Audit logs`
- `System configuration`

### Session + Routing Layer
Show:

- `Secure token storage`
- `Stored user profile`
- `Auto-redirect by role`
- `401 session reset`

## Key business flows to annotate
Add numbered callout labels near the main arrows. Use small circles with numbers.

### Flow 1: Login and session bootstrap
Callout text:

`1. User logs in with login_id/password. Backend validates credentials, returns JWT + user payload. Frontend stores token and routes to patient, doctor, or admin dashboard.`

### Flow 2: Patient INR report submission
Callout text:

`2. Patient submits INR value and optional PDF/image report. Backend validates input, uploads file to Filebase if attached, stores INR history in MongoDB, and flags critical values using SystemConfig thresholds.`

### Flow 3: Doctor updates patient plan
Callout text:

`3. Doctor edits dosage, report notes, next review date, or instructions. Backend updates PatientProfile, creates DOCTOR_UPDATE notification, stores it in MongoDB, and pushes a realtime event to the patient client over SSE.`

### Flow 4: Admin governance
Callout text:

`4. Admin manages doctors/patients, updates system configuration, reviews audit logs, broadcasts announcements, and can reset passwords or run batch operations.`

### Flow 5: Realtime notifications
Callout text:

`5. Patient and doctor clients maintain SSE connections. Notification events trigger unread-count refresh, popup dialogs, and notification center updates without full page reloads.`

### Flow 6: Production deployment
Callout text:

`6. Nginx fronts two backend containers. Deploy script rebuilds the inactive slot, waits for /health/ready to pass, rewrites upstream to the healthy slot, then drains and stops the old slot.`

### Flow 7: Offline ML workflow
Callout text:

`7. The ML pipeline trains warfarin dose and time-to-stability models, generates evaluation reports and presentation artifacts, and saves joblib/model files locally. This pipeline is currently separate from the live backend APIs.`

## Specific labels that should appear in the diagram
Make sure these literal terms appear somewhere, because they matter architecturally:

- `JWT`
- `MongoDB`
- `Mongoose`
- `Filebase`
- `SSE`
- `Blue-Green Deployment`
- `Nginx`
- `Flutter`
- `Express API`
- `SystemConfig`
- `Notification`
- `AuditLog`
- `PatientProfile`
- `DoctorProfile`
- `Admin`
- `Doctor`
- `Patient`

## Important nuances to capture correctly

### 1. There is one frontend app, not three separate apps
The app is one Flutter client with role-based experiences.

### 2. The backend is one main API service
Do not draw separate deployable patient API, doctor API, and admin API services. They are role-specific route groups inside one Express application.

### 3. Notifications are persisted and also streamed
The system is not websocket-based. It uses:

- persisted notifications in MongoDB
- live delivery over Server-Sent Events

Both must be visible in the diagram.

### 4. Object storage is not local disk in the runtime design
Uploaded reports and profile images go to Filebase S3-compatible storage, then the backend generates presigned URLs for access.

### 5. Blue and green share the same data backends
Both app slots point to the same MongoDB and Filebase services.

### 6. ML pipeline is separate from production request flow
Do not imply that the backend currently calls the ML scripts or loads those models during patient API requests. The repository contains them, but there is no live integration path in the backend code today.

### 7. Admin audit logging should be visible
Admin mutating routes pass through audit middleware that writes audit logs. Show this either as an arrow from `Admin APIs` or `Validation + Middleware` to `AuditLog` in MongoDB.

## Optional mini legend
Add a small legend in one corner:

- `Solid arrow = request/response`
- `Dashed arrow = async or operational flow`
- `Cylinder = persistent storage`
- `Dashed container = logical grouping / not in main runtime path`

## Suggested final composition
If the drawer follows these instructions correctly, the viewer should be able to understand this story at a glance:

`Patient/Doctor/Admin -> one Flutter app -> one Express backend -> MongoDB + Filebase -> SSE notifications to clients, deployed behind Nginx with blue-green containers, with a separate offline ML analysis pipeline in the same repo`

## What to avoid

- Do not draw the ML pipeline as if it is serving live dosage recommendations to patients.
- Do not draw separate databases for each role.
- Do not draw WebSockets.
- Do not over-detail every Flutter page or every Express route.
- Do not omit `Notification`, `SystemConfig`, or `AuditLog`; they are core to the system behavior.
- Do not show the frontend talking directly to MongoDB or Filebase.

## Deliverable expectation
The final Excalidraw should fit on one canvas and be presentation-ready.

If space allows, include short labels for the most important route groups:

- `/api/auth/*`
- `/api/patient/*`
- `/api/doctors/*`
- `/api/admin/*`
- `/api/statistics/*`
- `/api/*/notifications/stream`

That is enough detail for a high-level architecture diagram without turning it into a sequence diagram or ER diagram.
