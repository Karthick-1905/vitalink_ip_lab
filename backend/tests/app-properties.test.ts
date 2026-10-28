import mongoose from 'mongoose'
import axios, { type AxiosInstance } from 'axios'
import type { Server } from 'http'
import app from '@alias/app'
import AppProperties from '@alias/models/appproperties.model'
import BrandAsset from '@alias/models/brandasset.model'
import { DEFAULT_ADMIN_ROLE_POLICIES } from '@alias/constants/admin-capabilities'
import type { AdminAccessContext } from '@alias/types/admin-access'
import { getAdminProperties, getPublishedProperties, mutateProperties, validateProperties, PROPERTY_DEFAULTS } from '@alias/services/app-properties.service'
import { createBrandAsset, validateBrandImage } from '@alias/services/brand-asset.service'
import { getServerCopy } from '@alias/services/presentation-copy.service'
import { isControlPlaneRequest } from '@alias/middlewares/systemConfig.middleware'
import { config } from '@alias/config'
import { startMongoReplicaSet, type MongoReplicaSetHarness } from './setup/mongo-replica-set'

jest.setTimeout(120_000)
let harness: MongoReplicaSetHarness
let server: Server
let api: AxiosInstance
const admin: AdminAccessContext = {
  userId: '507f1f77bcf86cd799439011', role: 'app_admin', scope: 'global',
  permissions: { ...DEFAULT_ADMIN_ROLE_POLICIES.app_admin }, policyVersion: 1, readOnly: false,
}
const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='
beforeAll(async () => {
  harness = await startMongoReplicaSet({ databaseName: 'presentation_properties' })
  await mongoose.connect(harness.uri)
  await AppProperties.init()
  server = app.listen(0)
  api = axios.create({ baseURL: `http://127.0.0.1:${(server.address() as any).port}`, validateStatus: () => true })
})
afterAll(async () => {
  if (server) await new Promise<void>(resolve => server.close(() => resolve()))
  await mongoose.disconnect()
  if (harness) await harness.stop()
})
beforeEach(async () => { await AppProperties.deleteMany({}); await BrandAsset.deleteMany({}) })

test('public reads expose defaults without creating state; management stays authenticated', async () => {
  const response = await api.get('/api/v1/app-properties')
  expect(response.status).toBe(200)
  expect(response.data.data).toEqual({ schemaVersion: 1, revision: 0, properties: PROPERTY_DEFAULTS })
  expect(await AppProperties.countDocuments()).toBe(0)
  expect((await api.get('/api/v1/app-properties', { headers: { 'If-None-Match': response.headers.etag } })).status).toBe(304)
  expect((await api.get('/api/v1/admin/config/presentation')).status).toBe(401)
  expect((await api.put('/api/v1/admin/config/presentation', {})).status).toBe(401)
})

test('draft is private, publishing is atomic, rollback creates a new revision', async () => {
  const saved = await mutateProperties(admin, { action: 'save', expectedVersion: 0, properties: { 'branding.appName': 'Hospital Portal' } })
  expect(saved.version).toBe(1)
  expect((await getPublishedProperties()).properties['branding.appName']).toBe('VitaLink')
  const published = await mutateProperties(admin, { action: 'publish', expectedVersion: 1 })
  expect(published.published_revision).toBe(1)
  expect((await getPublishedProperties()).properties['branding.appName']).toBe('Hospital Portal')
  const response = await api.get('/api/v1/app-properties')
  expect(response.data.data.draft).toBeUndefined()
  expect(response.data.data.history).toBeUndefined()
  const restored = await mutateProperties(admin, { action: 'rollback', expectedVersion: 2, revision: 0 })
  expect(restored.published_revision).toBe(2)
  expect((await getPublishedProperties()).properties['branding.appName']).toBe('VitaLink')
})

test('simultaneous editors cannot overwrite each other', async () => {
  await getAdminProperties(admin)
  const results = await Promise.allSettled(['A', 'B'].map(value => mutateProperties(admin, {
    action: 'save', expectedVersion: 0, properties: { 'branding.appName': value },
  })))
  expect(results.filter(result => result.status === 'fulfilled')).toHaveLength(1)
  const failure = results.find(result => result.status === 'rejected') as PromiseRejectedResult
  expect(failure.reason.statusCode).toBe(409)
})

