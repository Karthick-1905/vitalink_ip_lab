import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

interface Config {
  port: number;
  databaseUrl: string;
  jwtSecret: string;
  jwtExpiresIn: string;
  nodeEnv: string;
  logLevel: string;
}



export const config : Config=  { 
    port: process.env.PORT ? parseInt(process.env.PORT, 10) : 3000,
    databaseUrl: process.env.MONGO_URI || 'mongodb://localhost:27017/VitaLink',
    jwtSecret: process.env.JWT_SECRET,
    jwtExpiresIn: process.env.JWT_EXPIRES_IN || '1h',
    nodeEnv : process.env.NODE_ENV || 'development',
    logLevel: process.env.LOG_LEVEL || 'info',
 };
    


