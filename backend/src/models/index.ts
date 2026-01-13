import mongoose from "mongoose";

const Schema = mongoose.Schema;

import { UserType } from "@src/validators";



// ==========================================
// 1. SHARED SUB-DOCUMENTS (Embedded)
// ==========================================

const DosageScheduleSchema = new Schema({
  monday: { type: Number, default: 0 },
  tuesday: { type: Number, default: 0 },
  wednesday: { type: Number, default: 0 },
  thursday: { type: Number, default: 0 },
  friday: { type: Number, default: 0 },
  saturday: { type: Number, default: 0 },
  sunday: { type: Number, default: 0 }
}, { _id: false }); // No ID needed for simple sub-docs

const InrLogSchema = new Schema({
  test_date: { type: Date, required: true },
  uploaded_at: { type: Date, default: Date.now },
  inr_value: { type: Number, required: true },
  is_critical: { type: Boolean, default: false },
  file_url: { type: String }, // Path to PDF/Image
  notes: { type: String }
});

const HealthLogSchema = new Schema({
  date: { type: Date, default: Date.now },
  type: { 
    type: String, 
    enum: ['SIDE_EFFECT', 'ILLNESS', 'LIFESTYLE', 'OTHER_MEDS'], 
    required: true 
  },
  description: { type: String, required: true },
  severity: { 
    type: String, 
    enum: ['Normal', 'High', 'Emergency'], 
    default: 'Normal' 
  },
  is_resolved: { type: Boolean, default: false }
});

// ==========================================
// 2. MAIN COLLECTION SCHEMAS
// ==========================================

// --- ADMIN ---
const AdminSchema = new Schema({
  admin_id: { type: String, required: true, unique: true },

  password_hash: { type: String, required: true },
  user_type: { type: String, default: UserType[UserType.ADMIN] },
  permission: { type : String , 
    enum : ['FULL_ACCESS', 'READ_ONLY', 'LIMITED_ACCESS'] ,
    default: 'FULL_ACCESS'
  },
  created_at: { type: Date, default: Date.now }
});

// --- DOCTOR ---
const DoctorSchema = new Schema({
  doctor_id: { type: String, required: true, unique: true },
  name: { type: String, required: true },
  user_type: { type: String, default: UserType[UserType.DOCTOR] },

  department: { type: String, default: 'Cardiology' },
  contact_number: { type: String },
  password_hash: { type: String, required: true },
  is_active: { type: Boolean, default: true },
  profile_picture_url: { type: String }
});

// --- PATIENT ---
const PatientSchema = new Schema({
  patient_id: { type: String, required: true, unique: true }, // OP Number
  assigned_doctor_id: { type: String, required: true, index: true }, // Foreign Key
  user_type: { type: String, default: UserType[UserType.PATIENT] },

  // Auth & Profile
  password_hash: { type: String, required: true },
  demographics: {
    name: { type: String, required: true },
    age: { type: Number },
    gender: { type: String },
    phone: { type: String },
    next_of_kin: {
      name: String,
      relation: String,
      phone: String
    }
  },

  // Medical Configuration
  medical_config: {
    diagnosis: { type: String },
    therapy_drug: { type: String }, // e.g., "Warfarin"
    therapy_start_date: { type: Date },
    target_inr: {
      min: { type: Number, default: 2.0 },
      max: { type: Number, default: 3.0 }
    }
  },

  // The Grid (Embedded 1:1)
  weekly_dosage: { type: DosageScheduleSchema, default: () => ({}) },

  // Logs (Embedded Arrays)
  inr_history: [InrLogSchema],
  health_logs: [HealthLogSchema],

  // Meta
  account_status: { 
    type: String, 
    enum: ['Active', 'Discharged', 'Deceased'], 
    default: 'Active' 
  }
}, { timestamps: true }); // Automatically adds createdAt, updatedAt

// ==========================================
// 3. EXPORTS
// ==========================================

export const Admin = mongoose.model('Admin', AdminSchema);
export const Doctor = mongoose.model('Doctor', DoctorSchema);
export const Patient = mongoose.model('Patient', PatientSchema);

export interface IAdmin  extends mongoose.Document , mongoose.InferSchemaType<typeof AdminSchema> {}
export interface IDoctor  extends mongoose.Document , mongoose.InferSchemaType<typeof DoctorSchema> {}
export interface IPatient  extends mongoose.Document , mongoose.InferSchemaType<typeof PatientSchema> {}

