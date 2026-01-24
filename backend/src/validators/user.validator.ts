import {z} from 'zod'
import { UserType } from './index'

const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/

export const registerSchema = z.object({
  body: z.object({
    login_id: z
      .string()
      .min(3, 'Login ID must be at least 3 characters')
      .max(50, 'Login ID must not exceed 50 characters')
      .regex(/^[a-zA-Z0-9_@.-]+$/, 'Login ID can only contain letters, numbers, underscores, dots, hyphens, and @'),
    password: z
      .string()
      .min(8, 'Password must be at least 8 characters')
      .regex(passwordRegex, 'Password must contain uppercase, lowercase, number, and special character (@$!%*?&)'),
    confirm_password: z
      .string()
      .min(8, 'Confirm password is required'),
    user_type: z
      .enum([UserType.ADMIN, UserType.DOCTOR, UserType.PATIENT])
      .refine(type => type !== UserType.ADMIN, {
        message: 'Admin users cannot self-register. Please contact system administrator.',
        path: ['user_type'],
      }),
  })
  .refine(data => data.password === data.confirm_password, {
    message: 'Passwords do not match',
    path: ['confirm_password'],
  })
  .and(
    z.object({
      body: z.object({
        doctor_details: z.object({
          department: z.string().optional(),
        }).optional(),
        patient_details: z.object({
          name: z.string().min(1, 'Patient name is required').optional(),
          age: z.number().int().positive().optional(),
          gender: z.enum(['Male', 'Female', 'Other']).optional(),
          phone: z.string().optional(),
        }).optional(),
      })
    })
  ),
  query: z.object({}).optional(),
  params: z.object({}).optional(),
}).optional()

export const loginSchema = z.object({
  body: z.object({
    login_id: z
      .string()
      .min(1, 'Login ID is required'),
    password: z
      .string()
      .min(1, 'Password is required'),
  }),
  query: z.object({}).optional(),
  params: z.object({}).optional(),
}).optional()

export const getUserSchema = z.object({
  params: z.object({
    id: z.string().min(1, 'User ID is required'),
  }),
  query: z.object({}).optional(),
  body: z.object({}).optional(),
}).optional()

export const updateUserSchema = z.object({
  params: z.object({
    id: z.string().min(1, 'User ID is required'),
  }),
  body: z.object({
    login_id: z
      .string()
      .min(3, 'Login ID must be at least 3 characters')
      .max(50, 'Login ID must not exceed 50 characters')
      .regex(/^[a-zA-Z0-9_@.-]+$/, 'Login ID can only contain letters, numbers, underscores, dots, hyphens, and @')
      .optional(),
    user_type: z
      .enum([UserType.DOCTOR, UserType.PATIENT])
      .optional(),
    doctor_details: z.object({
      department: z.string().optional(),
    }).optional(),
    patient_details: z.object({
      name: z.string().min(1, 'Patient name is required').optional(),
      age: z.number().int().positive().optional(),
      gender: z.enum(['Male', 'Female', 'Other']).optional(),
      phone: z.string().optional(),
    }).optional(),
  }),
  query: z.object({}).optional(),
}).optional()

export const deleteUserSchema = z.object({
  params: z.object({
    id: z.string().min(1, 'User ID is required'),
  }),
  query: z.object({}).optional(),
  body: z.object({}).optional(),
}).optional()

export const listUsersSchema = z.object({
  query: z.object({
    page: z.string().optional(),
    limit: z.string().optional(),
    user_type: z.enum([UserType.ADMIN, UserType.DOCTOR, UserType.PATIENT]).optional(),
  }).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
}).optional()

export const getDoctorSchema = z.object({
  params: z.object({
    id: z.string().min(1, 'Doctor ID is required'),
  }),
  query: z.object({}).optional(),
  body: z.object({}).optional(),
}).optional()

