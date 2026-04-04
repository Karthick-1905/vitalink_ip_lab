import { SystemConfig } from '@alias/models'

export async function getSystemConfig() {
  let config = await SystemConfig.findOne({ is_active: true })

  if (!config) {
    config = await SystemConfig.create({
      inr_thresholds: { critical_low: 1.5, critical_high: 4.5 },
      session_timeout_minutes: 30,
      rate_limit: { max_requests: 100, window_minutes: 15 },
      feature_flags: {
        registration_enabled: true,
        maintenance_mode: false,
        beta_features: false,
      },
      token_plans: [
        { plan_id: 'basic_49', price_inr: 49, tokens: 100, is_active: true },
        { plan_id: 'standard_99', price_inr: 99, tokens: 220, is_active: true },
      ],
      feature_weights: {
        PATIENT_DOSAGE: 2,
        PATIENT_HEALTH_LOG: 1,
        PATIENT_PROFILE_UPDATE: 1,
        PATIENT_REPORT_SUBMIT: 2,
      },
      token_settings: { allow_fractional: true, precision: 2 },
      is_active: true,
    })
  }

  return config
}

export async function updateSystemConfig(updates: {
  inr_thresholds?: { critical_low?: number; critical_high?: number }
  session_timeout_minutes?: number
  rate_limit?: { max_requests?: number; window_minutes?: number }
  feature_flags?: Record<string, boolean>
  token_plans?: Array<{ plan_id: string; price_inr: number; tokens: number; is_active?: boolean }>
  feature_weights?: Record<string, number>
  token_settings?: { allow_fractional?: boolean; precision?: number }
}) {
  let config = await SystemConfig.findOne({ is_active: true })

  if (!config) {
    config = await SystemConfig.create({
      ...updates,
      is_active: true,
    })
    return config
  }

  // Deep merge updates
  if (updates.inr_thresholds) {
    if (updates.inr_thresholds.critical_low !== undefined) {
      config.inr_thresholds.critical_low = updates.inr_thresholds.critical_low
    }
    if (updates.inr_thresholds.critical_high !== undefined) {
      config.inr_thresholds.critical_high = updates.inr_thresholds.critical_high
    }
  }

  if (updates.session_timeout_minutes !== undefined) {
    config.session_timeout_minutes = updates.session_timeout_minutes
  }

  if (updates.rate_limit) {
    if (updates.rate_limit.max_requests !== undefined) {
      config.rate_limit.max_requests = updates.rate_limit.max_requests
    }
    if (updates.rate_limit.window_minutes !== undefined) {
      config.rate_limit.window_minutes = updates.rate_limit.window_minutes
    }
  }

  if (updates.feature_flags) {
    for (const [key, value] of Object.entries(updates.feature_flags)) {
      config.feature_flags.set(key, value)
    }
  }

  if (updates.token_plans) {
    config.token_plans = updates.token_plans as any
  }

  if (updates.feature_weights) {
    for (const [key, value] of Object.entries(updates.feature_weights)) {
      config.feature_weights.set(key, value)
    }
  }

  if (updates.token_settings) {
    if (typeof updates.token_settings.allow_fractional === 'boolean') {
      config.token_settings.allow_fractional = updates.token_settings.allow_fractional
    }
    if (typeof updates.token_settings.precision === 'number') {
      config.token_settings.precision = updates.token_settings.precision
    }
  }

  await config.save()
  return config
}
