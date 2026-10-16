import request from "supertest";
import { PrismaClient } from "@prisma/client";
import * as argon2 from "argon2";
import { createApp } from "../src/app.js";

const app = createApp();
const prisma = new PrismaClient();

const uniq = (prefix: string) => `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@test.com`;
const uniqKey = (prefix: string) => `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e9)}-key`;
const uniqSlug = (prefix: string) => `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e9)}`;

async function register() {
  const email = uniq("admprod-cust");
  const res = await request(app)
    .post("/api/v1/auth/register")
    .send({ email, password: "Password123!" });
  expect(res.status).toBe(201);
  return { email, accessToken: res.body.accessToken as string };
}

async function ensureAdminToken(): Promise<string> {
  const email = process.env.ADMIN_EMAIL ?? "admin@demo.com";
  const password = process.env.ADMIN_PASSWORD ?? "Demo1234!";
  const first = await request(app).post("/api/v1/auth/login").send({ email, password });
  if (first.status === 200 && first.body.accessToken) {
    return first.body.accessToken as string;
  }
  const passwordHash = await argon2.hash(password, { type: argon2.argon2id });
  await prisma.user.upsert({
    where: { email },
    update: { passwordHash, role: "admin" },
    create: { email, passwordHash, role: "admin" },
  });
  const second = await request(app).post("/api/v1/auth/login").send({ email, password });
  expect(second.status).toBe(200);
  return second.body.accessToken as string;
}

let adminToken = "";

beforeAll(async () => {
  adminToken = await ensureAdminToken();
});

async function createAddress(token: string) {
  const res = await request(app)
    .post("/api/v1/addresses")
    .set("Authorization", `Bearer ${token}`)
    .send({ line1: "House 7", city: "Dhaka", phone: "01700000007" });
  expect(res.status).toBe(201);
  return res.body;
}

async function cleanupOrderAndProduct(orderId: number | undefined, productIds: number[]) {
  if (orderId) {
    await prisma.payment.deleteMany({ where: { orderId } }).catch(() => {});
    await prisma.orderItem.deleteMany({ where: { orderId } }).catch(() => {});
    await prisma.order.delete({ where: { id: orderId } }).catch(() => {});
  }
  for (const pid of productIds) {
    await prisma.product.delete({ where: { id: pid } }).catch(() => {});
  }
}

