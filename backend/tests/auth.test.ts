import request from "supertest";
import { createApp } from "../src/app.js";

const app = createApp();
const uniq = (prefix: string) => `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@test.com`;

describe("auth", () => {
  test("register creates customer and ignores role field", async () => {
    const email = uniq("reg");
    const res = await request(app)
      .post("/api/v1/auth/register")
      .send({ email, password: "Password123!", role: "admin" });
    expect(res.status).toBe(201);
    expect(res.body.user.email).toBe(email);
    expect(res.body.user.role).toBe("customer");
    expect(res.body.accessToken).toBeDefined();
    expect(res.body.refreshToken).toBeDefined();
  });

  test("register forces customer even when role:admin is sent", async () => {
    const email = uniq("inject");
    const res = await request(app)
      .post("/api/v1/auth/register")
      .send({ email, password: "Password123!", role: "admin" });
    expect(res.status).toBe(201);
    expect(res.body.user.role).toBe("customer");
  });

  test("register duplicate email returns 409", async () => {
    const email = uniq("dup");
    const first = await request(app)
      .post("/api/v1/auth/register")
      .send({ email, password: "Password123!" });
    expect(first.status).toBe(201);
    const second = await request(app)
      .post("/api/v1/auth/register")
      .send({ email, password: "Password123!" });
    expect(second.status).toBe(409);
  });

  test("register concurrent duplicate race returns one 201 + one 409 (P2002 path)", async () => {
    const email = uniq("race");
    const payload = { email, password: "Password123!" };
    const [a, b] = await Promise.all([
      request(app).post("/api/v1/auth/register").send(payload),
      request(app).post("/api/v1/auth/register").send(payload),
    ]);
    const statuses = [a.status, b.status].sort();
    expect(statuses).toEqual([201, 409]);
    const loser = a.status === 409 ? a : b;
    expect(JSON.stringify(loser.body).toLowerCase()).toContain("already");
  });

  test("login ok with valid credentials", async () => {
    const email = uniq("login");
    await request(app).post("/api/v1/auth/register").send({ email, password: "Password123!" });
    const res = await request(app).post("/api/v1/auth/login").send({ email, password: "Password123!" });
    expect(res.status).toBe(200);
    expect(res.body.accessToken).toBeDefined();
    expect(res.body.refreshToken).toBeDefined();
    expect(res.body.user.email).toBe(email);
  });

  test("login wrong password returns 401", async () => {
    const email = uniq("badpass");
    await request(app).post("/api/v1/auth/register").send({ email, password: "Password123!" });
    const res = await request(app).post("/api/v1/auth/login").send({ email, password: "WrongPass999!" });
    expect(res.status).toBe(401);
  });

  test("refresh rotation issues new pair and rejects old reuse", async () => {
    const email = uniq("refresh");
    const reg = await request(app)
      .post("/api/v1/auth/register")
      .send({ email, password: "Password123!" });
    expect(reg.status).toBe(201);
    const r1 = await request(app)
      .post("/api/v1/auth/refresh")
      .send({ refreshToken: reg.body.refreshToken });
    expect(r1.status).toBe(200);
    expect(r1.body.accessToken).toBeDefined();
    expect(r1.body.refreshToken).toBeDefined();
    expect(r1.body.refreshToken).not.toBe(reg.body.refreshToken);
    const reuse = await request(app)
      .post("/api/v1/auth/refresh")
      .send({ refreshToken: reg.body.refreshToken });
    expect(reuse.status).toBe(401);
  });

  test("logout revokes refresh token", async () => {
    const email = uniq("logout");
    const reg = await request(app)
      .post("/api/v1/auth/register")
      .send({ email, password: "Password123!" });
    expect(reg.status).toBe(201);
    const out = await request(app)
      .post("/api/v1/auth/logout")
      .send({ refreshToken: reg.body.refreshToken });
    expect([200, 204]).toContain(out.status);
    const after = await request(app)
      .post("/api/v1/auth/refresh")
      .send({ refreshToken: reg.body.refreshToken });
    expect(after.status).toBe(401);
  });

  test("me returns 401 without token and 200 with token", async () => {
    const noAuth = await request(app).get("/api/v1/auth/me");
    expect(noAuth.status).toBe(401);
    const email = uniq("me");
    const reg = await request(app)
      .post("/api/v1/auth/register")
      .send({ email, password: "Password123!" });
    expect(reg.status).toBe(201);
    const me = await request(app)
      .get("/api/v1/auth/me")
      .set("Authorization", `Bearer ${reg.body.accessToken}`);
    expect(me.status).toBe(200);
    expect(me.body.id).toBeDefined();
    expect(me.body.email).toBe(email);
    expect(me.body.role).toBe("customer");
  });
});
