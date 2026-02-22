import { Router } from "express";
import { validate } from "@alias/middlewares/ValidateResource";
import { authenticate } from "@alias/middlewares/authProvider.middleware";
import { changePasswordSchema, loginSchema } from "@alias/validators/user.validator";
import {
  changePasswordController,
  loginController,
  logoutController,
  getMeController,
} from "@alias/controllers/auth.controller";

const router = Router();

router.post("/login", validate(loginSchema), loginController);

router.post("/logout", authenticate, logoutController);

router.get("/me", authenticate, getMeController);

router.post("/change-password", authenticate, validate(changePasswordSchema), changePasswordController);

export default router
