import mongoose from 'mongoose'

export enum PaymentStatus {
  CREATED = 'CREATED',
  PAID = 'PAID',
  FAILED = 'FAILED',
  REFUNDED = 'REFUNDED',
}

const PaymentSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  provider: {
    type: String,
    default: 'razorpay',
  },
  plan_id: {
    type: String,
    required: true,
  },
  amount_inr: {
    type: Number,
    required: true,
  },
  amount_paise: {
    type: Number,
    required: true,
  },
  tokens_granted: {
    type: Number,
    required: true,
  },
  status: {
    type: String,
    enum: Object.values(PaymentStatus),
    default: PaymentStatus.CREATED,
  },
  order_id: {
    type: String,
    required: true,
    index: true,
  },
  payment_id: {
    type: String,
  },
  signature: {
    type: String,
  },
  receipt: {
    type: String,
  },
  notes: {
    type: mongoose.Schema.Types.Mixed,
  },
}, { timestamps: true })

PaymentSchema.index({ user_id: 1, createdAt: -1 })
PaymentSchema.index({ status: 1, createdAt: -1 })

export interface PaymentDocument extends mongoose.InferSchemaType<typeof PaymentSchema> {}

export default mongoose.model<PaymentDocument>('Payment', PaymentSchema)
