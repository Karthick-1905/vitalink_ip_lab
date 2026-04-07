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
  max_tokens: {
    type: Number,
    default: 200,
  },
  currency: {
    type: String,
    default: 'INR',
  },
}, { timestamps: true })

export interface TokenWalletDocument extends mongoose.InferSchemaType<typeof TokenWalletSchema> {}

export default mongoose.model<TokenWalletDocument>('TokenWallet', TokenWalletSchema)
