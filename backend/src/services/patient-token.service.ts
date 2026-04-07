import { TokenWallet, TokenTransaction, SystemConfig } from '@alias/models'
import { ApiError } from '@alias/utils'
import { StatusCodes } from 'http-status-codes'
import logger from '@alias/utils/logger'

export enum PatientFeature {
  DOCTOR_CONSULTATION = 'DOCTOR_CONSULTATION',
  REPORT_UPLOAD = 'REPORT_UPLOAD',
  HEALTH_LOG_UPDATE = 'HEALTH_LOG_UPDATE',
  PROFILE_UPDATE = 'PROFILE_UPDATE',
  DOSAGE_LOG = 'DOSAGE_LOG',
  VIDEO_CALL = 'VIDEO_CALL',
}

/**
 * Get the token cost for a specific feature from SystemConfig
 */
export async function getFeatureCost(feature: PatientFeature): Promise<number> {
  const config = await SystemConfig.findOne({ is_active: true }).lean()
  const featureWeights = config?.feature_weights || {}
  return (featureWeights as Record<string, number>)[feature] || 0
}

/**
 * Check if user has sufficient tokens for a feature
 * Throws error if insufficient balance
 */
export async function checkSufficientTokens(
  userId: string,
  feature: PatientFeature
): Promise<number> {
  const cost = await getFeatureCost(feature)
  
  if (cost === 0) {
    return 0 // No token cost for this feature
  }

  const wallet = await TokenWallet.findOne({ user_id: userId })

  if (!wallet || wallet.balance < cost) {
    const available = wallet?.balance ?? 0
    throw new ApiError(
      StatusCodes.PAYMENT_REQUIRED,
      `Insufficient tokens. Required: ${cost}, Available: ${available}`
    )
  }

  return cost
}

/**
 * Deduct tokens for a feature and create transaction record
 */
export async function deductTokensForFeature(
  userId: string,
  feature: PatientFeature,
  metadata?: Record<string, any>
): Promise<{ wallet: any; transaction: any }> {
  const cost = await checkSufficientTokens(userId, feature)

  if (cost === 0) {
    // No tokens to deduct
    return {
      wallet: await TokenWallet.findOne({ user_id: userId }),
      transaction: null,
    }
  }

  const [wallet, transaction] = await Promise.all([
    TokenWallet.findOneAndUpdate(
      { user_id: userId },
      { $inc: { balance: -cost } },
      { new: true }
    ),
    TokenTransaction.create({
      user_id: userId,
      delta: -cost,
      balance_after: (await TokenWallet.findOne({ user_id: userId }))?.balance || 0,
      feature_key: feature,
      weight: cost,
      source: 'PATIENT_SERVICE',
      metadata,
    }),
  ])

  if (!wallet) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Token wallet not found')
  }

  logger.info('Tokens deducted', {
    userId,
    feature,
    amount: cost,
    remainingBalance: wallet.balance,
  })

  return { wallet, transaction }
}

/**
 * Credit tokens to user wallet (e.g., from payment)
 */
export async function creditTokensForPayment(
  userId: string,
  amount: number,
  paymentId: string
): Promise<{ wallet: any; transaction: any }> {
  if (amount <= 0) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Amount must be greater than 0')
  }

  // Get current wallet to check max_tokens
  const currentWallet = await TokenWallet.findOne({ user_id: userId })
  if (!currentWallet) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Token wallet not found')
  }

  // Cap tokens at max_tokens (200), guard for existing wallets without the field
  const maxTokens = currentWallet.max_tokens ?? 200
  const newBalance = Math.min(currentWallet.balance + amount, maxTokens)
  const actualCredit = newBalance - currentWallet.balance

  const wallet = await TokenWallet.findOneAndUpdate(
    { user_id: userId },
    { $set: { balance: newBalance } },
    { new: true }
  )

  if (!wallet) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Token wallet not found')
  }

  const transaction = await TokenTransaction.create({
    user_id: userId,
    delta: actualCredit,
    balance_after: wallet.balance,
    feature_key: 'PAYMENT',
    weight: actualCredit,
    source: 'PAYMENT',
    metadata: { payment_id: paymentId },
  })

  logger.info('Tokens credited from payment', {
    userId,
    amount,
    paymentId,
    newBalance: wallet.balance,
  })

  return { wallet, transaction }
}

/**
 * Get current token balance for user
 */
export async function getTokenBalance(userId: string): Promise<number> {
  const wallet = await TokenWallet.findOne({ user_id: userId })
  return wallet?.balance ?? 0
}

/**
 * Get token transaction history for user
 */
export async function getTokenHistory(
  userId: string,
  options: { page?: number; limit?: number } = {}
): Promise<{ transactions: any[]; total: number; page: number; limit: number }> {
  const page = options.page || 1
  const limit = options.limit || 20
  const skip = (page - 1) * limit

  const [transactions, total] = await Promise.all([
    TokenTransaction.find({ user_id: userId })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean(),
    TokenTransaction.countDocuments({ user_id: userId }),
  ])

  return {
    transactions,
    total,
    page,
    limit,
  }
}

/**
 * Get feature costs summary from SystemConfig
 */
export async function getFeatureCostsSummary(): Promise<Record<string, number>> {
  const config = await SystemConfig.findOne({ is_active: true }).lean()
  return (config?.feature_weights || {}) as Record<string, number>
}
