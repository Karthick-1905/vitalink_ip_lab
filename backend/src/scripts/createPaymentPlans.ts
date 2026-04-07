import 'dotenv/config'
import mongoose from 'mongoose'
import { config } from '@alias/config'
import { SystemConfig } from '@alias/models'

async function createPaymentPlans() {
  try {
    await mongoose.connect(config.databaseUrl)
    console.log('✓ Connected to MongoDB\n')

    // Define payment plans
    const tokenPlans = [
      {
        plan_id: 'plan_100',
        plan_name: 'Basic Plan',
        tokens: 100,
        price_inr: 49,
        description: '100 tokens',
        is_active: true,
      },
      {
        plan_id: 'plan_200',
        plan_name: 'Premium Plan',
        tokens: 200,
        price_inr: 99,
        description: '200 tokens',
        is_active: true,
      },
    ]

    // Find or create SystemConfig
    let systemConfig = await SystemConfig.findOne({ is_active: true })

    if (!systemConfig) {
      console.log('📝 Creating new SystemConfig...')
      systemConfig = await SystemConfig.create({
        is_active: true,
        token_plans: tokenPlans,
      })
    } else {

        
      await systemConfig.save()
    }

    console.log('\n✅ PAYMENT PLANS CREATED SUCCESSFULLY\n')
    console.log('=' .repeat(50))
    tokenPlans.forEach((plan) => {
      console.log(`${plan.plan_id}: ${plan.tokens} tokens for ₹${plan.price_inr}`)
    })
    console.log('='.repeat(50))

    await mongoose.disconnect()
    process.exit(0)
  } catch (error: any) {
    console.error('❌ Error:', error.message)
    await mongoose.disconnect()
    process.exit(1)
  }
}

createPaymentPlans()
