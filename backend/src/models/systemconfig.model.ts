import mongoose from 'mongoose'

const SystemConfigSchema = new mongoose.Schema({
  inr_thresholds: {
    critical_low: { type: Number, default: 1.5 },
    critical_high: { type: Number, default: 4.5 },
  },
  session_timeout_minutes: {
    type: Number,
    default: 30,
  },
  rate_limit: {
    max_requests: { type: Number, default: 100 },
    window_minutes: { type: Number, default: 15 },
  },
  feature_flags: {
    type: Map,
    of: Boolean,
    default: {
      registration_enabled: true,
      maintenance_mode: false,
      beta_features: false,
    },
  },
  token_plans: {
    type: [
      {
        plan_id: { type: String, required: true },
        price_inr: { type: Number, required: true },
        tokens: { type: Number, required: true },
        is_active: { type: Boolean, default: true },
      },
    ],
    default: [
      { plan_id: 'basic_49', price_inr: 49, tokens: 100, is_active: true },
      { plan_id: 'standard_99', price_inr: 99, tokens: 220, is_active: true },
    ],
  },
  feature_weights: {
    type: Map,
    of: Number,
    default: {
      PATIENT_DOSAGE: 2,
      PATIENT_HEALTH_LOG: 1,
      PATIENT_PROFILE_UPDATE: 1,
      PATIENT_REPORT_SUBMIT: 2,
    },
  },
  token_settings: {
    allow_fractional: { type: Boolean, default: true },
    precision: { type: Number, default: 2 },
  },
  is_active: {
    type: Boolean,
    default: true,
  },
}, { timestamps: true })

export interface SystemConfigDocument extends mongoose.InferSchemaType<typeof SystemConfigSchema> {}

export default mongoose.model<SystemConfigDocument>('SystemConfig', SystemConfigSchema)
