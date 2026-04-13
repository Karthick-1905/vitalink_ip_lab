# VitaLink API Test Matrix

Generated from backend route, validator, controller, and test analysis.

## Health

### GET /

Request: API Root

Basic service reachability probe.

Auth: None

Test scenarios:
- Success response from server root
- Base URL misconfiguration

### GET /health/live

Request: Live Health Check

Liveness endpoint that should stay green while the process is up.

Auth: None

Test scenarios:
- Success response when process is alive

### GET /health/ready

Request: Ready Health Check

Readiness endpoint that reflects MongoDB connectivity.

Auth: None

Test scenarios:
- 200 when database is connected
- 503 when database is disconnected

## Auth

### POST /api/auth/login

Request: Login Admin

Admin login. Saves `admin_token` and updates generic `auth_token`.

Auth: None
Body: `login_id`, `password`

Test scenarios:
- Valid login returns JWT token
- Unknown login ID returns 400
- Wrong password returns 401
- Inactive account returns 403
- Missing fields return validation error

### POST /api/auth/login

Request: Login Doctor

Doctor login. Saves `doctor_token` and updates generic `auth_token`.

Auth: None
Body: `login_id`, `password`

Test scenarios:
- Valid doctor login
- Credential failures
- Inactive account

### POST /api/auth/login

Request: Login Patient

Patient login. Saves `patient_token` and updates generic `auth_token`.

Auth: None
Body: `login_id`, `password`

Test scenarios:
- Valid patient login
- Credential failures
- Inactive account

### POST /api/auth/logout

Request: Logout

Stateless logout acknowledgement.

Auth: Bearer token

Test scenarios:
- Success with valid token
- 401 without token
- 401 with invalid token

### GET /api/auth/me

Request: Get Current User

Fetches the authenticated user and populated profile data.

Auth: Bearer token

Test scenarios:
- Success with valid token
- 401 without token
- 401 with invalid token
- 404 when JWT user no longer exists

### POST /api/auth/change-password

Request: Change Password

Authenticated password rotation endpoint.

Auth: Bearer token
Body: `current_password`, `new_password`

Test scenarios:
- Success with strong new password
- 401 when current password is wrong
- 400 for weak password
- 400 when new password matches current password
- 401 without token

## Admin

### POST /api/admin/doctors

Request: Create Doctor

Create a doctor account and profile.

Auth: Admin bearer token
Body: `login_id`, `password`, `name`, optional doctor profile fields

Test scenarios:
- 201 for valid doctor creation
- 409 for duplicate login ID
- 400 for weak password or invalid URL fields
- 401 without token
- 403 for non-admin token

### GET /api/admin/doctors

Request: List Doctors

Paginated doctor listing with filters.

Auth: Admin bearer token
Query: `page`, `limit`, `department`, `is_active`, `search`

Test scenarios:
- 200 paginated success
- 400 for invalid pagination inputs
- 401 without token
- 403 for non-admin

### PUT /api/admin/doctors/{{doctor_id}}

Request: Update Doctor

Update doctor profile or account state.

Auth: Admin bearer token
Body: Optional profile and state fields

Test scenarios:
- 200 success update
- 404 when doctor is missing
- 400 for invalid payload shape
- 401 without token
- 403 for non-admin

### DELETE /api/admin/doctors/{{doctor_id}}

Request: Deactivate Doctor

Soft-deactivate a doctor account.

Auth: Admin bearer token

Test scenarios:
- 200 success deactivation
- 404 when doctor is missing
- 401 without token
- 403 for non-admin

### POST /api/admin/patients

Request: Create Patient

Create a patient and assign a doctor.

Auth: Admin bearer token
Body: Patient account, demographics, doctor assignment, optional medical config

Test scenarios:
- 201 success create
- 400 when assigned doctor is invalid
- 409 for duplicate login ID
- 400 for invalid gender/INR schema
- 401 without token
- 403 for non-admin

### GET /api/admin/patients

Request: List Patients

Paginated patient listing with assignment and status filters.

