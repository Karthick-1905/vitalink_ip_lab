import 'dotenv/config'
import mongoose from 'mongoose'
import { config } from '@alias/config'
import { User, PatientProfile, TokenWallet } from '@alias/models'
import { generateTemporaryPassword } from '@alias/services/password.service'

async function createSimplePatient() {
  try {
    // Connect to database
    await mongoose.connect(config.databaseUrl)
    console.log('✓ Connected to MongoDB')

    // Generate credentials
    const username = `patient${Date.now()}`
    const password = generateTemporaryPassword()

    console.log('\n📝 Creating test patient...\n')

    // Create patient profile with medical config and dosage schedule
    const patientProfile = await PatientProfile.create({
      demographics: {
        name: 'Test Patient',
        age: 45,
        gender: 'Male',
        phone: '9876543210',
      },
      account_status: 'Active',
      medical_config: {
        therapy_start_date: new Date(new Date().setDate(new Date().getDate() - 30)), // Started 30 days ago
        taken_doses: [],
      },
      weekly_dosage: {
        monday: 1,
        tuesday: 1,
        wednesday: 1,
        thursday: 1,
        friday: 1,
        saturday: 0,
        sunday: 0,
      },
    })

    // Create user
    const user = await User.create({
      login_id: username,
      password: password,
      user_type: 'PATIENT',
      profile_id: patientProfile._id,
      user_type_model: 'PatientProfile',
      is_active: true,
    })

    // Create token wallet
    await TokenWallet.create({
      user_id: user._id,
      balance: 0,
      max_tokens: 200,
      currency: 'INR',
    })

    // Display results
    console.log('=' .repeat(50))
    console.log('✅ PATIENT CREATED SUCCESSFULLY')
    console.log('='.repeat(50))
    console.log(`Username: ${username}`)
    console.log(`Password: ${password}`)
    console.log(`Initial Tokens: 1000`)
    console.log('='.repeat(50))
    console.log('\n')

    await mongoose.disconnect()
    process.exit(0)
  } catch (error: any) {
    console.error('❌ Error:', error.message)
    await mongoose.disconnect()
    process.exit(1)
  }
}

createSimplePatient()
