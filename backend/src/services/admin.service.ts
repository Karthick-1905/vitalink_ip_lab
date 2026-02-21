import { StatusCodes } from 'http-status-codes'
import { User, DoctorProfile, PatientProfile, AuditLog } from '@alias/models'
import { ApiError } from '@alias/utils'
import { UserType } from '@alias/validators'

async function findDoctorByIdentifier(identifier: string) {
  let doctor = await User.findById(identifier)
  if (!doctor || doctor.user_type !== UserType.DOCTOR) {
    doctor = await User.findOne({ login_id: identifier, user_type: UserType.DOCTOR })
  }
  if (!doctor || doctor.user_type !== UserType.DOCTOR) {
    return null
  }
  return doctor
}

// ─── Doctor Management ───

export async function registerDoctor(data: {
  login_id: string
  password: string
  name: string
  department?: string
  contact_number?: string
  profile_picture_url?: string
}) {
  const existingUser = await User.findOne({ login_id: data.login_id })
  if (existingUser) {
    throw new ApiError(StatusCodes.CONFLICT, 'A user with this login ID already exists')
  }

  const doctorProfile = await DoctorProfile.create({
    name: data.name,
    department: data.department || 'Cardiology',
    contact_number: data.contact_number,
    profile_picture_url: data.profile_picture_url,
  })

  const user = await User.create({
    login_id: data.login_id,
    password: data.password,
    user_type: UserType.DOCTOR,
    profile_id: doctorProfile._id,
    user_type_model: 'DoctorProfile',
  })

  return {
    user: await User.findById(user._id).populate('profile_id'),
  }
}

export async function getAllDoctors(
  filters: { department?: string; is_active?: boolean; search?: string } = {},
  pagination: { page?: number; limit?: number } = {}
) {
  const { department, is_active, search } = filters
  const page = pagination.page || 1
  const limit = pagination.limit || 20

  const query: any = { user_type: UserType.DOCTOR }

  if (typeof is_active === 'boolean') {
    query.is_active = is_active
  }

  const users = await User.find(query)
    .populate('profile_id')
    .sort({ createdAt: -1 })

  const filteredUsers = users.filter((user: any) => {
    const profile = user.profile_id as any
    if (!profile) return false
    if (department) {
      const departmentMatch = profile.department?.toLowerCase().includes(department.toLowerCase())
      if (!departmentMatch) return false
    }
    if (search) {
      const s = search.toLowerCase()
      const nameMatch = profile.name?.toLowerCase().includes(s)
      const loginMatch = user.login_id?.toLowerCase().includes(s)
      if (!nameMatch && !loginMatch) return false
    }
    return true
  })

  const total = filteredUsers.length
  const skip = (page - 1) * limit
  const paginatedUsers = filteredUsers.slice(skip, skip + limit)

  return {
    doctors: paginatedUsers,
    pagination: {
      total,
      page,
      limit,
      pages: Math.ceil(total / limit),
      hasNext: page * limit < total,
      hasPrev: page > 1,
    },
  }
}

export async function updateDoctor(
  userId: string,
  data: {
    name?: string
    department?: string
    contact_number?: string
    profile_picture_url?: string
    is_active?: boolean
    password?: string
  }
) {
  // Find user by _id or login_id
  let user = await User.findById(userId).populate('profile_id')
  if (!user) {
    user = await User.findOne({ login_id: userId }).populate('profile_id')
  }
  if (!user) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Doctor not found')
  }
  if (user.user_type !== UserType.DOCTOR) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'User is not a doctor')
  }

  // Update profile fields
  const profileUpdate: any = {}
  if (data.name) profileUpdate.name = data.name
  if (data.department) profileUpdate.department = data.department
  if (data.contact_number !== undefined) profileUpdate.contact_number = data.contact_number
  if (data.profile_picture_url !== undefined) profileUpdate.profile_picture_url = data.profile_picture_url

  if (Object.keys(profileUpdate).length > 0) {
    await DoctorProfile.findByIdAndUpdate(user.profile_id, profileUpdate)
  }

  // Update user-level fields
  if (typeof data.is_active === 'boolean') {
    user.is_active = data.is_active
  }
  if (data.password) {
    user.password = data.password
  }
  await user.save()

  return await User.findById(user._id).populate('profile_id')
}

export async function deactivateDoctor(userId: string) {
  let user = await User.findById(userId)
  if (!user) {
    user = await User.findOne({ login_id: userId })
  }
  if (!user) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Doctor not found')
  }
  if (user.user_type !== UserType.DOCTOR) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'User is not a doctor')
  }

  user.is_active = false
  await user.save()

  return { message: 'Doctor deactivated successfully' }
}

// ─── Patient Management ───

