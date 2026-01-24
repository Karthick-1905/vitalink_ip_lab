import express from "express";
import helmet from "helmet";
import limiter from "./config/ratelimiter";
import router from "./routes";

const app = express();

// Security middleware
app.use(helmet());
app.use(limiter);

// Body parsing middleware
app.use(express.json());

// Health check endpoint
app.get("/", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Welcome to VitaLink API",
    status: "Server is running",
  });
});

// API routes
app.use("/api", router);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "Route not found",
    path: req.path,
  });
});

// Global error handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error("Error:", err);

  res.status(err.statusCode || 500).json({
    success: false,
    message: err.message || "Internal server error",
    ...(process.env.NODE_ENV === "development" && { error: err }),
  });
});

export default app;