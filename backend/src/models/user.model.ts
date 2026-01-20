import { UserType } from "@src/validators";
import mongoose from "mongoose";

const UserSchema = new mongoose.Schema({
  login_id: { 
    type: String, 
    required: [true, 'Login ID is required'], 
    unique: true 
  }, 
  password: { 
    type: String, 
    required: [true, 'Password is required'] 
  },
  salt: {
    type: String, 
    required: [true, 'Salt is required']
  },
  user_type: { 
    type: String,
    enum: Object.values(UserType),
    required: [true, 'User type is required'] 
  },
  profile_id: {
    type: mongoose.Schema.Types.ObjectId,
    required: [true, 'Profile ID is required'],
    unique: true,
    refPath: 'user_type_model'
  },
  user_type_model: {
    type: String,
    required: true,
    validate: {
      validator: function (this: any, value: string) {
        const map = {
          ADMIN: 'AdminProfile',
          DOCTOR: 'DoctorProfile',
          PATIENT: 'PatientProfile',
        };
        return map[this.user_type] === value;
      },
      message: 'user_type_model does not match user_type',
    }
  },
  is_active: { type: Boolean, default: true },
}, { timestamps: true });

export interface UserDocument extends mongoose.InferSchemaType<typeof UserSchema>{}

export default mongoose.model<UserDocument>("User", UserSchema)