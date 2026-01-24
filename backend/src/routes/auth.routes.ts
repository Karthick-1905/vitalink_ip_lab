import { Router } from "express";
import { validate } from "@src/middlewares/ValidateResource";
import { authenticate } from "@src/middlewares/authProvider.middleware";
import { registerSchema, loginSchema } from "@src/validators";
import {
  registerController,
  loginController,
  logoutController,
  getMeController,
} from "@src/controllers/auth.controller";

const router = Router();

/**
 * POST /api/auth/register
 * Register a new user (Doctor or Patient)
 * Public endpoint
 */
router.post("/register", validate(registerSchema), registerController);

/**
 * POST /api/auth/login
 * Authenticate user and get JWT token
 * Public endpoint
 */
router.post("/login", validate(loginSchema), loginController);

/**
 * POST /api/auth/logout
 * Logout user (invalidate session)
 * Protected endpoint
 */
router.post("/logout", authenticate, logoutController);

/**
 * GET /api/auth/me
 * Get current authenticated user's profile
 * Protected endpoint
 */
router.get("/me", authenticate, getMeController);

export default router