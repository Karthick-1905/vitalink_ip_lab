export enum UserType {
  ADMIN = 'ADMIN',
  DOCTOR = 'DOCTOR',
  PATIENT = 'PATIENT',
}

export interface JWTPayload {
  user_id: string;
  user_type: UserType;
}