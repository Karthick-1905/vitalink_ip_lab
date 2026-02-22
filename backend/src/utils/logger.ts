import { config } from '@alias/config'
import { createLogger, format, transports } from 'winston'

const logFormat = format.printf(({ level, message, timestamp, requestId, stack, ...meta }) => {
  const logMessage = stack || message
  const requestIdSegment = requestId ? ` [request-id:${requestId}]` : ''
  const metaSegment = Object.keys(meta).length > 0 ? ` ${JSON.stringify(meta)}` : ''
  return `${timestamp} [${level}]${requestIdSegment}: ${logMessage}${metaSegment}`;
});

const activeTransports: any[] = [
  new transports.Console({
    format: format.combine(format.colorize(), logFormat),
  }),
]

const lokiUrl = process.env.LOKI_URL?.trim()
if (lokiUrl) {
  try {
    const LokiTransport = require('winston-loki')
    const lokiUsername = process.env.LOKI_USERNAME?.trim()
    const lokiPassword = process.env.LOKI_PASSWORD?.trim()

    activeTransports.push(
      new LokiTransport({
        host: lokiUrl,
        labels: {
          app: 'vitalink-backend',
          env: config.nodeEnv,
        },
        json: true,
        replaceTimestamp: true,
        basicAuth: lokiUsername && lokiPassword ? `${lokiUsername}:${lokiPassword}` : undefined,
        onConnectionError: (error: Error) => {
          console.error(`Loki transport connection error: ${error.message}`)
        },
      })
    )
  } catch (error) {
    console.error(`Failed to initialize Loki transport: ${(error as Error).message}`)
  }
}

const logger = createLogger({
  level: config.logLevel,
  format: format.combine(
    format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    format.errors({ stack: true }),
    format.splat(),
    format.json()
  ),
  transports: activeTransports,
})

export default logger
