import { Request, Response, NextFunction } from 'express'
import { StatusCodes } from 'http-status-codes'
import { verifyToken, extractTokenFromHeader } from '@src/utils/jwt.utils'
import { JWTPayload, UserType } from '@src/validators'

/**
 * Extend Express Request to include user data
 */
declare global {
  namespace Express {
    interface Request {
      user?: JWTPayload
    }
  }
}

/**
 * Authenticate middleware - verifies JWT token from Authorization header
 * Attaches user data to req.user if valid
 */
export const authenticate = (req: Request, res: Response, next: NextFunction): void => {
  try {
    const authHeader = req.headers.authorization
    const token = extractTokenFromHeader(authHeader)

    if (!token) {
      res.status(StatusCodes.UNAUTHORIZED).json({
        success: false,
        message: 'Missing authentication token. Please provide Authorization header with Bearer token.',
      })
      return
    }

    const payload = verifyToken(token)

    if (!payload) {
      res.status(StatusCodes.UNAUTHORIZED).json({
        success: false,
        message: 'Invalid or expired authentication token.',
      })
      return
    }

    // Attach user data to request
    req.user = payload
    next()
  } catch (error) {
    res.status(StatusCodes.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Error during authentication.',
    })
  }
}

/**
 * Authorization middleware factory - restricts access to specific user roles
 * @param allowedRoles - Array of UserType values that are allowed
 * @returns Middleware function
 */
export const authorize = (allowedRoles: UserType[]) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    // Check if authenticate middleware has been applied
    if (!req.user) {
      res.status(StatusCodes.UNAUTHORIZED).json({
        success: false,
        message: 'Authentication required.',
      })
      return
    }

    // Check if user role is in allowed roles
    if (!allowedRoles.includes(req.user.user_type)) {
      res.status(StatusCodes.FORBIDDEN).json({
        success: false,
        message: 'Insufficient permissions. Your role does not have access to this resource.',
      })
      return
    }

    next()
  }
}
