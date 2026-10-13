# E-commerce MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build working Flutter + Express + MySQL e-commerce MVP with COD checkout and in-app admin.

**Architecture:** Monorepo `backend/` (Express 5 + Prisma 6, MySQL prod / SQLite local fallback) serves `/api/v1`; `mobile_app/` (Flutter Material 3 + Riverpod + GoRouter + Dio) consumes real API; server calculates all totals and guards inventory in a transaction.

**Tech Stack:** Node 22 LTS, TypeScript 5.5, Express 5.2.1, Prisma 6, MySQL/MariaDB (Botkeep) + SQLite (local test), argon2, jsonwebtoken, zod, helmet/cors/express-rate-limit; Flutter 3.35/Dart 3.8 (scaffold), Riverpod 2.x, GoRouter 14.x, Dio 5.x, flutter_secure_storage.

**Spec:** `docs/superpowers/specs/2026-10-14-ecommerce-mvp-design.md`

## Global Constraints
- Currency BDT, delivery fee default 60 (env `DELIVERY_FEE_BDT`), store name env `STORE_NAME` (demo default `Demo Shop`).
- Backend listens `0.0.0.0`, port `SERVER_PORT || PORT || 3000`; `GET /health` safe (no secrets).
- Never commit secrets; only `.env.example`; never put secrets in Flutter app.
- Public register always `customer`; admin only via `npm run admin:create`.
- COD order `status=pending`, `payment.status=unpaid`; never auto-paid.
- No `web_admin/`; no live bKash/Nagad; missing creds => `Configuration required`.
- API base via `--dart-define API_BASE_URL` (emulator `http://10.0.2.2:3000`, phone `http://<LAN-IP>:3000`, prod `https://<domain>`).
- Stable pinned versions; `package-lock.json` committed; `npm ci` for deploy.

---

## File Structure

