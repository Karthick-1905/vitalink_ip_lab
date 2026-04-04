import mongoose from 'mongoose'

export enum TokenTransactionSource {
  USAGE = 'USAGE',
  PAYMENT = 'PAYMENT',
  ADJUSTMENT = 'ADJUSTMENT',
}

const TokenTransactionSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  delta: {
    type: Number,
    required: true,
  },
  balance_after: {
    type: Number,
    required: true,
  },
  feature_key: {
    type: String,
  },
  weight: {
    type: Number,
  },
  source: {
    type: String,
    enum: Object.values(TokenTransactionSource),
    required: true,
  },
  request_id: {
    type: String,
  },
  payment_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Payment',
  },
  metadata: {
    type: mongoose.Schema.Types.Mixed,
  },
}, { timestamps: true })

TokenTransactionSchema.index({ user_id: 1, createdAt: -1 })
TokenTransactionSchema.index({ source: 1, createdAt: -1 })

export interface TokenTransactionDocument extends mongoose.InferSchemaType<typeof TokenTransactionSchema> {}

export default mongoose.model<TokenTransactionDocument>('TokenTransaction', TokenTransactionSchema)
