import request from "supertest";
import { PrismaClient } from "@prisma/client";
import * as argon2 from "argon2";
import { createApp } from "../src/app.js";

const app = createApp();
const prisma = new PrismaClient();

const uniq = (prefix: string) => `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@test.com`;
const uniqKey = (prefix: string) => `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e9)}-key`;

async function register() {
  const email = uniq("adm-cust");
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

describe("admin", () => {
  test("GET /api/v1/admin/dashboard returns 401 without token", async () => {
    const res = await request(app).get("/api/v1/admin/dashboard");
    expect(res.status).toBe(401);
  });

  test("GET /api/v1/admin/dashboard returns 403 for customer", async () => {
    const { accessToken } = await register();
    const res = await request(app)
      .get("/api/v1/admin/dashboard")
      .set("Authorization", `Bearer ${accessToken}`);
    expect(res.status).toBe(403);
  });

  test("admin dashboard 200 shape", async () => {
    const res = await request(app)
      .get("/api/v1/admin/dashboard")
      .set("Authorization", `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(typeof res.body.users).toBe("number");
    expect(typeof res.body.products).toBe("number");
    expect(typeof res.body.activeProducts).toBe("number");
    const byStatus = res.body.ordersByStatus ?? res.body.orders;
    expect(byStatus).toBeDefined();
    expect(typeof byStatus).toBe("object");
    expect(res.body.lowStock !== undefined).toBe(true);
    expect(res.body.revenue !== undefined || res.body.totalRevenue !== undefined).toBe(true);
  });

  test("product create/edit/deactivate + public hidden after deactivate", async () => {
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
    const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
    const name = `Admin-Prod-${suffix}`;

    const created = await request(app)
      .post("/api/v1/admin/products")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        name,
        categoryId: cat.id,
        description: "admin test product",
        priceBdt: 1500,
        stock: 10,
        imageUrl: "",
        isActive: true,
      });
    expect(created.status).toBe(201);
    const pid = created.body.id as number;
    expect(created.body.slug).toBeDefined();
    try {
      const patched = await request(app)
        .patch(`/api/v1/admin/products/${pid}`)
        .set("Authorization", `Bearer ${adminToken}`)
        .send({ priceBdt: 1750, stock: 8 });
      expect(patched.status).toBe(200);
      expect(patched.body.priceBdt).toBe(1750);

      const deactivated = await request(app)
        .delete(`/api/v1/admin/products/${pid}`)
        .set("Authorization", `Bearer ${adminToken}`);
      expect([200, 204]).toContain(deactivated.status);

      const pub = await request(app).get(`/api/v1/products/${pid}`);
      expect(pub.status).toBe(404);
    } finally {
      const orders = await prisma.order.findMany({ where: { items: { some: { productId: pid } } } });
      for (const o of orders) {
        await prisma.payment.deleteMany({ where: { orderId: o.id } }).catch(() => {});
        await prisma.orderItem.deleteMany({ where: { orderId: o.id } }).catch(() => {});
        await prisma.order.delete({ where: { id: o.id } }).catch(() => {});
      }
      await prisma.product.delete({ where: { id: pid } }).catch(() => {});
    }
  });

  test("order list + status update flow visible to customer", async () => {
    const cust = await register();
    const addr = await createAddress(cust.accessToken);
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
    const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
    const prod = await prisma.product.create({
      data: {
        name: `Admin-Order-Prod-${suffix}`,
        slug: `admin-order-prod-${suffix}`,
        description: "order flow product",
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
          idempotencyKey: uniqKey("admflow"),
        });
      expect(co.status).toBe(201);
      orderId = co.body.id;
      expect(co.body.status).toBe("pending");

      const list = await request(app)
        .get("/api/v1/admin/orders")
        .set("Authorization", `Bearer ${adminToken}`);
      expect(list.status).toBe(200);
      const items = Array.isArray(list.body) ? list.body : list.body.items;
      expect(Array.isArray(items)).toBe(true);
      const found = items.find((o: any) => o.id === orderId);
      expect(found).toBeDefined();
      expect(found.items).toBeDefined();
      expect(found.payment).toBeDefined();

      for (const s of ["confirmed", "shipped", "delivered"]) {
        const upd = await request(app)
          .patch(`/api/v1/admin/orders/${orderId}/status`)
          .set("Authorization", `Bearer ${adminToken}`)
          .send({ status: s });
        expect(upd.status).toBe(200);
        expect(upd.body.status).toBe(s);
      }

      const detail = await request(app)
        .get(`/api/v1/orders/${orderId}`)
        .set("Authorization", `Bearer ${cust.accessToken}`);
      expect(detail.status).toBe(200);
      expect(detail.body.status).toBe("delivered");
    } finally {
      if (orderId) {
        await prisma.payment.deleteMany({ where: { orderId } }).catch(() => {});
        await prisma.orderItem.deleteMany({ where: { orderId } }).catch(() => {});
        await prisma.order.delete({ where: { id: orderId } }).catch(() => {});
      }
      await prisma.product.delete({ where: { id: prod.id } }).catch(() => {});
    }
  });

  test("invalid status 400", async () => {
    const cust = await register();
    const addr = await createAddress(cust.accessToken);
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
    const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
    const prod = await prisma.product.create({
      data: {
        name: `Admin-BadStatus-${suffix}`,
        slug: `admin-badstatus-${suffix}`,
        description: "x",
        priceBdt: 500,
        stock: 10,
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
          idempotencyKey: uniqKey("badst"),
        });
      expect(co.status).toBe(201);
      orderId = co.body.id;
      const bad = await request(app)
        .patch(`/api/v1/admin/orders/${orderId}/status`)
        .set("Authorization", `Bearer ${adminToken}`)
        .send({ status: "bogus" });
      expect(bad.status).toBe(400);
    } finally {
      if (orderId) {
        await prisma.payment.deleteMany({ where: { orderId } }).catch(() => {});
        await prisma.orderItem.deleteMany({ where: { orderId } }).catch(() => {});
        await prisma.order.delete({ where: { id: orderId } }).catch(() => {});
      }
      await prisma.product.delete({ where: { id: prod.id } }).catch(() => {});
    }
  });

  test("dashboard revenue excludes cancelled orders", async () => {
    const cust = await register();
    const addr = await createAddress(cust.accessToken);
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
    const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
    const prod = await prisma.product.create({
      data: {
        name: `Admin-Rev-${suffix}`,
        slug: `admin-rev-${suffix}`,
        description: "revenue test",
        priceBdt: 1000,
        stock: 20,
        categoryId: cat.id,
        isActive: true,
      },
    });
    const dash = (t: string) =>
      request(app).get("/api/v1/admin/dashboard").set("Authorization", `Bearer ${t}`);
    let orderId = 0;
    let orderTotal = 0;
    try {
      const before = await dash(adminToken);
      expect(before.status).toBe(200);
      const revBefore = (before.body.revenue ?? before.body.totalRevenue) as number;

      const co = await request(app)
        .post("/api/v1/checkout")
        .set("Authorization", `Bearer ${cust.accessToken}`)
        .send({
          addressId: addr.id,
          items: [{ productId: prod.id, qty: 2 }],
          idempotencyKey: uniqKey("revdash"),
        });
      expect(co.status).toBe(201);
      orderId = co.body.id;
      orderTotal = co.body.total as number;

      const afterCreate = await dash(adminToken);
      expect(afterCreate.status).toBe(200);
      const revAfterCreate = (afterCreate.body.revenue ?? afterCreate.body.totalRevenue) as number;
      expect(revAfterCreate).toBe(revBefore + orderTotal);

      const cancel = await request(app)
        .patch(`/api/v1/admin/orders/${orderId}/status`)
        .set("Authorization", `Bearer ${adminToken}`)
        .send({ status: "cancelled" });
      expect(cancel.status).toBe(200);

      const afterCancel = await dash(adminToken);
      expect(afterCancel.status).toBe(200);
      const revAfterCancel = (afterCancel.body.revenue ?? afterCancel.body.totalRevenue) as number;
      expect(revAfterCancel).toBe(revBefore);
    } finally {
      if (orderId) {
        await prisma.payment.deleteMany({ where: { orderId } }).catch(() => {});
        await prisma.orderItem.deleteMany({ where: { orderId } }).catch(() => {});
        await prisma.order.delete({ where: { id: orderId } }).catch(() => {});
      }
      await prisma.product.delete({ where: { id: prod.id } }).catch(() => {});
    }
  });

  test("dashboard lowStock lists only active products", async () => {
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
    const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
    const active = await prisma.product.create({
      data: {
        name: `Admin-Low-Active-${suffix}`,
        slug: `admin-low-active-${suffix}`,
        description: "low active",
        priceBdt: 100,
        stock: 2,
        categoryId: cat.id,
        isActive: true,
      },
    });
    const inactive = await prisma.product.create({
      data: {
        name: `Admin-Low-Inactive-${suffix}`,
        slug: `admin-low-inactive-${suffix}`,
        description: "low inactive",
        priceBdt: 100,
        stock: 1,
        categoryId: cat.id,
        isActive: false,
      },
    });
    try {
      const res = await request(app)
        .get("/api/v1/admin/dashboard")
        .set("Authorization", `Bearer ${adminToken}`);
      expect(res.status).toBe(200);
      const low = res.body.lowStock as Array<any>;
      expect(Array.isArray(low)).toBe(true);
      const ids = low.map((p: any) => p.id);
      expect(ids).toContain(active.id);
      expect(ids).not.toContain(inactive.id);
    } finally {
      await prisma.product.delete({ where: { id: active.id } }).catch(() => {});
      await prisma.product.delete({ where: { id: inactive.id } }).catch(() => {});
    }
  });

  test("invalid product 404", async () => {
    const upd = await request(app)
      .patch("/api/v1/admin/products/99999999")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ priceBdt: 10 });
    expect(upd.status).toBe(404);
    const del = await request(app)
      .delete("/api/v1/admin/products/99999999")
      .set("Authorization", `Bearer ${adminToken}`);
    expect(del.status).toBe(404);
  });
});
