import request from "supertest";
import { PrismaClient } from "@prisma/client";
import { createApp } from "../src/app.js";
import { isPushEnabled, sendToTopic, sendToUser } from "../src/lib/push.js";

const app = createApp();
const prisma = new PrismaClient();

const uniq = (prefix: string) =>
  `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@test.com`;

async function register() {
  const email = uniq("push-cust");
  const res = await request(app)
    .post("/api/v1/auth/register")
    .send({ email, password: "Password123!" });
  expect(res.status).toBe(201);
  return { email, accessToken: res.body.accessToken as string };
}

const token = (suffix: string) => `fcm-test-token-${suffix}-${Date.now()}`;

describe("push sender (disabled-safe, no creds locally)", () => {
  test("sender disabled without creds, never throws", async () => {
    expect(process.env.FIREBASE_SERVICE_ACCOUNT ?? "").toBe("");
    expect(isPushEnabled()).toBe(false);
    await expect(
      sendToTopic("new_products", {
        title: "t",
        body: "b",
        data: { type: "new_product", productId: "1" },
      }),
    ).resolves.toBeNull();
    const alice = await register();
    const me = await prisma.user.findUniqueOrThrow({ where: { email: alice.email } });
    await expect(
      sendToUser(me.id, { title: "t", body: "b", data: { type: "order_update" } }),
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
