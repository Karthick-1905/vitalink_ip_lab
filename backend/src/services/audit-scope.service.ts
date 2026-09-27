import { AdminProfile, DoctorProfile, PatientProfile } from '@alias/models'

/** Snapshot scope at event creation; never use this to infer historical ownership. */
export async function snapshotUserAuditScope(user: { user_type?: string; profile_id?: unknown }) {
  const profile = user.user_type === 'ADMIN'
    ? await AdminProfile.findById(user.profile_id).select('hospital_id admin_role').lean()
    : user.user_type === 'DOCTOR'
      ? await DoctorProfile.findById(user.profile_id).select('hospital_id').lean()
      : user.user_type === 'PATIENT'
        ? await PatientProfile.findById(user.profile_id).select('hospital_id').lean()
        : undefined
  return {
    scope_version: 1,
    event_hospital_id: profile?.hospital_id,
    resource_hospital_id: profile?.hospital_id,
    actor_hospital_id: profile?.hospital_id,
    actor_role: (profile as { admin_role?: string } | undefined)?.admin_role ?? user.user_type,
  }
}
