import { Router } from "express";
import user_router from "./user.routes";
import doctor_router from "./doctor.routes";
import { auth_router } from "./auth.routes";


const router = Router();
router.use("/users", user_router);
router.use("/doctors", doctor_router)
router.use("/auth", auth_router);

export default router;