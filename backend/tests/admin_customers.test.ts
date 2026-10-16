import request from "supertest";
import { PrismaClient } from "@prisma/client";
import * as argon2 from "argon2";
import { createApp } from "../src/app.js";

const app = createApp();
const prisma = new PrismaClient();

const uniq = (prefix: string) => `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@test.com`;
const uniqKey = (prefix: string) => `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e9)}-key`;

async function registerCustomer(opts?: { fullName?: string; phone?: string }) {
  const email = uniq("susp-cust");
  const password = "Password123!";
  const res = await request(app)
    .post("/api/v1/auth/register")
    .send({
      email,
      password,
      ...(opts?.fullName !== undefined ? { fullName: opts.fullName } : {}),
      ...(opts?.phone !== undefined ? { phone: opts.phone } : {}),
    });
  expect(res.status).toBe(201);
  return {
    email,
    password,
    user: res.body.user as { id: number; email: string; role: string },
    accessToken: res.body.accessToken as string,
  };
}

async function ensureAdminToken(): Promise<{ token: string; adminId: number }> {
  const email = process.env.ADMIN_EMAIL ?? "admin@demo.com";
  const password = process.env.ADMIN_PASSWORD ?? "Demo1234!";
  const first = await request(app).post("/api/v1/auth/login").send({ email, password });
  if (first.status === 200 && first.body.accessToken) {
    return { token: first.body.accessToken as string, adminId: first.body.user.id as number };
  }
  const passwordHash = await argon2.hash(password, { type: argon2.argon2id });
  await prisma.user.upsert({
    where: { email },
    update: { passwordHash, role: "admin" },
    create: { email, passwordHash, role: "admin" },
  });
  const second = await request(app).post("/api/v1/auth/login").send({ email, password });
  expect(second.status).toBe(200);
  return { token: second.body.accessToken as string, adminId: second.body.user.id as number };
}

async function createAddress(token: string) {
  const res = await request(app)
    .post("/api/v1/addresses")
    .set("Authorization", `Bearer ${token}`)
    .send({ line1: "House 7", city: "Dhaka", phone: "01700000007" });
  expect(res.status).toBe(201);
  return res.body as { id: number };
}

async function createProduct(opts?: { priceBdt?: number; stock?: number }) {
  const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
  const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
  return prisma.product.create({
    data: {
      name: `Susp-Prod-${suffix}`,
      slug: `susp-prod-${suffix}`,
      description: "suspend test product",
      priceBdt: opts?.priceBdt ?? 750,
      stock: opts?.stock ?? 20,
      categoryId: cat.id,
      isActive: true,
    },
  });
}

async function checkout(token: string, addressId: number, productId: number, qty = 1) {
  return request(app)
    .post("/api/v1/checkout")
    .set("Authorization", `Bearer ${token}`)
    .send({ addressId, items: [{ productId, qty }], idempotencyKey: uniqKey("susp") });
}

async function cleanupOrder(orderId: number) {
  await prisma.payment.deleteMany({ where: { orderId } }).catch(() => {});
  await prisma.orderItem.deleteMany({ where: { orderId } }).catch(() => {});
  await prisma.order.delete({ where: { id: orderId } }).catch(() => {});
}

let adminToken = "";
let adminId = 0;

beforeAll(async () => {
  const admin = await ensureAdminToken();
  adminToken = admin.token;
  adminId = admin.adminId;
});

const adminAuth = () => `Bearer ${adminToken}`;

