# Security

## Passwords — argon2id

- Hashing: `argon2.hash(password, { type: argon2id })` (`backend/src/lib/password.ts`);
  verify swallows errors → `false`. Plaintext is never stored or logged.
- Registration requires `password ≥ 8 chars`; admin:create enforces the same.

## JWT + rotation

- Access token: `{ sub: userId, role }`, HS256, **15 min** (`signAccessToken`).
- Refresh token: `{ sub, jti }`, HS256, **30 days**; random `jti` guarantees
  uniqueness so two tokens issued in the same second never collide on storage.
- Only **SHA-256 hashes** of refresh tokens are stored (`RefreshSession.tokenHash`);
  raw tokens live only in client hands.
- `/refresh` verifies JWT → looks up session → rejects revoked/expired/mismatched
  → revokes old, issues new pair. Reused (replayed) refresh tokens are rejected
  (`401`). `/logout` revokes by token hash (body or `Bearer`).

## RBAC

- Public registration is **always `customer`** — a `role` field in the body is
  stripped/ignored (tested, incl. `role: "admin"` attack case).
- `requireAuth` (Bearer access token → `req.user { id, role }`, else `401`) guards
  profile/addresses/checkout/orders + all admin routes.
- `requireAdmin` adds `role === "admin"` check → `403` otherwise.
- Order/address reads are owner-scoped; cross-user order detail returns `404`
  (no existence oracle); foreign checkout address → `403`.

## Rate limiting & hardening

- `POST /api/v1/auth/login`: 10 req/min per IP (`express-rate-limit`, standard headers).
- `helmet()` secure headers on; `express.json()` bodies; zod validation on every
  mutating route; JSON error handler keeps stack traces off the wire
  (`500 { error: "internal error" }`, logged server-side).
- CORS is **open** (`cors()` defaults) for MVP LAN/emulator testing — restrict
  `origin` to the web_admin/storefront domain if a browser client is added.

## Checkout integrity

- Totals fully server-calculated (`priceBdt × qty`, `DELIVERY_FEE_BDT` from env);
  any client-supplied total is ignored (tamper test in suite).
- Stock decremented atomically: `updateMany({ stock: { gte: qty } })` guard inside
  the order transaction; oversell → `409` with per-item availability.
- `idempotencyKey` (unique, min 8) makes retries safe; cross-user key reuse → `409`.

## Payments — COD only

- Checkout always creates `payment { method: "COD", status: "unpaid" }` via
  `CodProvider`. COD stays `unpaid` until cash is collected (status transitions
  are manual via admin order status, not payment webhooks).
- bKash/Nagad are **not wired**: stubs return `configuration_required` and never
  fake success. No real-money path exists in this build.

## Secrets & ops

- Secrets come from env (`JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`,
  `ADMIN_PASSWORD`, `DATABASE_URL`); `.env.example` holds placeholders only.
  Never commit `.env`. Dev fallbacks (`dev-access-secret`) are for local runs —
  production **must** set strong unique secrets or all sessions are forgeable.
- Demo admin default `admin@demo.com / Demo1234!` is seed-only convenience;
  change `ADMIN_PASSWORD` in production and rotate JWT secrets regularly.
