import { Request, Response } from 'express'
import { StatusCodes } from 'http-status-codes'
import { ApiResponse, asyncHandler } from '@alias/utils'
import * as paymentService from '@alias/services/payment.service'
import * as tokenService from '@alias/services/token.service'
import type { CreatePaymentOrderInput } from '@alias/validators/payment.validator'

export const createPaymentOrder = asyncHandler(async (req: Request<{}, {}, CreatePaymentOrderInput['body']>, res: Response) => {
  const { user_id } = req.user
  const { plan_id } = req.body

  const result = await paymentService.createPaymentOrder({
    userId: user_id,
    planId: plan_id,
        requestId: (req as any).requestId,
  })

  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Payment order created', result))
})

export const getTokenBalance = asyncHandler(async (req: Request, res: Response) => {
  const { user_id } = req.user
  const balance = await tokenService.getBalance(user_id)

  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Token balance fetched', { balance }))
})

export const getTokenTransactions = asyncHandler(async (req: Request, res: Response) => {
  const { user_id } = req.user
  const { page, limit } = req.query as any
  const pageNum = page ? parseInt(page, 10) : 1
  const limitNum = limit ? parseInt(limit, 10) : 20

  const result = await tokenService.listTransactions(user_id, {}, { page: pageNum, limit: limitNum })

  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Token transactions fetched', result))
})

export const handleRazorpayWebhook = asyncHandler(async (req: Request, res: Response) => {
  const signature = req.headers['x-razorpay-signature'] as string
    const rawBody = (req as any).rawBody || ''

  const result = await paymentService.handleRazorpayWebhook({
    rawBody,
    signature,
    payload: req.body,
  })

  res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Webhook processed', result))
})
