import { Router } from "express";
import type { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";
import { requireAuth } from "../middleware/auth.js";

export const profileRouter = Router();

profileRouter.use(requireAuth);

profileRouter.get("/profile", async (req: Request, res: Response) => {
  const user = await prisma.user.findUnique({ where: { id: req.user!.id } });
  if (!user) {
    res.status(401).json({ error: "unauthorized" });
    return;
  }
  const profile = await prisma.customerProfile.upsert({
    where: { userId: user.id },
    update: {},
    create: { userId: user.id },
  });
  res.status(200).json({
    user: { id: user.id, email: user.email, role: user.role },
    profile,
  });
});

const patchProfileSchema = z.object({
  fullName: z.string().min(1).optional(),
  phone: z.string().optional(),
});

profileRouter.patch("/profile", async (req: Request, res: Response) => {
  const parsed = patchProfileSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "validation", details: parsed.error.flatten() });
    return;
  }
  const user = await prisma.user.findUnique({ where: { id: req.user!.id } });
  if (!user) {
    res.status(401).json({ error: "unauthorized" });
    return;
  }
  const data: { fullName?: string; phone?: string } = {};
  if (parsed.data.fullName !== undefined) data.fullName = parsed.data.fullName;
  if (parsed.data.phone !== undefined) data.phone = parsed.data.phone;
  const profile = await prisma.customerProfile.upsert({
    where: { userId: user.id },
    update: data,
    create: { userId: user.id, ...data },
  });
  res.status(200).json(profile);
});

profileRouter.get("/addresses", async (req: Request, res: Response) => {
  const addresses = await prisma.address.findMany({
    where: { userId: req.user!.id },
    orderBy: [{ isDefault: "desc" }, { id: "asc" }],
  });
  res.status(200).json(addresses);
});

const createAddressSchema = z.object({
  label: z.string().default("home"),
  line1: z.string().min(1),
  city: z.string().min(1),
  postal: z.string().optional(),
  phone: z.string().min(1),
  isDefault: z.boolean().optional(),
});

profileRouter.post("/addresses", async (req: Request, res: Response) => {
  const parsed = createAddressSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "validation", details: parsed.error.flatten() });
    return;
  }
  const userId = req.user!.id;
  const { label, line1, city, postal, phone, isDefault } = parsed.data;

  if (isDefault === true) {
    const created = await prisma.$transaction(async (tx) => {
      await tx.address.updateMany({ where: { userId }, data: { isDefault: false } });
      return tx.address.create({
        data: { userId, label, line1, city, postal: postal ?? null, phone, isDefault: true },
      });
    });
    res.status(201).json(created);
    return;
  }

  const created = await prisma.address.create({
    data: {
      userId,
      label,
      line1,
      city,
      postal: postal ?? null,
      phone,
      isDefault: false,
    },
  });
  res.status(201).json(created);
});
