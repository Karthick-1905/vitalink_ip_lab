import mongoose from 'mongoose'

export enum AdminPermission {
  FULL_ACCESS = 'FULL_ACCESS',
  READ_ONLY = 'READ_ONLY',
  LIMITED_ACCESS = 'LIMITED_ACCESS',
}

const AdminProfileSchema = new mongoose.Schema({
  permission: {
    type: String,
    enum: Object.values(AdminPermission),
    default: AdminPermission.FULL_ACCESS,
  },
}, { timestamps: true })

export interface AdminProfileDocument extends mongoose.InferSchemaType<typeof AdminProfileSchema> {}

export default mongoose.model<AdminProfileDocument>('AdminProfile', AdminProfileSchema)
