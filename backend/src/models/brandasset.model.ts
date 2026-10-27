import mongoose from 'mongoose'

const BrandAssetSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  content_type: { type: String, enum: ['image/png', 'image/jpeg'], required: true },
  bytes: { type: Buffer, required: true, select: false },
  created_by: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
}, { timestamps: true })

export default mongoose.model('BrandAsset', BrandAssetSchema)
