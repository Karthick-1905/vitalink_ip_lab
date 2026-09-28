import mongoose from 'mongoose'
import axios, { AxiosInstance } from 'axios'
import type { Server } from 'http'
import app from '@alias/app'
import { AdminProfile, AdminRolePolicy, AuthSession, AuditLog, DoctorProfile, Hospital, PatientProfile, User } from '@alias/models'
import { DEFAULT_ADMIN_ROLE_POLICIES } from '@alias/constants/admin-capabilities'
import { AdminRole } from '@alias/models/adminprofile.model'
import { AuditAction } from '@alias/models/auditlog.model'
import type { AdminAccessContext } from '@alias/types/admin-access'
import { getAuditLogs, performBatchOperation, setDoctorAccountStatus, setPatientAccountStatus, updateHospital } from '@alias/services/admin.service'
import { hasActiveHospitalAccess } from '@alias/services/hospital-access.service'
import logger from '@alias/utils/logger'
import { createAuthSession } from '@alias/services/auth-session.service'
import { activateAdminTotpEnrollment, createAdminTotpEnrollment, generateTotpCode } from '@alias/services/admin-totp.service'
import { safeRequestUrl } from '@alias/utils/request-log'
import { isControlPlaneRequest } from '@alias/middlewares/systemConfig.middleware'
import { startMongoReplicaSet, MongoReplicaSetHarness } from './setup/mongo-replica-set'

jest.setTimeout(120_000)
let harness: MongoReplicaSetHarness
let server: Server
let api: AxiosInstance
let hospital: any, other: any, doctor: any, patient: any, admin: any, platform: any
let tenant: AdminAccessContext, global: AdminAccessContext
const secret = 'Regression@1234'
const context = (user: any, role: 'app_admin' | 'hospital_admin', hospitalId?: string): AdminAccessContext => ({
  userId: String(user._id), role, scope: hospitalId ? 'tenant' : 'global', hospitalId, hospitalCode: hospitalId ? 'CRIT_A' : undefined,
  permissions: { ...DEFAULT_ADMIN_ROLE_POLICIES[role] }, policyVersion: 1, readOnly: false,
})
async function login(user: any) {
  const result = await api.post('/api/auth/login', { login_id: user.login_id, password: secret })
  expect(result.status).toBe(200)
  return { headers: { Authorization: `Bearer ${result.data.data.token}` } }
}
beforeAll(async () => {
  harness = await startMongoReplicaSet({ databaseName: 'critical_regressions' })
  await mongoose.connect(harness.uri)
  server = app.listen(0)
  api = axios.create({ baseURL: `http://localhost:${(server.address() as any).port}`, validateStatus: () => true })
  hospital = await Hospital.create({ code: 'CRIT_A', name: 'A', location: 'Test', admin_email: 'a@example.com' })
  other = await Hospital.create({ code: 'CRIT_B', name: 'B', location: 'Test', admin_email: 'b@example.com' })
  const dp = await DoctorProfile.create({ hospital_id: hospital._id, name: 'Doctor', contact_number: '9000000001' })
  doctor = await User.create({ login_id: 'critical-doctor', password: secret, user_type: 'DOCTOR', profile_id: dp._id })
  const pp = await PatientProfile.create({ hospital_id: hospital._id, assigned_doctor_id: doctor._id, demographics: { name: 'Patient' }, account_status: 'Discharged' })
  patient = await User.create({ login_id: 'critical-patient', password: secret, user_type: 'PATIENT', profile_id: pp._id, is_active: false })
  const ap = await AdminProfile.create({ hospital_id: hospital._id, admin_role: AdminRole.HOSPITAL_ADMIN })
  admin = await User.create({ login_id: 'critical-admin', password: secret, user_type: 'ADMIN', profile_id: ap._id })
  const gp = await AdminProfile.create({ admin_role: AdminRole.APP_ADMIN })
  platform = await User.create({ login_id: 'critical-platform', password: secret, user_type: 'ADMIN', profile_id: gp._id })
  tenant = context(admin, 'hospital_admin', String(hospital._id))
  global = context(platform, 'app_admin')
  await AdminRolePolicy.create(Object.values(AdminRole).map(role => ({ role_key: role, capabilities: DEFAULT_ADMIN_ROLE_POLICIES[role], protected: role === 'app_admin', schema_version: 2, policy_version: 1, updated_by: platform._id, change_reason: 'Fixture' })))
})
afterEach(() => jest.restoreAllMocks())
afterAll(async () => {
  if (server) await new Promise<void>(resolve => server.close(() => resolve()))
  await mongoose.disconnect()
  await harness?.stop()
})

