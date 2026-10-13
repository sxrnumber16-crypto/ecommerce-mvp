import cors from "cors";
import express from "express";
import helmet from "helmet";

export function createApp() {
  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use(express.json());

  app.get("/health", (_req, res) => {
    res.status(200).json({ status: "ok" });
  });

  // Later tasks mount /api/v1 routers here (auth/catalog/checkout/admin).

  return app;
}
