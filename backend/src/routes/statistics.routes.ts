import { Router } from 'express'
import { authenticate, authorize } from '@alias/middlewares'
import { UserType } from '@alias/validators'
import {
  getAdminStats, getTrends, getCompliance, getWorkload, getPeriodStats,
} from '@alias/controllers/statistics.controller'

const router = Router()

// All statistics routes require authentication
router.use(authenticate)

// Admin-only statistics
router.get('/admin', authorize([UserType.ADMIN]), getAdminStats)
router.get('/trends', authorize([UserType.ADMIN]), getTrends)
router.get('/compliance', authorize([UserType.ADMIN]), getCompliance)
router.get('/workload', authorize([UserType.ADMIN]), getWorkload)
router.get('/period', authorize([UserType.ADMIN]), getPeriodStats)

export default router
