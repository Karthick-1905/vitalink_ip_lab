import { StatusCodes } from 'http-status-codes'
import { ApiError } from '@alias/utils'
import AppProperties from '@alias/models/appproperties.model'
import BrandAsset from '@alias/models/brandasset.model'
import defaults from '@alias/config/app-properties.defaults.json'
import { requireAdminCapabilityContext, type AdminAccessContext } from '@alias/types/admin-access'

export const PROPERTY_DEFAULTS: Record<string, string> = defaults
export const PROPERTY_HISTORY_LIMIT = 20
const dangerousKeys = new Set(['__proto__', 'constructor', 'prototype'])

export function validateProperties(value: unknown): Record<string, string> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Properties must be a JSON object.')
  }
  const result: Record<string, string> = {}
  for (const [key, item] of Object.entries(value)) {
    if (dangerousKeys.has(key) || !Object.hasOwn(PROPERTY_DEFAULTS, key)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, `Unknown property: ${key}`)
    }
    if (typeof item !== 'string' || item.length > 4000 || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(item)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, `Invalid property: ${key}`)
    }
    if (key.startsWith('theme.') && !/^#[0-9a-fA-F]{6}$/.test(item)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Theme colors must use #RRGGBB.')
    }
    if (key.startsWith('asset.') && item !== PROPERTY_DEFAULTS[key] && !/^brand-asset:[a-f0-9]{64}$/.test(item)) {
      let url: URL
      try { url = new URL(item) } catch { throw new ApiError(StatusCodes.BAD_REQUEST, 'Images must use HTTPS URLs.') }
      if (url.protocol !== 'https:' || url.username || url.password || url.hash) {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'Images must use HTTPS URLs without credentials or fragments.')
      }
    }
    const placeholders = (s: string) => [...s.matchAll(/\{([a-zA-Z][a-zA-Z0-9_]*)\}/g)].map(m => m[1]).sort().join(',')
    if (placeholders(item) !== placeholders(PROPERTY_DEFAULTS[key])) {
      throw new ApiError(StatusCodes.BAD_REQUEST, `Required placeholders changed: ${key}`)
    }
    if (item !== PROPERTY_DEFAULTS[key]) result[key] = item
  }
  // Leave ample space below MongoDB's 16 MiB document limit, including history.
  if (Buffer.byteLength(JSON.stringify(result)) > 256 * 1024) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Property overrides must not exceed 256 KiB.')
  }
  return result
}

function requireAccess(access: AdminAccessContext, write = false) {
  requireAdminCapabilityContext(access, write ? 'platform.system_config.manage' : 'platform.system_config.read', {
    role: 'app_admin', scope: 'global',
  })
}

async function load() {
  const existing = await AppProperties.findById('global').lean()
  if (existing) return existing
  try {
    return (await AppProperties.create({ _id: 'global' })).toObject()
  } catch (error: any) {
    if (error?.code !== 11000) throw error
    return AppProperties.findById('global').lean()
  }
}

export async function getPublishedProperties() {
  // Public reads never create database state and never return drafts or actor IDs.
  const document = await AppProperties.findById('global').lean()
  return {
    schemaVersion: 1,
    revision: document?.published_revision ?? 0,
    properties: { ...PROPERTY_DEFAULTS, ...(document?.published ?? {}) },
  }
}

export async function getAdminProperties(access: AdminAccessContext) {
  requireAccess(access)
  const document = await load()
  return { ...document, defaults: PROPERTY_DEFAULTS, schemaVersion: 1 }
}

export async function mutateProperties(access: AdminAccessContext, body: any) {
  requireAccess(access, true)
  if (!body || !['save', 'publish', 'rollback'].includes(body.action)
    || !Number.isSafeInteger(body.expectedVersion) || body.expectedVersion < 0
    || Object.keys(body).some(key => !['action', 'expectedVersion', 'properties', 'revision'].includes(key))) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Provide action and expectedVersion.')
  }
  const current = await load()
  if (current.version !== body.expectedVersion) throw new ApiError(StatusCodes.CONFLICT, 'Configuration changed. Reload before saving.')
  const update: any = { $inc: { version: 1 }, $set: { updated_by: access.userId } }
  if (body.action === 'save') {
    update.$set.draft = validateProperties(body.properties)
  } else {
    if (body.properties !== undefined) throw new ApiError(StatusCodes.BAD_REQUEST, 'Save the draft before publishing.')
    const previous = body.action === 'rollback'
      ? current.history.find((entry: any) => entry.revision === body.revision)
      : undefined
    if (body.action === 'rollback' && !previous) throw new ApiError(StatusCodes.BAD_REQUEST, 'Rollback revision is not retained.')
    const properties = validateProperties(previous ? previous.properties : current.draft)
    update.$set.published = properties
    update.$set.draft = properties
    update.$inc.published_revision = 1
    update.$push = { history: { $each: [{
      revision: current.published_revision + 1, properties,
      published_at: new Date(), published_by: access.userId,
      restored_from: previous?.revision,
    }], $slice: -PROPERTY_HISTORY_LIMIT } }
    // Preserve the original defaults as a rollback target on first publication.
    if (current.published_revision === 0) update.$push.history.$each.unshift({
      revision: 0, properties: {}, published_at: new Date(), published_by: access.userId,
    })
  }
  const references = Object.entries(body.action === 'save' ? update.$set.draft : update.$set.published)
    .filter(([key, value]) => key.startsWith('asset.') && typeof value === 'string' && /^brand-asset:[a-f0-9]{64}$/.test(value))
    .map(([, value]) => value as string)
  for (const reference of new Set(references)) {
    if (!await BrandAsset.exists({ _id: reference.substring(12) })) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'The referenced brand image does not exist. Upload it before saving.')
    }
  }
  const changed = await AppProperties.findOneAndUpdate(
    { _id: 'global', version: body.expectedVersion }, update, { new: true, runValidators: true },
  ).lean()
  if (!changed) throw new ApiError(StatusCodes.CONFLICT, 'Configuration changed. Reload before saving.')
  return { ...changed, defaults: PROPERTY_DEFAULTS, schemaVersion: 1 }
}
