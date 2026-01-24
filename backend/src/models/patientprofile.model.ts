import mongoose from "mongoose";
import { DosageScheduleSchema, InrLogSchema, HealthLogSchema } from "./index";

const PatientProfileSchema = new mongoose.Schema({
  assigned_doctor_id: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'User', 
    index: true 
  },
  demographics: {
    name: { type: String, required: [true, "Name is required"] },
    age: { type: Number },
    gender: { 
        type: String,
        enum: ["Male", "Female", "Other"]
    },
    phone: { type: String },
    next_of_kin: {
      name: { type: String },
      relation: { type: String },
      phone: { type: String }
    }
  },
  // TODO: Review After This
  medical_config: {
    diagnosis: { type: String },
    therapy_drug: { type: String },
    therapy_start_date: { type: Date },
    target_inr: {
      min: { type: Number, default: 2.0 },
      max: { type: Number, default: 3.0 }
    }
  },
  weekly_dosage: DosageScheduleSchema,
  inr_history: [InrLogSchema],
  health_logs: [HealthLogSchema],
  account_status: { 
    type: String, 
    enum: ['Active', 'Discharged', 'Deceased'], 
    default: 'Active' 
  }
}, {timestamps: true});

export interface PatientProfileDocument extends mongoose.Document, mongoose.InferSchemaType<typeof PatientProfileSchema>{}

export default mongoose.model<PatientProfileDocument>("PatientProfile", PatientProfileSchema)