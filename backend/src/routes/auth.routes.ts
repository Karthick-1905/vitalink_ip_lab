import { Router } from "express";
import { AuthController } from "@src/controllers/auth.controller";
const auth_router = Router();


auth_router.post("/login", AuthController.login);
auth_router.post("/register", AuthController.register);
auth_router.post("/logout", AuthController.logout);

export { auth_router };