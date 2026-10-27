import { createHash } from 'crypto'
import { StatusCodes } from 'http-status-codes'
import { ApiError } from '@alias/utils'
import BrandAsset from '@alias/models/brandasset.model'
import { requireAdminCapabilityContext, type AdminAccessContext } from '@alias/types/admin-access'

export function validateBrandImage(body: any) {
  const fail = () => { throw new ApiError(StatusCodes.BAD_REQUEST, 'Use a PNG or JPEG up to 512 KiB and 2048 pixels per side.') }
  if (!body || typeof body.contentBase64 !== 'string' || body.contentBase64.length > 699052
    || !/^[A-Za-z0-9+/]+={0,2}$/.test(body.contentBase64)) return fail()
  const bytes = Buffer.from(body.contentBase64, 'base64')
  if (!bytes.length || bytes.length > 512 * 1024 || bytes.toString('base64') !== body.contentBase64) return fail()
  let contentType = ''
  let width = 0
  let height = 0
  if (bytes.length >= 33 && bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))
    && bytes.toString('ascii', 12, 16) === 'IHDR') {
    contentType = 'image/png'
    width = bytes.readUInt32BE(16); height = bytes.readUInt32BE(20)
  } else if (bytes.length >= 4 && bytes[0] === 255 && bytes[1] === 216) {
    contentType = 'image/jpeg'
    let offset = 2
    while (offset + 4 < bytes.length) {
      if (bytes[offset++] !== 255) return fail()
      while (bytes[offset] === 255) offset++
      const marker = bytes[offset++]
      if (marker === 0xd9 || marker === 0xda) break
      if (offset + 2 > bytes.length) return fail()
      const length = bytes.readUInt16BE(offset)
      if (length < 2 || offset + length > bytes.length) return fail()
      if ([0xc0,0xc1,0xc2].includes(marker) && length >= 8) {
        height = bytes.readUInt16BE(offset + 3); width = bytes.readUInt16BE(offset + 5); break
      }
      offset += length
    }
  }
  if (!contentType || !width || !height || width > 2048 || height > 2048) return fail()
  return { bytes, contentType, id: createHash('sha256').update(bytes).digest('hex') }
}

export async function createBrandAsset(access: AdminAccessContext, body: unknown) {
  requireAdminCapabilityContext(access, 'platform.system_config.manage', { role: 'app_admin', scope: 'global' })
  const image = validateBrandImage(body)
  await BrandAsset.updateOne({ _id: image.id }, { $setOnInsert: {
    content_type: image.contentType, bytes: image.bytes, created_by: access.userId,
  } }, { upsert: true })
  return { asset: `brand-asset:${image.id}` }
}

export async function getBrandAsset(id: string) {
  if (!/^[a-f0-9]{64}$/.test(id)) throw new ApiError(StatusCodes.NOT_FOUND, 'Image not found.')
  const image = await BrandAsset.findById(id).select('+bytes').lean()
  if (!image) throw new ApiError(StatusCodes.NOT_FOUND, 'Image not found.')
  return image
}
