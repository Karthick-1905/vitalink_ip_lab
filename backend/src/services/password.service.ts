import { StatusCodes } from 'http-status-codes'
import { randomInt } from 'crypto'
import { User, AuditLog } from '@alias/models'
import { AuditAction } from '@alias/models/auditlog.model'
import { ApiError } from '@alias/utils'

function getRandomChar(charset: string): string {
  return charset[randomInt(0, charset.length)]
}

export function generateTemporaryPassword(length = 16): string {
  const normalizedLength = Math.max(length, 12)
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
  const lower = 'abcdefghijkmnopqrstuvwxyz'
  const numbers = '23456789'
  const symbols = '!@#$%^&*()-_=+'
  const all = upper + lower + numbers + symbols

  const passwordChars = [
    getRandomChar(upper),
    getRandomChar(lower),
    getRandomChar(numbers),
    getRandomChar(symbols),
  ]

  for (let i = passwordChars.length; i < normalizedLength; i++) {
    passwordChars.push(getRandomChar(all))
  }

  for (let i = passwordChars.length - 1; i > 0; i--) {
    const swapIndex = randomInt(0, i + 1)
    const temp = passwordChars[i]
    passwordChars[i] = passwordChars[swapIndex]
    passwordChars[swapIndex] = temp
  }

  return passwordChars.join('')
}

export async function adminResetPassword(
  adminUserId: string,
  targetUserId: string,
  newPassword?: string
) {
  const targetUser = await User.findById(targetUserId)
  if (!targetUser) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Target user not found')
  }

  const password = newPassword?.trim() || generateTemporaryPassword()
  targetUser.password = password
  targetUser.must_change_password = true
  await targetUser.save()

  // Log the action
  await AuditLog.create({
    user_id: adminUserId,
    user_type: 'ADMIN',
    action: AuditAction.PASSWORD_RESET,
    description: `Admin reset password for user ${targetUser.login_id}`,
    resource_type: 'User',
    resource_id: targetUserId,
    success: true,
  })

  return {
    message: 'Password reset successfully',
    user_id: targetUserId,
    login_id: targetUser.login_id,
    temporary_password: password,
    must_change_password: true,
  }
}
