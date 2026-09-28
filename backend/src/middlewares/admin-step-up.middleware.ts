import type { RequestHandler } from 'express'
import { StatusCodes } from 'http-status-codes'
import { User } from '@alias/models'
import { comparePasswords } from '@alias/utils'
import { verifyAdminTotpForStepUp } from '@alias/services/admin-totp.service'
import { recordFailedLoginAttempt } from '@alias/services/login-lockout.service'

/** The credentials are checked for this request only. No reusable grant is issued. */
export const requireAdminStepUp: RequestHandler = async (req, res, next) => {
  try {
    const password = req.header('x-step-up-password')
    const code = req.header('x-step-up-totp')
    if (!password || !code || !/^\d{6}$/.test(code) || !req.user?.user_id || !req.user.session_id) {
      res.status(StatusCodes.FORBIDDEN).json({ success: false, message: 'Password and authenticator code are required for this action.', code: 'STEP_UP_REQUIRED' })
      return
    }
    const user = await User.findOne({ _id: req.user.user_id, user_type: 'ADMIN', is_active: true })
    if (!user || (user.locked_until && user.locked_until.getTime() > Date.now())) {
      res.status(StatusCodes.FORBIDDEN).json({ success: false, message: 'Administrator verification is unavailable.', code: 'STEP_UP_REQUIRED' })
      return
    }
    const passwordValid = await comparePasswords({ password, salt: user.salt, hashedPassword: user.password })
    if (!passwordValid || !await verifyAdminTotpForStepUp(user, code)) {
      await recordFailedLoginAttempt(user._id)
      res.status(StatusCodes.FORBIDDEN).json({ success: false, message: 'Administrator verification failed.', code: 'STEP_UP_REQUIRED' })
      return
    }
    next()
  } catch (error) {
    next(error)
  }
}
