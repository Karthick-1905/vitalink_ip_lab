import mongoose from 'mongoose'

export enum AuditAction {
  LOGIN = 'LOGIN',
  LOGIN_CHALLENGE = 'LOGIN_CHALLENGE',
  LOGOUT = 'LOGOUT',
  LOGIN_FAILED = 'LOGIN_FAILED',
  USER_CREATE = 'USER_CREATE',
  USER_UPDATE = 'USER_UPDATE',
  USER_DEACTIVATE = 'USER_DEACTIVATE',
  USER_ACTIVATE = 'USER_ACTIVATE',
  USER_DELETE = 'USER_DELETE',
  PASSWORD_RESET = 'PASSWORD_RESET',
  PASSWORD_CHANGE = 'PASSWORD_CHANGE',
  MFA_SETUP = 'MFA_SETUP',
  MFA_ACTIVATE = 'MFA_ACTIVATE',
  MFA_RESET = 'MFA_RESET',
  PATIENT_REASSIGN = 'PATIENT_REASSIGN',
  PATIENT_DISCHARGE = 'PATIENT_DISCHARGE',
  INR_SUBMIT = 'INR_SUBMIT',
  INR_UPDATE = 'INR_UPDATE',
  DOSAGE_UPDATE = 'DOSAGE_UPDATE',
  HEALTH_LOG_CREATE = 'HEALTH_LOG_CREATE',
  CONFIG_UPDATE = 'CONFIG_UPDATE',
  ROLE_POLICY_UPDATE = 'ROLE_POLICY_UPDATE',
  ADMIN_ACCOUNT_CREATE = 'ADMIN_ACCOUNT_CREATE',
  ADMIN_ROLE_ASSIGN = 'ADMIN_ROLE_ASSIGN',
  ADMIN_SCOPE_CHANGE = 'ADMIN_SCOPE_CHANGE',
  ADMIN_ACCOUNT_SUSPEND = 'ADMIN_ACCOUNT_SUSPEND',
  ADMIN_ACCOUNT_RESTORE = 'ADMIN_ACCOUNT_RESTORE',
  NOTIFICATION_BROADCAST = 'NOTIFICATION_BROADCAST',
  BATCH_OPERATION = 'BATCH_OPERATION',
  PROFILE_UPDATE = 'PROFILE_UPDATE',
  REPORT_UPDATE = 'REPORT_UPDATE',
}

const AuditLogSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    immutable: true,
  },
  // Missing scope denotes a legacy/unresolved event, visible only to platform readers.
  event_hospital_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Hospital', immutable: true },
  actor_hospital_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Hospital', immutable: true },
  actor_role: { type: String, immutable: true },
  resource_hospital_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Hospital', immutable: true },
  scope_version: { type: Number, immutable: true },
  user_type: {
    type: String,
    required: true,
    immutable: true,
  },
  action: {
    type: String,
    enum: Object.values(AuditAction),
    required: true,
  },
  description: {
    type: String,
    required: true,
  },
  resource_type: {
    type: String,
  },
  resource_id: {
    type: String,
  },
  previous_data: {
    type: mongoose.Schema.Types.Mixed,
  },
  new_data: {
    type: mongoose.Schema.Types.Mixed,
  },
  ip_address: {
    type: String,
  },
  user_agent: {
    type: String,
  },
  success: {
    type: Boolean,
    default: true,
  },
  error_message: {
    type: String,
  },
  metadata: {
    type: mongoose.Schema.Types.Mixed,
  },
}, { timestamps: true })

AuditLogSchema.index({ event_hospital_id: 1, createdAt: -1, _id: -1 })

// Compound indexes for efficient querying
AuditLogSchema.index({ user_id: 1, createdAt: -1 })
AuditLogSchema.index({ action: 1, createdAt: -1 })
AuditLogSchema.index({ resource_type: 1, resource_id: 1 })
AuditLogSchema.index({ success: 1, createdAt: -1 })
AuditLogSchema.index({
  'metadata.login_attempt.normalized_login_id': 1,
  'metadata.login_attempt.ip_address': 1,
  createdAt: -1,
})

export interface AuditLogDocument extends mongoose.InferSchemaType<typeof AuditLogSchema> {}

export default mongoose.model<AuditLogDocument>('AuditLog', AuditLogSchema)
