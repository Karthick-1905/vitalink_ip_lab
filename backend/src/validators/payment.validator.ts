import { z } from 'zod'

export const createPaymentOrderSchema = z.object({
  body: z.object({
    plan_id: z.string().min(1, 'plan_id is required'),
  }).strict(),
})

export type CreatePaymentOrderInput = z.infer<typeof createPaymentOrderSchema>
