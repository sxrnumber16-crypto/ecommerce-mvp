# Admin Analytics + Payment Toggle Spec (2026-10-15)

## 1. Goal
Make the in-app admin panel feel like a real business dashboard (graphs,
not just numbers) and let the admin record cash collection on COD orders.
Push notifications are explicitly OUT of this spec (next sub-project, needs
user-created Firebase project).

## 2. Non-goals
- No Firebase/FCM, no new packages beyond `fl_chart`.
- Existing `/admin/dashboard` unchanged (old app versions keep working).
- No audit log table; no partial payments; no online payment states.

## 3. Backend

### 3.1 `GET /api/v1/admin/analytics?days=14` (requireAdmin)
- `days`: int 1–90, default 14; else 400.
- Response:
  `{"days":14,"daily":[{"date":"YYYY-MM-DD","orders":n,"revenue":bdt}],`
  `"topProducts":[{"id","name","qty","revenue"} (top 5 by qty)],`
  `"ordersByStatus":{...},"lowStock":[{id,name,stock}] (stock<=5, active)}`
- `daily`/`topProducts` EXCLUDE cancelled orders; revenue = sum(order.total).
- Days with zero activity appear with zeros (continuous series for charts).
- Date bucketing in server local day (documented; single-shop MVP).

### 3.2 `PATCH /api/v1/admin/orders/:id/payment` (requireAdmin)
- Body `{status: "paid"|"unpaid"}` (zod enum), else 400/404.
- Only when payment.method is COD; cancelled orders → 409.
- Toggles payment.status; order.status untouched.
- Returns the order with payment status.

## 4. App — Admin dashboard v2
- Stat cards row (today revenue/orders + totals) from existing dashboard API.
- Revenue line chart (14d default, `fl_chart`, teal) + orders bar chart.
- Days chips 7/14/30 → re-query analytics endpoint.
- Status donut + Top-5 list + low-stock alert cards.
- Order detail (admin): payment dropdown Paid/Unpaid calling the new
  endpoint; payment shown read-only to customers (existing order detail).
- Design tokens only; bilingual labels; dark mode; loading/empty/error.

## 5. Verification
- Backend Vitest: 401 anon / 403 customer on both endpoints; days=0/200 →
  400; daily sums vs seeded orders; cancelled excluded; top-5 order;
  payment toggle paid→unpaid→paid; 409 on cancelled; invalid status 400.
- App: widget test (dashboard renders with fake analytics JSON) +
  `flutter analyze` + full CI APK.
- Existing suites stay green (47 backend + app widget tests).

## Self-review
- [x] No TBD; values exact (days range, enum, chart package).
- [x] Consistent: cancelled excluded everywhere (matches revenue rule);
      payment toggle independent of order status transitions.
- [x] Scoped: analytics + one toggle; FCM explicitly deferred.
- [x] Unambiguous: endpoint paths, response shapes, UI mapping fixed.
