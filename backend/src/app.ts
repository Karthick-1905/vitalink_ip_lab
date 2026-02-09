import express from "express";
import helmet from "helmet";
import limiter from "./config/ratelimiter";
import router from "./routes";
import errorHandler from "./middlewares/errorHandler";
import { ApiResponse } from "./utils";
import { StatusCodes } from "http-status-codes";
import morgan from "morgan";
import logger from "./utils/logger";
import cors from "cors";
import connectDB from "./config/db";

const app = express();

console.log("Backend: App initializing...");
connectDB();
console.log("Backend: Database connection initiated.");

app.use(morgan('dev', {
  stream: {
    write: message => {
      logger.info(message.trim());
    }
  }
}));

app.use(helmet());
app.use(limiter);

app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  optionsSuccessStatus: 204,
}));

app.use(express.json());

app.get("/health-check", (req, res) => {
  console.log("Backend: Health check endpoint hit");
  return res.json(new ApiResponse(StatusCodes.OK, "Welcome to the API"))
});

app.use("/api", router);
app.use(errorHandler);

export default app;
