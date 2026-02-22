import mongoose from 'mongoose'

/**
 * Safely extracts a string representation of a MongoDB ObjectId from various input types.
 * Handles raw strings, ObjectId instances, objects with `_id`, and anything with `.toString()`.
 */
export function getObjectIdString(value: unknown): string | null {
  if (!value) return null
  if (typeof value === 'string') return value
  if (value instanceof mongoose.Types.ObjectId) return value.toString()
  if (typeof value === 'object' && value !== null && '_id' in value) {
    return getObjectIdString((value as { _id?: unknown })._id)
  }
  if (typeof (value as { toString?: () => string }).toString === 'function') {
    const converted = (value as { toString: () => string }).toString()
    if (converted && converted !== '[object Object]') {
      return converted
    }
  }
  return null
}
