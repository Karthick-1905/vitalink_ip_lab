import { Schema } from "mongoose";

export const DosageScheduleSchema = new Schema({
  monday: { type: Number, default: 0 },
  tuesday: { type: Number, default: 0 },
  wednesday: { type: Number, default: 0 },
  thursday: { type: Number, default: 0 },
  friday: { type: Number, default: 0 },
  saturday: { type: Number, default: 0 },
  sunday: { type: Number, default: 0 }
}, { _id: false });

export const InrLogSchema = new Schema({
  test_date: { type: Date, required: true },
  uploaded_at: { type: Date, default: Date.now },
  inr_value: { type: Number, required: true },
  is_critical: { type: Boolean, default: false },
  file_url: { type: String },
  notes: { type: String }
});

export const HealthLogSchema = new Schema({
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