Auth: Admin bearer token
Query: `page`, `limit`, `assigned_doctor_id`, `account_status`, `search`

Test scenarios:
- 200 paginated success
- 400 for invalid pagination input
- 401 without token
- 403 for non-admin

### PUT /api/admin/patients/{{patient_id}}

Request: Update Patient

Update patient account or profile fields.

Auth: Admin bearer token
Body: Optional demographics, medical config, assignment, status, active flag, password

Test scenarios:
- 200 success update
- 404 when patient is missing
- 400 for invalid status or schema
- 401 without token
- 403 for non-admin

### DELETE /api/admin/patients/{{patient_id}}

Request: Deactivate Patient

Soft-deactivate a patient account.

Auth: Admin bearer token

Test scenarios:
- 200 success deactivation
- 404 when patient is missing
- 401 without token
- 403 for non-admin

### PUT /api/admin/reassign/{{patient_op_num}}

Request: Reassign Patient

Reassign patient ownership to a new doctor.

Auth: Admin bearer token
Body: `new_doctor_id`

Test scenarios:
- 200 success reassignment
- 404 when patient OP number is unknown
- 400 when target doctor is invalid
- 401 without token
- 403 for non-admin

### GET /api/admin/audit-logs

Request: Get Audit Logs

Audit log search and pagination.

Auth: Admin bearer token
Query: `page`, `limit`, `user_id`, `action`, `start_date`, `end_date`, `success`

Test scenarios:
- 200 paginated success
- Invalid date filters handled by service
- 401 without token
- 403 for non-admin

### GET /api/admin/config

Request: Get System Config

Fetch mutable system config document.

Auth: Admin bearer token

Test scenarios:
- 200 success
- 401 without token
- 403 for non-admin

### PUT /api/admin/config

Request: Update System Config

Patch system config. Body is strict Zod schema.

Auth: Admin bearer token
Body: `inr_thresholds`, `session_timeout_minutes`, `rate_limit`, `feature_flags`

Test scenarios:
- 200 success update
- 400 for unexpected fields
- 400 for non-positive numbers
- 401 without token
- 403 for non-admin

### POST /api/admin/notifications/broadcast

Request: Broadcast Notification

Broadcast notifications to users or segments.

Auth: Admin bearer token
Body: `title`, `message`, `target`, optional `user_ids`, `priority`

Test scenarios:
- 200 success broadcast
- 400 when target is SPECIFIC but user_ids missing
- 400 for invalid target or priority
- 401 without token
- 403 for non-admin

### POST /api/admin/users/batch

Request: Batch User Operation

Bulk activate, deactivate, or reset password.

Auth: Admin bearer token
Body: `operation`, `user_ids[]`

Test scenarios:
- 200 success for valid operation
- 400 for empty user_ids
- 400 for unsupported operation
- 401 without token
- 403 for non-admin

### POST /api/admin/users/reset-password

Request: Reset User Password

Admin password reset with optional explicit replacement password.

Auth: Admin bearer token
Body: `target_user_id`, optional `new_password`

Test scenarios:
- 200 success reset
- 404 for unknown user
- 400 for invalid body
- 401 without token
- 403 for non-admin

### GET /api/admin/system/health

Request: System Health

Administrative system health snapshot.

Auth: Admin bearer token

Test scenarios:
- 200 success with health metrics
- 401 without token
- 403 for non-admin

### GET /api/admin/legacy/patients

Request: Legacy List Patients

Legacy patient listing endpoint.

Auth: Admin bearer token

Test scenarios:
- 200 success
- 401 without token
- 403 for non-admin

### GET /api/admin/legacy/patient/{{patient_op_num}}

Request: Legacy Get Patient By OP

Legacy patient lookup by OP/login ID.

Auth: Admin bearer token

Test scenarios:
- 200 when patient exists
- 404 when patient is missing
- 401 without token
- 403 for non-admin

### GET /api/admin/legacy/doctor/{{doctor_id}}

Request: Legacy Get Doctor By ID

Legacy doctor lookup by Mongo user ID.

