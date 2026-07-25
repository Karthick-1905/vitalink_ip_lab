/** Default critical INR band used when system config is missing or invalid. */
export const DEFAULT_INR_CRITICAL_LOW = 1.5
export const DEFAULT_INR_CRITICAL_HIGH = 4.5

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