test('unknown uploaded-logo references cannot be saved', async () => {
  await expect(mutateProperties(admin, { action: 'save', expectedVersion: 0,
    properties: { 'asset.hospitalLogo': `brand-asset:${'0'.repeat(64)}` },
  })).rejects.toMatchObject({ statusCode: 400 })
  expect((await getAdminProperties(admin)).version).toBe(0)
})

test('browser clients can read ETag and preflight conditional property requests', async () => {
  const origin = config.corsAllowedOrigins[0] || 'http://localhost:3000'
  const response = await api.get('/api/v1/app-properties', { headers: { Origin: origin } })
  expect(response.headers['access-control-expose-headers']).toContain('ETag')
  const preflight = await api.options('/api/v1/app-properties', { headers: {
    Origin: origin, 'Access-Control-Request-Method': 'GET', 'Access-Control-Request-Headers': 'if-none-match',
  } })
  expect(preflight.status).toBe(204)
  expect(preflight.headers['access-control-allow-headers']).toContain('If-None-Match')
})

test('rejects invalid colors, assets, unknown keys and missing template placeholders', () => {
  for (const properties of [
    { 'theme.primary': 'red' }, { 'asset.hospitalLogo': 'javascript:alert(1)' },
    { 'asset.hospitalLogo': 'http://example.com/logo.png' },
    { 'jwtSecret': 'not-public' }, { 'notification.dosage.message': 'Take {dose}mg' },
    JSON.parse('{"__proto__":"bad"}'),
  ]) expect(() => validateProperties(properties)).toThrow()
  expect(validateProperties({ 'theme.primary': '#123ABC' })).toEqual({ 'theme.primary': '#123ABC' })
})

test('tenant, auditor and read-only contexts cannot mutate presentation settings', async () => {
  for (const access of [{ ...admin, role: 'hospital_admin', scope: 'tenant' }, { ...admin, role: 'auditor' }, { ...admin, readOnly: true }]) {
    await expect(mutateProperties(access as AdminAccessContext, { action: 'publish', expectedVersion: 0 })).rejects.toMatchObject({ statusCode: 403 })
  }
  expect(await AppProperties.countDocuments()).toBe(0)
})

test('uploads are content-addressed and public images contain the original bytes', async () => {
  const result = await createBrandAsset(admin, { contentBase64: png })
  await createBrandAsset(admin, { contentBase64: png })
  expect(await BrandAsset.countDocuments()).toBe(1)
  const response = await api.get(`/api/v1/app-properties/assets/${result.asset.substring(12)}`, { responseType: 'arraybuffer' })
  expect(response.status).toBe(200)
  expect(response.headers['content-type']).toContain('image/png')
  expect(Buffer.from(response.data).equals(Buffer.from(png, 'base64'))).toBe(true)
  expect((await api.get('/api/v1/app-properties/assets/missing')).status).toBe(404)
})

test('rejects oversized, unsupported and oversized-dimension image uploads', () => {
  expect(() => validateBrandImage({ contentBase64: Buffer.from('<svg/>').toString('base64') })).toThrow()
  expect(() => validateBrandImage({ contentBase64: 'A'.repeat(700000) })).toThrow()
  const tooWide = Buffer.from(png, 'base64'); tooWide.writeUInt32BE(99999, 16)
  expect(() => validateBrandImage({ contentBase64: tooWide.toString('base64') })).toThrow()
})

test('server templates keep clinical placeholders and do not re-expand substituted data', async () => {
  await mutateProperties(admin, { action: 'save', expectedVersion: 0, properties: {
    'notification.dosage.message': 'Today: {dose}mg of {drugName}.',
  } })
  await mutateProperties(admin, { action: 'publish', expectedVersion: 1 })
  const copy = await getServerCopy()
  expect(copy('notification.dosage.message', { dose: 2, drugName: '{dose}' })).toBe('Today: 2mg of {dose}.')
})

test('new endpoints remain available during maintenance without broadening patient access', () => {
  expect(isControlPlaneRequest('/api/v1/app-properties')).toBe(true)
  expect(isControlPlaneRequest('/api/v1/admin/config/presentation')).toBe(true)
  expect(isControlPlaneRequest(`/api/v1/app-properties/assets/${'a'.repeat(64)}`)).toBe(true)
  expect(isControlPlaneRequest('/api/v1/patient/profile')).toBe(false)
})
