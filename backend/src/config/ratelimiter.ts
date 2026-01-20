import { rateLimit } from 'express-rate-limit'

const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 200,
    message: "Too many requests from this IP, please try again after 15 minutes",
    statusCode: 429,
    handler: (req, res, /*next*/) => {
        res.status(429).json({
            success: false,
            message: 'Too many requests from this IP, please try again after 15 minutes'
        });
    },legacyHeaders: false,
    ipv6Subnet: 56,
})

export default limiter;