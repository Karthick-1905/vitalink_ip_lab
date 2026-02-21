import { StatusCodes } from 'http-status-codes'
import { User, AuditLog } from '@alias/models'
import { AuditAction } from '@alias/models/auditlog.model'
import { ApiError } from '@alias/utils'

export async function adminResetPassword(
  adminUserId: string,
  targetUserId: string,
  newPassword?: string
) {
  const targetUser = await User.findById(targetUserId)
  if (!targetUser) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Target user not found')
  }

  const password = newPassword || 'VitaLink@User123'
  targetUser.password = password
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
  }
}
