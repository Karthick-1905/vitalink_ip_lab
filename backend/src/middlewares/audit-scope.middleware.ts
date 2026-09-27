import type { RequestHandler } from 'express'
import mongoose from 'mongoose'
import { AdminProfile, Hospital, Invoice } from '@alias/models'

/** Capture persisted context before a mutation can move the actor or resource. */
export const captureAdminAuditScope: RequestHandler = async (req, res, next) => {
  if (!['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)) return next()
  try {
    const actor = await AdminProfile.findById(req.authUser?.profile_id).select('hospital_id admin_role').lean()
    res.locals.auditActor = { hospital_id: actor?.hospital_id, role: actor?.admin_role }
    const path = req.path.replace(/\/$/, '')
    const target = /^\/(hospitals|billing\/invoices)\/([^/]+)(?:\/(?:status|checkout))?$/.exec(path)
    if (target) {
      const id = decodeURIComponent(target[2])
      if (target[1] === 'hospitals') {
        const hospital = await Hospital.findOne(mongoose.isValidObjectId(id) ? { _id: id } : { code: id.toUpperCase() }).select('_id').lean()
        res.locals.auditEventHospitalId = hospital?._id
      } else if (mongoose.isValidObjectId(id)) {
        res.locals.auditEventHospitalId = (await Invoice.findById(id).select('hospital_id').lean())?.hospital_id
      }
    }
    next()
  } catch (error) {
    // Do not execute an administrative mutation if its pre-event scope cannot be captured.
    next(error)
  }
}