describe("admin customers + suspend enforcement", () => {
  test("suspend blocks login (401 suspended) + checkout (403); history intact; unsuspend restores", async () => {
    const cust = await registerCustomer({ fullName: "Suspend Me", phone: "01711111111" });
    const addr = await createAddress(cust.accessToken);
    const prod = await createProduct();
    let orderId = 0;
    try {
      const co = await checkout(cust.accessToken, addr.id, prod.id);
      expect(co.status).toBe(201);
      orderId = co.body.id as number;

      const baseline = await request(app)
        .get(`/api/v1/orders/${orderId}`)
        .set("Authorization", `Bearer ${cust.accessToken}`);
      expect(baseline.status).toBe(200);

      const susp = await request(app)
        .patch(`/api/v1/admin/customers/${cust.user.id}/status`)
        .set("Authorization", adminAuth())
        .send({ status: "suspended" });
      expect(susp.status).toBe(200);
      expect(susp.body.status).toBe("suspended");

      const login = await request(app)
        .post("/api/v1/auth/login")
        .send({ email: cust.email, password: cust.password });
      expect(login.status).toBe(401);
      expect(JSON.stringify(login.body).toLowerCase()).toContain("suspended");
      expect(login.body.accessToken).toBeUndefined();
      expect(login.body.refreshToken).toBeUndefined();

      const blocked = await checkout(cust.accessToken, addr.id, prod.id);
      expect(blocked.status).toBe(403);
      expect(JSON.stringify(blocked.body).toLowerCase()).toContain("suspended");

      const hist = await request(app)
        .get("/api/v1/orders")
        .set("Authorization", `Bearer ${cust.accessToken}`);
      expect(hist.status).toBe(200);
      expect(Array.isArray(hist.body)).toBe(true);
      expect(hist.body.find((o: any) => o.id === orderId)).toBeDefined();

      const detail = await request(app)
        .get(`/api/v1/orders/${orderId}`)
        .set("Authorization", `Bearer ${cust.accessToken}`);
      expect(detail.status).toBe(200);
      expect(detail.body.id).toBe(orderId);

      const uns = await request(app)
        .patch(`/api/v1/admin/customers/${cust.user.id}/status`)
        .set("Authorization", adminAuth())
        .send({ status: "active" });
      expect(uns.status).toBe(200);
      expect(uns.body.status).toBe("active");

      const relogin = await request(app)
        .post("/api/v1/auth/login")
        .send({ email: cust.email, password: cust.password });
      expect(relogin.status).toBe(200);
      expect(relogin.body.accessToken).toBeDefined();
    } finally {
      if (orderId) await cleanupOrder(orderId);
      await prisma.product.delete({ where: { id: prod.id } }).catch(() => {});
    }
  });

  test("self-suspend returns 409 and admin stays active", async () => {
    const res = await request(app)
      .patch(`/api/v1/admin/customers/${adminId}/status`)
      .set("Authorization", adminAuth())
      .send({ status: "suspended" });
    expect(res.status).toBe(409);
    const me = await prisma.user.findUnique({ where: { id: adminId } });
    expect((me as any)?.status ?? "active").toBe("active");
  });

  test("suspending another admin returns 403", async () => {
    const email = uniq("second-admin");
    const passwordHash = await argon2.hash("Password123!", { type: argon2.argon2id });
    const second = await prisma.user.create({ data: { email, passwordHash, role: "admin" } });
    try {
      const res = await request(app)
        .patch(`/api/v1/admin/customers/${second.id}/status`)
        .set("Authorization", adminAuth())
        .send({ status: "suspended" });
      expect(res.status).toBe(403);
      const after = await prisma.user.findUnique({ where: { id: second.id } });
      expect((after as any)?.status ?? "active").toBe("active");
    } finally {
      await prisma.user.delete({ where: { id: second.id } }).catch(() => {});
    }
  });

  test("customers list/detail shape; totalSpent excludes cancelled", async () => {
    const cust = await registerCustomer({ fullName: "Shape Test", phone: "01722222222" });
    const addr = await createAddress(cust.accessToken);
    const prod = await createProduct({ priceBdt: 500, stock: 30 });
    let orderA = 0;
    let orderB = 0;
    let totalA = 0;
    let totalB = 0;
    try {
      const a = await checkout(cust.accessToken, addr.id, prod.id, 1);
      expect(a.status).toBe(201);
      orderA = a.body.id as number;
      totalA = a.body.total as number;
      const b = await checkout(cust.accessToken, addr.id, prod.id, 2);
      expect(b.status).toBe(201);
      orderB = b.body.id as number;
      totalB = b.body.total as number;

      const frag = encodeURIComponent(cust.email.split("@")[0]);
      const list = await request(app)
        .get(`/api/v1/admin/customers?search=${frag}`)
        .set("Authorization", adminAuth());
      expect(list.status).toBe(200);
      expect(Array.isArray(list.body.items)).toBe(true);
      expect(typeof list.body.total).toBe("number");
      expect(list.body.page).toBeDefined();
      const found = (list.body.items as any[]).find((u: any) => u.id === cust.user.id);
      expect(found).toBeDefined();
      expect(found.email).toBe(cust.email);
      expect(found.role).toBe("customer");
      expect(found.status).toBe("active");
      expect(found.fullName).toBe("Shape Test");
      expect(found.phone).toBe("01722222222");
      expect(found.orderCount).toBeGreaterThanOrEqual(2);
      expect(found.totalSpent).toBe(totalA + totalB);

      const detail = await request(app)
        .get(`/api/v1/admin/customers/${cust.user.id}`)
        .set("Authorization", adminAuth());
      expect(detail.status).toBe(200);
      expect(detail.body.id).toBe(cust.user.id);
      expect(detail.body.email).toBe(cust.email);
      expect(detail.body.status).toBe("active");
      expect(detail.body.profile?.fullName ?? detail.body.fullName).toBeDefined();
      expect(Array.isArray(detail.body.addresses)).toBe(true);
      expect(detail.body.addresses.length).toBeGreaterThanOrEqual(1);
      expect(Array.isArray(detail.body.orders)).toBe(true);
      expect(detail.body.orders.length).toBeGreaterThanOrEqual(2);
      expect(detail.body.orders[0].id).toBeGreaterThan(detail.body.orders[1].id);
      expect(detail.body.payments).toBeDefined();

      const cancel = await request(app)
        .patch(`/api/v1/admin/orders/${orderA}/status`)
        .set("Authorization", adminAuth())
        .send({ status: "cancelled" });
      expect(cancel.status).toBe(200);

      const relist = await request(app)
        .get(`/api/v1/admin/customers?search=${frag}`)
        .set("Authorization", adminAuth());
      expect(relist.status).toBe(200);
      const refound = (relist.body.items as any[]).find((u: any) => u.id === cust.user.id);
      expect(refound).toBeDefined();
      expect(refound.totalSpent).toBe(totalB);
    } finally {
      if (orderA) await cleanupOrder(orderA);
      if (orderB) await cleanupOrder(orderB);
      await prisma.product.delete({ where: { id: prod.id } }).catch(() => {});
    }
  });

  test("customers routes: anon 401, customer 403", async () => {
    const cust = await registerCustomer();

    const anonList = await request(app).get("/api/v1/admin/customers");
    expect(anonList.status).toBe(401);
    const custList = await request(app)
      .get("/api/v1/admin/customers")
      .set("Authorization", `Bearer ${cust.accessToken}`);
    expect(custList.status).toBe(403);

    const anonDetail = await request(app).get(`/api/v1/admin/customers/${cust.user.id}`);
    expect(anonDetail.status).toBe(401);
    const custDetail = await request(app)
      .get(`/api/v1/admin/customers/${cust.user.id}`)
      .set("Authorization", `Bearer ${cust.accessToken}`);
    expect(custDetail.status).toBe(403);

    const anonPatch = await request(app)
      .patch(`/api/v1/admin/customers/${cust.user.id}/status`)
      .send({ status: "suspended" });
    expect(anonPatch.status).toBe(401);
    const custPatch = await request(app)
      .patch(`/api/v1/admin/customers/${cust.user.id}/status`)
      .set("Authorization", `Bearer ${cust.accessToken}`)
      .send({ status: "suspended" });
    expect(custPatch.status).toBe(403);
  });

  test("status patch validation: 400 bad enum, 404 missing", async () => {
    const cust = await registerCustomer();

    const badEnum = await request(app)
      .patch(`/api/v1/admin/customers/${cust.user.id}/status`)
      .set("Authorization", adminAuth())
      .send({ status: "bogus" });
    expect(badEnum.status).toBe(400);

    const missingBody = await request(app)
      .patch(`/api/v1/admin/customers/${cust.user.id}/status`)
      .set("Authorization", adminAuth())
      .send({});
    expect(missingBody.status).toBe(400);

    const missing = await request(app)
      .patch("/api/v1/admin/customers/99999999/status")
      .set("Authorization", adminAuth())
      .send({ status: "suspended" });
    expect(missing.status).toBe(404);

    const badId = await request(app)
      .patch("/api/v1/admin/customers/abc/status")
      .set("Authorization", adminAuth())
      .send({ status: "suspended" });
    expect(badId.status).toBe(404);

    const noDetail = await request(app)
      .get("/api/v1/admin/customers/99999999")
      .set("Authorization", adminAuth());
    expect(noDetail.status).toBe(404);
  });
});