Auth: Admin bearer token

Test scenarios:
- 200 when doctor exists
- 404 when doctor is missing
- 401 without token
- 403 for non-admin

## Doctors

### GET /api/doctors/notifications/stream

Request: Stream Notifications

Server-sent events stream for doctor notifications. Uses token query param or Authorization header.

Auth: Doctor token via `token` query param or Authorization header
Query: `token`

Test scenarios:
- Stream connects with valid token
- 401 without token
- 401 with invalid or expired token

### GET /api/doctors/notifications

Request: List Notifications

Paginated doctor notifications.

Auth: Doctor bearer token
Query: `page`, `limit`, `is_read`

Test scenarios:
- 200 success
- 400 for invalid ObjectId filters not applicable here
- 400 for invalid pagination strings
- 401 without token
- 400 when non-doctor token is used

### PATCH /api/doctors/notifications/read-all

Request: Mark All Notifications Read

Marks all doctor notifications as read.

Auth: Doctor bearer token

Test scenarios:
- 200 success
- 401 without token
- 400 when non-doctor token is used

### PATCH /api/doctors/notifications/{{notification_id}}/read

Request: Mark Notification Read

Marks one doctor notification as read.

Auth: Doctor bearer token

Test scenarios:
- 200 when notification exists
- 404 for unknown notification
- 400 for invalid ObjectId
- 401 without token
- 400 when non-doctor token is used

### GET /api/doctors/patients

Request: List Assigned Patients

Lists patients assigned to the authenticated doctor.

Auth: Doctor bearer token

Test scenarios:
- 200 with patients
- 200 with empty array
- 401 without token
- 400 when non-doctor token is used

### GET /api/doctors/patients/{{patient_op_num}}

Request: Get Patient

Fetch one patient by OP/login ID.

Auth: Doctor bearer token

Test scenarios:
- 200 when patient exists and belongs to doctor
- 404 when patient is missing
- 403 for unauthorized doctor-patient access
- 401 without token

### POST /api/doctors/patients

Request: Create Patient

Doctor-side patient creation with default temporary password equal to contact number.

Auth: Doctor bearer token
Body: Patient demographics, OP number, dosage schedule, optional history and therapy config

Test scenarios:
- 201 success create
- 409 for duplicate OP number
- 400 for invalid gender/date/contact lengths
- 401 without token
- 400 when non-doctor token is used

### PATCH /api/doctors/patients/{{patient_op_num}}/reassign

Request: Reassign Patient

Doctor-triggered reassignment to another doctor login ID.

Auth: Doctor bearer token
Body: `new_doctor_id`

Test scenarios:
- 200 success
- 400 when target doctor is missing
- 403 when patient is not owned by doctor
- 404 for unknown patient
- 401 without token

### PUT /api/doctors/patients/{{patient_op_num}}/dosage

Request: Update Patient Dosage

Replace weekly dosage schedule.

Auth: Doctor bearer token
Body: `prescription` daily number map

Test scenarios:
- 200 success
- 400 for malformed schedule
- 403 when patient ownership is wrong
- 404 when patient is missing
- 401 without token

### GET /api/doctors/patients/{{patient_op_num}}/reports

Request: List Patient Reports

List patient INR reports with presigned file URLs when present.

Auth: Doctor bearer token

Test scenarios:
- 200 success
- 403 when doctor does not own patient
- 404 when patient is missing
- 401 without token

### GET /api/doctors/patients/{{patient_op_num}}/reports/{{report_id}}

Request: Get Patient Report

Fetch one patient report by embedded report ObjectId.

Auth: Doctor bearer token

Test scenarios:
- 200 success
- 400 for invalid report_id
- 403 when doctor does not own patient
- 404 when report or patient is missing
- 401 without token

### PUT /api/doctors/patients/{{patient_op_num}}/reports/{{report_id}}

Request: Update Patient Report

Update report notes or critical flag.

Auth: Doctor bearer token
Body: Optional `is_critical`, `notes`

