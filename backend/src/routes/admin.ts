import { Router } from "express";
import type { Request, Response } from "express";
import { z } from "zod";
import { prisma } from "../lib/prisma.js";
import { requireAdmin, requireAuth } from "../middleware/auth.js";

export const adminRouter = Router();

adminRouter.use(requireAuth, requireAdmin);

function slugify(input: string): string {
  const base = input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .replace(/-+/g, "-");
  return base || `product-${Date.now()}`;
}

async function uniqueSlug(candidate: string): Promise<string> {
  let slug = candidate;
  let n = 0;
  for (;;) {
    const existing = await prisma.product.findUnique({ where: { slug } });
    if (!existing) return slug;
    n += 1;
    slug = `${candidate}-${Date.now().toString(36)}-${n}`;
    if (n > 5) {
      slug = `${candidate}-${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
      const retry = await prisma.product.findUnique({ where: { slug } });
      if (!retry) return slug;
    }
  }
}

const imageUrlSchema = z.string().url().or(z.literal("")).optional();

const productCreateSchema = z.object({
  name: z.string().min(1),
  slug: z.string().min(1).optional(),
  categoryId: z.number().int().positive(),
  description: z.string().optional().default(""),
  priceBdt: z.number().int().min(1),
  stock: z.number().int().min(0).optional().default(0),
  imageUrl: imageUrlSchema,
  isActive: z.boolean().optional().default(true),
});

const productPatchSchema = productCreateSchema.partial();

const orderStatusSchema = z.object({
  status: z.enum(["pending", "confirmed", "shipped", "delivered", "cancelled"]),
});

adminRouter.get("/dashboard", async (_req: Request, res: Response) => {
  const [users, products, activeProducts, grouped, lowStockItems, revenueAgg] = await Promise.all([
    prisma.user.count(),
    prisma.product.count(),
    prisma.product.count({ where: { isActive: true } }),
    prisma.order.groupBy({ by: ["status"], _count: { status: true } }),
    prisma.product.findMany({
      where: { stock: { lte: 5 }, isActive: true },
      orderBy: { stock: "asc" },
      take: 20,
      select: { id: true, name: true, slug: true, stock: true, priceBdt: true, isActive: true },
    }),
    prisma.order.aggregate({ where: { status: { not: "cancelled" } }, _sum: { total: true } }),
  ]);

  const ordersByStatus: Record<string, number> = {};
  for (const g of grouped) {
    ordersByStatus[g.status] = g._count.status;
  }

  const revenue = revenueAgg._sum.total ?? 0;

  res.status(200).json({
    users,
    products,
    activeProducts,
    ordersByStatus,
    orders: ordersByStatus,
    lowStock: lowStockItems,
    lowStockCount: lowStockItems.length,
    revenue,
    totalRevenue: revenue,
  });
});

adminRouter.post("/products", async (req: Request, res: Response) => {
  const parsed = productCreateSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "validation", details: parsed.error.flatten() });
    return;
  }
  const { name, categoryId, description, priceBdt, stock, imageUrl, isActive } = parsed.data;
  let slug = parsed.data.slug?.trim();
  if (!slug) {
    slug = await uniqueSlug(slugify(name));
  } else {
    const existing = await prisma.product.findUnique({ where: { slug } });
    if (existing) {
      res.status(409).json({ error: "slug already exists" });
      return;
    }
  }

  const category = await prisma.category.findUnique({ where: { id: categoryId } });
  if (!category) {
    res.status(400).json({ error: "category not found" });
    return;
  }

  const created = await prisma.product.create({
    data: {
      name,
      slug,
      categoryId,
      description: description ?? "",
      priceBdt,
      stock: stock ?? 0,
      imageUrl: !imageUrl ? null : imageUrl,
      isActive: isActive ?? true,
    },
  });
  res.status(201).json(created);
});

adminRouter.patch("/products/:id", async (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1) {
    res.status(404).json({ error: "not found" });
    return;
  }
  const parsed = productPatchSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "validation", details: parsed.error.flatten() });
    return;
  }
  const existing = await prisma.product.findUnique({ where: { id } });
  if (!existing) {
    res.status(404).json({ error: "not found" });
    return;
  }

  if (parsed.data.categoryId !== undefined) {
    const category = await prisma.category.findUnique({ where: { id: parsed.data.categoryId } });
    if (!category) {
      res.status(400).json({ error: "category not found" });
      return;
    }
  }

  if (parsed.data.slug !== undefined) {
    const slug = parsed.data.slug.trim();
    if (!slug) {
      res.status(400).json({ error: "validation", details: "slug must not be empty" });
      return;
    }
    const clash = await prisma.product.findUnique({ where: { slug } });
    if (clash && clash.id !== id) {
      res.status(409).json({ error: "slug already exists" });
      return;
    }
  }

  const data: any = {};
  if (parsed.data.name !== undefined) data.name = parsed.data.name;
  if (parsed.data.slug !== undefined) data.slug = parsed.data.slug.trim();
  if (parsed.data.categoryId !== undefined) data.categoryId = parsed.data.categoryId;
  if (parsed.data.description !== undefined) data.description = parsed.data.description;
  if (parsed.data.priceBdt !== undefined) data.priceBdt = parsed.data.priceBdt;
  if (parsed.data.stock !== undefined) data.stock = parsed.data.stock;
  if (parsed.data.imageUrl !== undefined) data.imageUrl = !parsed.data.imageUrl ? null : parsed.data.imageUrl;
  if (parsed.data.isActive !== undefined) data.isActive = parsed.data.isActive;

  const updated = await prisma.product.update({ where: { id }, data });
  res.status(200).json(updated);
});

adminRouter.delete("/products/:id", async (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1) {
    res.status(404).json({ error: "not found" });
    return;
  }
  const existing = await prisma.product.findUnique({ where: { id } });
  if (!existing) {
    res.status(404).json({ error: "not found" });
    return;
  }
  const updated = await prisma.product.update({ where: { id }, data: { isActive: false } });
  res.status(200).json(updated);
});

adminRouter.get("/orders", async (req: Request, res: Response) => {
  let page = Number(req.query.page ?? 1);
  let limit = Number(req.query.limit ?? 20);
  if (!Number.isFinite(page) || page < 1) page = 1;
  if (!Number.isFinite(limit) || limit < 1) limit = 20;
  page = Math.floor(page);
  limit = Math.floor(limit);
  if (limit > 100) limit = 100;

  const [total, items] = await Promise.all([
    prisma.order.count(),
    prisma.order.findMany({
      orderBy: { id: "desc" },
      skip: (page - 1) * limit,
      take: limit,
      include: {
        items: true,
        payment: true,
        user: { select: { id: true, email: true } },
      },
    }),
  ]);
  res.status(200).json({ items, page, limit, total });
});

adminRouter.patch("/orders/:id/status", async (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1) {
    res.status(404).json({ error: "not found" });
    return;
  }
  const parsed = orderStatusSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "validation", details: parsed.error.flatten() });
    return;
  }
  const existing = await prisma.order.findUnique({ where: { id } });
  if (!existing) {
    res.status(404).json({ error: "not found" });
    return;
  }
  const updated = await prisma.order.update({
    where: { id },
    data: { status: parsed.data.status },
    include: {
      items: true,
      payment: true,
      user: { select: { id: true, email: true } },
    },
  });
  res.status(200).json(updated);
});
