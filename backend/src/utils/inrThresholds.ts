/** Default critical INR band used when system config is missing or invalid. */
export const DEFAULT_INR_CRITICAL_LOW = 1.5
export const DEFAULT_INR_CRITICAL_HIGH = 4.5

/** Default therapeutic INR band when patient target is missing or invalid. */
export const DEFAULT_INR_TARGET_MIN = 2.0
export const DEFAULT_INR_TARGET_MAX = 3.0

/**
 * Normalize system-level critical INR thresholds.
 * Invalid or inverted values fall back to the safe defaults.
 */
export function getSafeInrThresholds(
  thresholds: { critical_low?: number; critical_high?: number } | undefined | null,
): { criticalLow: number; criticalHigh: number } {
  const defaultThresholds = {
    criticalLow: DEFAULT_INR_CRITICAL_LOW,
    criticalHigh: DEFAULT_INR_CRITICAL_HIGH,
  }
  const rawLow = thresholds?.critical_low
  const rawHigh = thresholds?.critical_high
  const criticalLow = typeof rawLow === 'number' && Number.isFinite(rawLow)
    ? rawLow
    : defaultThresholds.criticalLow
  const criticalHigh = typeof rawHigh === 'number' && Number.isFinite(rawHigh)
    ? rawHigh
    : defaultThresholds.criticalHigh

  if (criticalLow >= criticalHigh) {
    return defaultThresholds
  }

  return { criticalLow, criticalHigh }
}

/**
 * Resolve patient therapeutic INR bounds from medical_config.target_inr.
 * Invalid or inverted values fall back to the clinical default (2.0–3.0).
 */
export function getSafeInrTargetRange(
  targetInr: { min?: number; max?: number } | undefined | null,
): { targetInrMin: number; targetInrMax: number } {
  const defaults = {
    targetInrMin: DEFAULT_INR_TARGET_MIN,
    targetInrMax: DEFAULT_INR_TARGET_MAX,
  }
  const min = targetInr?.min
  const max = targetInr?.max
  if (
    typeof min === 'number' &&
    typeof max === 'number' &&
    Number.isFinite(min) &&
    Number.isFinite(max) &&
    min < max
  ) {
    return { targetInrMin: min, targetInrMax: max }
  }
  return defaults
}
