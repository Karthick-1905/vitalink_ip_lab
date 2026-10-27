import mongoose from 'mongoose'
import AppProperties from '@alias/models/appproperties.model'
import { PROPERTY_DEFAULTS } from '@alias/services/app-properties.service'

/** Snapshot per operation. Configuration failure must not stop clinical work. */
export async function getServerCopy() {
  let properties: Record<string, string> = PROPERTY_DEFAULTS
  if (mongoose.connection.readyState === 1) {
    try {
      const current = await AppProperties.findById('global').maxTimeMS(1000).lean()
      properties = { ...PROPERTY_DEFAULTS, ...(current?.published ?? {}) }
    } catch { /* Keep bundled wording. */ }
  }
  return (key: string, arguments_: Record<string, unknown> = {}) => {
    const value = properties[key] ?? PROPERTY_DEFAULTS[key] ?? key
    // One pass prevents placeholder-like user data from becoming a template.
    return value.replace(/\{([a-zA-Z][a-zA-Z0-9_]*)\}/g, (match, name) =>
      Object.hasOwn(arguments_, name) ? String(arguments_[name]) : match)
  }
}
