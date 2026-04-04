import { Router } from "express";
import doctor_router from "./doctor.routes";
import auth_router from "./auth.routes";
import patient_router from "./patient.routes";
import admin_router from "./admin.routes";
import statistics_router from "./statistics.routes";
import payment_router from "./payment.routes";

const router = Router();

router.use("/doctors", doctor_router)
router.use("/auth", auth_router);
router.use("/patient", patient_router)
router.use("/admin", admin_router)
router.use("/statistics", statistics_router)
router.use("/payments", payment_router)

export default router;