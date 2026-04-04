import { Request } from 'express'
import { JWTPayload } from '@alias/validators'

/**
 * Extend Express Request type to include user authentication data
 */
declare global {
  namespace Express {
    interface Request {
      user?: JWTPayload
      requestId?: string
      validatedQuery?: unknown
      rawBody?: string
    }
  }
}
declare module "express-serve-static-core" {
  interface Request {
    requestId?: string;
    validatedQuery?: unknown;
    rawBody?: string;
  }
}
