import { Request, Response } from 'express'
import { StatusCodes } from 'http-status-codes'
import { asyncHandler, ApiResponse } from '@alias/utils'
import * as adminService from '@alias/services/admin.service'
import * as configService from '@alias/services/config.service'
import * as notificationService from '@alias/services/notification.service'
import * as passwordService from '@alias/services/password.service'
import { User, DoctorProfile, PatientProfile } from '@alias/models'
import { UserType } from '@alias/validators'

// ─── Doctor Management ───

export const createDoctor = asyncHandler(async (req: Request, res: Response) => {
  const result = await adminService.registerDoctor(req.body)
  res.status(StatusCodes.CREATED).json(new ApiResponse(StatusCodes.CREATED, 'Doctor created successfully', result))
})

export const getAllDoctors = asyncHandler(async (req: Request, res: Response) => {
  const { page, limit, department, is_active, search } = req.query as any
  const filters: any = {}
  if (department) filters.department = department
  if (is_active !== undefined) filters.is_active = is_active === 'true'
  if (search) filters.search = search

  const result = await adminService.getAllDoctors(filters, { page: Number(page), limit: Number(limit) })
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Doctors retrieved successfully', result))
})

export const updateDoctor = asyncHandler(async (req: Request, res: Response) => {
  const { id } = req.params
  const result = await adminService.updateDoctor(id, req.body)
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Doctor updated successfully', result))
})

export const deactivateDoctor = asyncHandler(async (req: Request, res: Response) => {
  const { id } = req.params
  const result = await adminService.deactivateDoctor(id)
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Doctor deactivated successfully', result))
})

// ─── Patient Management ───

export const createPatient = asyncHandler(async (req: Request, res: Response) => {
  const result = await adminService.onboardPatient(req.body)
  res.status(StatusCodes.CREATED).json(new ApiResponse(StatusCodes.CREATED, 'Patient created successfully', result))
})

export const getAllPatients = asyncHandler(async (req: Request, res: Response) => {
  const { page, limit, assigned_doctor_id, account_status, search } = req.query as any
  const filters: any = {}
  if (assigned_doctor_id) filters.assigned_doctor_id = assigned_doctor_id
  if (account_status) filters.account_status = account_status
  if (search) filters.search = search

  const result = await adminService.getAllPatients(filters, { page: Number(page), limit: Number(limit) })
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Patients retrieved successfully', result))
})

export const updatePatient = asyncHandler(async (req: Request, res: Response) => {
  const { id } = req.params
  const result = await adminService.updatePatient(id, req.body)
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Patient updated successfully', result))
})

export const deactivatePatient = asyncHandler(async (req: Request, res: Response) => {
  const { id } = req.params
  const result = await adminService.deactivatePatient(id)
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Patient deactivated successfully', result))
})

export const reassignPatient = asyncHandler(async (req: Request, res: Response) => {
  const { op_num } = req.params
  const { new_doctor_id } = req.body
  const result = await adminService.reassignPatient(op_num, new_doctor_id)
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Patient reassigned successfully', result))
})

// ─── Audit Logs ───

export const getAuditLogs = asyncHandler(async (req: Request, res: Response) => {
  const { page, limit, user_id, action, start_date, end_date, success } = req.query as any
  const filters: any = {}
  if (user_id) filters.user_id = user_id
  if (action) filters.action = action
  if (start_date) filters.start_date = start_date
  if (end_date) filters.end_date = end_date
  if (success !== undefined) filters.success = success === 'true'

  const result = await adminService.getAuditLogs(filters, { page: Number(page), limit: Number(limit) })
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Audit logs retrieved successfully', result))
})

// ─── System Config ───

export const getSystemConfig = asyncHandler(async (req: Request, res: Response) => {
  const config = await configService.getSystemConfig()
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'System config retrieved', config))
})

export const updateSystemConfig = asyncHandler(async (req: Request, res: Response) => {
  const config = await configService.updateSystemConfig(req.body)
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'System config updated', config))
})

// ─── Notifications ───

export const broadcastNotification = asyncHandler(async (req: Request, res: Response) => {
  const { title, message, target, user_ids, priority } = req.body
  const result = await notificationService.broadcastNotification(title, message, target, user_ids, priority)
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Notification broadcast successful', result))
})

// ─── Batch Operations ───

export const performBatchOperation = asyncHandler(async (req: Request, res: Response) => {
  const { operation, user_ids } = req.body
  const result = await adminService.performBatchOperation(operation, user_ids)
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Batch operation completed', result))
})

// ─── System Health ───

export const getSystemHealth = asyncHandler(async (req: Request, res: Response) => {
  const health = await adminService.getSystemHealth()
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'System health', health))
})

// ─── Legacy Endpoints ───

export const listAllPatients = asyncHandler(async (req: Request, res: Response) => {
  const patients = await User.find({ user_type: UserType.PATIENT })
    .populate('profile_id')
    .sort({ createdAt: -1 })
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'All patients', { patients }))
})

export const getPatientById = asyncHandler(async (req: Request, res: Response) => {
  const { op_num } = req.params
  const user = await User.findOne({ login_id: op_num, user_type: UserType.PATIENT }).populate('profile_id')
  if (!user) {
    res.status(StatusCodes.NOT_FOUND).json(new ApiResponse(StatusCodes.NOT_FOUND, 'Patient not found'))
    return
  }
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Patient found', { patient: user }))
})

export const getDoctorById = asyncHandler(async (req: Request, res: Response) => {
  const { id } = req.params
  const user = await User.findById(id).populate('profile_id')
  if (!user || user.user_type !== UserType.DOCTOR) {
    res.status(StatusCodes.NOT_FOUND).json(new ApiResponse(StatusCodes.NOT_FOUND, 'Doctor not found'))
    return
  }
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Doctor found', { doctor: user }))
})

// ─── Password Reset ───

export const resetUserPassword = asyncHandler(async (req: Request, res: Response) => {
  const { target_user_id, new_password } = req.body
  const adminUserId = req.user!.user_id
  const result = await passwordService.adminResetPassword(adminUserId, target_user_id, new_password)
  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Password reset successful', result))
})
