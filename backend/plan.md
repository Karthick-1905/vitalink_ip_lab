## Plan: Authentication and Role-Based Access Control Implementation

Implement a secure authentication system using JWT and bcrypt, with distinct roles for Admin, Doctor, and Patient. This includes custom middleware for authorization and role-specific endpoints.

### Steps
1. Implement password hashing logic and JWT generation in [backend/src/services/auth.service.ts](backend/src/services/auth.service.ts) and [backend/src/controllers/auth.controller.ts](backend/src/controllers/auth.controller.ts).
2. Create authentication and role-based authorization middleware in [backend/src/middlewares/auth.middleware.ts](backend/src/middlewares/auth.middleware.ts) to protect routes.
3. Update [backend/src/models/Admin.ts](backend/src/models/Admin.ts), [backend/src/models/Doctor.ts](backend/src/models/Doctor.ts), and [backend/src/models/Patient.ts](backend/src/models/Patient.ts) with password comparison methods.
4. Define and implement Admin-only management endpoints for Doctor registration and Patient management in [backend/src/routes/admin.routes.ts](backend/src/routes/admin.routes.ts).
5. Implement role-specific logic for Doctors (manage assigned patients) and Patients (view/log medical data) in their respective controllers and services.
6. Wire all role-restricted routes into [backend/src/routes/index.ts](backend/src/routes/index.ts) applying the new `authorize` middleware.

### Endpoints

#### 1. Authentication Endpoints (Public/Auth)
- `POST /api/auth/login`: Authenticate users (Admin, Doctor, or Patient) and return a JWT.
- `GET /api/auth/me`: Retrieve current user's profile and role from the token.
- `POST /api/auth/logout`: Invalidate the current session.

#### 2. Admin Endpoints (Admin Only)
- `POST /api/admin/doctors`: Register new doctors and assign credentials.
- `GET /api/admin/doctors`: List all doctors.
- `PUT /api/admin/doctors/:id`: Update doctor profile or active status.
- `DELETE /api/admin/doctors/:id`: Soft delete or deactivate a doctor.
- `POST /api/admin/patients`: Onboard patients and link them to primary doctors.
- `GET /api/admin/patients`: List all hospitalized patients.
- `PUT /api/admin/patients/:id`: Update patient demographics and account status.

#### 3. Doctor Endpoints (Doctor Only)
- `GET /api/doctor/patients`: List patients specifically assigned to the logged-in doctor.
- `GET /api/doctor/patients/:id`: View detailed medical history and INR logs for a specific patient.
- `PUT /api/doctor/patients/:id/dosage`: Update a patient's medication dosage grid.
- `PUT /api/doctor/patients/:id/config`: Modify patient clinical parameters (INR range, therapy drug).
- `GET /api/doctor/alerts`: View flagged patients with critical INR values.

#### 4. Patient Endpoints (Patient Only)
- `GET /api/patient/profile`: View personal profile and current medication schedule.
- `POST /api/patient/inr-logs`: Upload new INR test results and report values.
- `GET /api/patient/inr-logs`: View historic INR test history.
- `POST /api/patient/health-logs`: Log side effects, bleeding, or other health symptoms.

### Further Considerations
1. Should we use a unified `User` model with a `role` field instead of separate `Admin`/`Doctor`/`Patient` models to simplify authentication?
2. Do you have a preferred validation library (e.g., Zod, Joi) for the request validators in [backend/src/validators/](backend/src/validators/)?
3. Should 'superadmin' be a fixed role, or should we support multiple Admin accounts with varying permissions?
