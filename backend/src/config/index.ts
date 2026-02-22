import 'dotenv/config'
import type { StringValue } from 'ms'

interface Config {
  port: number
  databaseUrl: string
  jwtSecret: string
  jwtExpiresIn: StringValue | number
  nodeEnv: string
  logLevel: string
  accessKeyId: string
  secretAccessKey: string
  bucketName?: string
}

const nodeEnv = process.env.NODE_ENV || 'development'
const isProduction = nodeEnv === 'production'
const isTest = nodeEnv === 'test'

function getEnv(
  key: string,
  options: {
    requiredInProduction?: boolean
    defaultValue?: string
  } = {}
): string {
  const value = process.env[key]?.trim()

  if (value) {
    return value
  }

  if (isProduction && options.requiredInProduction) {
    throw new Error(`Missing required environment variable in production: ${key}`)
  }

  if (options.defaultValue !== undefined) {
    return options.defaultValue
  }

  return ''
}

const defaultDatabaseUrl = isTest
  ? 'mongodb://localhost:27017/VitaLink_test'
  : 'mongodb://localhost:27017/VitaLink'

const defaultJwtSecret = isTest
  ? 'test-only-jwt-secret'
  : 'dev-only-jwt-secret-change-me'

export const config: Config = {
  port: process.env.PORT ? parseInt(process.env.PORT, 10) : 3000,
  databaseUrl: getEnv('MONGO_URI', { requiredInProduction: true, defaultValue: defaultDatabaseUrl }),
  jwtSecret: getEnv('JWT_SECRET', { requiredInProduction: true, defaultValue: defaultJwtSecret }),
  jwtExpiresIn: (getEnv('JWT_EXPIRES_IN', { defaultValue: '1h' }) as StringValue),
  nodeEnv,
  logLevel: getEnv('LOG_LEVEL', { defaultValue: 'info' }),
  accessKeyId: getEnv('ACCESS_KEY_ID'),
  secretAccessKey: getEnv('SECRET_ACCESS_KEY'),
  bucketName: process.env.S3_BUCKET_NAME,
}