test('patient second-write failure rolls back login and security version', async () => {
  const original = PatientProfile.updateOne.bind(PatientProfile)
  jest.spyOn(PatientProfile, 'updateOne').mockImplementation(((filter: any, update: any, options: any) => {
    if (options?.session && update?.$set?.account_status) throw new Error('injected profile failure')
    return original(filter, update, options)
  }) as any)
  await expect(setPatientAccountStatus(String(patient._id), { is_active: true }, tenant)).rejects.toThrow('injected profile failure')
  expect((await User.findById(patient._id))?.is_active).toBe(false)
  expect((await User.findById(patient._id))?.security_version).toBe(0)
  expect((await PatientProfile.findById(patient.profile_id))?.account_status).toBe('Discharged')
})

test('individual and batch transitions commit together and expose cleanup failure', async () => {
  jest.spyOn(AuthSession, 'updateMany').mockRejectedValueOnce(new Error('cleanup offline'))
  const result = await setPatientAccountStatus(String(patient._id), { is_active: true }, tenant)
  expect(result.revocation_cleanup_completed).toBe(false)
  expect((await User.findById(patient._id))?.security_version).toBe(1)
  expect((await PatientProfile.findById(patient.profile_id))?.account_status).toBe('Active')
  const batch = await performBatchOperation('deactivate', [String(patient._id)], tenant)
  expect(batch.results[0].success).toBe(true)
  expect((await User.findById(patient._id))?.security_version).toBe(2)
  expect((await PatientProfile.findById(patient.profile_id))?.account_status).toBe('Discharged')
})

test('doctor activation and deactivation bump security in the same write', async () => {
  await setDoctorAccountStatus(String(doctor._id), false, tenant)
  expect((await User.findById(doctor._id))?.security_version).toBe(1)
  await setDoctorAccountStatus(String(doctor._id), true, tenant)
  expect((await User.findById(doctor._id))?.security_version).toBe(2)
})

test('terminal patient status and stale expected state cannot be overwritten', async () => {
  const original = PatientProfile.updateOne.bind(PatientProfile)
  let injected = false
  jest.spyOn(PatientProfile, 'updateOne').mockImplementation(((filter: any, update: any, options: any) => {
    if (!injected && update?.$push?.file_operation_leases) {
      injected = true
      return original({ _id: patient.profile_id }, { $set: { account_status: 'Deceased' } }).then(() => original(filter, update, options))
    }
    return original(filter, update, options)
  }) as any)
  await expect(setPatientAccountStatus(String(patient._id), { is_active: true }, tenant)).rejects.toMatchObject({ statusCode: 409 })
  expect((await User.findById(patient._id))?.is_active).toBe(false)
  expect((await User.findById(patient._id))?.security_version).toBe(2)
  expect((await PatientProfile.findById(patient.profile_id))?.account_status).toBe('Deceased')
})

test('event scope survives actor transfer and excludes unscoped historical rows even with actor filter', async () => {
  await AuditLog.create([
    { user_id: admin._id, user_type: 'ADMIN', action: AuditAction.USER_UPDATE, description: 'A event', event_hospital_id: hospital._id, scope_version: 1 },
    { user_id: admin._id, user_type: 'ADMIN', action: AuditAction.USER_UPDATE, description: 'Legacy event' },
  ])
  await AdminProfile.updateOne({ _id: admin.profile_id }, { $set: { hospital_id: other._id } })
  const a = await getAuditLogs({ user_id: String(admin._id) }, {}, tenant)
  const b = await getAuditLogs({ user_id: String(admin._id) }, {}, { ...tenant, hospitalId: String(other._id) })
  expect(a.logs.map(log => log.description)).toEqual(['A event'])
  expect(b.logs).toHaveLength(0)
  await AdminProfile.updateOne({ _id: admin.profile_id }, { $set: { hospital_id: hospital._id } })
})

