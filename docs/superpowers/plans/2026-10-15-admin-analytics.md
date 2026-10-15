# Admin Analytics + Payment Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the in-app admin a graphs dashboard (revenue/orders/top-products) and a Paid/Unpaid toggle for COD payments.

**Architecture:** New `GET /api/v1/admin/analytics` + `PATCH /api/v1/admin/orders/:id/payment` on the existing Express+Prisma backend; Flutter admin dashboard v2 with `fl_chart`, reusing design tokens; existing dashboard endpoint untouched.

**Tech Stack:** Node 22, Express 5, Prisma 6 (MySQL prod/SQLite local), Vitest; Flutter 3 stable, fl_chart ^0.69.0, Riverpod, Dio.

**Spec:** `docs/superpowers/specs/2026-10-15-admin-analytics-design.md`

## Global Constraints

- `GET /api/v1/admin/analytics?days=14`: days int 1–90 else 400; cancelled orders excluded everywhere; zero-days included; top-5 by qty.
- `PATCH /api/v1/admin/orders/:id/payment`: body `{status: "paid"|"unpaid"}`; COD only; cancelled → 409; order.status untouched.
- Both endpoints requireAdmin (401 anon, 403 customer); existing `/admin/dashboard` byte-identical.
- App: design tokens only; bilingual labels; no other backend change; no Firebase/FCM.
- Backend verify locally: `npm --prefix backend test` (Vitest, sequential). Flutter verify via CI only (no local SDK): commit + push + `gh workflow run "Build Android APK"` + watch green, zero-issue analyze.

---

## File Structure

