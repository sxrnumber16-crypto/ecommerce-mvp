import { vi } from "vitest";

vi.mock("../src/lib/push.js", () => ({
  isPushEnabled: () => true,
  sendToTopic: vi.fn(),
  sendToUser: vi.fn(),
}));

import request from "supertest";
import { PrismaClient } from "@prisma/client";
import * as argon2 from "argon2";
import { createApp } from "../src/app.js";
import { sendToTopic, sendToUser } from "../src/lib/push.js";

const app = createApp();
const prisma = new PrismaClient();

const uniq = (prefix: string) =>
  `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@test.com`;
const uniqKey = (prefix: string) => `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e9)}-key`;

async function register() {
  const email = uniq("push-cust");
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

const token = (suffix: string) => `fcm-test-token-${suffix}-${Date.now()}`;

describe("push sender (disabled-safe, no creds locally)", () => {
  test("sender disabled without creds, never throws", async () => {
    // Module is mocked for trigger tests below; verify the REAL sender here.
    const actual =
      await vi.importActual<typeof import("../src/lib/push.js")>("../src/lib/push.js");
    expect(process.env.FIREBASE_SERVICE_ACCOUNT ?? "").toBe("");
    expect(actual.isPushEnabled()).toBe(false);
    await expect(
      actual.sendToTopic("new_products", {
        title: "t",
        body: "b",
        data: { type: "new_product", productId: "1" },
      }),
    ).resolves.toBeNull();
    const alice = await register();
    const me = await prisma.user.findUniqueOrThrow({ where: { email: alice.email } });
    await expect(
      actual.sendToUser(me.id, { title: "t", body: "b", data: { type: "order_update" } }),
    ).resolves.toBeNull();
  });
});

describe("device tokens", () => {
  test("POST /devices upserts my token (201 then 200 idempotent); DELETE removes (200)", async () => {
    const alice = await register();
    const auth = { Authorization: `Bearer ${alice.accessToken}` };
    const t = token("alice1");

    const r1 = await request(app).post("/api/v1/devices").set(auth).send({ token: t });
    expect(r1.status).toBe(201);

    const r2 = await request(app).post("/api/v1/devices").set(auth).send({ token: t });
    expect(r2.status).toBe(200);

    const del = await request(app).delete("/api/v1/devices").set(auth).send({ token: t });
    expect(del.status).toBe(200);

    const me = await prisma.user.findUniqueOrThrow({ where: { email: alice.email } });
    expect(await prisma.deviceToken.findMany({ where: { userId: me.id } })).toHaveLength(0);
  });

  test("cross-user isolation: deleting my token never removes another user's token", async () => {
    const alice = await register();
    const bob = await register();
    const tA = token("alice-iso");
    const tB = token("bob-iso");

    await request(app).post("/api/v1/devices").set(`Authorization`, `Bearer ${alice.accessToken}`).send({ token: tA }).expect(201);
    await request(app).post("/api/v1/devices").set(`Authorization`, `Bearer ${bob.accessToken}`).send({ token: tB }).expect(201);

    // Alice tries to delete Bob's token value -> must not touch Bob's row, still 200.
    const del = await request(app)
      .delete("/api/v1/devices")
      .set("Authorization", `Bearer ${alice.accessToken}`)
      .send({ token: tB });
    expect(del.status).toBe(200);

    const bobRow = await prisma.user.findUniqueOrThrow({ where: { email: bob.email } });
    const bobTokens = await prisma.deviceToken.findMany({ where: { userId: bobRow.id } });
    expect(bobTokens.map((r) => r.token)).toContain(tB);

    // Cleanup own tokens.
    await request(app).delete("/api/v1/devices").set("Authorization", `Bearer ${alice.accessToken}`).send({ token: tA }).expect(200);
    await request(app).delete("/api/v1/devices").set("Authorization", `Bearer ${bob.accessToken}`).send({ token: tB }).expect(200);
  });

  test("devices require auth + validate token length", async () => {
    await request(app).post("/api/v1/devices").send({ token: token("anon") }).expect(401);
    await request(app).delete("/api/v1/devices").send({ token: token("anon") }).expect(401);

    const alice = await register();
    const auth = { Authorization: `Bearer ${alice.accessToken}` };
    await request(app).post("/api/v1/devices").set(auth).send({}).expect(400);
    await request(app).post("/api/v1/devices").set(auth).send({ token: "short" }).expect(400);
    await request(app).post("/api/v1/devices").set(auth).send({ token: "x".repeat(256) }).expect(400);
    await request(app).delete("/api/v1/devices").set(auth).send({}).expect(400);
  });
});

describe("push triggers", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  test("admin product create broadcasts to new_products topic", async () => {
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
    const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
    const name = `Push-Trig-Prod-${suffix}`;

    const created = await request(app)
      .post("/api/v1/admin/products")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        name,
        categoryId: cat.id,
        description: "push trigger product",
        priceBdt: 1500,
        stock: 5,
        imageUrl: "",
        isActive: true,
      });
    expect(created.status).toBe(201);
    const pid = created.body.id as number;

    try {
      expect(vi.mocked(sendToTopic)).toHaveBeenCalledTimes(1);
      const [topic, msg] = vi.mocked(sendToTopic).mock.calls[0] as unknown as [
        string,
        { title: string; body: string; data: Record<string, string> },
      ];
      expect(topic).toBe("new_products");
      expect(msg.data.productId).toBe(String(pid));
      expect(typeof msg.data.productId).toBe("string");
    } finally {
      await prisma.product.delete({ where: { id: pid } }).catch(() => {});
    }
  });

  test("admin order pending->confirmed notifies the ordering user", async () => {
    const cust = await register();
    const addr = await createAddress(cust.accessToken);
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
    const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
    const prod = await prisma.product.create({
      data: {
        name: `Push-Trig-Order-${suffix}`,
        slug: `push-trig-order-${suffix}`,
        description: "push trigger order product",
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
          idempotencyKey: uniqKey("pushtrig"),
        });
      expect(co.status).toBe(201);
      orderId = co.body.id as number;
      expect(co.body.status).toBe("pending");

      const orderingUser = await prisma.user.findUniqueOrThrow({ where: { email: cust.email } });
      const adminEmail = process.env.ADMIN_EMAIL ?? "admin@demo.com";
      const adminUser = await prisma.user.findUniqueOrThrow({ where: { email: adminEmail } });
      expect(orderingUser.id).not.toBe(adminUser.id);

      vi.clearAllMocks();

      const upd = await request(app)
        .patch(`/api/v1/admin/orders/${orderId}/status`)
        .set("Authorization", `Bearer ${adminToken}`)
        .send({ status: "confirmed" });
      expect(upd.status).toBe(200);
      expect(upd.body.status).toBe("confirmed");

      expect(vi.mocked(sendToUser)).toHaveBeenCalledTimes(1);
      const [userId, msg] = vi.mocked(sendToUser).mock.calls[0] as unknown as [
        number,
        { title: string; body: string; data: Record<string, string> },
      ];
      expect(userId).toBe(orderingUser.id);
      expect(msg.data.orderId).toBe(String(orderId));
      expect(msg.data.status).toBe("confirmed");
      expect(typeof msg.data.orderId).toBe("string");
      expect(typeof msg.data.status).toBe("string");
    } finally {
      if (orderId) {
        await prisma.payment.deleteMany({ where: { orderId } }).catch(() => {});
        await prisma.orderItem.deleteMany({ where: { orderId } }).catch(() => {});
        await prisma.order.delete({ where: { id: orderId } }).catch(() => {});
      }
      await prisma.product.delete({ where: { id: prod.id } }).catch(() => {});
    }
  });

  test("payment toggle sends no push", async () => {
    const cust = await register();
    const addr = await createAddress(cust.accessToken);
    const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
    const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
    const prod = await prisma.product.create({
      data: {
        name: `Push-Trig-Pay-${suffix}`,
        slug: `push-trig-pay-${suffix}`,
        description: "push no-trigger product",
        priceBdt: 600,
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
          idempotencyKey: uniqKey("pushnopay"),
        });
      expect(co.status).toBe(201);
      orderId = co.body.id as number;

      vi.clearAllMocks();

      const toggled = await request(app)
        .patch(`/api/v1/admin/orders/${orderId}/payment`)
        .set("Authorization", `Bearer ${adminToken}`)
        .send({ status: "paid" });
      expect(toggled.status).toBe(200);

      expect(vi.mocked(sendToUser)).not.toHaveBeenCalled();
      expect(vi.mocked(sendToTopic)).not.toHaveBeenCalled();
    } finally {
      if (orderId) {
        await prisma.payment.deleteMany({ where: { orderId } }).catch(() => {});
        await prisma.orderItem.deleteMany({ where: { orderId } }).catch(() => {});
        await prisma.order.delete({ where: { id: orderId } }).catch(() => {});
      }
      await prisma.product.delete({ where: { id: prod.id } }).catch(() => {});
    }
  });
});
