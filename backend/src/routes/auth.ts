import { createHash } from "node:crypto";
import { Router } from "express";
import type { Request, Response } from "express";
import rateLimit from "express-rate-limit";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";
import { hashPassword, verifyPassword } from "../lib/password.js";
import { signAccessToken, signRefreshToken, verifyRefreshToken } from "../lib/jwt.js";
import { requireAuth } from "../middleware/auth.js";

export function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

function refreshExpiresAt(): Date {
  return new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
}

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  fullName: z.string().min(1).optional(),
  phone: z.string().optional(),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

const logoutSchema = z.object({
  refreshToken: z.string().min(1).optional(),
});

const loginLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
});

export const authRouter = Router();

authRouter.post("/register", async (req: Request, res: Response) => {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "validation", details: parsed.error.flatten() });
    return;
  }
  const { email, password, fullName, phone } = parsed.data;

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    res.status(409).json({ error: "email already registered" });
    return;
  }

  const passwordHash = await hashPassword(password);
  // Public register is always customer — any `role` in body is ignored (zod strips it).
  const user = await prisma.user.create({
    data: {
      email,
      passwordHash,
      role: "customer",
      ...(fullName !== undefined || phone !== undefined
        ? { profile: { create: { fullName: fullName ?? null, phone: phone ?? null } } }
        : {}),
    },
  });

  const refreshToken = signRefreshToken(user.id);
  await prisma.refreshSession.create({
    data: { userId: user.id, tokenHash: hashToken(refreshToken), expiresAt: refreshExpiresAt() },
  });
  const accessToken = signAccessToken(user.id, user.role);

  res.status(201).json({
    user: { id: user.id, email: user.email, role: user.role },
    accessToken,
    refreshToken,
  });
});

authRouter.post("/login", loginLimiter, async (req: Request, res: Response) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "validation", details: parsed.error.flatten() });
    return;
  }
  const { email, password } = parsed.data;

  const user = await prisma.user.findUnique({ where: { email } });
  if (!user || !(await verifyPassword(user.passwordHash, password))) {
    res.status(401).json({ error: "invalid credentials" });
    return;
  }

  const refreshToken = signRefreshToken(user.id);
  await prisma.refreshSession.create({
    data: { userId: user.id, tokenHash: hashToken(refreshToken), expiresAt: refreshExpiresAt() },
  });
  const accessToken = signAccessToken(user.id, user.role);

  res.status(200).json({
    user: { id: user.id, email: user.email, role: user.role },
    accessToken,
    refreshToken,
  });
});

authRouter.post("/refresh", async (req: Request, res: Response) => {
  const parsed = refreshSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "validation", details: parsed.error.flatten() });
    return;
  }
  let userId: number;
  try {
    userId = verifyRefreshToken(parsed.data.refreshToken).sub;
  } catch {
    res.status(401).json({ error: "invalid refresh token" });
    return;
  }

  const tokenHash = hashToken(parsed.data.refreshToken);
  const session = await prisma.refreshSession.findUnique({ where: { tokenHash } });
  if (!session || session.revokedAt !== null || session.expiresAt <= new Date() || session.userId !== userId) {
    res.status(401).json({ error: "invalid refresh token" });
    return;
  }

  await prisma.refreshSession.update({
    where: { tokenHash },
    data: { revokedAt: new Date() },
  });

  const user = await prisma.user.findUnique({ where: { id: session.userId } });
  if (!user) {
    res.status(401).json({ error: "invalid refresh token" });
    return;
  }

  const nextRefresh = signRefreshToken(user.id);
  await prisma.refreshSession.create({
    data: { userId: user.id, tokenHash: hashToken(nextRefresh), expiresAt: refreshExpiresAt() },
  });
  const accessToken = signAccessToken(user.id, user.role);

  res.status(200).json({
    user: { id: user.id, email: user.email, role: user.role },
    accessToken,
    refreshToken: nextRefresh,
  });
});

authRouter.post("/logout", async (req: Request, res: Response) => {
  const parsed = logoutSchema.safeParse(req.body ?? {});
  if (!parsed.success) {
    res.status(400).json({ error: "validation", details: parsed.error.flatten() });
    return;
  }
  let candidate: string | undefined = parsed.data.refreshToken;
  if (!candidate) {
    const header = req.headers.authorization;
    if (header && header.startsWith("Bearer ")) {
      candidate = header.slice("Bearer ".length).trim() || undefined;
    }
  }
  if (!candidate) {
    res.status(400).json({ error: "refreshToken required" });
    return;
  }
  await prisma.refreshSession.updateMany({
    where: { tokenHash: hashToken(candidate), revokedAt: null },
    data: { revokedAt: new Date() },
  });
  res.status(200).json({ ok: true });
});

authRouter.get("/me", requireAuth, async (req: Request, res: Response) => {
  const user = await prisma.user.findUnique({ where: { id: req.user!.id } });
  if (!user) {
    res.status(401).json({ error: "unauthorized" });
    return;
  }
  res.status(200).json({ id: user.id, email: user.email, role: user.role });
});
