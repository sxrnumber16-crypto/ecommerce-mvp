export const config = {
  host: "0.0.0.0",
  port: Number(process.env.SERVER_PORT ?? process.env.PORT ?? 3000),
  storeName: process.env.STORE_NAME ?? "Orvix Shop",
  deliveryFeeBdt: Number(process.env.DELIVERY_FEE_BDT ?? 60),
  jwtAccessSecret: process.env.JWT_ACCESS_SECRET ?? "dev-access-secret",
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET ?? "dev-refresh-secret",
  databaseUrl: process.env.DATABASE_URL ?? "",
};
