import cors from "cors";
import express from "express";
import type { NextFunction, Request, Response } from "express";
import helmet from "helmet";
import { authRouter } from "./routes/auth.js";
import { catalogRouter } from "./routes/products.js";
import { profileRouter } from "./routes/profile.js";
import { checkoutRouter } from "./routes/checkout.js";
import { ordersRouter } from "./routes/orders.js";
import { adminRouter } from "./routes/admin.js";
import { devicesRouter } from "./routes/devices.js";

export function createApp() {
  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use(express.json());

  app.get("/health", (_req, res) => {
    res.status(200).json({ status: "ok" });
  });

  // Later tasks mount /api/v1 routers here (auth/catalog/checkout/admin).
  app.use("/api/v1/auth", authRouter);
  app.use("/api/v1", catalogRouter);
  app.use("/api/v1", profileRouter);
  app.use("/api/v1", checkoutRouter);
  app.use("/api/v1", ordersRouter);
  app.use("/api/v1/admin", adminRouter);
  app.use("/api/v1/devices", devicesRouter);

  // JSON error handler (must stay after routes; keeps GET /health intact).
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    console.error(err);
    res.status(500).json({ error: "internal error" });
  });

  return app;
}
