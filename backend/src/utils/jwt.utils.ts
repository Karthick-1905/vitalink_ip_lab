import jwt from 'jsonwebtoken'
import { config } from '@src/config'
import { JWTPayload } from '@src/validators'

/**
 * Generate a JWT token from a payload
 * @param payload - User identification data (user_id and user_type)
 * @returns Signed JWT token string
 */
export function generateToken(payload: JWTPayload): string {
  try {
    const token = jwt.sign(payload, config.jwtSecret, {
      expiresIn: config.jwtExpiresIn,
    })
    return token
  } catch (error) {
    throw new Error(`Failed to generate token: ${(error as Error).message}`)
  }
}

/**
 * Verify and decode a JWT token
 * @param token - JWT token string to verify
 * @returns Decoded payload if valid, null if invalid or expired
 */
export function verifyToken(token: string): JWTPayload | null {
  try {
    const decoded = jwt.verify(token, config.jwtSecret) as JWTPayload
    return decoded
  } catch (error) {
    // Token is invalid or expired, return null
    return null
  }
}

/**
 * Extract token from Authorization header
 * Expected format: "Bearer {token}"
 * @param authHeader - Authorization header value
 * @returns Token string or null if malformed
 */
export function extractTokenFromHeader(authHeader?: string): string | null {
  if (!authHeader) {
    return null
  }

  const parts = authHeader.split(' ')
  
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return null
  }

  return parts[1]
}