test('platform hospital mutation records tenant event scope', async () => {
  const auth = await login(platform)
  const result = await api.put(`/api/admin/hospitals/${hospital._id}`, { name: 'A renamed' }, auth)
  expect(result.status).toBe(200)
  const logs = await getAuditLogs({ user_id: String(platform._id) }, {}, tenant)
  expect(logs.logs.some(log => String(log.event_hospital_id) === String(hospital._id))).toBe(true)
})

test('suspension preserves independently disabled accounts and restores active member access', async () => {
  const preSuspensionUser = await User.findById(doctor._id).lean()
  const result = await updateHospital(String(hospital._id), { status: 'suspended' }, global)
  expect(result.users_deactivated).toBe(0)
  expect((await User.findById(doctor._id))?.is_active).toBe(true)
  expect((await User.findById(admin._id))?.is_active).toBe(true)
  expect((await User.findById(patient._id))?.is_active).toBe(false)
  expect(await hasActiveHospitalAccess(doctor)).toBe(false)
  await updateHospital(String(hospital._id), { status: 'active' }, global)
  expect(await hasActiveHospitalAccess(doctor)).toBe(true)
  expect(await createAuthSession({ user: preSuspensionUser! })).toBeNull()
  expect((await User.findById(patient._id))?.is_active).toBe(false)
})

test('maintenance recovery supports a fresh authenticated bootstrap and disabling maintenance', async () => {
  const auth = await login(platform)
  expect((await api.put('/api/admin/config', { feature_flags: { maintenance_mode: true } }, auth)).status).toBe(200)
  expect((await api.get('/api/admin/hospitals', auth)).status).toBe(503)
  expect((await api.get('/api/admin/access/me')).status).toBe(401)
  const freshAuth = await login(platform)
  expect((await api.get('/api/auth/me', freshAuth)).status).toBe(200)
  expect((await api.get('/api/admin/access/me', freshAuth)).status).toBe(200)
  expect((await api.get('/api/admin/config', freshAuth)).status).toBe(200)
  expect((await api.put('/api/admin/config', { feature_flags: { maintenance_mode: false } }, freshAuth)).status).toBe(200)
  expect((await api.get('/api/admin/hospitals', freshAuth)).status).toBe(200)
})

test('access log formatting drops identifiers, searches, unknown paths and unvalidated operational values', () => {
  expect(safeRequestUrl({ route: { path: '/patients/:id' }, originalUrl: '/api/admin/patients/NAME?search=Alice&token=secret&page=2&limit=Alice' } as any)).toBe('/patients/:id?page=2')
  expect(safeRequestUrl({ originalUrl: '/Alice?search=Bob' } as any)).toBe('[unmatched]')
  for (const path of ['/admin/config/evil', '/patients/auth/login', '/health-data', '/admin/access/me/evil']) expect(isControlPlaneRequest(path)).toBe(false)
})


test('actual patient search and unmatched requests do not log search terms or identifiers', async () => {
  const auth = await login(admin)
  const log = jest.spyOn(logger, 'info')
  await api.get('/api/admin/patients?search=SensitivePatientName&page=1', auth)
  await api.get('/api/PatientIdentifierNoRoute?search=SensitivePatientName', auth)
  // Morgan completes on response finish, before Axios resolves these requests.
  const messages = log.mock.calls.map(call => String(call[0])).join('\n')
  expect(messages).toContain('/patients?page=1')
  expect(messages).toContain('[request-id=')
  expect(messages).not.toContain('SensitivePatientName')
  expect(messages).not.toContain('PatientIdentifierNoRoute')
})

