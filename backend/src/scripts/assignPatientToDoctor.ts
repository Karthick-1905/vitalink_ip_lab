import 'dotenv/config'
import connectDB from '@alias/config/db'
import { User, PatientProfile } from '@alias/models'
import { UserType } from '@alias/validators'
import logger from '@alias/utils/logger'
import { getObjectIdString } from '@alias/utils/objectid'

async function main() {
  const doctorLoginId = process.argv[2]
  const patientLoginId = process.argv[3]

  if (!doctorLoginId || !patientLoginId) {
    console.error('Usage: ts-node src/scripts/assignPatientToDoctor.ts <doctor_login_id> <patient_login_id>')
    console.error('Example: ts-node src/scripts/assignPatientToDoctor.ts DOC001 PAT001')
    process.exit(1)
  }

  await connectDB()

  // Find the doctor user
  const doctorUser = await User.findOne({ login_id: doctorLoginId, user_type: UserType.DOCTOR })
  if (!doctorUser) {
    logger.error(`Doctor with login_id "${doctorLoginId}" not found`)
    process.exit(1)
  }

  // Find the patient user
  const patientUser = await User.findOne({ login_id: patientLoginId, user_type: UserType.PATIENT })
  if (!patientUser) {
    logger.error(`Patient with login_id "${patientLoginId}" not found`)
    process.exit(1)
  }

  // Find the patient profile
  const patientProfile = await PatientProfile.findById(patientUser.profile_id)
  if (!patientProfile) {
    logger.error(`Patient profile not found for patient "${patientLoginId}"`)
    process.exit(1)
  }

  // Check current assignment
  const assignedDoctorId = getObjectIdString(patientProfile.assigned_doctor_id)
  const doctorUserId = getObjectIdString(doctorUser._id)
  const doctorProfileId = getObjectIdString(doctorUser.profile_id)
  if (assignedDoctorId && (assignedDoctorId === doctorUserId || assignedDoctorId === doctorProfileId)) {
    logger.warn(`Patient "${patientLoginId}" is already assigned to doctor "${doctorLoginId}"`)
    process.exit(0)
  }

  // Assign the patient to the doctor
  patientProfile.assigned_doctor_id = doctorUser._id
  await patientProfile.save()

  logger.info(`Successfully assigned patient "${patientLoginId}" to doctor "${doctorLoginId}"`)
  logger.info(`Patient Name: ${patientProfile.demographics?.name || 'Unknown'}`)
  
  process.exit(0)
}

main().catch((err) => {
  console.error('Error:', err.message)
  process.exit(1)
})
