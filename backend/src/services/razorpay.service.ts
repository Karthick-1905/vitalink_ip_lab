import Razorpay from 'razorpay'
import crypto from 'crypto'
import { config } from '@alias/config'

const client = new Razorpay({
  key_id: config.razorpayKeyId,
  key_secret: config.razorpayKeySecret,
})

export async function createRazorpayOrder(params: {
  amountPaise: number
  currency?: string
  receipt: string
  notes?: Record<string, string>
}) {
  return client.orders.create({
    amount: params.amountPaise,
    currency: params.currency ?? 'INR',
    receipt: params.receipt,
    notes: params.notes,
  })
}

export function verifyRazorpayWebhookSignature(rawBody: string, signature: string) {
  const expected = crypto
    .createHmac('sha256', config.razorpayWebhookSecret)
    .update(rawBody, 'utf8')
    .digest('hex')
  return expected === signature
}
