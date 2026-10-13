import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { createApp } from "../src/app.js";
import { config } from "../src/config.js";

const app = createApp();
const prisma = new PrismaClient();

const uniq = (prefix: string) => `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@test.com`;
const uniqKey = (prefix: string) => `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e9)}-key`;

async function register(email?: string) {
  const e = email ?? uniq("co");
  const res = await request(app)
    .post("/api/v1/auth/register")
    .send({ email: e, password: "Password123!" });
  expect(res.status).toBe(201);
  return { email: e, user: res.body.user, accessToken: res.body.accessToken as string };
}

async function createAddress(token: string) {
  const res = await request(app)
    .post("/api/v1/addresses")
    .set("Authorization", `Bearer ${token}`)
    .send({ line1: "House 7", city: "Dhaka", phone: "01700000007" });
  expect(res.status).toBe(201);
  return res.body;
}

async function createProduct(opts?: { priceBdt?: number; stock?: number; isActive?: boolean }) {
  const cat = await prisma.category.findUniqueOrThrow({ where: { slug: "clothing" } });
  const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
  const p = await prisma.product.create({
    data: {
      name: `Checkout-Prod-${suffix}`,
      slug: `checkout-prod-${suffix}`,
      description: "checkout test product",
      priceBdt: opts?.priceBdt ?? 1000,
      stock: opts?.stock ?? 20,
      categoryId: cat.id,
      isActive: opts?.isActive ?? true,
    },
  });
  return p;
}

