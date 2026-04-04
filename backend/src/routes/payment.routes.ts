import { Router } from 'express'
import { 
  createPaymentOrder,
  getTokenBalance,
  getTokenTransactions,
  handleRazorpayWebhook 
} from '@alias/controllers/payment.controller'

const router = Router()

router.post('/order', createPaymentOrder)
router.get('/balance', getTokenBalance)
router.get('/transactions', getTokenTransactions)
router.post('/razorpay/webhook', handleRazorpayWebhook)

export default router