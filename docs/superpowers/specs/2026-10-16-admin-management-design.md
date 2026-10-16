# Admin Product + Customer Management Spec (2026-10-16)

## 1. Goal
Make the in-app admin panel production-capable: full product lifecycle
(list/edit/deactivate/safe-delete) and customer management (list/detail/
suspend). Order history is never destroyed.

## 2. Non-goals
- No bulk import/export, no roles beyond admin/customer, no audit log.

## 3. Backend

### 3.1 Products (requireAdmin, existing guard)
- `GET /api/v1/admin/products?search=&active=all|true|false&page=&limit=`
  → `{items[{id,name,slug,priceBdt,stock,imageUrl,isActive,category}],
  page,limit,total}` — INCLUDES inactive (differs from public list).
- `DELETE /api/v1/admin/products/:id` → hard delete ONLY when zero
  `order_items` reference it; else **409** `{error: has_orders}`.
  Invalid id → 404.
- Existing POST/PATCH (incl. isActive toggle) unchanged.

### 3.2 Customers (requireAdmin)
- `User.status`: `active|suspended`, default `active` (migration on both
  sqlite + mysql schemas).
- Login with suspended → **401** `{error: suspended}` (no token issued).
  Checkout with suspended → **403**. History/orders untouched.
- Admin CANNOT suspend self (own id → 409) and cannot suspend other
  admins (role check → 403).
- `GET /api/v1/admin/customers?search=&page=` →
  `{items[{id,email,role,status,fullName,phone,orderCount,totalSpent}],…}`.
- `GET /api/v1/admin/customers/:id` → profile + addresses + orders
  (id,total,status,createdAt) + payments summary.
- `PATCH /api/v1/admin/customers/:id/status` `{status: active|suspended}`.

## 4. App (admin section, guard unchanged)
- **Products tab**: replaces dashboard entry — search field, All/Active/
  Inactive chips, rows (thumb/name/price/stock/badge), tap → editor
  (existing), swipe/button: deactivate/reactivate + delete (confirm
  dialog; 409 → 'অর্ডার আছে / Has orders — deactivate instead').
- **Customers tab**: list (name/email/order count), detail (info card +
  order history + total spent), Suspend/Unsuspend button + confirm;
  suspended users badged red.
- Customer login screen: `suspended` error → bilingual notice
  ('অ্যাকাউন্ট স্থগিত / Account suspended — support-এ যোগাযোগ করুন').
- Tokens only; dark/light; loading/empty/error states.

## 5. Verification
- Backend Vitest: admin list incl inactive + search; hard delete ok when
  unused; 409 when referenced; 404 bad id; suspend → login 401 +
  checkout 403 + history intact; self-suspend 409; suspend-admin 403;
  customer detail shape; 401/403 anon/customer on all routes.
- App: widget tests (list renders, suspend button wiring with fake api) +
  analyze + CI APK.
- Existing suites green. Live smoke: suspend test customer → login
  blocked → unsuspend → works; delete unused product ok.

## Self-review
- [x] No TBD; paths, enums, codes exact.
- [x] Consistent: history never deleted (409 guard); suspend blocks
      auth+order but preserves data; self/admin protection.
- [x] Scoped: management only; no import/export/audit.
- [x] Unambiguous: response shapes and UI mapping fixed.
