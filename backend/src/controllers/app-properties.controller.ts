import { asyncHandler, ApiResponse } from '@alias/utils'
import { requireAdminAccessContext } from '@alias/types/admin-access'
import { getAdminProperties, getPublishedProperties, mutateProperties } from '@alias/services/app-properties.service'
import { createBrandAsset, getBrandAsset } from '@alias/services/brand-asset.service'
import { createHash } from 'crypto'

export const readPublishedProperties = asyncHandler(async (_req, res) => {
  const data = await getPublishedProperties()
  const etag = `"properties-v1-${createHash('sha256').update(JSON.stringify(data)).digest('hex')}"`
  res.set('ETag', etag).set('Cache-Control', 'public, max-age=0, must-revalidate')
  res.json(new ApiResponse(200, 'Application properties', data))
})

export const readAdminProperties = asyncHandler(async (req, res) => {
  res.set('Cache-Control', 'no-store')
  res.json(new ApiResponse(200, 'Presentation configuration', await getAdminProperties(requireAdminAccessContext(req))))
})

export const writeAdminProperties = asyncHandler(async (req, res) => {
  res.set('Cache-Control', 'no-store')
  const data = await mutateProperties(requireAdminAccessContext(req), req.body)
  res.locals.auditResourceId = 'global'
  res.json(new ApiResponse(200, 'Presentation configuration updated', data))
})

export const uploadBrandAsset = asyncHandler(async (req, res) => {
  res.status(201).json(new ApiResponse(201, 'Brand image uploaded', await createBrandAsset(requireAdminAccessContext(req), req.body)))
})

export const readBrandAsset = asyncHandler(async (req, res) => {
  const image = await getBrandAsset(String(req.params.id))
  res.set('Cache-Control', 'public, max-age=31536000, immutable')
  const bytes = Buffer.isBuffer(image.bytes) ? image.bytes : Buffer.from((image.bytes as any).buffer)
  res.set('X-Content-Type-Options', 'nosniff').type(image.content_type).send(bytes)
})