Test scenarios:
- 200 success
- 400 for invalid payload or report_id
- 403 unauthorized patient access
- 404 report missing
- 401 without token

### PUT /api/doctors/patients/{{patient_op_num}}/config

Request: Update Next Review

Set next review date for the patient.

Auth: Doctor bearer token
Body: `date` in DD-MM-YYYY format

Test scenarios:
- 200 success
- 400 for invalid date format
- 403 unauthorized patient access
- 404 patient missing
- 401 without token

### PUT /api/doctors/patients/{{patient_op_num}}/instructions

Request: Update Instructions

Set patient care instructions.

Auth: Doctor bearer token
Body: `instructions[]`

Test scenarios:
- 200 success
- 400 when instructions is not an array of strings
- 403 unauthorized patient access
- 404 patient missing
- 401 without token

### GET /api/doctors/profile

Request: Get Profile

Fetch doctor profile with optional presigned profile image URL and patient count.

Auth: Doctor bearer token

Test scenarios:
- 200 success
- 404 when doctor record is missing
- 401 without token
- 400 when non-doctor token is used

### PUT /api/doctors/profile

Request: Update Profile

Update doctor profile fields.

Auth: Doctor bearer token
Body: Optional `name`, `department`, `contact_number`

Test scenarios:
- 200 success
- 400 for invalid contact number length or extra fields
- 404 when doctor record is missing
- 401 without token

### GET /api/doctors/doctors

Request: List Doctors

List all doctor users with populated profiles.

Auth: Doctor bearer token

Test scenarios:
- 200 success
- 401 without token
- 400 when non-doctor token is used

### POST /api/doctors/profile-pic

Request: Upload Profile Picture

Upload doctor profile image.

Auth: Doctor bearer token
Headers: Multipart form-data
Body: `file`

Test scenarios:
- 200 success
- 400 when file is missing
- 400 when file type is invalid
- 400 when file exceeds 5 MB
- 401 without token

## Patient

### GET /api/patient/notifications/stream

Request: Stream Notifications

Server-sent events stream for patient notifications.

Auth: Patient token via `token` query param or Authorization header
Query: `token`

Test scenarios:
- Stream connects with valid token
- 401 without token
- 401 with invalid or expired token

### GET /api/patient/profile

Request: Get Profile

Fetch patient profile with assigned doctor details and doctor update summary.

Auth: Patient bearer token

Test scenarios:
- 200 success
- 401 without token
- 404 if patient no longer exists
- 400 when non-patient token is used

### PUT /api/patient/profile

Request: Update Profile

Update patient profile, history, and therapy start date.

Auth: Patient bearer token
Body: Optional demographics, medical history, medical_config.therapy_start_date

Test scenarios:
- 200 success
- 400 for invalid gender or future therapy start date
- 400 for unexpected fields due to strict schema
- 401 without token

### GET /api/patient/reports

Request: Get Reports

Fetch INR history, health logs, weekly dosage, and medical config.

Auth: Patient bearer token

Test scenarios:
- 200 success
- 401 without token
- 404 when patient profile is missing

### POST /api/patient/reports

Request: Submit Report

Submit INR test result with optional upload.

Auth: Patient bearer token
Headers: Multipart form-data
Body: `inr_value`, `test_date`, optional `file`

Test scenarios:
- 200 success
- 400 for non-numeric INR
- 400 for invalid date format
- 400 for invalid file type
- 400 for file > 10 MB
- 507/insufficient storage when upload backend fails
- 401 without token

### GET /api/patient/missed-doses

Request: Get Missed Doses

Calculate missed doses from therapy start date, dosage schedule, and taken dose history.

Auth: Patient bearer token

Test scenarios:
- 200 success
- 400 when therapy start or schedule is missing
- 401 without token

### GET /api/patient/dosage-calendar

Request: Get Dosage Calendar

Dose calendar with taken, missed, and scheduled dates.

Auth: Patient bearer token
Query: `months` between 1 and 6, optional `start_date` in DD-MM-YYYY

