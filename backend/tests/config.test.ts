import { afterEach, expect, test, vi } from "vitest";

afterEach(() => {
  vi.unstubAllEnvs();
  vi.resetModules();
});

test("production refuses demo JWT secrets", async () => {
  vi.stubEnv("NODE_ENV", "production");
  vi.stubEnv("RAILWAY_ENVIRONMENT", undefined);
  vi.stubEnv("JWT_ACCESS_SECRET", "dev-access-secret");
  vi.stubEnv("JWT_REFRESH_SECRET", "dev-refresh-secret");
  await expect(import("../src/config.js")).rejects.toThrow(
    /JWT_ACCESS_SECRET must be set/,
  );
});

test("production boots with strong secrets", async () => {
  vi.stubEnv("NODE_ENV", "production");
  vi.stubEnv("JWT_ACCESS_SECRET", "a9fK2xQ8mZpL4vN7cR1tY6wE3sH0jD5xY7");
  vi.stubEnv("JWT_REFRESH_SECRET", "xY7a9fK2xQ8mZpL4vN7cR1tY6wE3sH0jD5");
  const { config } = await import("../src/config.js");
  expect(config.jwtAccessSecret).toContain("a9fK2x");
});

test("dev boots with demo secrets", async () => {
  vi.stubEnv("NODE_ENV", "test");
  vi.stubEnv("RAILWAY_ENVIRONMENT", undefined);
  vi.stubEnv("JWT_ACCESS_SECRET", "dev-access-secret");
  vi.stubEnv("JWT_REFRESH_SECRET", "dev-refresh-secret");
  const { config } = await import("../src/config.js");
  expect(config.jwtAccessSecret).toBe("dev-access-secret");
});
