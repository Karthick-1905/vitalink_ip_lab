import mongoose from 'mongoose'

// A single atomic document keeps draft, publication and rollback history consistent.
const AppPropertiesSchema = new mongoose.Schema({
  _id: { type: String, default: 'global' },
  version: { type: Number, default: 0 },
  published_revision: { type: Number, default: 0 },
  draft: { type: mongoose.Schema.Types.Mixed, default: {} },
  published: { type: mongoose.Schema.Types.Mixed, default: {} },
  history: { type: [mongoose.Schema.Types.Mixed], default: [] },
  updated_by: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true, minimize: false })

export default mongoose.model('AppProperties', AppPropertiesSchema)