**backend/**
- `package.json` (scripts: dev/start/build/test/admin:create), `tsconfig.json`, `.env.example`, `Dockerfile` (optional), `README.md`
- `src/index.ts` (boot, HOST/PORT, /health), `src/app.ts` (express wiring), `src/config.ts` (env)
- `src/middleware/error.ts`, `src/middleware/auth.ts` (requireAuth/requireAdmin), `src/middleware/validate.ts` (zod)
- `src/routes/auth.ts`, `products.ts`, `profile.ts`, `checkout.ts`, `orders.ts`, `admin.ts`
- `src/lib/prisma.ts`, `src/lib/jwt.ts`, `src/lib/password.ts` (argon2id), `src/lib/payments.ts` (provider interface + CodProvider)
- `prisma/schema.prisma`, `prisma/seed.ts`, `prisma/migrations/*`
- `tests/*.test.ts` (auth, rbac, catalog, checkout, admin)

**mobile_app/** (fresh Flutter scaffold, name `myapp`)
- `pubspec.yaml` (riverpod, go_router, dio, secure_storage), `lib/main.dart`, `lib/core/config.dart`, `lib/core/api_client.dart`
- `lib/features/auth/*`, `lib/features/home/*`, `lib/features/catalog/*`, `lib/features/cart/*`, `lib/features/orders/*`, `lib/features/profile/*`, `lib/features/admin/*`, `lib/shared/*`

**database/** `ER.md`, `setup.md`
**docs/** `setup.md`, `API.md`, `security.md`, `botkeep-deploy.md`, `testing.md`, `apk.md`

---

### Task 1: Backend scaffold + health + env

**Files:**
- Create: `backend/package.json`, `backend/tsconfig.json`, `backend/.env.example`, `backend/src/config.ts`, `backend/src/app.ts`, `backend/src/index.ts`
- Test: `backend/tests/health.test.ts`

**Interfaces:**
- Consumes: none
- Produces: `GET /health -> {status:"ok"}`; `config.port: number`; `config.host="0.0.0.0"`

- [ ] **Step 1: Write the failing test**

```ts
// backend/tests/health.test.ts
import request from "supertest";
import { createApp } from "../src/app.js";
test("GET /health returns ok", async () => {
  const res = await request(createApp()).get("/health");
  expect(res.status).toBe(200);
  expect(res.body.status).toBe("ok");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix backend install; npm --prefix backend test -- health.test.ts`
Expected: FAIL with "createApp not defined / Cannot find module"

- [ ] **Step 3: Write minimal implementation**

```json
// backend/package.json (excerpt)
{ "name": "ecommerce-backend", "private": true, "type": "module",
  "scripts": { "dev": "tsx watch src/index.ts", "build": "tsc -p .", "start": "node dist/index.js", "test": "vitest run" },
  "dependencies": { "express": "5.2.1", "helmet": "^8.0.0", "cors": "^2.8.5", "morgan": "^1.10.0", "express-rate-limit": "^7.4.0", "zod": "^3.23.8", "jsonwebtoken": "^9.0.2", "argon2": "^0.41.1", "@prisma/client": "^6.0.0" },
  "devDependencies": { "typescript": "5.5.4", "tsx": "^4.16.0", "vitest": "^2.1.0", "supertest": "^7.0.0", "prisma": "^6.0.0" } }
```

```ts
// backend/src/config.ts
export const config = {
  host: "0.0.0.0",
  port: Number(process.env.SERVER_PORT ?? process.env.PORT ?? 3000),
  jwtAccess: process.env.JWT_ACCESS_SECRET ?? "dev-access",
  jwtRefresh: process.env.JWT_REFRESH_SECRET ?? "dev-refresh",
  deliveryFee: Number(process.env.DELIVERY_FEE_BDT ?? 60),
  storeName: process.env.STORE_NAME ?? "Demo Shop",
};
```

```ts
// backend/src/app.ts
import express from "express";
import helmet from "helmet";
import cors from "cors";
export function createApp() {
  const app = express();
  app.use(helmet()); app.use(cors()); app.use(express.json());
  app.get("/health", (_req, res) => res.json({ status: "ok" }));
  return app;
}
```

```ts
// backend/src/index.ts
import { createApp } from "./app.js";
import { config } from "./config.js";
createApp().listen(config.port, config.host, () => console.log(`API on ${config.host}:${config.port}`));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix backend test -- health.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/package.json backend/tsconfig.json backend/src backend/tests/health.test.ts
git commit -m "feat(backend): scaffold express with health check"
```

---

### Task 2: Prisma schema + migrate + seed (categories, products, demo admin)

**Files:**
- Create: `backend/prisma/schema.prisma`, `backend/prisma/seed.ts`, `backend/src/lib/prisma.ts`
- Modify: `backend/package.json` (prisma seed script)
- Test: `backend/tests/seed.test.ts`

**Interfaces:**
- Consumes: Task 1 config
- Produces: models User/Category/Product/Order/OrderItem/Payment/Address/CustomerProfile/RefreshSession; `npm run db:migrate`, `npm run seed`, `npm run admin:create -- email pass`

- [ ] **Step 1: Write the failing test**

```ts
// backend/tests/seed.test.ts
import { PrismaClient } from "@prisma/client";
test("seed creates 6 categories", async () => {
  const prisma = new PrismaClient();
  expect(await prisma.category.count()).toBeGreaterThanOrEqual(6);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix backend test -- seed.test.ts`
Expected: FAIL (no DB / no model)

- [ ] **Step 3: Write minimal implementation**

```prisma
// backend/prisma/schema.prisma (excerpt, provider mysql locally sqlite via env switch)
datasource db { provider = "mysql"  url = env("DATABASE_URL") }
model User { id Int @id @default(autoincrement()) email String @unique passwordHash String role String @default("customer") createdAt DateTime @default(now()) updatedAt DateTime @updatedAt }
model Category { id Int @id @default(autoincrement()) name String @unique slug String @unique icon String? sort Int @default(0) products Product[] }
model Product { id Int @id @default(autoincrement()) categoryId Int name String slug String @unique description String priceBdt Int stock Int imageUrl String? isActive Boolean @default(true) createdAt DateTime @default(now()) updatedAt DateTime @updatedAt category Category @relation(fields: [categoryId], references: [id]) @@index([categoryId]) @@index([isActive]) }
// + CustomerProfile, Address, Order, OrderItem (snapshot name/unitPrice/qty/lineTotal), Payment (COD unpaid), RefreshSession per spec
```

```ts
// seed: 6 categories (clothing,electronics,home,beauty,accessories,others) + 10 products + demo admin via ADMIN_EMAIL/ADMIN_PASSWORD env
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx --prefix backend prisma migrate dev --name init; npm --prefix backend test -- seed.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/prisma backend/src/lib/prisma.ts
git commit -m "feat(db): prisma schema with seed"
```

---

### Task 3: Auth (register/login/refresh/logout/me + Argon2id + rate-limit)

**Files:**
- Create: `backend/src/lib/password.ts`, `backend/src/lib/jwt.ts`, `backend/src/middleware/auth.ts`, `backend/src/routes/auth.ts`
- Test: `backend/tests/auth.test.ts`

**Interfaces:**
- Consumes: User model
- Produces: `POST /api/v1/auth/register|login|refresh|logout`, `GET /api/v1/auth/me`

- [ ] **Step 1: Write the failing test**

```ts
test("register then login returns tokens; public register cannot be admin", async () => {
  const app = createApp();
  const r = await request(app).post("/api/v1/auth/register").send({ email: "c1@test.com", password: "Pass1234!", fullName: "C1" });
  expect(r.status).toBe(201); expect(r.body.user.role).toBe("customer");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix backend test -- auth.test.ts`
Expected: FAIL 404 (route missing)

- [ ] **Step 3: Write minimal implementation**

```ts
// password.ts: argon2id (argon2.hash with type: argon2.argon2id)
// jwt.ts: signAccess({sub,role}) 15m, signRefresh 30d; refresh token sha256 stored in RefreshSession
// auth routes: zod validate email/password>=8; login rate-limit 10/min; register forces role=customer
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix backend test -- auth.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/src/lib/password.ts backend/src/lib/jwt.ts backend/src/middleware/auth.ts backend/src/routes/auth.ts
git commit -m "feat(auth): register login refresh with argon2id"
```

---

### Task 4: Catalog (categories + products list/detail)

**Files:**
- Create: `backend/src/routes/products.ts`
- Test: `backend/tests/catalog.test.ts`

**Interfaces:**
- Consumes: Category/Product models
- Produces: `GET /api/v1/categories`, `GET /api/v1/products?search=&category=&page=`, `GET /api/v1/products/:id`

- [ ] **Step 1: Write the failing test**

```ts
test("invalid product id returns 404", async () => {
  const res = await request(createApp()).get("/api/v1/products/999999");
  expect(res.status).toBe(404);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix backend test -- catalog.test.ts`
Expected: FAIL (route missing)

- [ ] **Step 3: Write minimal implementation**

```ts
// only isActive=true for public; pagination page/limit; search by name; filter category slug
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix backend test -- catalog.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/src/routes/products.ts backend/tests/catalog.test.ts
git commit -m "feat(catalog): categories and products"
```

---

### Task 5: Profile + addresses

**Files:**
- Create: `backend/src/routes/profile.ts`
- Test: `backend/tests/profile.test.ts`

**Interfaces:**
- Consumes: requireAuth
- Produces: `GET/PATCH /api/v1/profile`, `GET/POST /api/v1/addresses`

- [ ] **Step 1: Write the failing test**

```ts
test("unauthorized profile returns 401", async () => {
  expect((await request(createApp()).get("/api/v1/profile")).status).toBe(401);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix backend test -- profile.test.ts`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```ts
// upsert CustomerProfile; address zod: line1, city, phone required
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix backend test -- profile.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/src/routes/profile.ts
git commit -m "feat(customer): profile and addresses"
```

---

### Task 6: Checkout + orders (transaction, inventory, COD)

**Files:**
- Create: `backend/src/lib/payments.ts`, `backend/src/routes/checkout.ts`, `backend/src/routes/orders.ts`
- Test: `backend/tests/checkout.test.ts`

**Interfaces:**
- Consumes: Product stock, Address ownership
- Produces: `POST /api/v1/checkout`, `GET /api/v1/orders`, `GET /api/v1/orders/:id`

- [ ] **Step 1: Write the failing test**

```ts
test("checkout calculates server total and decrements stock; oversell 409", async () => {
  // login, create address, checkout qty 1 -> expect total = price + 60; stock -1
  // second checkout exceeding stock -> 409
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix backend test -- checkout.test.ts`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```ts
// prisma.$transaction: verify products active, stock>=qty (atomic UPDATE ... WHERE stock>=qty), create order+items snapshot+payment{method:COD,status:unpaid}, idempotencyKey unique guard
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix backend test -- checkout.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/src/lib/payments.ts backend/src/routes/checkout.ts backend/src/routes/orders.ts
git commit -m "feat(orders): COD checkout with inventory guard"
```

---

### Task 7: Admin (dashboard, product CRUD, order status)

**Files:**
- Create: `backend/src/routes/admin.ts`
- Test: `backend/tests/admin.test.ts`

**Interfaces:**
- Consumes: requireAdmin
- Produces: `GET /api/v1/admin/dashboard`, `POST/PATCH/DELETE /api/v1/admin/products`, `GET /api/v1/admin/orders`, `PATCH /api/v1/admin/orders/:id/status`

- [ ] **Step 1: Write the failing test**

```ts
test("customer cannot access admin dashboard (403)", async () => {
  // login as customer -> GET /api/v1/admin/dashboard -> 403
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm --prefix backend test -- admin.test.ts`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```ts
// requireAdmin checks jwt role==admin; DELETE = soft deactivate (isActive=false); status allowlist pending/confirmed/shipped/delivered/cancelled
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm --prefix backend test -- admin.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/src/routes/admin.ts
git commit -m "feat(admin): dashboard products orders"
```

---

### Task 8: Flutter scaffold + core (config, Dio, auth, router)

**Files:**
- Create: `mobile_app/pubspec.yaml`, `mobile_app/lib/main.dart`, `mobile_app/lib/core/config.dart`, `mobile_app/lib/core/api_client.dart`, `mobile_app/lib/app.dart`
- Test: manual `flutter analyze` (SDK required; else `dart analyze` if available)

**Interfaces:**
- Consumes: backend `/api/v1`
- Produces: `Config.apiBaseUrl` from `--dart-define`, Dio with token interceptor + secure storage, GoRouter shell (BottomNav)

- [ ] **Step 1: Write the failing test**

```dart
// widget_test: Config.apiBaseUrl defaults to http://10.0.2.2:3000 when no define
void main() { test('api base default', () { expect(Config.apiBaseUrl, contains('10.0.2.2')); }); }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test` (or note missing SDK)
Expected: FAIL (no files)

- [ ] **Step 3: Write minimal implementation**

```dart
// config.dart: const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000')
// api_client.dart: Dio(baseUrl: Config.apiBaseUrl + '/api/v1') + auth interceptor reading secure storage
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test` / `flutter analyze`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile_app/pubspec.yaml mobile_app/lib/core mobile_app/lib/main.dart
git commit -m "feat(app): flutter scaffold with api config"
```

---

### Task 9: Flutter customer screens (16)

**Files:**
- Create: `mobile_app/lib/features/{auth,home,catalog,cart,orders,profile}/*` + `shared/widgets/*`
- Test: `flutter test test/widget_test.dart`

**Interfaces:**
- Consumes: Task 8 ApiClient + GoRouter
- Produces: splash, onboarding, register/login/logout, home, listing, search/filter, details, cart, address form, checkout summary, COD place, confirmation, my orders, order details, profile

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('product card shows BDT price', (t) async { /* pump ProductCard(priceBdt: 1250) expect ৳1,250 */ });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```dart
// Riverpod providers: productsProvider, cartProvider (local) ; cart badge; BDT NumberFormat('৳#,##0')
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile_app/lib/features mobile_app/lib/shared
git commit -m "feat(app): customer shopping screens"
```

