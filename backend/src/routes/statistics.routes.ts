import { Router } from 'express'
import { authenticate, authorize, validate } from '@alias/middlewares'
import { UserType } from '@alias/validators'
import {
  getAdminStats, getTrends, getCompliance, getWorkload, getPeriodStats,
} from '@alias/controllers/statistics.controller'
import { z } from 'zod'

const router = Router()
const validDateString = z.string('Date should be a string').refine(
  (value) => !Number.isNaN(Date.parse(value)),
  'Date should be a valid date string'
)

const trendsQuerySchema = z.object({
  query: z.object({
    period: z.enum(['7d', '30d', '90d', '1y']).optional(),
  }).strict()
})

const periodStatsQuerySchema = z.object({
  query: z.object({
    start_date: validDateString.optional(),
    end_date: validDateString.optional(),
  }).strict().refine(
    ({ start_date, end_date }) => {
      if (!start_date || !end_date) return true
      return new Date(end_date).getTime() >= new Date(start_date).getTime()
    },
    { message: 'end_date must be greater than or equal to start_date' }
  )
})

// All statistics routes require authentication
router.use(authenticate)

// Admin-only statistics
router.get('/admin', authorize([UserType.ADMIN]), getAdminStats)
router.get('/trends', authorize([UserType.ADMIN]), validate(trendsQuerySchema), getTrends)
router.get('/compliance', authorize([UserType.ADMIN]), getCompliance)
router.get('/workload', authorize([UserType.ADMIN]), getWorkload)
router.get('/period', authorize([UserType.ADMIN]), validate(periodStatsQuerySchema), getPeriodStats)

export default router
