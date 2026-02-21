import { Router } from 'express'
import { authenticate, authorize, validate } from '@alias/middlewares'
import { UserType } from '@alias/validators'
import {
  createDoctor, getAllDoctors, updateDoctor, deactivateDoctor,
  createPatient, getAllPatients, updatePatient, deactivatePatient,
  reassignPatient, getAuditLogs, getSystemConfig, updateSystemConfig,
  broadcastNotification, performBatchOperation, getSystemHealth,
  listAllPatients, getPatientById, getDoctorById, resetUserPassword,
} from '@alias/controllers/admin.controller'
import {
  createDoctorSchema, updateDoctorSchema, getDoctorsSchema,
  createPatientSchema, updatePatientSchema, getUsersSchema,
  reassignPatientSchema, userIdParamSchema,
} from '@alias/validators/admin.validator'

const router = Router()

// All admin routes require authentication + ADMIN role
router.use(authenticate)
router.use(authorize([UserType.ADMIN]))

// ─── Doctor Management ───
router.post('/doctors', validate(createDoctorSchema), createDoctor)
router.get('/doctors', validate(getDoctorsSchema), getAllDoctors)
router.put('/doctors/:id', validate(updateDoctorSchema), updateDoctor)
router.delete('/doctors/:id', validate(userIdParamSchema), deactivateDoctor)

// ─── Patient Management ───
router.post('/patients', validate(createPatientSchema), createPatient)
router.get('/patients', validate(getUsersSchema), getAllPatients)
router.put('/patients/:id', validate(updatePatientSchema), updatePatient)
router.delete('/patients/:id', validate(userIdParamSchema), deactivatePatient)

// ─── Patient Reassignment ───
router.put('/reassign/:op_num', validate(reassignPatientSchema), reassignPatient)

// ─── Audit Logs ───
router.get('/audit-logs', getAuditLogs)

// ─── System Config ───
router.get('/config', getSystemConfig)
router.put('/config', updateSystemConfig)

// ─── Notifications ───
router.post('/notifications/broadcast', broadcastNotification)

// ─── Batch Operations ───
router.post('/users/batch', performBatchOperation)

// ─── Password Reset ───
router.post('/users/reset-password', resetUserPassword)

// ─── System Health ───
router.get('/system/health', getSystemHealth)

// ─── Legacy Endpoints ───
router.get('/legacy/patients', listAllPatients)
router.get('/legacy/patient/:op_num', getPatientById)
router.get('/legacy/doctor/:id', getDoctorById)

export default router