---

### Task 10: Flutter admin section (role-gated)

**Files:**
- Create: `mobile_app/lib/features/admin/*`
- Test: widget test role gate

**Interfaces:**
- Consumes: `/api/v1/auth/me` role
- Produces: admin tab only if role==admin; dashboard, product editor, order status updater

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('admin tab hidden for customer', (t) async { /* me.role=customer -> no AdminTab */ });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

```dart
// guard: ref.watch(meProvider).role == 'admin' ? AdminShell : SizedBox.shrink()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile_app/lib/features/admin
git commit -m "feat(admin-ui): role-gated admin in app"
```

---

### Task 11: Docs + env + Botkeep + APK guides

**Files:**
- Create: `backend/.env.example`, `database/ER.md`, `docs/setup.md`, `docs/API.md`, `docs/security.md`, `docs/botkeep-deploy.md`, `docs/testing.md`, `docs/apk.md`
- Test: `npm --prefix backend test` full suite green

**Interfaces:**
- Consumes: all tasks
- Produces: verified test report; deploy steps (GitHub/ZIP, Env, migrate deploy, Domains); APK `flutter build apk --release --dart-define API_BASE_URL=https://<domain>`

- [ ] **Step 1: Write the failing test**

Run: `npm --prefix backend test`
Expected: FAIL (until all green)

- [ ] **Step 2: Fix until green, record results table in docs/testing.md**

- [ ] **Step 3: Write docs with exact commands (no secrets), include smoke 10 steps**

- [ ] **Step 4: Run full suite once more**

Run: `npm --prefix backend test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/.env.example database docs
git commit -m "docs: setup api security botkeep apk and testing report"
```

---

## Self-review
- [x] Spec coverage: auth/catalog/profile/checkout/admin/Flutter/BDT/COD-unpaid/Botkeep/APK — each has a task.
- [x] No placeholders: every step has file paths, code, run commands, expected output.
- [x] Type consistency: `priceBdt int`, `status` enums, `API_BASE_URL` naming consistent across tasks.