export async function onboardPatient(data: {
  login_id: string
  password: string
  assigned_doctor_id: string // supports doctor user _id or doctor login_id
  demographics: {
    name: string
    age?: number
    gender?: 'Male' | 'Female' | 'Other'
    phone?: string
    next_of_kin?: { name?: string; relation?: string; relationship?: string; phone?: string }
  }
  medical_config?: {
    diagnosis?: string
    therapy_drug?: string
    therapy_start_date?: string
    target_inr?: { min: number; max: number }
  }
}) {
  const existingUser = await User.findOne({ login_id: data.login_id })
  if (existingUser) {
    throw new ApiError(StatusCodes.CONFLICT, 'A user with this login ID already exists')
  }

  // Validate assigned doctor
  const doctorUser = await findDoctorByIdentifier(data.assigned_doctor_id)
  if (!doctorUser || doctorUser.user_type !== UserType.DOCTOR) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid or inactive doctor ID')
  }
  if (!doctorUser.is_active) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Assigned doctor is inactive')
  }

  const nextOfKin = data.demographics.next_of_kin
    ? {
        name: data.demographics.next_of_kin.name,
        relation: data.demographics.next_of_kin.relation ?? data.demographics.next_of_kin.relationship,
        phone: data.demographics.next_of_kin.phone,
      }
    : undefined

  const patientProfile = await PatientProfile.create({
    assigned_doctor_id: doctorUser._id,
    demographics: {
      name: data.demographics.name,
      age: data.demographics.age,
      gender: data.demographics.gender,
      phone: data.demographics.phone,
      next_of_kin: nextOfKin,
    },
    medical_config: data.medical_config
      ? {
          ...data.medical_config,
          therapy_start_date: data.medical_config.therapy_start_date
            ? new Date(data.medical_config.therapy_start_date)
            : undefined,
        }
      : undefined,
  })

  const user = await User.create({
    login_id: data.login_id,
    password: data.password,
    user_type: UserType.PATIENT,
    profile_id: patientProfile!._id,
    user_type_model: 'PatientProfile',
  })

  return {
    user: await User.findById(user._id).populate('profile_id'),
  }
}

export async function getAllPatients(
  filters: { assigned_doctor_id?: string; account_status?: string; search?: string } = {},
  pagination: { page?: number; limit?: number } = {}
) {
  const page = pagination.page || 1
  const limit = pagination.limit || 20

  const query: any = { user_type: UserType.PATIENT }

  const users = await User.find(query)
    .populate('profile_id')
    .sort({ createdAt: -1 })

  let assignedDoctorId: string | undefined
  if (filters.assigned_doctor_id) {
    const doctorUser = await findDoctorByIdentifier(filters.assigned_doctor_id)
    if (!doctorUser) {
      return {
        patients: [],
        pagination: {
          total: 0,
          page,
          limit,
          pages: 0,
          hasNext: false,
          hasPrev: false,
        },
      }
    }
    assignedDoctorId = String(doctorUser._id)
  }

  const filteredUsers = users.filter((user: any) => {
    const profile = user.profile_id as any
    if (!profile) return false
    if (assignedDoctorId && String(profile.assigned_doctor_id) !== assignedDoctorId) return false
    if (filters.account_status && profile.account_status !== filters.account_status) return false
    if (filters.search) {
      const s = filters.search.toLowerCase()
      const nameMatch = profile.demographics?.name?.toLowerCase().includes(s)
      const loginMatch = user.login_id?.toLowerCase().includes(s)
      if (!nameMatch && !loginMatch) return false
    }
    return true
  })

  const total = filteredUsers.length
  const skip = (page - 1) * limit
  const paginatedUsers = filteredUsers.slice(skip, skip + limit)

  return {
    patients: paginatedUsers,
    pagination: {
      total,
      page,
      limit,
      pages: Math.ceil(total / limit),
      hasNext: page * limit < total,
      hasPrev: page > 1,
    },
  }
}

export async function updatePatient(
  userId: string,
  data: {
    demographics?: any
    medical_config?: any
    assigned_doctor_id?: string
    account_status?: string
    is_active?: boolean
    password?: string
  }
) {
  let user = await User.findById(userId).populate('profile_id')
  if (!user) {
    user = await User.findOne({ login_id: userId }).populate('profile_id')
  }
  if (!user) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Patient not found')
  }
  if (user.user_type !== UserType.PATIENT) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'User is not a patient')
  }

  const profileUpdate: any = {}
  if (data.demographics) profileUpdate.demographics = data.demographics
  if (data.medical_config) profileUpdate.medical_config = data.medical_config
  if (data.account_status) profileUpdate.account_status = data.account_status

  if (data.assigned_doctor_id) {
    const doctorUser = await findDoctorByIdentifier(data.assigned_doctor_id)
    if (!doctorUser || doctorUser.user_type !== UserType.DOCTOR || !doctorUser.is_active) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid or inactive doctor ID')
    }
    profileUpdate.assigned_doctor_id = doctorUser._id
  }

  if (Object.keys(profileUpdate).length > 0) {
    await PatientProfile.findByIdAndUpdate(user.profile_id, profileUpdate)
  }

  if (typeof data.is_active === 'boolean') {
    user.is_active = data.is_active
  }
  if (data.password) {
    user.password = data.password
  }
  await user.save()

  return await User.findById(user._id).populate('profile_id')
}

