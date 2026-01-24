import { Request } from 'express'
import { JWTPayload } from '@src/validators'

/**
 * Extend Express Request type to include user authentication data
 */
declare global {
  namespace Express {
    interface Request {
      user?: JWTPayload
    }
  }
}
