import { Router } from "express";
import type { Request, Response } from "express";
import { z } from "zod";
import { config } from "../config.js";
import { prisma } from "../lib/prisma.js";
import { CodProvider } from "../lib/payments.js";
import { requireAuth } from "../middleware/auth.js";

export const checkoutRouter = Router();

checkoutRouter.use(requireAuth);

const checkoutSchema = z.object({
  addressId: z.number().int().positive(),
  items: z
    .array(
      z.object({
        productId: z.number().int().positive(),
        qty: z.number().int().min(1).max(10),
      }),
    )
    .min(1),
  idempotencyKey: z.string().min(8),
});

class InsufficientStockError extends Error {
  insufficient: Array<{ productId: number; available: number }>;
  constructor(insufficient: Array<{ productId: number; available: number }>) {
    super("insufficient stock");
    this.insufficient = insufficient;
  }
}

const orderInclude = { items: true, payment: true } as const;

checkoutRouter.post("/checkout", async (req: Request, res: Response) => {
  const parsed = checkoutSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "validation", details: parsed.error.flatten() });
    return;
  }
  const userId = req.user!.id;
  const { addressId, items, idempotencyKey } = parsed.data;

  try {
    const result = await prisma.$transaction(async (tx) => {
      const existing = await tx.order.findUnique({
        where: { idempotencyKey },
        include: orderInclude,
      });
      if (existing) {
        if (existing.userId !== userId) {
          const err: any = new Error("idempotency key in use");
          err.code = "IDEMPOTENCY_CONFLICT";
          throw err;
        }
        const err: any = new Error("idempotent replay");
        err.code = "IDEMPOTENT_REPLAY";
        err.order = existing;
        throw err;
      }

      const address = await tx.address.findUnique({ where: { id: addressId } });
      if (!address) {
        const err: any = new Error("address not found");
        err.code = "ADDRESS_NOT_FOUND";
        throw err;
      }
      if (address.userId !== userId) {
        const err: any = new Error("forbidden");
        err.code = "ADDRESS_FORBIDDEN";
        throw err;
      }

      const ids = [...new Set(items.map((i) => i.productId))];
      const products = await tx.product.findMany({ where: { id: { in: ids } } });
      const byId = new Map(products.map((p) => [p.id, p]));

      const insufficient: Array<{ productId: number; available: number }> = [];
      for (const item of items) {
        const p = byId.get(item.productId);
        if (!p || !p.isActive) {
          const err: any = new Error("product not found");
          err.code = "PRODUCT_NOT_FOUND";
          err.productId = item.productId;
          throw err;
        }
        if (item.qty > p.stock) {
          insufficient.push({ productId: item.productId, available: p.stock });
        }
      }
      if (insufficient.length > 0) {
        throw new InsufficientStockError(insufficient);
      }

      let subtotal = 0;
      const itemsData = items.map((item) => {
        const p = byId.get(item.productId)!;
        const unitPrice = p.priceBdt;
        const lineTotal = unitPrice * item.qty;
        subtotal += lineTotal;
        return {
          productId: p.id,
          name: p.name,
          unitPrice,
          qty: item.qty,
          lineTotal,
        };
      });

      const deliveryFee = config.deliveryFeeBdt;
      const total = subtotal + deliveryFee;

      // COD-only wiring: derive unpaid status from CodProvider (never bKash/Nagad).
      const cod = new CodProvider();
      const init = await cod.create({ orderId: 0, amount: total });

      const created = await tx.order.create({
        data: {
          userId,
          addressId,
          subtotal,
          deliveryFee,
          total,
          status: "pending",
          idempotencyKey,
          items: { create: itemsData },
          payment: {
            create: { method: "COD", status: init.status, amount: total },
          },
        },
        include: orderInclude,
      });

      for (const item of items) {
        const updated = await tx.product.updateMany({
          where: { id: item.productId, stock: { gte: item.qty } },
          data: { stock: { decrement: item.qty } },
        });
        if (updated.count !== 1) {
          const current = await tx.product.findUnique({ where: { id: item.productId } });
          throw new InsufficientStockError([
            { productId: item.productId, available: current?.stock ?? 0 },
          ]);
        }
      }

      return { order: created, replay: false };
    });

    res.status(201).json(result.order);
  } catch (err: any) {
    if (err?.code === "IDEMPOTENT_REPLAY" && err.order) {
      res.status(200).json(err.order);
      return;
    }
    if (err?.code === "IDEMPOTENCY_CONFLICT") {
      res.status(409).json({ error: "idempotency key in use" });
      return;
    }
    if (err?.code === "ADDRESS_NOT_FOUND") {
      res.status(404).json({ error: "address not found" });
      return;
    }
    if (err?.code === "ADDRESS_FORBIDDEN") {
      res.status(403).json({ error: "forbidden" });
      return;
    }
    if (err?.code === "PRODUCT_NOT_FOUND") {
      res.status(404).json({ error: "product not found", productId: err.productId });
      return;
    }
    if (err instanceof InsufficientStockError) {
      res.status(409).json({ error: "insufficient stock", insufficient: err.insufficient });
      return;
    }
    // Prisma unique race on idempotencyKey (concurrent duplicate): return existing for same user.
    if (err?.code === "P2002") {
      const existing = await prisma.order.findUnique({
        where: { idempotencyKey },
        include: orderInclude,
      });
      if (existing && existing.userId === userId) {
        res.status(200).json(existing);
        return;
      }
      res.status(409).json({ error: "idempotency key in use" });
      return;
    }
    throw err;
  }
});
