import * as jwt from 'jsonwebtoken';
import bcrypt from 'bcrypt';
import { UserType , JWTPayload} from '../validators';
import { config } from '../config';


export class AuthService{

    static async hashPassword(password: string): Promise<string>{
        const saltRounds = 10;
        return await bcrypt.hash(password, saltRounds);
    }

    static async verifyPassword(password: string, hash: string): Promise<boolean>{
        return await bcrypt.compare(password, hash);
    }

    static async generateToken(user_id: string, user_type :UserType ): Promise<string>{
        const payload = { user_id, user_type };
        return jwt.sign(payload, config.jwtSecret, { expiresIn: config.jwtExpiresIn });
    }

    static verifyToken(token: string): JWTPayload | null {
        try {
            const decoded = jwt.verify(token, config.jwtSecret);
            if (typeof decoded === 'object' && decoded !== null && 'user_id' in decoded && 'user_type' in decoded) {
                return decoded as JWTPayload;
            }
            return null;
        } catch (err) {
            return null;
        }
    }
}