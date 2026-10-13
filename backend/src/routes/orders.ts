import { Router } from "express";
import type { Request, Response } from "express";
import { prisma } from "../lib/prisma.js";
import { requireAuth } from "../middleware/auth.js";

export const ordersRouter = Router();

ordersRouter.use(requireAuth);

ordersRouter.get("/orders", async (req: Request, res: Response) => {
  const orders = await prisma.order.findMany({
    where: { userId: req.user!.id },
    orderBy: { id: "desc" },
    include: {
      items: true,
      payment: true,
      _count: { select: { items: true } },
    },
  });
  res.status(200).json(orders);
});

ordersRouter.get("/orders/:id", async (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1) {
    res.status(404).json({ error: "not found" });
    return;
  }
  const order = await prisma.order.findFirst({
    where: { id, userId: req.user!.id },
    include: { items: true, payment: true, address: true },
  });
  if (!order) {
    res.status(404).json({ error: "not found" });
    return;
  }
  res.status(200).json(order);
});
