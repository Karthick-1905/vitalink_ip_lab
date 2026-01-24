import { User, AdminProfile, DoctorProfile, PatientProfile } from '@src/models'
import { UserType, JWTPayload } from '@src/validators'
import { generateToken, hashPassword, comparePasswords, generateSalt } from '@src/utils'

interface RegisterUserData {
  login_id: string
  password: string
  user_type: Exclude<UserType, 'ADMIN'>
  doctor_details?: {
    department?: string
  }
  patient_details?: {
    name?: string
    age?: number
    gender?: 'Male' | 'Female' | 'Other'
    phone?: string
  }
}

interface LoginResponse {
  token: string
  user: {
    user_id: string
    login_id: string
    user_type: UserType
  }
}

/**
 * Register a new user (Doctor or Patient)
 * @param registerData - User registration data
 * @returns Created user data with user_id
 * @throws Error if user already exists or invalid user type
 */
export async function registerUser(registerData: RegisterUserData) {
  const { login_id, password, user_type, doctor_details, patient_details } = registerData

  // Check if user already exists
  const existingUser = await User.findOne({ login_id })
  if (existingUser) {
    throw new Error('User with this login ID already exists')
  }

  // Generate salt and hash password
  const salt = generateSalt()
  const hashedPassword = await hashPassword(password, salt)

  // Determine which profile model to use
  let profileModel: any
  let profileData: any

  if (user_type === UserType.DOCTOR) {
    profileModel = DoctorProfile
    profileData = {
      name: doctor_details?.department || 'Unknown',
      department: doctor_details?.department || 'Cardiology',
    }
  } else if (user_type === UserType.PATIENT) {
    profileModel = PatientProfile
    profileData = {
      demographics: {
        name: patient_details?.name || 'Unknown',
        age: patient_details?.age,
        gender: patient_details?.gender || 'Other',
        phone: patient_details?.phone,
      },
    }
  } else {
    throw new Error('Invalid user type for registration')
  }

  // Create profile first
  const profile = await profileModel.create(profileData)

  // Determine model name for user_type_model field
  const modelNameMap = {
    [UserType.DOCTOR]: 'DoctorProfile',
    [UserType.PATIENT]: 'PatientProfile',
  }

  // Create user
  const user = await User.create({
    login_id,
    password: hashedPassword,
    salt,
    user_type,
    profile_id: profile._id,
    user_type_model: modelNameMap[user_type],
    is_active: true,
  })

  return {
    user_id: user._id.toString(),
    login_id: user.login_id,
    user_type: user.user_type,
  }
}

/**
 * Authenticate user and generate JWT token
 * @param login_id - User's login ID
 * @param password - User's password (plaintext)
 * @returns Token and user info
 * @throws Error if credentials invalid or account inactive
 */
export async function loginUser(login_id: string, password: string): Promise<LoginResponse> {
  // Find user
  const user = await User.findOne({ login_id }).lean()

  if (!user) {
    throw new Error('Invalid credentials')
  }

  // Check if account is active
  if (!user.is_active) {
    throw new Error('Account is inactive. Please contact administrator.')
  }

  // Verify password
  const isPasswordValid = await comparePasswords({
    password,
    salt: user.salt,
    hashedPassword: user.password,
  })

  if (!isPasswordValid) {
    throw new Error('Invalid credentials')
  }

  // Generate JWT token
  const payload: JWTPayload = {
    user_id: user._id.toString(),
    user_type: user.user_type as UserType,
  }

  const token = generateToken(payload)

  return {
    token,
    user: {
      user_id: user._id.toString(),
      login_id: user.login_id,
      user_type: user.user_type as UserType,
    },
  }
}

/**
 * Get user profile with role-specific details
 * @param user_id - MongoDB user ID
 * @param user_type - User role type
 * @returns User data with profile
 * @throws Error if user not found
 */
export async function getUserProfile(user_id: string, user_type: UserType) {
  const user = await User.findById(user_id).lean()

  if (!user) {
    throw new Error('User not found')
  }

  // Fetch appropriate profile based on user_type
  let profile: any

  if (user_type === UserType.ADMIN) {
    profile = await AdminProfile.findById(user.profile_id).lean()
  } else if (user_type === UserType.DOCTOR) {
    profile = await DoctorProfile.findById(user.profile_id).lean()
  } else if (user_type === UserType.PATIENT) {
    profile = await PatientProfile.findById(user.profile_id).lean()
  }

  return {
    user_id: user._id.toString(),
    login_id: user.login_id,
    user_type: user.user_type,
    is_active: user.is_active,
    created_at: user.createdAt,
    profile,
  }
}
