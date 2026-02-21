import { z } from 'zod'

// ─── Param Schemas ───

export const userIdParamSchema = z.object({
  params: z.object({
    id: z.string().min(1, 'User ID is required'),
  }),
})

// ─── Doctor Schemas ───

export const createDoctorSchema = z.object({
  body: z.object({
    login_id: z.string().min(3, 'Login ID must be at least 3 characters'),
    password: z
      .string()
      .min(8, 'Password must be at least 8 characters')
      .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
      .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
      .regex(/[0-9]/, 'Password must contain at least one digit')
      .regex(/[^A-Za-z0-9]/, 'Password must contain at least one special character'),
    name: z.string().min(1, 'Name is required'),
    department: z.string().optional(),
    contact_number: z.string().optional(),
    profile_picture_url: z.string().url().optional(),
  }),
})

export const updateDoctorSchema = z.object({
  params: z.object({
    id: z.string().min(1, 'Doctor ID is required'),
  }),
  body: z.object({
    name: z.string().min(1).optional(),
    department: z.string().optional(),
    contact_number: z.string().optional(),
    profile_picture_url: z.string().url().optional().nullable(),
    is_active: z.boolean().optional(),
    password: z.string().min(8).optional(),
  }),
})

export const getDoctorsSchema = z.object({
  query: z.object({
    page: z.coerce.number().int().positive().optional(),
    limit: z.coerce.number().int().positive().max(100).optional(),
    department: z.string().optional(),
    is_active: z.enum(['true', 'false']).optional(),
    search: z.string().optional(),
  }),
})

// ─── Patient Schemas ───

export const createPatientSchema = z.object({
  body: z.object({
    login_id: z.string().min(3, 'Login ID must be at least 3 characters'),
    password: z
      .string()
      .min(8, 'Password must be at least 8 characters')
      .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
      .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
      .regex(/[0-9]/, 'Password must contain at least one digit')
      .regex(/[^A-Za-z0-9]/, 'Password must contain at least one special character'),
    assigned_doctor_id: z.string().min(1, 'Assigned doctor ID is required'),
    demographics: z.object({
      name: z.string().min(1, 'Patient name is required'),
      age: z.number().int().positive().optional(),
      gender: z.enum(['Male', 'Female', 'Other']).optional(),
      phone: z.string().optional(),
      next_of_kin: z
        .object({
          name: z.string().optional(),
          relation: z.string().optional(),
          relationship: z.string().optional(),
          phone: z.string().optional(),
        })
        .optional(),
    }),
    medical_config: z
      .object({
        diagnosis: z.string().optional(),
        therapy_drug: z.string().optional(),
        therapy_start_date: z.string().optional(),
        target_inr: z
          .object({
            min: z.number().positive(),
            max: z.number().positive(),
          })
          .optional(),
      })
      .optional(),
  }),
})

export const updatePatientSchema = z.object({
  params: z.object({
    id: z.string().min(1, 'Patient ID is required'),
  }),
  body: z.object({
    demographics: z
      .object({
        name: z.string().optional(),
        age: z.number().int().positive().optional(),
        gender: z.string().optional(),
        phone: z.string().optional(),
        next_of_kin: z
          .object({
            name: z.string().optional(),
            relation: z.string().optional(),
            relationship: z.string().optional(),
            phone: z.string().optional(),
          })
          .optional(),
      })
      .optional(),
    medical_config: z
      .object({
        diagnosis: z.string().optional(),
        therapy_drug: z.string().optional(),
        therapy_start_date: z.string().optional(),
        target_inr: z
          .object({
            min: z.number().positive(),
            max: z.number().positive(),
          })
          .optional(),
      })
      .optional(),
    assigned_doctor_id: z.string().optional(),
    account_status: z.enum(['Active', 'Discharged', 'Deceased']).optional(),
    is_active: z.boolean().optional(),
    password: z.string().min(8).optional(),
  }),
})

export const getUsersSchema = z.object({
  query: z.object({
    page: z.coerce.number().int().positive().optional(),
    limit: z.coerce.number().int().positive().max(100).optional(),
    assigned_doctor_id: z.string().optional(),
    account_status: z.string().optional(),
    search: z.string().optional(),
  }),
})

// ─── Reassign Schema ───

export const reassignPatientSchema = z.object({
  params: z.object({
    op_num: z.string().min(1, 'Patient OP number is required'),
  }),
  body: z.object({
    new_doctor_id: z.string().min(1, 'New doctor ID is required'),
  }),
})