Test scenarios:
- 200 success
- 400 for invalid start_date format
- 400 when schedule is missing
- 401 without token
- Edge: months clamped between 1 and 6

### POST /api/patient/dosage

Request: Log Dosage

Mark one dose date as taken.

Auth: Patient bearer token
Body: `date` in DD-MM-YYYY

Test scenarios:
- 200 success
- 400 for invalid format
- 400 when same date is logged twice
- 401 without token

### POST /api/patient/health-logs

Request: Update Health Logs

Upsert health log item by type.

Auth: Patient bearer token
Body: `type`, `description`

Test scenarios:
- 200 success
- 400 for invalid enum or missing description
- 401 without token

### GET /api/patient/notifications

Request: List Notifications

Paginated app notifications for the patient.

Auth: Patient bearer token
Query: `page`, `limit`, `is_read`

Test scenarios:
- 200 success
- 400 for invalid pagination strings
- 401 without token
- 400 when non-patient token is used

### PATCH /api/patient/notifications/read-all

Request: Mark All Notifications Read

Marks all patient notifications as read.

Auth: Patient bearer token

Test scenarios:
- 200 success
- 401 without token
- 400 when non-patient token is used

### PATCH /api/patient/notifications/{{notification_id}}/read

Request: Mark Notification Read

Marks one patient notification as read.

Auth: Patient bearer token

Test scenarios:
- 200 success
- 404 when notification is missing
- 400 for invalid ObjectId
- 401 without token

### GET /api/patient/doctor-updates/summary

Request: Doctor Updates Summary

Unread count and latest doctor update notification.

Auth: Patient bearer token

Test scenarios:
- 200 success
- 401 without token
- 400 when non-patient token is used

### GET /api/patient/doctor-updates

Request: List Doctor Updates

List doctor update events derived from notification documents.

Auth: Patient bearer token
Query: `unread_only`, `limit`

Test scenarios:
- 200 success
- 400 for invalid query values
- 401 without token

### PATCH /api/patient/doctor-updates/read-all

Request: Mark All Doctor Updates Read

Marks all unread doctor updates as read.

Auth: Patient bearer token

Test scenarios:
- 200 success
- 401 without token

### PATCH /api/patient/doctor-updates/{{doctor_update_event_id}}/read

Request: Mark Doctor Update Read

Marks one doctor update event as read.

Auth: Patient bearer token

Test scenarios:
- 200 success
- 404 when doctor update is missing
- 400 for invalid ObjectId
- 401 without token

### POST /api/patient/profile-pic

Request: Upload Profile Picture

Upload patient profile image.

Auth: Patient bearer token
Headers: Multipart form-data
Body: `file`

Test scenarios:
- 200 success
- 400 when file is missing
- 400 when file type is invalid
- 400 when file exceeds 5 MB
- 401 without token

## Statistics

### GET /api/statistics/admin

Request: Admin Dashboard Stats

High-level admin counts for doctors, patients, and audit logs.

Auth: Admin bearer token

Test scenarios:
- 200 success
- 401 without token
- 403 for non-admin token

### GET /api/statistics/trends

Request: Registration Trends

Registration trends across doctors and patients.

Auth: Admin bearer token
Query: `period` one of 7d, 30d, 90d, 1y

Test scenarios:
- 200 success
- 400 for unsupported period
- 401 without token
- 403 for non-admin

### GET /api/statistics/compliance

Request: INR Compliance Stats

INR compliance breakdown for patients.

Auth: Admin bearer token

Test scenarios:
- 200 success
- 401 without token
- 403 for non-admin

### GET /api/statistics/workload

Request: Doctor Workload Stats

Doctor workload distribution stats.

Auth: Admin bearer token

Test scenarios:
- 200 success
- 401 without token
- 403 for non-admin

### GET /api/statistics/period

Request: Period Stats

Statistics filtered by a custom date range.

Auth: Admin bearer token
Query: Optional `start_date`, `end_date` parseable date strings

Test scenarios:
- 200 success
- 400 when end_date is before start_date
- 400 for invalid date strings
- 401 without token
- 403 for non-admin

