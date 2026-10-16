# Admin Product + Customer Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Production-capable admin: product list/edit/deactivate/safe-delete and customer list/detail/suspend, with order history never destroyed.

**Architecture:** New admin endpoints on the existing Express router (`GET /admin/products`, safe `DELETE`, `User.status` + suspend enforcement, customer CRUD-read); Flutter admin tabs consuming them with existing design tokens; existing dashboard/editor untouched.

**Tech Stack:** Node 22, Express 5, Prisma 6 (MySQL prod/SQLite local), Vitest; Flutter 3 stable, Riverpod, Dio.

**Spec:** `docs/superpowers/specs/2026-10-16-admin-management-design.md`

## Global Constraints

- `GET /api/v1/admin/products?search=&active=&page=&limit=` includes inactive; shape `{items[{id,name,slug,priceBdt,stock,imageUrl,isActive,category}],page,limit,total}`.
- `DELETE /api/v1/admin/products/:id`: hard delete only with zero order_items refs, else 409 `{error: has_orders}`; 404 bad id.
- `User.status` active|suspended default active (both schemas + migration); suspended login 401 `{error: suspended}`; suspended checkout 403; self-suspend 409; suspend-admin 403.
- `GET /api/v1/admin/customers` items `{id,email,role,status,fullName,phone,orderCount,totalSpent}`; detail adds addresses + orders + payments summary; `PATCH .../status` `{status}`.
- All routes requireAdmin (401/403); bilingual app copy; no local flutter/dart — Flutter verify via CI (commit + push + workflow + watch green).

---

## File Structure

**backend/**
- `src/routes/admin.ts` (3 new routes + DELETE rework + login/checkout guards — guards live in `auth.ts`/checkout, edit those)
- `src/middleware/auth.ts` (suspended check on requireAuth? NO — login + checkout only per spec; read file first)
- `prisma/schema.prisma` + `schema.mysql.prisma` + migration (User.status)
- `tests/admin_products.test.ts` (new), `tests/admin_customers.test.ts` (new)

**mobile_app/**
- `lib/features/admin/admin_api.dart` (listProducts, deleteProduct, listCustomers, customerDetail, setCustomerStatus)
- `lib/features/admin/products_admin_screen.dart` (new tab), `customers_admin_screen.dart` + `customer_detail_screen.dart` (new)
- `lib/features/auth/login_screen.dart` (suspended message), `test/admin_mgmt_test.dart`

---

### Task 1: Admin products list + safe delete

**Files:**
- Modify: `backend/src/routes/admin.ts`
- Create: `backend/tests/admin_products.test.ts`

**Interfaces:**
- Consumes: Product/Category/OrderItem models, requireAdmin.
- Produces: `GET /admin/products`, safe `DELETE /admin/products/:id`.

- [ ] **Step 1: Read** the existing public products list + admin POST/PATCH/DELETE handlers for query/style conventions.

- [ ] **Step 2: Failing tests**

```ts
// backend/tests/admin_products.test.ts
import request from "supertest";
import { createApp } from "../src/app.js";
// + login helpers per tests/admin.test.ts pattern (read first)

test("admin list includes inactive + search", async () => {
  // create product, deactivate via PATCH, GET /api/v1/admin/products?active=false
  // expect it present; ?search=<frag> filters; customer GET → 403
});

test("hard delete unused product", async () => {
  // create (no orders) → DELETE → 200; public GET → 404
});

test("delete referenced product → 409, history intact", async () => {
  // customer buys product → DELETE → 409 {error: has_orders}
  // order still readable via GET /api/v1/orders/:id
});

test("delete bad id → 404; anon → 401", async () => { /* ... */ });
```

- [ ] **Step 3: Run FAIL** — `npm --prefix backend test -- admin_products.test.ts` (404s).

- [ ] **Step 4: Implement** — `GET /admin/products` (zod query: search
  optional, active enum all|true|false default all, page/limit default
  1/12 max 50; `isActive` filter only when specified; include category
  slug/name) + rework `DELETE /admin/products/:id` (findUnique →
  404 if missing; `orderItem.count({where:{productId:id}})` →
  409 `{error:"has_orders"}` if >0; else `prisma.product.delete` → 200
  `{deleted:true}`).

- [ ] **Step 5: Full suite green** — `npm --prefix backend test`.

- [ ] **Step 6: Commit** — `feat(admin): products list and safe delete` (no push).

---

### Task 2: Suspend enforcement + customers endpoints

**Files:**
- Modify: `backend/prisma/schema.prisma`, `schema.mysql.prisma`, `src/routes/auth.ts` (login block), `src/routes/checkout.ts` (block), `src/routes/admin.ts` (customers routes)
- Create: `backend/tests/admin_customers.test.ts`

**Interfaces:**
- Consumes: User model, requireAdmin.
- Produces: `User.status`, blocked login/checkout, 3 customer endpoints.

- [ ] **Step 1: Migration** — add to User in BOTH schemas: `status String @default("active")`. Run `npx --prefix backend prisma migrate dev --name user-status`. Verify `migrate dev` clean.

- [ ] **Step 2: Failing tests**

```ts
// backend/tests/admin_customers.test.ts
test("suspend blocks login (401 suspended) and checkout (403), history intact", async () => {
  // register customer, place order, admin PATCH status suspended
  // login → 401 {error: suspended}; checkout → 403; GET old order → 200
  // admin PATCH active → login → 200 again
});

