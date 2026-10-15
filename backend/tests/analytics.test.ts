import request from "supertest";
import { PrismaClient } from "@prisma/client";
import * as argon2 from "argon2";
import { createApp } from "../src/app.js";

const app = createApp();
const prisma = new PrismaClient();

const uniq = (prefix: string) => `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@test.com`;
const uniqKey = (prefix: string) => `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e9)}-key`;

async function register() {
  const email = uniq("analytics-cust");
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

describe("admin analytics", () => {
  test("GET /api/v1/admin/analytics returns 401 without token", async () => {
    const res = await request(app).get("/api/v1/admin/analytics");
    expect(res.status).toBe(401);
  });

  test("GET /api/v1/admin/analytics returns 403 for customer", async () => {
    const { accessToken } = await register();
    const res = await request(app)
      .get("/api/v1/admin/analytics")
      .set("Authorization", `Bearer ${accessToken}`);
    expect(res.status).toBe(403);
  });

  test("days=0/200/abc returns 400 with error", async () => {
    for (const q of ["?days=0", "?days=200", "?days=abc"]) {
      const res = await request(app)
        .get(`/api/v1/admin/analytics${q}`)
        .set("Authorization", `Bearer ${adminToken}`);
      expect(res.status).toBe(400);
      expect(res.body.error).toBeDefined();
    }
  });

  test("daily length matches days, default 14", async () => {
    const res = await request(app)
      .get("/api/v1/admin/analytics")
      .set("Authorization", `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.days).toBe(14);
    expect(Array.isArray(res.body.daily)).toBe(true);
    expect(res.body.daily).toHaveLength(14);
  });

  test("daily sums vs seeded orders exclude cancelled, top5 capped", async () => {
    const cust = await register();
    const addr = await createAddress(cust.accessToken);
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
    const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
    const prodA = await prisma.product.create({
      data: {
        name: `Analytics-A-${suffix}`,
        slug: `analytics-a-${suffix}`,
        description: "analytics a",
        priceBdt: 800,
        stock: 50,
        categoryId: cat.id,
        isActive: true,
      },
    });
    const prodB = await prisma.product.create({
      data: {
        name: `Analytics-B-${suffix}`,
        slug: `analytics-b-${suffix}`,
        description: "analytics b",
        priceBdt: 500,
        stock: 50,
        categoryId: cat.id,
        isActive: true,
      },
    });
    const days = 7;
    const orderIds: number[] = [];
    let expectedOrders = 0;
    let expectedRevenue = 0;
    try {
      const before = await request(app)
        .get(`/api/v1/admin/analytics?days=${days}`)
        .set("Authorization", `Bearer ${adminToken}`);
      expect(before.status).toBe(200);
      const beforeOrders = (before.body.daily as any[]).reduce((s, d) => s + d.orders, 0);
      const beforeRevenue = (before.body.daily as any[]).reduce((s, d) => s + d.revenue, 0);

      const co1 = await request(app)
        .post("/api/v1/checkout")
        .set("Authorization", `Bearer ${cust.accessToken}`)
        .send({
          addressId: addr.id,
          items: [{ productId: prodA.id, qty: 2 }],
          idempotencyKey: uniqKey("anlyt1"),
        });
      expect(co1.status).toBe(201);
      orderIds.push(co1.body.id);

      const co2 = await request(app)
        .post("/api/v1/checkout")
        .set("Authorization", `Bearer ${cust.accessToken}`)
        .send({
          addressId: addr.id,
          items: [{ productId: prodB.id, qty: 1 }],
          idempotencyKey: uniqKey("anlyt2"),
        });
      expect(co2.status).toBe(201);
      orderIds.push(co2.body.id);

      expectedOrders = 2;
      expectedRevenue = (co1.body.total as number) + (co2.body.total as number);

      const co3 = await request(app)
        .post("/api/v1/checkout")
        .set("Authorization", `Bearer ${cust.accessToken}`)
        .send({
          addressId: addr.id,
          items: [{ productId: prodA.id, qty: 1 }],
          idempotencyKey: uniqKey("anlyt3"),
        });
      expect(co3.status).toBe(201);
      orderIds.push(co3.body.id);
      const cancel = await request(app)
        .patch(`/api/v1/admin/orders/${co3.body.id}/status`)
        .set("Authorization", `Bearer ${adminToken}`)
        .send({ status: "cancelled" });
      expect(cancel.status).toBe(200);

      const after = await request(app)
        .get(`/api/v1/admin/analytics?days=${days}`)
        .set("Authorization", `Bearer ${adminToken}`);
      expect(after.status).toBe(200);
      expect(after.body.days).toBe(days);
      expect(after.body.daily).toHaveLength(days);
      for (const d of after.body.daily as any[]) {
        expect(typeof d.date).toBe("string");
        expect(typeof d.orders).toBe("number");
        expect(typeof d.revenue).toBe("number");
      }
      const afterOrders = (after.body.daily as any[]).reduce((s, d) => s + d.orders, 0);
      const afterRevenue = (after.body.daily as any[]).reduce((s, d) => s + d.revenue, 0);
      expect(afterOrders).toBe(beforeOrders + expectedOrders);
      expect(afterRevenue).toBe(beforeRevenue + expectedRevenue);

      expect(Array.isArray(after.body.topProducts)).toBe(true);
      expect(after.body.topProducts.length).toBeLessThanOrEqual(5);
      for (const p of after.body.topProducts as any[]) {
        expect(typeof p.id).toBe("number");
        expect(typeof p.name).toBe("string");
        expect(typeof p.qty).toBe("number");
        expect(typeof p.revenue).toBe("number");
      }
      const foundA = (after.body.topProducts as any[]).find((p) => p.id === prodA.id);
      expect(foundA).toBeDefined();
      expect(foundA.qty).toBeGreaterThanOrEqual(2);

      expect(typeof after.body.ordersByStatus).toBe("object");

      expect(Array.isArray(after.body.lowStock)).toBe(true);
      for (const p of after.body.lowStock as any[]) {
        expect(typeof p.id).toBe("number");
        expect(typeof p.name).toBe("string");
        expect(typeof p.stock).toBe("number");
        expect(p.stock).toBeLessThanOrEqual(5);
      }
    } finally {
      for (const oid of orderIds) {
        await prisma.payment.deleteMany({ where: { orderId: oid } }).catch(() => {});
        await prisma.orderItem.deleteMany({ where: { orderId: oid } }).catch(() => {});
        await prisma.order.delete({ where: { id: oid } }).catch(() => {});
      }
      await prisma.product.delete({ where: { id: prodA.id } }).catch(() => {});
      await prisma.product.delete({ where: { id: prodB.id } }).catch(() => {});
    }
  });

  test("lowStock lists only active products ascending", async () => {
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
    const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
    const active = await prisma.product.create({
      data: {
        name: `Analytics-Low-Active-${suffix}`,
        slug: `analytics-low-active-${suffix}`,
        description: "low active",
        priceBdt: 100,
        stock: 2,
        categoryId: cat.id,
        isActive: true,
      },
    });
    const inactive = await prisma.product.create({
      data: {
        name: `Analytics-Low-Inactive-${suffix}`,
        slug: `analytics-low-inactive-${suffix}`,
        description: "low inactive",
        priceBdt: 100,
        stock: 1,
        categoryId: cat.id,
        isActive: false,
      },
    });
    try {
      const res = await request(app)
        .get("/api/v1/admin/analytics?days=7")
        .set("Authorization", `Bearer ${adminToken}`);
      expect(res.status).toBe(200);
      const low = res.body.lowStock as Array<any>;
      const ids = low.map((p: any) => p.id);
      expect(ids).toContain(active.id);
      expect(ids).not.toContain(inactive.id);
      const stocks = low.map((p: any) => p.stock);
      expect([...stocks].sort((a, b) => a - b)).toEqual(stocks);
    } finally {
      await prisma.product.delete({ where: { id: active.id } }).catch(() => {});
      await prisma.product.delete({ where: { id: inactive.id } }).catch(() => {});
    }
  });
});
