# Testing

## Backend — full suite (real run, 2026-10-14)

Command: `npm --prefix backend test` (vitest, sequential single-fork).
Result: **Test Files 7 passed (7), Tests 47 passed (47), Duration ~40s.**

| File | Tests | Notes |
|---|---|---|
| `tests/checkout.test.ts` | 13 | server-calculated totals, atomic stock decrement, oversell 409, idempotent replay, invalid/inactive product 404, qty 400, foreign address 403/404, duplicate-productId aggregation (incl. over-stock 409, over-10 400), history+detail isolation |
| `tests/auth.test.ts` | 9 | register (role ignored incl. `role:admin` attack), duplicate 409 incl. concurrent-race P2002 path, login ok/401, refresh rotation + old-reuse reject, logout revoke, me 401/200 |
| `tests/admin.test.ts` | 9 | dashboard 403 for customer, product create/edit/deactivate (+ hidden publicly), order list + status flow, invalid status 400, revenue excludes cancelled, lowStock active-only |
| `tests/profile.test.ts` | 7 | profile get/patch, address create+list, isDefault switch, cross-user isolation, validation 400 |
| `tests/catalog.test.ts` | 7 | categories, products list/search/filter/pagination, inactive hidden, detail 404 |
| `tests/health.test.ts` | 1 | `GET /health` → `{ status: "ok" }` |
| `tests/seed.test.ts` | 1 | seed counts (6 categories, 10 products) |

Total: 13 + 9 + 9 + 7 + 7 + 1 + 1 = **47/47 passing**.

## Flutter — UNVERIFIED

No Flutter/Dart SDK on this machine (`flutter` not recognized), so
`flutter test` / `flutter analyze` were **not run**. `mobile_app/test/widget_test.dart`
holds the API-base default expectation for CI with an SDK.

## Live API smoke — 10 steps (real run, 2026-10-14, PASS 10/10)

Server: `npx tsx src/index.ts` with `SERVER_PORT=3457`,
`DATABASE_URL=file:./smoke-task11.db` (fresh `prisma migrate deploy` + `npm run seed`:
6 categories, 10 products, admin `admin@demo.com`). Smoke DB/file and script kept
out of git (temp only). Test emails unique per run (`smoke11+<stamp>@demo.com`).

| # | Step | Result |
|---|---|---|
| 1 | `POST /api/v1/auth/register` customer | PASS 201, `userId=2`, `email=smoke11+mv7pm51d@demo.com` |
| 2 | `POST /api/v1/auth/login` customer | PASS 200, `userId=2` |
| 3 | `GET /api/v1/categories` | PASS 200, `count=6` |
| 4 | `GET /api/v1/products?limit=5` | PASS 200, `total=10`, `firstId=1`, `price=1250` |
| 5 | `POST /api/v1/addresses` (default home, Dhaka) | PASS 201, `addressId=1` |
| 6 | `POST /api/v1/checkout` COD (`productId=1 × 1`, idem `smoke11-<stamp>`) | PASS 201, `orderId=1`, `subtotal=1250`, `delivery=60`, `total=1310`, `payment=COD/unpaid` |
| 7 | `GET /api/v1/orders/1` (readback) | PASS 200, `status=pending`, `total=1310`, `items=1` |
| 8 | `POST /api/v1/auth/login` admin | PASS 200, `adminId=1`, `role=admin` |
| 9 | `PATCH /api/v1/admin/orders/1/status` → `confirmed` | PASS 200, `status=confirmed` |
| 10 | `GET /api/v1/orders/1` as customer | PASS 200, `status=confirmed` (update visible) |

Totals check: `1250 + 60 = 1310` ✓. COD payment `unpaid` ✓.
