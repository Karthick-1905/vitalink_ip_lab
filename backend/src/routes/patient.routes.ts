import { Router } from 'express'
import multer from 'multer'
import { authenticate, AllowPatient, validate } from '@src/middlewares'
import {
	getProfile,
	updateinr,
	missedDoses,
	getReport,
	submitReport,
	takeDosage,
} from '@src/controllers/patient.controller'
import { logInrSchema, missedDoseSchema, reportSchema, takeDosageSchema } from '@src/validators/patient.validator'

const upload = multer({ dest: 'uploads/reports/' })

const router = Router()

router.get('/profile', authenticate, AllowPatient, getProfile)
router.post('/inr-logs', authenticate, AllowPatient, validate(logInrSchema), updateinr)
router.get('/reports', authenticate, AllowPatient, getReport)
router.post('/reports', authenticate, AllowPatient, upload.single('file'), validate(reportSchema), submitReport)
router.post('/missed-doses', authenticate, AllowPatient, validate(missedDoseSchema), missedDoses)
router.post('/dosage', authenticate, AllowPatient, validate(takeDosageSchema), takeDosage)

export default router
