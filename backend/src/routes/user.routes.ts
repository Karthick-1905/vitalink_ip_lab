import { Router } from "express";

const user_router = Router();
user_router.get("/", (req, res) => {
    res.send("API is running...");
})


export default user_router;