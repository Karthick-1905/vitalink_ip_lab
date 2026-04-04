import mongoose from 'mongoose'

const TokenWalletSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
    index: true,
  },
  balance: {
    type: Number,
    default: 0,
  },
  currency: {
    type: String,
    default: 'INR',
  },
}, { timestamps: true })

TokenWalletSchema.index({ user_id: 1 })

export interface TokenWalletDocument extends mongoose.InferSchemaType<typeof TokenWalletSchema> {}

export default mongoose.model<TokenWalletDocument>('TokenWallet', TokenWalletSchema)
