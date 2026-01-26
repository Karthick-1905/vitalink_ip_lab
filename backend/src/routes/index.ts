import { Router } from "express";
import doctor_router from "./doctor.routes";
import auth_router from "./auth.routes";
import patient_router from "./patient.routes";
import admin_router from "./admin.routes";

const router = Router();

router.use("/admin", admin_router);
router.use("/doctors", doctor_router)
router.use("/auth", auth_router);
router.use("/patient", patient_router)

export default router;