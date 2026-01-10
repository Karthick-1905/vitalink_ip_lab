import { Router } from "express";
import user_router from "./user.routes";
import doctor_router from "./doctor.routes";


const router = Router();
router.use("/users", user_router);
router.use("/doctors", doctor_router)

export default router;