describe("admin products list + safe delete", () => {
  test("GET /api/v1/admin/products returns 401 without token", async () => {
    const res = await request(app).get("/api/v1/admin/products");
    expect(res.status).toBe(401);
  });

  test("GET /api/v1/admin/products returns 403 for customer", async () => {
    const { accessToken } = await register();
    const res = await request(app)
      .get("/api/v1/admin/products")
      .set("Authorization", `Bearer ${accessToken}`);
    expect(res.status).toBe(403);
  });

  test("admin list includes inactive + exact shape + active filter", async () => {
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
    const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
    const active = await prisma.product.create({
      data: {
        name: `AdminList-Active-${suffix}`,
        slug: `adminlist-active-${suffix}`.toLowerCase(),
        description: "list active",
        priceBdt: 500,
        stock: 5,
        categoryId: cat.id,
        isActive: true,
      },
    });
    const inactive = await prisma.product.create({
      data: {
        name: `AdminList-Inactive-${suffix}`,
        slug: `adminlist-inactive-${suffix}`.toLowerCase(),
        description: "list inactive",
        priceBdt: 700,
        stock: 3,
        categoryId: cat.id,
        isActive: false,
      },
    });
    try {
      const res = await request(app)
        .get("/api/v1/admin/products")
        .query({ search: suffix, limit: 12 })
        .set("Authorization", `Bearer ${adminToken}`);
      expect(res.status).toBe(200);
      expect(res.body.page).toBe(1);
      expect(res.body.limit).toBe(12);
      expect(typeof res.body.total).toBe("number");
      expect(Array.isArray(res.body.items)).toBe(true);
      const ids = (res.body.items as Array<any>).map((p: any) => p.id);
      expect(ids).toContain(active.id);
      expect(ids).toContain(inactive.id);

      const item = (res.body.items as Array<any>).find((p: any) => p.id === active.id);
      expect(Object.keys(item).sort()).toEqual(
        ["category", "id", "imageUrl", "isActive", "name", "priceBdt", "slug", "stock"].sort(),
      );
      expect(item.category).toMatchObject({ slug: "clothing" });
      expect(typeof item.category.name).toBe("string");

      const onlyActive = await request(app)
        .get("/api/v1/admin/products")
        .query({ search: suffix, active: "true" })
        .set("Authorization", `Bearer ${adminToken}`);
      expect(onlyActive.status).toBe(200);
      const activeIds = (onlyActive.body.items as Array<any>).map((p: any) => p.id);
      expect(activeIds).toContain(active.id);
      expect(activeIds).not.toContain(inactive.id);

      const onlyInactive = await request(app)
        .get("/api/v1/admin/products")
        .query({ search: suffix, active: "false" })
        .set("Authorization", `Bearer ${adminToken}`);
      expect(onlyInactive.status).toBe(200);
      const inactiveIds = (onlyInactive.body.items as Array<any>).map((p: any) => p.id);
      expect(inactiveIds).not.toContain(active.id);
      expect(inactiveIds).toContain(inactive.id);
    } finally {
      await cleanupOrderAndProduct(undefined, [active.id, inactive.id]);
    }
  });

  test("admin list search filter narrows results", async () => {
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
    const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
    const target = await prisma.product.create({
      data: {
        name: `SearchTarget-${suffix}`,
        slug: `searchtarget-${suffix}`.toLowerCase(),
        description: "search me",
        priceBdt: 400,
        stock: 4,
        categoryId: cat.id,
        isActive: true,
      },
    });
    const other = await prisma.product.create({
      data: {
        name: `SearchOther-${suffix}-zzz`,
        slug: `searchother-${suffix}-zzz`.toLowerCase(),
        description: "other product",
        priceBdt: 400,
        stock: 4,
        categoryId: cat.id,
        isActive: true,
      },
    });
    try {
      const res = await request(app)
        .get("/api/v1/admin/products")
        .query({ search: `SearchTarget-${suffix}` })
        .set("Authorization", `Bearer ${adminToken}`);
      expect(res.status).toBe(200);
      const ids = (res.body.items as Array<any>).map((p: any) => p.id);
      expect(ids).toContain(target.id);
      expect(ids).not.toContain(other.id);
    } finally {
      await cleanupOrderAndProduct(undefined, [target.id, other.id]);
    }
  });

  test("hard delete unused product removes it (public GET 404 after)", async () => {
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
    const suffix = uniqSlug("admin-hard-del");
    const prod = await prisma.product.create({
      data: {
        name: `HardDel-${suffix}`,
        slug: suffix.toLowerCase(),
        description: "hard delete me",
        priceBdt: 900,
        stock: 6,
        categoryId: cat.id,
        isActive: true,
      },
    });
    try {
      const del = await request(app)
        .delete(`/api/v1/admin/products/${prod.id}`)
        .set("Authorization", `Bearer ${adminToken}`);
      expect(del.status).toBe(200);
      expect(del.body).toEqual({ deleted: true });

      const pub = await request(app).get(`/api/v1/products/${prod.id}`);
      expect(pub.status).toBe(404);

      const gone = await prisma.product.findUnique({ where: { id: prod.id } });
      expect(gone).toBeNull();
    } finally {
      await cleanupOrderAndProduct(undefined, [prod.id]);
    }
  });

  test("referenced product delete 409 + order still readable", async () => {
    const cust = await register();
    const addr = await createAddress(cust.accessToken);
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
    const suffix = uniqSlug("admin-ref-del");
    const prod = await prisma.product.create({
      data: {
        name: `RefDel-${suffix}`,
        slug: suffix.toLowerCase(),
        description: "referenced product",
        priceBdt: 800,
        stock: 20,
        categoryId: cat.id,
        isActive: true,
      },
    });
    let orderId = 0;
    try {
      const co = await request(app)
        .post("/api/v1/checkout")
        .set("Authorization", `Bearer ${cust.accessToken}`)
        .send({
          addressId: addr.id,
          items: [{ productId: prod.id, qty: 1 }],
          idempotencyKey: uniqKey("refdel"),
        });
      expect(co.status).toBe(201);
      orderId = co.body.id;

      const del = await request(app)
        .delete(`/api/v1/admin/products/${prod.id}`)
        .set("Authorization", `Bearer ${adminToken}`);
      expect(del.status).toBe(409);
      expect(del.body).toEqual({ error: "has_orders" });

      const detail = await request(app)
        .get(`/api/v1/orders/${orderId}`)
        .set("Authorization", `Bearer ${cust.accessToken}`);
      expect(detail.status).toBe(200);
      expect(detail.body.id).toBe(orderId);
    } finally {
      await cleanupOrderAndProduct(orderId, [prod.id]);
    }
  });

  test("delete bad id 404", async () => {
    const del = await request(app)
      .delete("/api/v1/admin/products/99999999")
      .set("Authorization", `Bearer ${adminToken}`);
    expect(del.status).toBe(404);
  });
});
