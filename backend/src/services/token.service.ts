import { StatusCodes } from 'http-status-codes'
import { ApiError } from '@alias/utils'
import { TokenWallet, TokenTransaction, SystemConfig } from '@alias/models'
import { TokenTransactionSource } from '@alias/models/tokentransaction.model'

export type FeatureKey =
  | 'PATIENT_DOSAGE'
  | 'PATIENT_HEALTH_LOG'
  | 'PATIENT_PROFILE_UPDATE'
  | 'PATIENT_REPORT_SUBMIT'

const roundToPrecision = (value: number, precision: number) => {
  const factor = Math.pow(10, precision)
  return Math.round((value + Number.EPSILON) * factor) / factor
}

const getTokenConfig = async () => {
  const config = await SystemConfig.findOne({ is_active: true }).lean()
  const precision = typeof config?.token_settings?.precision === 'number'
    ? config.token_settings.precision
    : 2
  const allowFractional = config?.token_settings?.allow_fractional !== false
  const featureWeights = config?.feature_weights
    ? Object.fromEntries(Object.entries(config.feature_weights))
    : {}

  return { precision, allowFractional, featureWeights }
}

export const getFeatureWeight = async (featureKey: FeatureKey): Promise<number> => {
  const { featureWeights } = await getTokenConfig()
  const rawWeight = featureWeights?.[featureKey]
  return typeof rawWeight === 'number' ? rawWeight : 0
}

export const ensureWallet = async (userId: string) => {
  let wallet = await TokenWallet.findOne({ user_id: userId })
  if (!wallet) {
    wallet = await TokenWallet.create({ user_id: userId, balance: 0 })
  }
  return wallet
}

export const getBalance = async (userId: string) => {
  const wallet = await ensureWallet(userId)
  return wallet.balance
}

export const ensureSufficientBalance = async (userId: string, weight: number) => {
  if (weight <= 0) return
  const wallet = await ensureWallet(userId)
  if (wallet.balance < weight) {
    throw new ApiError(StatusCodes.PAYMENT_REQUIRED, 'Insufficient token balance')
  }
}

export const debitForFeature = async (params: {
  userId: string
  featureKey: FeatureKey
  weight: number
  requestId?: string
}) => {
  if (params.weight <= 0) return null

  const { precision } = await getTokenConfig()

  const updatedWallet = await TokenWallet.findOneAndUpdate(
    { user_id: params.userId, balance: { $gte: params.weight } },
    { $inc: { balance: -params.weight } },
    { new: true }
  )

  if (!updatedWallet) {
    throw new ApiError(StatusCodes.PAYMENT_REQUIRED, 'Insufficient token balance')
  }

  const roundedBalance = roundToPrecision(updatedWallet.balance, precision)
  if (roundedBalance !== updatedWallet.balance) {
    updatedWallet.balance = roundedBalance
    await updatedWallet.save()
  }

  return TokenTransaction.create({
    user_id: params.userId,
    delta: -params.weight,
    balance_after: roundedBalance,
    feature_key: params.featureKey,
    weight: params.weight,
    source: TokenTransactionSource.USAGE,
    request_id: params.requestId,
  })
}

export const creditFromPayment = async (params: {
  userId: string
  amount: number
  paymentId: string
  requestId?: string
}) => {
  const { precision } = await getTokenConfig()
  const wallet = await ensureWallet(params.userId)
  const updatedBalance = roundToPrecision(wallet.balance + params.amount, precision)
  wallet.balance = updatedBalance
  await wallet.save()

  await TokenTransaction.create({
    user_id: params.userId,
    delta: params.amount,
    balance_after: updatedBalance,
    source: TokenTransactionSource.PAYMENT,
    payment_id: params.paymentId,
    request_id: params.requestId,
  })

  return wallet
}

export const listTransactions = async (userId: string, filters: { source?: string } = {}, pagination: { page?: number; limit?: number } = {}) => {
  const page = pagination.page || 1
  const limit = pagination.limit || 20

  const query: Record<string, unknown> = { user_id: userId }
  if (filters.source) {
    query.source = filters.source
  }

  const transactions = await TokenTransaction.find(query)
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit)

  const total = await TokenTransaction.countDocuments(query)

  return {
    transactions,
    pagination: {
      total,
      page,
      limit,
      pages: Math.ceil(total / limit),
      hasNext: page * limit < total,
      hasPrev: page > 1,
    },
  }
}

export const resolvePlan = async (planId: string) => {
  const config = await SystemConfig.findOne({ is_active: true }).lean()
  const plans = config?.token_plans || []
  const plan = plans.find((p: any) => p.plan_id === planId && p.is_active !== false)
  if (!plan) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid or inactive plan')
  }
  return plan
}

