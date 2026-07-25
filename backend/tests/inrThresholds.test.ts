import { describe, expect, it } from '@jest/globals'
import {
  DEFAULT_INR_CRITICAL_HIGH,
  DEFAULT_INR_CRITICAL_LOW,
  getSafeInrThresholds,
} from '@alias/utils/inrThresholds'

describe('getSafeInrThresholds', () => {
  it('returns defaults for missing or null thresholds', () => {
    expect(getSafeInrThresholds(undefined)).toEqual({
      criticalLow: DEFAULT_INR_CRITICAL_LOW,
      criticalHigh: DEFAULT_INR_CRITICAL_HIGH,
    })
    expect(getSafeInrThresholds(null)).toEqual({
      criticalLow: DEFAULT_INR_CRITICAL_LOW,
      criticalHigh: DEFAULT_INR_CRITICAL_HIGH,
    })
  })

  it('accepts finite configured thresholds', () => {
    expect(getSafeInrThresholds({ critical_low: 1.2, critical_high: 5 })).toEqual({
      criticalLow: 1.2,
      criticalHigh: 5,
    })
  })

  it('falls back when thresholds are inverted or non-finite', () => {
    expect(getSafeInrThresholds({ critical_low: 4, critical_high: 2 })).toEqual({
      criticalLow: DEFAULT_INR_CRITICAL_LOW,
      criticalHigh: DEFAULT_INR_CRITICAL_HIGH,
    })
    // Non-finite low uses the default low while preserving a valid high.
    expect(getSafeInrThresholds({ critical_low: Number.NaN, critical_high: 4 })).toEqual({
      criticalLow: DEFAULT_INR_CRITICAL_LOW,
      criticalHigh: 4,
    })
    expect(getSafeInrThresholds({ critical_low: 1, critical_high: Number.NaN })).toEqual({
      criticalLow: 1,
      criticalHigh: DEFAULT_INR_CRITICAL_HIGH,
    })
  })
})