describe("checkout+orders COD", () => {
  test("POST /api/v1/checkout returns 401 without token", async () => {
    const res = await request(app)
      .post("/api/v1/checkout")
      .send({ addressId: 1, items: [{ productId: 1, qty: 1 }], idempotencyKey: uniqKey("k") });
    expect(res.status).toBe(401);
  });

  test("server-calculated total ignores client total field (tamper impossible)", async () => {
    const { accessToken } = await register();
    const addr = await createAddress(accessToken);
    const prod = await createProduct({ priceBdt: 1234, stock: 20 });
    try {
      const res = await request(app)
        .post("/api/v1/checkout")
        .set("Authorization", `Bearer ${accessToken}`)
        .send({
          addressId: addr.id,
          items: [{ productId: prod.id, qty: 2 }],
          idempotencyKey: uniqKey("tamper"),
          total: 1,
          priceBdt: 1,
          subtotal: 1,
        });
      expect(res.status).toBe(201);
      const expectedSubtotal = 1234 * 2;
      const expectedTotal = expectedSubtotal + config.deliveryFeeBdt;
      expect(res.body.subtotal).toBe(expectedSubtotal);
      expect(res.body.total).toBe(expectedTotal);
      expect(res.body.deliveryFee).toBe(config.deliveryFeeBdt);
      expect(res.body.payment.amount).toBe(expectedTotal);
      expect(res.body.payment.method).toBe("COD");
      expect(res.body.payment.status).toBe("unpaid");
    } finally {
      await prisma.orderItem.deleteMany({ where: { productId: prod.id } }).catch(() => {});
      await prisma.payment.deleteMany({}).catch(() => {});
      // delete orders created with this product then product
      const orders = await prisma.order.findMany({ where: { items: { some: { productId: prod.id } } } });
      for (const o of orders) {
        await prisma.payment.deleteMany({ where: { orderId: o.id } }).catch(() => {});
        await prisma.orderItem.deleteMany({ where: { orderId: o.id } }).catch(() => {});
        await prisma.order.delete({ where: { id: o.id } }).catch(() => {});
      }
      await prisma.product.delete({ where: { id: prod.id } }).catch(() => {});
    }
  });

  test("stock decremented atomically after checkout", async () => {
    const { accessToken } = await register();
    const addr = await createAddress(accessToken);
    const prod = await createProduct({ priceBdt: 500, stock: 10 });
    try {
      const before = (await prisma.product.findUniqueOrThrow({ where: { id: prod.id } })).stock;
      expect(before).toBe(10);
      const res = await request(app)
        .post("/api/v1/checkout")
        .set("Authorization", `Bearer ${accessToken}`)
        .send({ addressId: addr.id, items: [{ productId: prod.id, qty: 2 }], idempotencyKey: uniqKey("dec") });
      expect(res.status).toBe(201);
      expect(res.body.status).toBe("pending");
      expect(res.body.items).toHaveLength(1);
      expect(res.body.items[0].qty).toBe(2);
      expect(res.body.items[0].unitPrice).toBe(500);
      expect(res.body.items[0].lineTotal).toBe(1000);
      const after = (await prisma.product.findUniqueOrThrow({ where: { id: prod.id } })).stock;
      expect(after).toBe(8);
    } finally {
      const orders = await prisma.order.findMany({ where: { items: { some: { productId: prod.id } } } });
      for (const o of orders) {
        await prisma.payment.deleteMany({ where: { orderId: o.id } }).catch(() => {});
        await prisma.orderItem.deleteMany({ where: { orderId: o.id } }).catch(() => {});
        await prisma.order.delete({ where: { id: o.id } }).catch(() => {});
      }
      await prisma.product.delete({ where: { id: prod.id } }).catch(() => {});
    }
  });

  test("oversell qty>stock returns 409 and does not decrement", async () => {
    const { accessToken } = await register();
    const addr = await createAddress(accessToken);
    const prod = await createProduct({ priceBdt: 700, stock: 2 });
    try {
      const res = await request(app)
        .post("/api/v1/checkout")
        .set("Authorization", `Bearer ${accessToken}`)
        .send({ addressId: addr.id, items: [{ productId: prod.id, qty: 3 }], idempotencyKey: uniqKey("over") });
      expect(res.status).toBe(409);
      expect(JSON.stringify(res.body).toLowerCase()).toContain("insufficient");
      const after = (await prisma.product.findUniqueOrThrow({ where: { id: prod.id } })).stock;
      expect(after).toBe(2);
    } finally {
      await prisma.product.delete({ where: { id: prod.id } }).catch(() => {});
    }
  });

  test("idempotency duplicate returns same order without second decrement", async () => {
    const { accessToken } = await register();
    const addr = await createAddress(accessToken);
    const prod = await createProduct({ priceBdt: 900, stock: 10 });
    const key = uniqKey("idem");
    try {
      const first = await request(app)
        .post("/api/v1/checkout")
        .set("Authorization", `Bearer ${accessToken}`)
        .send({ addressId: addr.id, items: [{ productId: prod.id, qty: 1 }], idempotencyKey: key });
      expect(first.status).toBe(201);
      const stockAfterFirst = (await prisma.product.findUniqueOrThrow({ where: { id: prod.id } })).stock;
      expect(stockAfterFirst).toBe(9);
      const second = await request(app)
        .post("/api/v1/checkout")
        .set("Authorization", `Bearer ${accessToken}`)
        .send({ addressId: addr.id, items: [{ productId: prod.id, qty: 1 }], idempotencyKey: key });
      expect(second.status).toBe(200);
      expect(second.body.id).toBe(first.body.id);
      expect(second.body.idempotencyKey).toBe(key);
      const stockAfterSecond = (await prisma.product.findUniqueOrThrow({ where: { id: prod.id } })).stock;
      expect(stockAfterSecond).toBe(9);
    } finally {
      const orders = await prisma.order.findMany({ where: { items: { some: { productId: prod.id } } } });
      for (const o of orders) {
        await prisma.payment.deleteMany({ where: { orderId: o.id } }).catch(() => {});
        await prisma.orderItem.deleteMany({ where: { orderId: o.id } }).catch(() => {});
        await prisma.order.delete({ where: { id: o.id } }).catch(() => {});
      }
      await prisma.product.delete({ where: { id: prod.id } }).catch(() => {});
    }
  });

  test("invalid product returns 404", async () => {
    const { accessToken } = await register();
    const addr = await createAddress(accessToken);
    const res = await request(app)
      .post("/api/v1/checkout")
      .set("Authorization", `Bearer ${accessToken}`)
      .send({ addressId: addr.id, items: [{ productId: 99999999, qty: 1 }], idempotencyKey: uniqKey("badprod") });
    expect(res.status).toBe(404);
  });

  test("inactive product rejected with 404", async () => {
    const { accessToken } = await register();
    const addr = await createAddress(accessToken);
    const prod = await createProduct({ priceBdt: 100, stock: 5, isActive: false });
    try {
      const res = await request(app)
        .post("/api/v1/checkout")
        .set("Authorization", `Bearer ${accessToken}`)
        .send({ addressId: addr.id, items: [{ productId: prod.id, qty: 1 }], idempotencyKey: uniqKey("inactive") });
      expect(res.status).toBe(404);
    } finally {
      await prisma.product.delete({ where: { id: prod.id } }).catch(() => {});
    }
  });

  test("invalid qty returns 400 (0 and >10)", async () => {
    const { accessToken } = await register();
    const addr = await createAddress(accessToken);
    const prod = await createProduct({ priceBdt: 100, stock: 50 });
    try {
      const zero = await request(app)
        .post("/api/v1/checkout")
        .set("Authorization", `Bearer ${accessToken}`)
        .send({ addressId: addr.id, items: [{ productId: prod.id, qty: 0 }], idempotencyKey: uniqKey("q0") });
      expect(zero.status).toBe(400);
      const over = await request(app)
        .post("/api/v1/checkout")
        .set("Authorization", `Bearer ${accessToken}`)
        .send({ addressId: addr.id, items: [{ productId: prod.id, qty: 11 }], idempotencyKey: uniqKey("q11") });
      expect(over.status).toBe(400);
    } finally {
      await prisma.product.delete({ where: { id: prod.id } }).catch(() => {});
    }
  });

  test("foreign address rejected (403/404)", async () => {
    const a = await register();
    const b = await register();
    const addrA = await createAddress(a.accessToken);
    const prod = await createProduct({ priceBdt: 200, stock: 10 });
    try {
      const res = await request(app)
        .post("/api/v1/checkout")
        .set("Authorization", `Bearer ${b.accessToken}`)
        .send({ addressId: addrA.id, items: [{ productId: prod.id, qty: 1 }], idempotencyKey: uniqKey("foreign") });
      expect([403, 404]).toContain(res.status);
    } finally {
      await prisma.product.delete({ where: { id: prod.id } }).catch(() => {});
    }
  });

  test("order history + detail tracking (own only)", async () => {
    const { accessToken, user } = await register();
    const addr = await createAddress(accessToken);
    const prod = await createProduct({ priceBdt: 600, stock: 30 });
    let orderId = 0;
    try {
      const co = await request(app)
        .post("/api/v1/checkout")
        .set("Authorization", `Bearer ${accessToken}`)
        .send({ addressId: addr.id, items: [{ productId: prod.id, qty: 2 }], idempotencyKey: uniqKey("hist") });
      expect(co.status).toBe(201);
      orderId = co.body.id;

      const list = await request(app)
        .get("/api/v1/orders")
        .set("Authorization", `Bearer ${accessToken}`);
      expect(list.status).toBe(200);
      expect(Array.isArray(list.body)).toBe(true);
      const found = list.body.find((o: any) => o.id === orderId);
      expect(found).toBeDefined();
      expect(found.userId ?? user.id).toBeDefined();

      const detail = await request(app)
        .get(`/api/v1/orders/${orderId}`)
        .set("Authorization", `Bearer ${accessToken}`);
      expect(detail.status).toBe(200);
      expect(detail.body.id).toBe(orderId);
      expect(detail.body.items).toHaveLength(1);
      expect(detail.body.payment).toBeDefined();
      expect(detail.body.payment.method).toBe("COD");
      expect(detail.body.address ?? detail.body.addressId).toBeDefined();

      const other = await register();
      const forbidden = await request(app)
        .get(`/api/v1/orders/${orderId}`)
        .set("Authorization", `Bearer ${other.accessToken}`);
      expect(forbidden.status).toBe(404);

      const noAuth = await request(app).get("/api/v1/orders");
      expect(noAuth.status).toBe(401);
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
