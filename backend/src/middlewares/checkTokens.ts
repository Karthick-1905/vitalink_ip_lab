import { Request, Response, NextFunction } from 'express'
import { ApiError } from '@alias/utils'
import { StatusCodes } from 'http-status-codes'
import * as patientTokenService from '@alias/services/patient-token.service'

/**
 * Middleware to check if patient has sufficient tokens for a feature
 * Usage: router.post('/endpoint', checkTokens(PatientFeature.FEATURE_NAME), controllerFunction)
 */
export const checkTokens = (feature: patientTokenService.PatientFeature) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const user = (req as any).user
      if (!user || !user.user_id) {
        throw new ApiError(StatusCodes.UNAUTHORIZED, 'User not authenticated')
      }

      // Check if user has sufficient tokens for this feature
      await patientTokenService.checkSufficientTokens(user.user_id, feature)

      // Store feature and cost in request for later use
      ;(req as any).tokenFeature = feature
      ;(req as any).tokenCost = await patientTokenService.getFeatureCost(feature)

      next()
    } catch (error) {
      if (error instanceof ApiError) {
        res.status(error.statusCode).json({
          success: false,
          statusCode: error.statusCode,
          message: error.message,
        })
      } else {
        next(error)
      }
    }
  }
}

/**
 * Helper function to deduct tokens after successful operation
 * Call this at the end of your controller function
 */
export const deductTokensAfterSuccess = async (req: Request, metadata?: Record<string, any>) => {
  const feature = (req as any).tokenFeature
  const user = (req as any).user

  if (!feature || !user) {
    return
  }

  try {
    await patientTokenService.deductTokensForFeature(user.user_id, feature, metadata)
  } catch (error) {
    // Log error but don't fail the request
    console.error('Error deducting tokens:', error)
  }
}