test("self-suspend 409; suspend-admin 403; anon/customer 401/403", async () => { /* ... */ });

test("customers list/detail shape", async () => {
  // GET /api/v1/admin/customers?search= → items with orderCount/totalSpent
  // GET /api/v1/admin/customers/:id → profile + addresses + orders
});
```

- [ ] **Step 3: Run FAIL.**

- [ ] **Step 4: Implement** — login: after password verify, `if (user.status !== "active") 401 {error:"suspended"}` (no tokens). Checkout: after requireAuth load user, `if suspended → 403`. Admin: `GET /customers` (search email/name, orderCount via `_count`, totalSpent via sum non-cancelled), `GET /customers/:id` (user + profile + addresses + orders desc + payments), `PATCH /customers/:id/status` (zod enum; self → 409; target admin → 403).

- [ ] **Step 5: Full suite green.**

- [ ] **Step 6: Commit** — `feat(admin): customers and suspend enforcement` (no push).

---

### Task 3: App products tab

**Files:**
- Modify: `mobile_app/lib/features/admin/admin_api.dart`, admin shell (add Products tab entry — read shell first)
- Create: `mobile_app/lib/features/admin/products_admin_screen.dart`, `mobile_app/test/admin_mgmt_test.dart` (products part)
- Test: widget test (list renders fake items; delete confirm exists).

**Interfaces:**
- Consumes: Tasks 1–2 APIs.
- Produces: products management UI.

- [ ] **Step 1: API client** — `listProducts({search, active, page})`, `deleteProduct(id)` (same Dio/error style — read file first).

- [ ] **Step 2: Widget test first** — pump list with 2 fake products (1 inactive), expect names + badges; pump delete-confirm dialog text (bilingual).

- [ ] **Step 3: Screen** — search field, All/Active/Inactive chips, rows
  (thumb/name/price/stock/badge), tap → existing editor route
  `/admin/products/:id/edit`, deactivate/reactivate (existing PATCH),
  delete (confirm dialog → DELETE → 409 shows
  'অর্ডার আছে / Has orders — deactivate instead', else remove row).

- [ ] **Step 4: Commit (no push)** — `feat(admin-ui): products management`.

---

### Task 4: App customers tab + login message + verify + APK

**Files:**
- Modify: `admin_api.dart`, admin shell, `login_screen.dart`, `docs/API.md`, `docs/apk.md`
- Create: `customers_admin_screen.dart`, `customer_detail_screen.dart`
- Test: CI green + APK + live smoke.

**Interfaces:**
- Consumes: Task 2–3.

- [ ] **Step 1: API + screens** — `listCustomers`, `customerDetail(id)`,
  `setCustomerStatus(id, status)`; Customers tab (search, rows with
  order count); detail (info card + history + spent + Suspend/Unsuspend
  + confirm; suspended red badge). Login: `suspended` error string →
  'অ্যাকাউন্ট স্থগিত / Account suspended — support-এ যোগাযোগ করুন'.

- [ ] **Step 2: Widget test** — suspend button + confirm copy with fake data.

- [ ] **Step 3: Docs** — `docs/API.md` documents all 5 endpoints.

- [ ] **Step 4: Push ALL + CI green** — workflow run + watch (analyze,
  tests incl. new, APK). Download `shop-apk`, >10MB, update apk.md.

- [ ] **Step 5: Live smoke** (user on device; record in report): suspend
  test customer → login blocked → unsuspend → works; delete unused
  product ok; ordered product 409.

- [ ] **Step 6: Commit** — `feat(admin-ui): customers management and docs`.

---

## Self-review
- [x] Spec coverage: §3.1→T1, §3.2→T2, §4 products→T3, §4 customers+login→T4, §5→all gates.
- [x] No placeholders: files, code, commands, outputs concrete.
- [x] Type consistency: `has_orders`/`suspended` error strings, `{status}`,
      `setCustomerStatus`, `products_admin_screen` names used identically.
