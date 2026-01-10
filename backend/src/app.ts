import express from "express";
import router from "./routes";



const app = express(); 

app.use(express.json())

app.get("/", (req, res) => {
    res.send("Welcome to the API");
});

app.use("/api", router);


export default app;