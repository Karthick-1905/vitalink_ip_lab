import { z } from 'zod'

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
})

export type LoginInput = z.infer<typeof loginSchema> 

const strongPasswordSchema = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
  .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
  .regex(/[0-9]/, 'Password must contain at least one digit')
  .regex(/[^A-Za-z0-9]/, 'Password must contain at least one special character')

export const changePasswordSchema = z.object({
  body: z
    .object({
      current_password: z.string().min(1, 'Current password is required'),
      new_password: strongPasswordSchema,
    })
    .refine((data) => data.current_password !== data.new_password, {
      message: 'New password must be different from current password',
      path: ['new_password'],
    }),
  query: z.object({}).optional(),
  params: z.object({}).optional(),
})

export type ChangePasswordInput = z.infer<typeof changePasswordSchema>


