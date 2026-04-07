import { StatusCodes } from 'http-status-codes'
import { ApiError } from '@alias/utils'
import { Payment, User } from '@alias/models'
import { PaymentStatus } from '@alias/models/payment.model'
import { createRazorpayOrder, verifyRazorpayWebhookSignature } from '@alias/services/razorpay.service'
import { creditFromPayment, resolvePlan } from '@alias/services/token.service'
import { creditTokensForPayment } from '@alias/services/patient-token.service'
import { config } from '@alias/config'
import * as notificationService from '@alias/services/notification.service'
import { UserType } from '@alias/validators'

export async function createPaymentOrder(params: { userId: string; planId: string; requestId?: string | null}) {
  if (!config.razorpayKeyId || !config.razorpayKeySecret) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Razorpay credentials are not configured')
  }

  const plan = await resolvePlan(params.planId)
  const amountInr = Number(plan.price_inr)
  const amountPaise = Math.round(amountInr * 100)
  const receipt = `plan_${plan.plan_id}_${params.userId}_${Date.now()}`

  let order
  try {
    order = await createRazorpayOrder({
      amountPaise,
      receipt,
      notes: {
        plan_id: plan.plan_id,
        user_id: params.userId,
      },
    })
  } catch (error: any) {
    throw new ApiError(StatusCodes.BAD_GATEWAY, 'Failed to create Razorpay order')
  }

  const payment = await Payment.create({
    user_id: params.userId,
    provider: 'razorpay',
    plan_id: plan.plan_id,
    amount_inr: amountInr,
    amount_paise: amountPaise,
    tokens_granted: Number(plan.tokens),
    status: PaymentStatus.CREATED,
    order_id: order.id,
    receipt,
    notes: order.notes || {},
  })

  return {
    payment,
    order: {
      id: order.id,
      amount: order.amount,
      currency: order.currency,
    },
    key_id: config.razorpayKeyId,
  }
}

export async function handleRazorpayWebhook(params: { rawBody: string; signature: string; payload: any }) {
  if (!verifyRazorpayWebhookSignature(params.rawBody, params.signature)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid Razorpay signature')
  }

  const event = params.payload?.event
  const paymentEntity = params.payload?.payload?.payment?.entity
  if (!paymentEntity || !paymentEntity.order_id) {
    return { status: 'ignored' }
  }

  const payment = await Payment.findOne({ order_id: paymentEntity.order_id })
  if (!payment) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found for order')
  }

  if (event === 'payment.captured' || paymentEntity.status === 'captured') {
    if (payment.status !== PaymentStatus.PAID) {
      payment.status = PaymentStatus.PAID
      payment.payment_id = paymentEntity.id
      payment.signature = params.signature
      await payment.save()

      await creditFromPayment({
        userId: String(payment.user_id),
        amount: payment.tokens_granted,
        paymentId: String(payment._id),
      })

      // Also credit using patient-token service
      await creditTokensForPayment(
        String(payment.user_id),
        payment.tokens_granted,
        String(payment._id)
      )

      const adminUsers = await User.find({ user_type: UserType.ADMIN, is_active: true }).select('_id')
      const adminIds = adminUsers.map(u => String(u._id))
      if (adminIds.length > 0) {
        await notificationService.broadcastNotification(
          'New payment received',
          `Payment ${payment._id} received for plan ${payment.plan_id}.`,
          'SPECIFIC',
          adminIds,
          'MEDIUM'
        )
      }
    }

    return { status: 'processed' }
  }

  if (event === 'payment.failed') {
    payment.status = PaymentStatus.FAILED
    payment.payment_id = paymentEntity.id
    payment.signature = params.signature
    await payment.save()
    return { status: 'failed' }
  }

  return { status: 'ignored' }
}

export async function getPayments(params: { page?: number; limit?: number; status?: string }) {
  const page = params.page || 1
  const limit = params.limit || 20

  const query: Record<string, any> = {}
  if (params.status) {
    query.status = params.status
  }

  const payments = await Payment.find(query)
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit)
    .populate('user_id', 'login_id user_type')

  const total = await Payment.countDocuments(query)

  return {
    payments,
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
