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

  await config.save()
  return config
}