export const listDoctorsSchema = z.object({
  query: z.object({
    page: z.string().optional(),
    limit: z.string().optional(),
    department: z.string().optional(),
  }).optional(),
  params: z.object({}).optional(),
  body: z.object({}).optional(),
}).optional()

export const updateDoctorSchema = z.object({
  params: z.object({
    id: z.string().min(1, 'Doctor ID is required'),
  }),
  body: z.object({
    login_id: z
      .string()
      .min(3, 'Login ID must be at least 3 characters')
      .max(50, 'Login ID must not exceed 50 characters')
      .regex(/^[a-zA-Z0-9_@.-]+$/, 'Login ID can only contain letters, numbers, underscores, dots, hyphens, and @')
      .optional(),
    doctor_details: z.object({
      department: z.string().optional(),
    }).optional(),
  }),
  query: z.object({}).optional(),
}).optional()

export const createAppointmentSchema = z.object({
  params: z.object({
    id: z.string().min(1, 'Doctor ID is required'),
  }),
  body: z.object({
    patient_id: z.string().min(1, 'Patient ID is required'),
    appointment_date: z.string().datetime('Invalid appointment date'),
    reason: z.string().min(1, 'Appointment reason is required'),
    notes: z.string().optional(),
  }),
  query: z.object({}).optional(),
}).optional()

export const listDoctorAppointmentsSchema = z.object({
  params: z.object({
    id: z.string().min(1, 'Doctor ID is required'),
  }),
  query: z.object({
    page: z.string().optional(),
    limit: z.string().optional(),
    status: z.enum(['scheduled', 'completed', 'cancelled']).optional(),
  }).optional(),
  body: z.object({}).optional(),
}).optional()

export const createPatientSchema = z.object({
  body: z.object({
    login_id: z
      .string()
      .min(3, 'Login ID must be at least 3 characters')
      .max(50, 'Login ID must not exceed 50 characters')
      .regex(/^[a-zA-Z0-9_@.-]+$/, 'Login ID can only contain letters, numbers, underscores, dots, hyphens, and @'),
    password: z
      .string()
      .min(8, 'Password must be at least 8 characters')
      .regex(passwordRegex, 'Password must contain uppercase, lowercase, number, and special character (@$!%*?&)'),
    patient_details: z.object({
      name: z.string().min(1, 'Patient name is required'),
      age: z.number().int().positive('Age must be a positive number'),
      gender: z.enum(['Male', 'Female', 'Other']),
      phone: z.string().min(1, 'Phone number is required'),
    }),
  }),
  query: z.object({}).optional(),
  params: z.object({}).optional(),
}).optional()

export const getPatientSchema = z.object({
  params: z.object({
    id: z.string().min(1, 'Patient ID is required'),
  }),
  query: z.object({}).optional(),
  body: z.object({}).optional(),
}).optional()

export const updatePatientSchema = z.object({
  params: z.object({
    id: z.string().min(1, 'Patient ID is required'),
  }),
  body: z.object({
    login_id: z
      .string()
      .min(3, 'Login ID must be at least 3 characters')
      .max(50, 'Login ID must not exceed 50 characters')
      .regex(/^[a-zA-Z0-9_@.-]+$/, 'Login ID can only contain letters, numbers, underscores, dots, hyphens, and @')
      .optional(),
    patient_details: z.object({
      name: z.string().min(1, 'Patient name is required').optional(),
      age: z.number().int().positive('Age must be a positive number').optional(),
      gender: z.enum(['Male', 'Female', 'Other']).optional(),
      phone: z.string().optional(),
    }).optional(),
  }),
  query: z.object({}).optional(),
}).optional()

export const getPatientAppointmentsSchema = z.object({
  params: z.object({
    id: z.string().min(1, 'Patient ID is required'),
  }),
  query: z.object({
    page: z.string().optional(),
    limit: z.string().optional(),
    status: z.enum(['scheduled', 'completed', 'cancelled']).optional(),
  }).optional(),
  body: z.object({}).optional(),
}).optional()