export async function deactivatePatient(userId: string) {
  let user = await User.findById(userId)
  if (!user) {
    user = await User.findOne({ login_id: userId })
  }
  if (!user) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Patient not found')
  }
  if (user.user_type !== UserType.PATIENT) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'User is not a patient')
  }

  user.is_active = false
  await user.save()

  // Also update account_status
  await PatientProfile.findByIdAndUpdate(user.profile_id, { account_status: 'Discharged' })

  return { message: 'Patient deactivated successfully' }
}

export async function reassignPatient(patientLoginId: string, newDoctorId: string) {
  const patientUser = await User.findOne({ login_id: patientLoginId }).populate('profile_id')
  if (!patientUser) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Patient not found')
  }
  if (patientUser.user_type !== UserType.PATIENT) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'User is not a patient')
  }

  const doctorUser = await findDoctorByIdentifier(newDoctorId)
  if (!doctorUser || doctorUser.user_type !== UserType.DOCTOR || !doctorUser.is_active) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid or inactive doctor')
  }

  const previousDoctorId = (patientUser.profile_id as any)?.assigned_doctor_id

  await PatientProfile.findByIdAndUpdate(patientUser.profile_id, {
    assigned_doctor_id: doctorUser._id,
  })

  return {
    message: 'Patient reassigned successfully',
    previous_doctor_id: previousDoctorId,
    new_doctor_id: String(doctorUser._id),
  }
}

// ─── Audit Logs ───

export async function getAuditLogs(
  filters: {
    user_id?: string
    action?: string
    start_date?: string
    end_date?: string
    success?: boolean
  } = {},
  pagination: { page?: number; limit?: number } = {}
) {
  const page = pagination.page || 1
  const limit = pagination.limit || 50

  const query: any = {}

  if (filters.user_id) query.user_id = filters.user_id
  if (filters.action) query.action = filters.action
  if (typeof filters.success === 'boolean') query.success = filters.success

  if (filters.start_date || filters.end_date) {
    query.createdAt = {}
    if (filters.start_date) query.createdAt.$gte = new Date(filters.start_date)
    if (filters.end_date) query.createdAt.$lte = new Date(filters.end_date)
  }

  const logs = await AuditLog.find(query)
    .populate('user_id', 'login_id user_type')
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit)

  const total = await AuditLog.countDocuments(query)

  return {
    logs,
    pagination: {
      total,
      page,
      limit,
      pages: Math.ceil(total / limit),
      hasNext: page * limit < total,
      hasPrev: page > 1,
    },
  }
}

// ─── Batch Operations ───

export async function performBatchOperation(
  operation: 'activate' | 'deactivate' | 'reset_password',
  userIds: string[]
) {
  const results: { userId: string; success: boolean; message: string }[] = []

  for (const userId of userIds) {
    try {
      const user = await User.findById(userId)
      if (!user) {
        results.push({ userId, success: false, message: 'User not found' })
        continue
      }

      switch (operation) {
        case 'activate':
          user.is_active = true
          await user.save()
          results.push({ userId, success: true, message: 'User activated' })
          break

        case 'deactivate':
          user.is_active = false
          await user.save()
          results.push({ userId, success: true, message: 'User deactivated' })
          break

        case 'reset_password':
          user.password = 'VitaLink@User123'
          await user.save()
          results.push({ userId, success: true, message: 'Password reset to default' })
          break

        default:
          results.push({ userId, success: false, message: 'Invalid operation' })
      }
    } catch (error: any) {
      results.push({ userId, success: false, message: error.message })
    }
  }

  return {
    operation,
    total: userIds.length,
    successful: results.filter(r => r.success).length,
    failed: results.filter(r => !r.success).length,
    results,
  }
}

// ─── System Health ───

export async function getSystemHealth() {
  const mongoose = await import('mongoose')

  const dbStates: Record<number, string> = {
    0: 'disconnected',
    1: 'connected',
    2: 'connecting',
    3: 'disconnecting',
  }

  return {
    status: 'ok',
    uptime: process.uptime(),
    database: {
      state: dbStates[mongoose.connection.readyState] || 'unknown',
      host: mongoose.connection.host,
      name: mongoose.connection.name,
    },
    memory: {
      rss: Math.round(process.memoryUsage().rss / 1024 / 1024) + ' MB',
      heapTotal: Math.round(process.memoryUsage().heapTotal / 1024 / 1024) + ' MB',
      heapUsed: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) + ' MB',
    },
    timestamp: new Date().toISOString(),
  }
}
