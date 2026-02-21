import { User, PatientProfile, DoctorProfile, AuditLog } from '@alias/models'
import { UserType } from '@alias/validators'

export async function getAdminDashboardStats() {
  const [totalDoctors, activeDoctors, totalPatients, activePatients, totalAuditLogs] = await Promise.all([
    User.countDocuments({ user_type: UserType.DOCTOR }),
    User.countDocuments({ user_type: UserType.DOCTOR, is_active: true }),
    User.countDocuments({ user_type: UserType.PATIENT }),
    User.countDocuments({ user_type: UserType.PATIENT, is_active: true }),
    AuditLog.countDocuments(),
  ])

  // Get recent registrations (last 30 days)
  const thirtyDaysAgo = new Date()
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

  const [recentDoctors, recentPatients] = await Promise.all([
    User.countDocuments({ user_type: UserType.DOCTOR, createdAt: { $gte: thirtyDaysAgo } }),
    User.countDocuments({ user_type: UserType.PATIENT, createdAt: { $gte: thirtyDaysAgo } }),
  ])

  return {
    doctors: {
      total: totalDoctors,
      active: activeDoctors,
      inactive: totalDoctors - activeDoctors,
      recent: recentDoctors,
    },
    patients: {
      total: totalPatients,
      active: activePatients,
      inactive: totalPatients - activePatients,
      recent: recentPatients,
    },
    audit_logs: totalAuditLogs,
  }
}

export async function getRegistrationTrends(period: string = '30d') {
  const days = period === '7d' ? 7 : period === '90d' ? 90 : period === '1y' ? 365 : 30
  const startDate = new Date()
  startDate.setDate(startDate.getDate() - days)

  const doctorTrends = await User.aggregate([
    { $match: { user_type: UserType.DOCTOR, createdAt: { $gte: startDate } } },
    {
      $group: {
        _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
        count: { $sum: 1 },
      },
    },
    { $sort: { _id: 1 } },
  ])

  const patientTrends = await User.aggregate([
    { $match: { user_type: UserType.PATIENT, createdAt: { $gte: startDate } } },
    {
      $group: {
        _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
        count: { $sum: 1 },
      },
    },
    { $sort: { _id: 1 } },
  ])

  return {
    period,
    doctors: doctorTrends.map(t => ({ date: t._id, count: t.count })),
    patients: patientTrends.map(t => ({ date: t._id, count: t.count })),
  }
}

export async function getInrComplianceStats() {
  const patients = await PatientProfile.find().select('inr_history medical_config demographics')

  let inRange = 0
  let belowRange = 0
  let aboveRange = 0
  let noData = 0

  for (const patient of patients) {
    const history = (patient as any).inr_history || []
    if (history.length === 0) {
      noData++
      continue
    }

    const latest = history[history.length - 1]
    const targetMin = (patient as any).medical_config?.target_inr?.min || 2.0
    const targetMax = (patient as any).medical_config?.target_inr?.max || 3.0

    if (latest.inr_value < targetMin) {
      belowRange++
    } else if (latest.inr_value > targetMax) {
      aboveRange++
    } else {
      inRange++
    }
  }

  return {
    total_patients: patients.length,
    in_range: inRange,
    below_range: belowRange,
    above_range: aboveRange,
    no_data: noData,
  }
}

export async function getDoctorWorkloadStats() {
  const workload = await PatientProfile.aggregate([
    { $match: { account_status: { $ne: 'Discharged' } } },
    {
      $group: {
        _id: '$assigned_doctor_id',
        patient_count: { $sum: 1 },
      },
    },
    {
      $lookup: {
        from: 'users',
        localField: '_id',
        foreignField: '_id',
        as: 'doctor_user',
      },
    },
    { $unwind: { path: '$doctor_user', preserveNullAndEmptyArrays: true } },
    {
      $lookup: {
        from: 'doctorprofiles',
        localField: 'doctor_user.profile_id',
        foreignField: '_id',
        as: 'doctor_profile',
      },
    },
    { $unwind: { path: '$doctor_profile', preserveNullAndEmptyArrays: true } },
    {
      $project: {
        doctor_id: '$_id',
        doctor_name: '$doctor_profile.name',
        department: '$doctor_profile.department',
        patient_count: 1,
      },
    },
    { $sort: { patient_count: -1 } },
  ])

  return workload
}

export async function getPeriodStatistics(
  startDate?: string,
  endDate?: string
) {
  const start = startDate ? new Date(startDate) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
  const end = endDate ? new Date(endDate) : new Date()

  const [newDoctors, newPatients, auditActions] = await Promise.all([
    User.countDocuments({
      user_type: UserType.DOCTOR,
      createdAt: { $gte: start, $lte: end },
    }),
    User.countDocuments({
      user_type: UserType.PATIENT,
      createdAt: { $gte: start, $lte: end },
    }),
    AuditLog.aggregate([
      { $match: { createdAt: { $gte: start, $lte: end } } },
      { $group: { _id: '$action', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
    ]),
  ])

  return {
    period: { start: start.toISOString(), end: end.toISOString() },
    new_doctors: newDoctors,
    new_patients: newPatients,
    audit_summary: auditActions.map(a => ({ action: a._id, count: a.count })),
  }
}
