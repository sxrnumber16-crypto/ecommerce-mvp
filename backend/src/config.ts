const isProd =
  process.env.NODE_ENV === "production" ||
  (process.env.RAILWAY_ENVIRONMENT ?? "") !== "";

function requiredSecret(
  name: "JWT_ACCESS_SECRET" | "JWT_REFRESH_SECRET",
  fallback: string,
): string {
  const value = process.env[name] ?? fallback;
  if (isProd && (value === fallback || value.trim() === "")) {
    throw new Error(
      `${name} must be set to a strong value in production (refusing to boot with a demo secret)`,
    );
  }
  return value;
}

export const config = {
  host: "0.0.0.0",
  port: Number(process.env.SERVER_PORT ?? process.env.PORT ?? 3000),
  storeName: process.env.STORE_NAME ?? "Orvix Shop",
  deliveryFeeBdt: Number(process.env.DELIVERY_FEE_BDT ?? 60),
  jwtAccessSecret: requiredSecret("JWT_ACCESS_SECRET", "dev-access-secret"),
  jwtRefreshSecret: requiredSecret(
    "JWT_REFRESH_SECRET",
    "dev-refresh-secret",
  ),
  databaseUrl: process.env.DATABASE_URL ?? "",
};
