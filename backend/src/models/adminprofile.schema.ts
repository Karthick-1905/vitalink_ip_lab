import mongoose from "mongoose";

const AdminProfileSchema = new mongoose.Schema({
  permission: { 
    type: String, 
    enum: ['FULL_ACCESS', 'READ_ONLY', 'LIMITED_ACCESS'],
    default: 'FULL_ACCESS'
  }
});

export interface AdminProfileDocument extends mongoose.Document, mongoose.InferSchemaType<typeof AdminProfileSchema>{}

export default mongoose.model<AdminProfileDocument>("AdminProfile", AdminProfileSchema)