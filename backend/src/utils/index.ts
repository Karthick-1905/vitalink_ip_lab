import { Admin, Doctor, Patient } from "@src/models";
import { UserType } from "@src/validators";

export { generateToken, verifyToken, extractTokenFromHeader } from './jwt.utils'
export { hashPassword, comparePasswords, generateSalt } from './auth.utils'

export function getModel(userType: UserType) {
    switch (userType) {
      case 'ADMIN':
        return Admin;
      case 'DOCTOR':
        return Doctor;
      case 'PATIENT':
        return Patient;
      default:
        throw new Error('Invalid user type');
    }
}