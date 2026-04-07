import { NextFunction, Request, Response, Router } from 'express'
import multer from 'multer'
import { authenticate, AllowPatient, validate } from '@alias/middlewares'
import { checkTokens, deductTokensAfterSuccess } from '@alias/middlewares/checkTokens'
import { PatientFeature } from '@alias/services/patient-token.service'
import {
	getProfile,
	missedDoses,
	getReport,
	submitReport,
	takeDosage,
	getDosageCalendar,
	updateHealthLogs,
	updateProfilePicture,
	updateProfile,
	getDoctorUpdates,
	getDoctorUpdatesSummary,
	getNotifications,
	markAllNotificationsAsRead,
	markNotificationAsRead,
	markDoctorUpdateAsRead,
	markAllDoctorUpdatesAsRead,
	streamNotifications,
} from '@alias/controllers/patient.controller'
import { createPaymentOrder, getTokenBalance, getTokenTransactions, getFeatureCosts } from '@alias/controllers/payment.controller'
import {
	reportSchema,
	takeDosageSchema,
	updateHealthLogSchema,
	updateProfileSchema,
	doctorUpdatesQuerySchema,
	notificationsQuerySchema,
	markNotificationReadSchema,
	markDoctorUpdateReadSchema,
} from '@alias/validators/patient.validator'
import { createPaymentOrderSchema } from '@alias/validators/payment.validator'
import { ApiError } from '@alias/utils'
import { StatusCodes } from 'http-status-codes'

const REPORT_MAX_SIZE_BYTES = 10 * 1024 * 1024
const PROFILE_PICTURE_MAX_SIZE_BYTES = 5 * 1024 * 1024

const REPORT_MIME_TYPES = new Set(['application/pdf', 'image/png', 'image/jpeg', 'image/jpg'])
const PROFILE_PICTURE_MIME_TYPES = new Set(['image/png', 'image/jpeg', 'image/jpg', 'image/webp'])

const reportUpload = multer({
	storage: multer.memoryStorage(),
	limits: { fileSize: REPORT_MAX_SIZE_BYTES },
	fileFilter: (_req, file, cb) => {
		if (!REPORT_MIME_TYPES.has(file.mimetype)) {
			cb(new ApiError(StatusCodes.BAD_REQUEST, 'Invalid file type. Only PDF, PNG, JPEG allowed'))
			return
		}
		cb(null, true)
	}
})

const profilePictureUpload = multer({
	storage: multer.memoryStorage(),
	limits: { fileSize: PROFILE_PICTURE_MAX_SIZE_BYTES },
	fileFilter: (_req, file, cb) => {
		if (!PROFILE_PICTURE_MIME_TYPES.has(file.mimetype)) {
			cb(new ApiError(StatusCodes.BAD_REQUEST, 'Invalid file type. Only PNG, JPEG, JPG, and WEBP images are allowed'))
			return
		}
		cb(null, true)
	}
})

const uploadReportFile = (req: Request, res: Response, next: NextFunction) => {
	reportUpload.single('file')(req, res, (err: unknown) => {
		if (!err) {
			next()
			return
		}

		if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
			next(new ApiError(StatusCodes.BAD_REQUEST, 'File size exceeds 10MB limit'))
			return
		}

		next(err as Error)
	})
}

const uploadProfilePictureFile = (req: Request, res: Response, next: NextFunction) => {
	profilePictureUpload.single('file')(req, res, (err: unknown) => {
		if (!err) {
			next()
			return
		}

		if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
			next(new ApiError(StatusCodes.BAD_REQUEST, 'File size exceeds 5MB limit'))
			return
		}

		next(err as Error)
	})
}

const router = Router()

router.route('/profile').get(authenticate, AllowPatient, getProfile).put(authenticate, AllowPatient, checkTokens(PatientFeature.PROFILE_UPDATE), validate(updateProfileSchema), updateProfile)
router.get('/reports', authenticate, AllowPatient, getReport)
router.post('/reports', authenticate, AllowPatient, checkTokens(PatientFeature.REPORT_UPLOAD), uploadReportFile, validate(reportSchema), submitReport)
router.get('/missed-doses', authenticate, AllowPatient, missedDoses)
router.get('/dosage-calendar', authenticate, AllowPatient, getDosageCalendar)
router.post('/dosage', authenticate, AllowPatient, checkTokens(PatientFeature.DOSAGE_LOG), validate(takeDosageSchema), takeDosage)
router.post('/health-logs', authenticate, AllowPatient, checkTokens(PatientFeature.HEALTH_LOG_UPDATE), validate(updateHealthLogSchema), updateHealthLogs)
router.get('/tokens/balance', authenticate, AllowPatient, getTokenBalance)
router.get('/tokens/transactions', authenticate, AllowPatient, getTokenTransactions)
router.get('/tokens/feature-costs', authenticate, AllowPatient, getFeatureCosts)
router.post('/payments/order', authenticate, AllowPatient, validate(createPaymentOrderSchema), createPaymentOrder)
router.get('/notifications/stream', streamNotifications)
router.get('/notifications', authenticate, AllowPatient, validate(notificationsQuerySchema), getNotifications)
router.patch('/notifications/read-all', authenticate, AllowPatient, markAllNotificationsAsRead)
router.patch('/notifications/:notification_id/read', authenticate, AllowPatient, validate(markNotificationReadSchema), markNotificationAsRead)
router.get('/doctor-updates/summary', authenticate, AllowPatient, getDoctorUpdatesSummary)
router.get('/doctor-updates', authenticate, AllowPatient, validate(doctorUpdatesQuerySchema), getDoctorUpdates)
router.patch('/doctor-updates/read-all', authenticate, AllowPatient, markAllDoctorUpdatesAsRead)
router.patch('/doctor-updates/:event_id/read', authenticate, AllowPatient, validate(markDoctorUpdateReadSchema), markDoctorUpdateAsRead)
router.post("/profile-pic", authenticate, AllowPatient, uploadProfilePictureFile, updateProfilePicture)

export default router
