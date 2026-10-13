# E-commerce MVP Design — 2026-10-14

## 1. লক্ষ্য ও স্কোপ
- Flutter Android অ্যাপ (real API, persistent data) + Node.js Express API + MySQL/MariaDB (Botkeep)।
- Phase 1 MVP only: customer shopping (16 screens) + Flutter ভেতরে minimal admin। React web admin, analytics, promotion, live bKash/Nagad নয়।
- Store: demo নাম (পরিবর্তনযোগ্য), currency BDT, delivery charge 60৳ (configurable)।
- ভাষা: ব্যবহারকারীর সাথে বাংলা।

## 2. Phase 1 Inspection ফলাফল (verified)
- `F:\Test new model\Flutter`: শুধু pubspec.yaml/README, `lib/` ও `android/` নেই — starter অসম্পূর্ণ, fresh scaffold দরকার (নাম `myapp` রাখা হবে)।
- Env: Node v25.9.0 + npm 11.12.1 + Java 21 আছে; Flutter/Dart SDK নেই; ANDROID_HOME নেই → এই মেশিনে release APK build সম্ভব নয়।
- Botkeep docs verified: Node.js + MySQL/MariaDB/PostgreSQL/Redis profiles, প্রতিটি DB 1 slot, shared pool, `0.0.0.0` + `SERVER_PORT`, Domains দিয়ে HTTPS, Environment-এ secrets, GitHub/ZIP deploy, Console/Files/Backup। Dashboard-এ সরাসরি access নেই, তাই plan limits/private networking অযাচাইকৃত।
- সিদ্ধান্ত: Botkeep-ready কোড + deploy গাইড, local-এ SQLite fallback দিয়ে verify, live deploy ব্যবহারকারী করবেন। মিথ্যা "deployed" দাবি নয়।

## 3. Approach (অনুমোদিত: পদ্ধতি 1)
- Prisma MySQL-prod + SQLite-local fallback, `DATABASE_URL` দিয়ে switch।
- বিকল্প বাতিল: pure-MySQL everywhere (ভারী), static demo (requirement বিরোধী)।

## 4. Architecture
```
mobile_app/ (Flutter) --HTTPS/Dio--> backend/ (Express :PORT) --> MySQL (Botkeep) / SQLite (local test)
                                            |
                                     Prisma migrations, JWT, Argon2id
```
- Backend: Node 22 LTS, Express 5, Prisma 6, Zod, helmet, cors, express-rate-limit, morgan/pino।
- Auth: access JWT 15m + rotating refresh 30d (sha256 hash DB-তে), `Authorization: Bearer`, secure storage মোবাইলে।
- Roles: `customer`, `admin` — public register সবসময় customer; admin শুধু CLI (`npm run admin:create`)।
- Mobile: Material 3, Riverpod, GoRouter, Dio, flutter_secure_storage, feature-based structure।

## 5. Database Schema (min)
- users(id, email unique, password_hash, role, timestamps)
- customer_profiles(id, user_id FK unique, full_name, phone)
- addresses(id, user_id FK, label, line1, city, postal, phone, is_default)
- categories(id, name unique, slug unique, icon, sort)
- products(id, category_id FK, name, slug, description, price_bdt int, stock int, image_url, is_active, timestamps, indexes)
- orders(id, user_id FK, address snapshot, subtotal, delivery_fee, total, status[pending|confirmed|shipped|delivered|cancelled], idempotency_key unique, timestamps)
- order_items(id, order_id FK, product_id FK, name snapshot, unit_price, qty, line_total)
- payments(id, order_id FK unique, method[COD], status[unpaid|paid|failed], amount, provider_ref nullable)
- refresh_sessions(id, user_id FK, token_hash unique, expires_at, revoked_at)
- Seed: 6 categories + 8-10 products + demo admin admin@demo.com (env থেকে, hardcode নয়)।

## 6. API Contract `/api/v1`
- Auth: POST register/login/refresh/logout, GET me
- Catalog: GET categories, GET products?search=&category=&page=, GET products/:id
- Customer: GET/PATCH profile, GET/POST addresses
- Orders: POST checkout {addressId, items[{productId,qty}], idempotencyKey}, GET orders, GET orders/:id
- Admin: GET dashboard (counts, low stock), POST/PATCH/DELETE products, GET orders, PATCH orders/:id/status
- Misc: GET /health (no secrets), CORS prod-allowlist, validation 400, auth 401, forbidden 403, stock conflict 409।
- সব admin route backend `requireAdmin` দিয়ে guard। দাম/মোট সার্ভার হিসাব করবে।

## 7. Checkout ও Inventory Safety
- Validate product active + qty>=1; stock check; transaction-এ order+items+payment(COD unpaid) create + atomic decrement (`UPDATE products SET stock=stock-qty WHERE id AND stock>=qty`)।
- Oversell হলে rollback + 409। Idempotency-Key duplicate রোধ। COD কখনো auto-paid নয়।
- Payment interface: `PaymentProvider` + `CodProvider`; bKash/Nagad missing হলে `Configuration required`।

## 8. Flutter Screens ও Config
- 16 customer screens (splash, onboarding, register, login, home, listing, search/filter, details, cart, address, checkout summary, COD place, confirmation, my orders, order details, profile) + BottomNav + cart badge + BDT format + light/dark + loading/empty/error।
- Admin section: login-এর পর role=admin হলে dashboard, product create/edit/deactivate, orders list, status update, payment status view।
- API base: `--dart-define API_BASE_URL=` (emulator http://10.0.2.2:3000, ফোন http://<LAN-IP>:3000, prod https://<domain>)। localhost hardcode নয়।

## 9. Testing
- Vitest/Jest: register/login, Argon2id, RBAC (customer 403 admin-এ), catalog + invalid id/qty, COD totals server-side, inventory decrement + oversell 409 + concurrent guard, order history, admin CRUD, unauthorized 401/403।
- Smoke (10 ধাপ): backend start → register → browse → cart → COD → DB verify → admin login → status update → customer-এ updated দেখা।

## 10. Deploy ও APK
- Botkeep: 2 slots (Node + MySQL), Env (DATABASE_URL, JWT secrets, STORE_NAME, DELIVERY_FEE_BDT), start `npm ci && npx prisma migrate deploy && npm start`, HOST 0.0.0.0, PORT=SERVER_PORT||PORT fallback, /health, backup + persistent volume।
- APK: `flutter build apk --release --dart-define API_BASE_URL=https://...`, ফোনে install গাইড। এই env-এ Flutter নেই বলে APK এখানে verify হয়নি — শুধু code + guide।
- Secrets কখনো repo/app-এ নয়; `.env.example` only।

## 11. Deliverables ও Order
- `mobile_app/`, `backend/`, `database/`, `docs/` (setup, API, security, deploy, testing, APK)। `web_admin/` নয়।
- Phases 2-10: backend/DB → auth/RBAC → catalog → Flutter screens → cart/COD → admin UI → test → Botkeep guide → APK guide। প্রতিটি phase-এ report + limits।

## Self-review
- [x] Placeholder নেই (demo মান explicit: 60৳, admin@demo.com)।
- [x] Scope single MVP; web admin/analytics বাদ — consistent।
- [x] Ambiguity দূর: PORT fallback, COD unpaid, role CLI-only, APK unverified明示।
