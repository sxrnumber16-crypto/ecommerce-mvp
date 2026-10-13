import request from "supertest";
import { createApp } from "../src/app.js";
import { prisma } from "../src/lib/prisma.js";

const app = createApp();
const uniq = (prefix: string) => `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@test.com`;

async function register(email?: string) {
  const e = email ?? uniq("prof");
  const res = await request(app)
    .post("/api/v1/auth/register")
    .send({ email: e, password: "Password123!" });
  expect(res.status).toBe(201);
  return { email: e, user: res.body.user, accessToken: res.body.accessToken as string };
}

describe("profile+addresses", () => {
  test("GET /api/v1/profile returns 401 without token", async () => {
    const res = await request(app).get("/api/v1/profile");
    expect(res.status).toBe(401);
  });

  test("GET /api/v1/profile creates/returns profile", async () => {
    const { accessToken, email } = await register();
    const res = await request(app)
      .get("/api/v1/profile")
      .set("Authorization", `Bearer ${accessToken}`);
    expect(res.status).toBe(200);
    expect(res.body.user.email).toBe(email);
    expect(res.body.profile).toBeDefined();
    expect(res.body.profile.userId).toBe(res.body.user.id);
  });

  test("PATCH /api/v1/profile updates and returns profile", async () => {
    const { accessToken } = await register();
    await request(app)
      .get("/api/v1/profile")
      .set("Authorization", `Bearer ${accessToken}`);
    const res = await request(app)
      .patch("/api/v1/profile")
      .set("Authorization", `Bearer ${accessToken}`)
      .send({ fullName: "Test User", phone: "01700000000" });
    expect(res.status).toBe(200);
    expect(res.body.fullName).toBe("Test User");
    expect(res.body.phone).toBe("01700000000");
    const get = await request(app)
      .get("/api/v1/profile")
      .set("Authorization", `Bearer ${accessToken}`);
    expect(get.body.profile.fullName).toBe("Test User");
  });

  test("addresses empty then create + list", async () => {
    const { accessToken } = await register();
    const empty = await request(app)
      .get("/api/v1/addresses")
      .set("Authorization", `Bearer ${accessToken}`);
    expect(empty.status).toBe(200);
    expect(empty.body).toEqual([]);
    const created = await request(app)
      .post("/api/v1/addresses")
      .set("Authorization", `Bearer ${accessToken}`)
      .send({ line1: "House 1", city: "Dhaka", phone: "01700000001" });
    expect(created.status).toBe(201);
    expect(created.body.line1).toBe("House 1");
    expect(created.body.label).toBe("home");
    const list = await request(app)
      .get("/api/v1/addresses")
      .set("Authorization", `Bearer ${accessToken}`);
    expect(list.status).toBe(200);
    expect(list.body).toHaveLength(1);
    expect(list.body[0].line1).toBe("House 1");
  });

  test("isDefault switch unsets others", async () => {
    const { accessToken } = await register();
    const a1 = await request(app)
      .post("/api/v1/addresses")
      .set("Authorization", `Bearer ${accessToken}`)
      .send({ line1: "House A", city: "Dhaka", phone: "01700000001", isDefault: true });
    expect(a1.status).toBe(201);
    expect(a1.body.isDefault).toBe(true);
    const a2 = await request(app)
      .post("/api/v1/addresses")
      .set("Authorization", `Bearer ${accessToken}`)
      .send({ line1: "House B", city: "Dhaka", phone: "01700000002", isDefault: true });
    expect(a2.status).toBe(201);
    const list = await request(app)
      .get("/api/v1/addresses")
      .set("Authorization", `Bearer ${accessToken}`);
    expect(list.body).toHaveLength(2);
    expect(list.body[0].id).toBe(a2.body.id);
    expect(list.body[0].isDefault).toBe(true);
    const first = list.body.find((a: any) => a.id === a1.body.id);
    expect(first.isDefault).toBe(false);
  });

  test("other-user isolation: A cannot see B address", async () => {
    const a = await register();
    const b = await register();
    const created = await request(app)
      .post("/api/v1/addresses")
      .set("Authorization", `Bearer ${b.accessToken}`)
      .send({ line1: "B House", city: "Dhaka", phone: "01700000009" });
    expect(created.status).toBe(201);
    const listA = await request(app)
      .get("/api/v1/addresses")
      .set("Authorization", `Bearer ${a.accessToken}`);
    expect(listA.body.find((x: any) => x.id === created.body.id)).toBeUndefined();
    // Direct prisma check: address belongs to B, not A
    const row = await prisma.address.findUnique({ where: { id: created.body.id } });
    expect(row).toBeDefined();
    expect(row!.userId).toBe(b.user.id);
    expect(row!.userId).not.toBe(a.user.id);
  });

  test("POST /api/v1/addresses validation 400 missing line1", async () => {
    const { accessToken } = await register();
    const res = await request(app)
      .post("/api/v1/addresses")
      .set("Authorization", `Bearer ${accessToken}`)
      .send({ city: "Dhaka", phone: "01700000001" });
    expect(res.status).toBe(400);
  });
});
