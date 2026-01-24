import { Request, Response } from 'express'
import { StatusCodes } from 'http-status-codes'
import * as authService from '@src/services/auth.service'
import { UserType } from '@src/validators'

/**
 * POST /api/auth/register
 * Register a new user (Doctor or Patient)
 */
export const registerController = async (req: Request, res: Response): Promise<void> => {
  try {
    const { login_id, password, user_type, doctor_details, patient_details } = req.body

    const newUser = await authService.registerUser({
      login_id,
      password,
      user_type,
      doctor_details,
      patient_details,
    })

    res.status(StatusCodes.CREATED).json({
      success: true,
      message: 'User registered successfully',
      data: {
        user: newUser,
      },
    })
  } catch (error) {
    const errorMessage = (error as Error).message

    // Check for specific errors
    if (errorMessage.includes('already exists')) {
      res.status(StatusCodes.CONFLICT).json({
        success: false,
        message: 'User with this login ID already exists',
        errors: [{ message: errorMessage }],
      })
      return
    }

    if (errorMessage.includes('Invalid user type')) {
      res.status(StatusCodes.BAD_REQUEST).json({
        success: false,
        message: 'Invalid user type provided',
        errors: [{ message: errorMessage }],
      })
      return
    }

    res.status(StatusCodes.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Error during registration',
      errors: [{ message: errorMessage }],
    })
  }
}

/**
 * POST /api/auth/login
 * Authenticate user and return JWT token
 */
export const loginController = async (req: Request, res: Response): Promise<void> => {
  try {
    const { login_id, password } = req.body

    const result = await authService.loginUser(login_id, password)

    res.status(StatusCodes.OK).json({
      success: true,
      message: 'Login successful',
      data: {
        token: result.token,
        user: result.user,
      },
    })
  } catch (error) {
    const errorMessage = (error as Error).message

    // Check for specific errors
    if (errorMessage.includes('Invalid credentials')) {
      res.status(StatusCodes.UNAUTHORIZED).json({
        success: false,
        message: 'Invalid login credentials',
        errors: [{ message: 'Login ID or password is incorrect' }],
      })
      return
    }

    if (errorMessage.includes('inactive')) {
      res.status(StatusCodes.FORBIDDEN).json({
        success: false,
        message: 'Account is inactive',
        errors: [{ message: errorMessage }],
      })
      return
    }

    res.status(StatusCodes.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Error during login',
      errors: [{ message: errorMessage }],
    })
  }
}

/**
 * POST /api/auth/logout
 * Logout user (invalidate session)
 * Note: With stateless JWT, logout is primarily frontend-side (clear token)
 * Server-side implementation would require token blacklist/Redis
 */
export const logoutController = async (req: Request, res: Response): Promise<void> => {
  try {
    res.status(StatusCodes.OK).json({
      success: true,
      message: 'Logout successful. Please clear the token from client-side.',
    })
  } catch (error) {
    const errorMessage = (error as Error).message

    res.status(StatusCodes.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Error during logout',
      errors: [{ message: errorMessage }],
    })
  }
}

/**
 * GET /api/auth/me
 * Get current authenticated user's profile
 */
export const getMeController = async (req: Request, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(StatusCodes.UNAUTHORIZED).json({
        success: false,
        message: 'User not authenticated',
      })
      return
    }

    const userProfile = await authService.getUserProfile(
      req.user.user_id,
      req.user.user_type
    )

    res.status(StatusCodes.OK).json({
      success: true,
      message: 'User profile retrieved successfully',
      data: {
        user: userProfile,
      },
    })
  } catch (error) {
    const errorMessage = (error as Error).message

    if (errorMessage.includes('not found')) {
      res.status(StatusCodes.NOT_FOUND).json({
        success: false,
        message: 'User not found',
        errors: [{ message: errorMessage }],
      })
      return
    }

    res.status(StatusCodes.INTERNAL_SERVER_ERROR).json({
      success: false,
      message: 'Error retrieving user profile',
      errors: [{ message: errorMessage }],
    })
  }
}
