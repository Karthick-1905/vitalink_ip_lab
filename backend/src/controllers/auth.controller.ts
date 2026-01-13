import { AuthService } from "@src/services/auth.service";
import { Request, Response } from "express";
import { UserType } from "@src/validators";
import { getModel } from "@src/utils";
import { ca } from "zod/v4/locales";

export class AuthController {
    
    static async login(req: Request, res: Response) {
        try {
            const { id, password, user_type } = req.body;
            const Model = getModel(user_type as UserType);
            const user = await (Model as any).findOne({ id }).select("+password");

            if (!user) {
                return res.status(404).json({ message: "User not found" });
            }
            const isMatch = await AuthService.verifyPassword(password, user.password_hash);
            if (!isMatch) {
                return res.status(401).json({ message: "Invalid credentials" });
            }

            const token = await AuthService.generateToken(user.id, user.user_type);
            return res.status(200).json({ token });
        } catch (err) {
            return res.status(500).json({ message: "Internal server error" });
        }
    }

    static async register(req: Request, res: Response) {
        try {
            console.log("Register attempt:", req.body);
            const { id, password, user_type } = req.body;
            const Model = getModel(user_type as UserType);
            const existingUser = await (Model as any).findOne({ id });
            

            if (existingUser) {
                console.log("User already exists:", id);
                return res.status(409).json({ message: "User already exists" });
            }

            const hashedPassword = await AuthService.hashPassword(password);
            console.log("Password hashed for user:", id);
            const newUser = new Model({ admin_id: id, password_hash: hashedPassword, user_type });
            await newUser.save();
            console.log("User registered successfully:", id);
            return res.status(201).json({ message: "User registered successfully" });
        } catch (err) {
            console.log("Register error:", err);
            return res.status(500).json({ message: "Internal server error" });
        }
    }

    static async logout(req: Request, res: Response) {
        try {
            // For JWT, logout can be handled on the client side by deleting the token.
            // Optionally, you can implement token blacklisting on the server side.
            return res.status(200).json({ message: "User logged out successfully" });
        } catch (err) {
            return res.status(500).json({ message: "Internal server error" });
        }
    }

    static async refreshToken(req: Request, res: Response) {
        try {
            const { token } = req.body; 
            const payload = await AuthService.verifyToken(token);
            if (!payload) {
                return res.status(401).json({ message: "Invalid token" });
            }
            const newToken = await AuthService.generateToken(payload.user_id, payload.user_type);
            return res.status(200).json({ token: newToken });
        } catch (err) {
            return res.status(500).json({ message: "Internal server error" });
        }
    }
}