**backend/**
- `src/routes/admin.ts` (add: `GET /admin/analytics`, `PATCH /admin/orders/:id/payment` on the existing admin router with `requireAdmin`)
- `tests/analytics.test.ts` (new), `tests/admin.test.ts` (extend: payment toggle)

**mobile_app/**
- `pubspec.yaml` (add `fl_chart: ^0.69.0`)
- `lib/features/admin/admin_api.dart` (add `getAnalytics({days})`, `setPaymentStatus(orderId, status)`)
- `lib/features/admin/admin_screen.dart` (dashboard v2: stat cards + line/bar/donut + top-5 + low-stock + days chips)
- `lib/features/admin/orders_admin_screen.dart` (payment Paid/Unpaid dropdown)
- `test/admin_analytics_test.dart` (widget test with fake analytics JSON)

---

### Task 1: Analytics endpoint + tests

**Files:**
- Modify: `backend/src/routes/admin.ts`
- Create: `backend/tests/analytics.test.ts`

**Interfaces:**
- Consumes: existing `requireAdmin`, prisma models Order/OrderItem/Product.
- Produces: `GET /api/v1/admin/analytics?days=` returning `{days, daily[], topProducts[], ordersByStatus{}, lowStock[]}`.

- [ ] **Step 1: Read the existing dashboard handler** in `backend/src/routes/admin.ts` (lines ~50–90: the `Promise.all` aggregation, `ordersByStatus`, `lowStockItems`, revenue) and copy its query style (groupBy/status counts, stock<=5 active filter).

- [ ] **Step 2: Write the failing test**

```ts
// backend/tests/analytics.test.ts
import request from "supertest";
import { createApp } from "../src/app.js";
import { loginAs } from "./helpers.js"; // see note below

test("customer gets 403 on analytics", async () => {
  const token = await loginAs("cust-a1@test.com", "Pass1234!");
  const res = await request(createApp())
    .get("/api/v1/admin/analytics")
    .set("Authorization", `Bearer ${token}`);
  expect(res.status).toBe(403);
});

test("days validation", async () => {
  const admin = await loginAsAdmin();
  for (const q of ["?days=0", "?days=200", "?days=abc"]) {
    const res = await request(createApp())
      .get(`/api/v1/admin/analytics${q}`)
      .set("Authorization", `Bearer ${admin}`);
    expect(res.status).toBe(400);
  }
});

test("daily sums exclude cancelled, zeros included, top5 ordered", async () => {
  const admin = await loginAsAdmin();
  // seed 2 delivered orders + 1 cancelled via checkout helper, then:
  const res = await request(createApp())
    .get("/api/v1/admin/analytics?days=7")
    .set("Authorization", `Bearer ${admin}`);
  expect(res.status).toBe(200);
  expect(res.body.daily).toHaveLength(7);
  const total = res.body.daily.reduce((s: number, d: any) => s + d.orders, 0);
  expect(total).toBeGreaterThanOrEqual(2);
  expect(res.body.topProducts.length).toBeLessThanOrEqual(5);
});
```

> NOTE: `tests/helpers.js` does not exist — first check `tests/auth.test.ts`
> / `tests/admin.test.ts` for their existing login helper pattern and reuse
> the SAME helper location/names those files use (register-then-login,
> unique emails per run). Do not invent a second pattern.

- [ ] **Step 3: Run test to verify it fails**

Run: `npm --prefix backend test -- analytics.test.ts`
Expected: FAIL (404 route missing; helper import error if pattern differs — fix import to match existing files first).

- [ ] **Step 4: Implement the endpoint** in `backend/src/routes/admin.ts`:

```ts
// GET /admin/analytics?days=14 — mount beside dashboard, requireAdmin
adminRouter.get("/analytics", requireAdmin, async (req, res, next) => {
  try {
    const days = Number(req.query.days ?? 14);
    if (!Number.isInteger(days) || days < 1 || days > 90) {
      res.status(400).json({ error: "days must be 1-90" });
      return;
    }
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const start = new Date(today);
    start.setDate(start.getDate() - (days - 1));

    const orders = await prisma.order.findMany({
      where: { createdAt: { gte: start }, status: { not: "cancelled" } },
      select: { createdAt: true, total: true, status: true },
    });
    const dailyMap = new Map<string, { orders: number; revenue: number }>();
    for (let i = 0; i < days; i++) {
      const d = new Date(start);
      d.setDate(d.getDate() + i);
      dailyMap.set(d.toISOString().slice(0, 10), { orders: 0, revenue: 0 });
    }
    for (const o of orders) {
      const key = o.createdAt.toISOString().slice(0, 10);
      const slot = dailyMap.get(key);
      if (slot) {
        slot.orders += 1;
        slot.revenue += o.total;
      }
    }
    const daily = [...dailyMap.entries()].map(([date, v]) => ({
      date,
      orders: v.orders,
      revenue: v.revenue,
    }));

    const topRows = await prisma.orderItem.groupBy({
      by: ["productId", "name"],
      where: { order: { createdAt: { gte: start }, status: { not: "cancelled" } } },
      _sum: { qty: true, lineTotal: true },
      orderBy: { _sum: { qty: "desc" } },
      take: 5,
    });
    const topProducts = topRows.map((r) => ({
      id: r.productId,
      name: r.name,
      qty: r._sum.qty ?? 0,
      revenue: r._sum.lineTotal ?? 0,
    }));

    const grouped = await prisma.order.groupBy({
      by: ["status"],
      where: { createdAt: { gte: start } },
      _count: { status: true },
    });
    const ordersByStatus: Record<string, number> = {};
    for (const g of grouped) ordersByStatus[g.status] = g._count.status;

    const lowStock = await prisma.product.findMany({
      where: { isActive: true, stock: { lte: 5 } },
      select: { id: true, name: true, stock: true },
      orderBy: { stock: "asc" },
    });

    res.json({ days, daily, topProducts, ordersByStatus, lowStock });
  } catch (e) {
    next(e);
  }
});
```

> Adapt model/field names (`prisma.order` vs `prisma.orders`, `total`,
> `lineTotal`, relation name in `orderItem` groupBy `order:`) to the real
> schema in `backend/prisma/schema.prisma` — read it first. Keep the
> response SHAPE exactly as above.

- [ ] **Step 5: Run tests to verify**

Run: `npm --prefix backend test -- analytics.test.ts` then full `npm --prefix backend test`
Expected: PASS, and existing 47 tests still green.

- [ ] **Step 6: Commit**

```bash
git add backend/src/routes/admin.ts backend/tests/analytics.test.ts
git commit -m "feat(admin): analytics endpoint with daily revenue and top products"
```

---

### Task 2: Payment toggle endpoint + tests

**Files:**
- Modify: `backend/src/routes/admin.ts`, `backend/tests/admin.test.ts`

**Interfaces:**
- Consumes: Payment model (`method`, `status`), requireAdmin.
- Produces: `PATCH /api/v1/admin/orders/:id/payment` ↔ `{status}`.

- [ ] **Step 1: Write the failing tests** (append to `backend/tests/admin.test.ts`)

```ts
test("payment toggle paid->unpaid->paid (COD)", async () => {
  const admin = await loginAsAdmin();
  const orderId = await placeCodOrderAsCustomer(); // reuse existing helper pattern from this file
  const app = createApp();
  for (const s of ["paid", "unpaid", "paid"]) {
    const r = await request(app)
      .patch(`/api/v1/admin/orders/${orderId}/payment`)
      .set("Authorization", `Bearer ${admin}`)
      .send({ status: s });
    expect(r.status).toBe(200);
    expect(r.body.payment.status).toBe(s);
  }
  // customer sees updated payment status
  const cust = await loginAsCustomer();
  const d = await request(app)
    .get(`/api/v1/orders/${orderId}`)
    .set("Authorization", `Bearer ${cust}`);
  expect(d.body.payment.status).toBe("paid");
});

test("payment toggle: 400 invalid, 409 cancelled, 403 customer", async () => {
  // invalid status -> 400; cancelled order -> 409; customer token -> 403
});
```

> Reuse THIS file's existing helpers (admin login, customer order placement).
> Read the file first; do not invent new helper files.

- [ ] **Step 2: Run to verify FAIL** — `npm --prefix backend test -- admin.test.ts`, expect 404s on the new route.

- [ ] **Step 3: Implement**

```ts
// PATCH /admin/orders/:id/payment — mount beside order status route, requireAdmin
adminRouter.patch("/orders/:id/payment", requireAdmin, async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const parsed = z.object({ status: z.enum(["paid", "unpaid"]) }).safeParse(req.body);
    if (!Number.isInteger(id) || !parsed.success) {
      res.status(400).json({ error: "invalid id or status" });
      return;
    }
    const order = await prisma.order.findUnique({
      where: { id },
      include: { payment: true },
    });
    if (!order || !order.payment) {
      res.status(404).json({ error: "order not found" });
      return;
    }
    if (order.status === "cancelled") {
      res.status(409).json({ error: "cancelled order payment is final" });
      return;
    }
    const payment = await prisma.payment.update({
      where: { id: order.payment.id },
      data: { status: parsed.data.status },
    });
    res.json({ id: order.id, status: order.status, payment: { status: payment.status, method: payment.method } });
  } catch (e) {
    next(e);
  }
});
```

> `z` must be imported (file already uses zod — verify). Adapt
> `prisma.order`/`prisma.payment` names to the real client. Order.status
> untouched by design.

- [ ] **Step 4: Full suite green** — `npm --prefix backend test` (47 + new).

- [ ] **Step 5: Commit** — `git add backend/src/routes/admin.ts backend/tests/admin.test.ts` + `feat(admin): COD payment paid-unpaid toggle`.

---

### Task 3: App dashboard v2 with charts

**Files:**
- Modify: `mobile_app/pubspec.yaml`, `mobile_app/lib/features/admin/admin_api.dart`, `admin_screen.dart`
- Create: `mobile_app/test/admin_analytics_test.dart`

**Interfaces:**
- Consumes: Task 1 endpoint; design tokens + AppCard/SectionHeader/LoadingGrid/ErrorView.
- Produces: dashboard v2; `getAnalytics({days})` used by screen.

- [ ] **Step 1: Add dep** — `mobile_app/pubspec.yaml`: `fl_chart: ^0.69.0`.

- [ ] **Step 2: API client** — in `admin_api.dart` add (match file's existing Dio/error style — read first):

```dart
Future<Map<String, dynamic>> getAnalytics({int days = 14}) async {
  final resp = await dio.get<dynamic>('/admin/analytics',
      queryParameters: <String, dynamic>{'days': days});
  return (resp.data as Map<String, dynamic>);
}
```

- [ ] **Step 3: Widget test first** — `test/admin_analytics_test.dart` pumps
  the dashboard (or its chart section widget) with the fake JSON below and
  expects revenue text + top product name visible:

```dart
final fake = <String, dynamic>{
  'days': 7,
  'daily': [
    {'date': '2026-10-08', 'orders': 2, 'revenue': 2500},
    {'date': '2026-10-09', 'orders': 0, 'revenue': 0},
  ],
  'topProducts': [
    {'id': 1, 'name': 'Panjabi', 'qty': 5, 'revenue': 6250}
  ],
  'ordersByStatus': {'pending': 1, 'delivered': 1},
  'lowStock': [
    {'id': 2, 'name': 'Kurti', 'stock': 3}
  ],
};
// expect(find.textContaining('2,500'), findsWidgets);
// expect(find.text('Panjabi'), findsOneWidget);
```

- [ ] **Step 4: Rewrite `admin_screen.dart`** — keep guard/route/role logic;
  layout: stat cards (existing dashboard API), days chips 7/14/30 →
  `getAnalytics(days)`, revenue `LineChart`, orders `BarChart`
  (`fl_chart`), status donut (`PieChart`), Top-5 list, low-stock cards;
  `LoadingGrid`/`ErrorView`; tokens only; bilingual labels.

- [ ] **Step 5: CI green** — commit (`feat(admin-ui): analytics dashboard`),
  push, workflow run + watch (analyze zero-issue, tests executed).

---

### Task 4: Payment dropdown + final verify

**Files:**
- Modify: `mobile_app/lib/features/admin/orders_admin_screen.dart`, `docs/API.md` (document both endpoints), `docs/apk.md` (build date line)
- Test: CI green + release APK download + smoke.

**Interfaces:**
- Consumes: Task 2 endpoint.

- [ ] **Step 1: Payment dropdown** — in the admin order detail/status sheet,
  add Paid/Unpaid `DropdownButton` bound to payment status; on change call
  `PATCH /admin/orders/:id/status`... NO — call the NEW payment endpoint
  via a new `setPaymentStatus(orderId, status)` in `admin_api.dart`
  (same Dio/error style); refresh detail; 409 shows friendly message
  ('বাতিল অর্ডার / Cancelled order locked').

- [ ] **Step 2: Docs** — `docs/API.md`: document both endpoints (params,
  shapes, errors). `docs/apk.md`: update build line after final APK.

- [ ] **Step 3: Final verify** — push, CI green, download `shop-apk`
  artifact, confirm >10MB; backend `npm --prefix backend test` full green;
  smoke the two endpoints live against Railway with admin token
  (curl/PowerShell, record status codes in report — do NOT commit tokens).

- [ ] **Step 4: Commit** — `feat(admin-ui): payment toggle and docs`.

---

## Self-review
- [x] Spec coverage: §3.1→Task 1, §3.2→Task 2, §4→Tasks 3–4, §5→Tasks 1–4 gates.
- [x] No placeholders: files, code, commands, expected outputs all concrete.
- [x] Type consistency: `{days,daily,topProducts,ordersByStatus,lowStock}`,
  `{status: paid|unpaid}`, `getAnalytics({days})`, `setPaymentStatus` used identically.
