import { Router } from "express";
import type { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";
import { requireAuth } from "../middleware/auth.js";

export const devicesRouter = Router();

devicesRouter.use(requireAuth);

const tokenSchema = z.object({
  token: z.string().min(10).max(255),
});

devicesRouter.post("/", async (req: Request, res: Response) => {
  const parsed = tokenSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "validation", details: parsed.error.flatten() });
    return;
  }
  const userId = req.user!.id;
  const existing = await prisma.deviceToken.findUnique({ where: { token: parsed.data.token } });
  if (existing) {
    if (existing.userId !== userId) {
      const moved = await prisma.deviceToken.update({
        where: { token: parsed.data.token },
        data: { userId },
      });
      res.status(200).json(moved);
      return;
    }
    res.status(200).json(existing);
    return;
  }
  const created = await prisma.deviceToken.create({
    data: { userId, token: parsed.data.token },
  });
  res.status(201).json(created);
});

devicesRouter.delete("/", async (req: Request, res: Response) => {
  const parsed = tokenSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "validation", details: parsed.error.flatten() });
    return;
  }
  await prisma.deviceToken.deleteMany({
    where: { userId: req.user!.id, token: parsed.data.token },
  });
  res.status(200).json({ ok: true });
});
