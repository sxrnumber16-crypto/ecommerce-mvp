import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { createApp } from "../src/app.js";

const app = createApp();
const prisma = new PrismaClient();

describe("catalog", () => {
  test("GET /api/v1/categories returns 6 sorted with id/name/slug/icon", async () => {
    const res = await request(app).get("/api/v1/categories");
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBe(6);
    for (const c of res.body) {
      expect(c).toHaveProperty("id");
      expect(c).toHaveProperty("name");
      expect(c).toHaveProperty("slug");
      expect(c).toHaveProperty("icon");
    }
    // sorted by sort asc: clothing first, others last (seed order)
    expect(res.body[0].slug).toBe("clothing");
    expect(res.body[5].slug).toBe("others");
  });

  test("GET /api/v1/products list paginated with total", async () => {
    const res = await request(app).get("/api/v1/products");
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty("items");
    expect(res.body).toHaveProperty("page", 1);
    expect(res.body).toHaveProperty("limit", 12);
    expect(res.body).toHaveProperty("total");
    expect(Array.isArray(res.body.items)).toBe(true);
    expect(res.body.total).toBeGreaterThanOrEqual(8);
    expect(res.body.items.length).toBeLessThanOrEqual(12);
    for (const p of res.body.items) {
      expect(p).toHaveProperty("id");
      expect(p).toHaveProperty("name");
      expect(p.category).toHaveProperty("slug");
      expect(p.category).toHaveProperty("name");
    }
  });

  test("GET /api/v1/products search filters", async () => {
    const uniq = `SearchMe-${Date.now()}`;
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
    const created = await prisma.product.create({
      data: {
        name: uniq,
        slug: `searchme-${Date.now()}`,
        description: "search target",
        priceBdt: 999,
        stock: 5,
        categoryId: cat.id,
        isActive: true,
      },
    });
    try {
      const res = await request(app).get("/api/v1/products").query({ search: uniq });
      expect(res.status).toBe(200);
      expect(res.body.total).toBeGreaterThanOrEqual(1);
      expect(res.body.items.length).toBeGreaterThanOrEqual(1);
      expect(res.body.items.some((p: any) => p.id === created.id)).toBe(true);
    } finally {
      await prisma.product.delete({ where: { id: created.id } });
    }
  });

  test("GET /api/v1/products category filter works", async () => {
    const res = await request(app).get("/api/v1/products").query({ category: "clothing" });
    expect(res.status).toBe(200);
    expect(res.body.total).toBeGreaterThanOrEqual(1);
    for (const p of res.body.items) {
      expect(p.category.slug).toBe("clothing");
    }
  });

  test("inactive products hidden from list and detail", async () => {
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
    const created = await prisma.product.create({
      data: {
        name: `Inactive-${Date.now()}`,
        slug: `inactive-${Date.now()}`,
        description: "hidden",
        priceBdt: 100,
        stock: 1,
        categoryId: cat.id,
        isActive: false,
      },
    });
    try {
      const list = await request(app).get("/api/v1/products").query({ limit: 50 });
      expect(list.status).toBe(200);
      expect(list.body.items.some((p: any) => p.id === created.id)).toBe(false);
      const detail = await request(app).get(`/api/v1/products/${created.id}`);
      expect(detail.status).toBe(404);
    } finally {
      await prisma.product.delete({ where: { id: created.id } });
    }
  });

  test("GET /api/v1/products/:id returns priceBdt/stock with category", async () => {
    const list = await request(app).get("/api/v1/products").query({ limit: 1 });
    expect(list.status).toBe(200);
    const id = list.body.items[0].id;
    const res = await request(app).get(`/api/v1/products/${id}`);
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty("priceBdt");
    expect(res.body).toHaveProperty("stock");
    expect(res.body).toHaveProperty("category");
    expect(res.body.category).toHaveProperty("slug");
  });

  test("GET /api/v1/products/invalid returns 404", async () => {
    const res = await request(app).get("/api/v1/products/invalid");
    expect(res.status).toBe(404);
  });
});
