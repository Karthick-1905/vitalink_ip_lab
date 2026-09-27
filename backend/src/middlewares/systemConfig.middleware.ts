import { NextFunction, Request, Response } from 'express'
import { StatusCodes } from 'http-status-codes'
import { isFeatureEnabled } from '@alias/services/config.service'

// Exact bootstrap endpoints only. Every route keeps its authentication and RBAC.
const CONTROL_PLANE_PATHS = new Set([
  '/admin/config', '/admin/access/me', '/health', '/health/live', '/health/ready',
  '/auth/login', '/auth/login/otp/verify', '/auth/login/otp/resend',
  '/auth/login/totp/verify', '/auth/login/totp/enroll/setup', '/auth/login/totp/enroll/activate',
  '/auth/refresh', '/auth/revoke', '/auth/logout', '/auth/me', '/auth/change-password',
  '/auth/admin/mfa/totp/setup', '/auth/admin/mfa/totp/status', '/auth/admin/mfa/totp/activate',
])

export const isControlPlaneRequest = (path: string) =>
  CONTROL_PLANE_PATHS.has(path.toLowerCase().replace(/^\/api(?:\/v\d+)?(?=\/)/, '').replace(/\/$/, ''))

export const isPatientRegistrationRequest = (method: string, path: string) =>
  method === 'POST' && (/\/admin\/patients$/.test(path) || /\/doctors\/patients$/.test(path))

export const enforceSystemFeatureFlags = async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (await isFeatureEnabled('maintenance_mode') && !isControlPlaneRequest(req.path)) {
      res.status(StatusCodes.SERVICE_UNAVAILABLE).json({
        success: false,
        message: 'The service is temporarily unavailable for maintenance.',
      })
      return
    }

    const isPatientRegistration = isPatientRegistrationRequest(req.method, req.path)
    if (isPatientRegistration && !await isFeatureEnabled('patient_registration_enabled')) {
      res.status(StatusCodes.SERVICE_UNAVAILABLE).json({
        success: false,
        message: 'Patient registration is currently disabled.',
      })
      return
    }

    next()
  } catch (error) {
    next(error)
  }
}
