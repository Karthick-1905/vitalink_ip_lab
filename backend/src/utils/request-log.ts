import type { Request } from 'express'

/** Never interpolate raw paths or arbitrary query values into access logs. */
export function safeRequestUrl(req: Request): string {
  const route = typeof req.route?.path === 'string' ? req.route.path : '[unmatched]'
  // baseUrl may contain user input for parameterized mounts. Omit it entirely.
  const params = new URLSearchParams((req.originalUrl || req.url || '').split('?')[1] || '')
  const operational = new URLSearchParams()
  for (const key of ['page', 'limit']) {
    const value = params.get(key)
    if (value && /^\d{1,6}$/.test(value)) operational.set(key, value)
  }
  const query = operational.toString()
  return query ? `${route}?${query}` : route
}
