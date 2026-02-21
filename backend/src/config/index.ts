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
  bucketName: string
  defaultAdminEmail: string
  defaultAdminPassword: string
}

function getRequiredEnv(key: string): string {
  const value = process.env[key]
  if (!value) {
    throw new Error(`Missing environment variable: ${key}`)
  }
  return value
}

function getOptionalEnv(key: string, defaultValue: string): string {
  return process.env[key] || defaultValue
}

export const config: Config = {
  port: process.env.PORT ? parseInt(process.env.PORT, 10) : 3000,
  databaseUrl: process.env.MONGO_URI || 'mongodb://localhost:27017/VitaLink',
  jwtSecret: getRequiredEnv('JWT_SECRET'),
  jwtExpiresIn: (process.env.JWT_EXPIRES_IN || '1h') as StringValue,
  nodeEnv: process.env.NODE_ENV || 'development',
  logLevel: process.env.LOG_LEVEL || 'info',
  accessKeyId: process.env.ACCESS_KEY_ID || '',
  secretAccessKey: process.env.SECRET_ACCESS_KEY || '',
  bucketName: process.env.S3_BUCKET_NAME,
  defaultAdminEmail: getOptionalEnv('DEFAULT_ADMIN_EMAIL', 'admin@vitalink.com'),
  defaultAdminPassword: getOptionalEnv('DEFAULT_ADMIN_PASSWORD', 'VitaLink@Admin123'),
}



