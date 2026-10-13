import { Router } from "express";
import type { Request, Response } from "express";
import { prisma } from "../lib/prisma.js";

export const catalogRouter = Router();

catalogRouter.get("/categories", async (_req: Request, res: Response) => {
  const categories = await prisma.category.findMany({
    orderBy: { sort: "asc" },
    select: { id: true, name: true, slug: true, icon: true },
  });
  res.status(200).json(categories);
});

catalogRouter.get("/products", async (req: Request, res: Response) => {
  const search = typeof req.query.search === "string" ? req.query.search.trim() : "";
  const categorySlug = typeof req.query.category === "string" ? req.query.category.trim() : "";

  let page = Number(req.query.page ?? 1);
  let limit = Number(req.query.limit ?? 12);
  if (!Number.isFinite(page) || page < 1) page = 1;
  if (!Number.isFinite(limit) || limit < 1) limit = 12;
  page = Math.floor(page);
  limit = Math.floor(limit);
  if (limit > 50) limit = 50;

  const where: any = { isActive: true };
  if (categorySlug) {
    where.category = { slug: categorySlug };
  }
  if (search) {
    where.OR = [
      { name: { contains: search } },
      { description: { contains: search } },
      { slug: { contains: search } },
    ];
  }

  const [total, items] = await Promise.all([
    prisma.product.count({ where }),
    prisma.product.findMany({
      where,
      orderBy: { id: "asc" },
      skip: (page - 1) * limit,
      take: limit,
      include: { category: { select: { slug: true, name: true } } },
    }),
  ]);

  res.status(200).json({ items, page, limit, total });
});

catalogRouter.get("/products/:id", async (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1) {
    res.status(404).json({ error: "not found" });
    return;
  }
  const product = await prisma.product.findFirst({
    where: { id, isActive: true },
    include: { category: { select: { slug: true, name: true } } },
  });
  if (!product) {
    res.status(404).json({ error: "not found" });
    return;
  }
  res.status(200).json(product);
});