test('administrator transfer records source event scope and destination resource scope', async () => {
  const setup = await createAdminTotpEnrollment(platform)
  await activateAdminTotpEnrollment(platform, generateTotpCode(setup.secret))
  const refreshedPlatform = await User.findById(platform._id)
  const session = await createAuthSession({ user: refreshedPlatform! })
  expect(session).not.toBeNull()
  const timeStep = Math.floor(Date.now() / 30_000)
  const auth = { headers: {
    Authorization: `Bearer ${session!.token}`,
    'X-Step-Up-Password': secret,
    'X-Step-Up-Totp': generateTotpCode(setup.secret, timeStep),
  } }
  expect((await api.put(`/api/admin/admin-accounts/${admin._id}`, { hospital_id: String(other._id) }, { headers: { Authorization: auth.headers.Authorization } })).status).toBe(403)
  expect((await api.post(`/api/admin/admin-accounts/${admin._id}/mfa/reset`, {}, {
    headers: { Authorization: auth.headers.Authorization },
  })).status).toBe(403)
  expect((await api.put('/api/admin/role-policies/hospital_admin', {
    capabilities: DEFAULT_ADMIN_ROLE_POLICIES.hospital_admin,
    expected_version: 1,
    change_reason: 'Review policy verification',
  }, { headers: { Authorization: auth.headers.Authorization } })).status).toBe(403)
  expect((await api.put(`/api/admin/admin-accounts/${admin._id}`, { hospital_id: String(other._id) }, {
    headers: { ...auth.headers, 'X-Step-Up-Password': 'Wrong@1234' },
  })).status).toBe(403)
  const result = await api.put(`/api/admin/admin-accounts/${admin._id}`, { hospital_id: String(other._id) }, auth)
  expect(result.status).toBe(200)
  expect((await api.put(`/api/admin/admin-accounts/${admin._id}`, { role: 'auditor' }, auth)).status).toBe(403)
  const row = await AuditLog.findOne({ user_id: platform._id, action: AuditAction.ADMIN_SCOPE_CHANGE }).sort({ createdAt: -1 })
  expect(String(row?.event_hospital_id)).toBe(String(hospital._id))
  expect(String(row?.resource_hospital_id)).toBe(String(other._id))
  expect(row?.actor_role).toBe('app_admin')
  await AuditLog.updateOne({ _id: row!._id }, { $set: { event_hospital_id: other._id } })
  expect(String((await AuditLog.findById(row!._id))?.event_hospital_id)).toBe(String(hospital._id))
  const globalRole = await api.put(`/api/admin/admin-accounts/${admin._id}`, { role: 'auditor' }, {
    headers: { ...auth.headers, 'X-Step-Up-Totp': generateTotpCode(setup.secret, timeStep + 1) },
  })
  expect(globalRole.status).toBe(200)
  const roleEvent = await AuditLog.findOne({ user_id: platform._id, action: AuditAction.ADMIN_ROLE_ASSIGN }).sort({ createdAt: -1 })
  expect(String(roleEvent?.event_hospital_id)).toBe(String(other._id))
  expect(roleEvent?.resource_hospital_id).toBeUndefined()
})

test('session inventory is caller-owned and selective revocation invalidates one token', async () => {
  const first = await login(admin)
  const second = await login(admin)
  const inventory = await api.get('/api/auth/sessions', second)
  expect(inventory.status).toBe(200)
  const sessions = inventory.data.data.sessions as Array<{ id: string; current: boolean }>
  const current = sessions.find(session => session.current)
  const otherSession = sessions.find(session => !session.current)
  expect(current).toBeDefined()
  expect(otherSession).toBeDefined()
  expect(sessions.every(session => !('refresh_token_hash' in session))).toBe(true)
  expect((await api.delete(`/api/auth/sessions/${otherSession!.id}`, second)).status).toBe(200)
  expect((await api.get('/api/auth/me', first)).status).toBe(401)
  expect((await api.get('/api/auth/me', second)).status).toBe(200)
  expect((await api.delete(`/api/auth/sessions/${current!.id}`, first)).status).toBe(401)
})
