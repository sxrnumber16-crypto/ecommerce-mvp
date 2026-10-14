# API contract (`/api/v1`)

Base URL: `http://<host>:3000/api/v1` (mobile default via
`--dart-define=API_BASE_URL`, emulator `http://10.0.2.2:3000`).
Auth: `Authorization: Bearer <accessToken>` unless noted. All bodies/returns JSON.

## Conventions

- Success codes: `200` read/update, `201` created.
- Error shape: `{ "error": "<code>", "details"?: <zod flattened | string> }`.
- Common codes: `400 validation`, `401 unauthorized` / `invalid credentials` /
  `invalid refresh token`, `403 forbidden`, `404 not found` (+ specific
  `address not found`, `product not found`), `409` conflicts
  (`email already registered`, `insufficient stock`, `idempotency key in use`,
  `slug already exists`), `500 internal error`.

## Health (no prefix)

```http
GET /health
```

```json
{ "status": "ok" }
```

## Auth (`/auth`, public except /me)

### Register — `POST /api/v1/auth/register`

```json
{ "email": "u@example.com", "password": "Secret123", "fullName": "A", "phone": "017.." }
```

- `password` min 8. Any `role` field in body is **ignored** — always `customer`.
- `201`:
  ```json
  { "user": { "id": 1, "email": "u@example.com", "role": "customer" },
    "accessToken": "<jwt 15m>", "refreshToken": "<jwt 30d>" }
  ```
- `400` validation, `409` `{ "error": "email already registered" }`.

### Login — `POST /api/v1/auth/login` (rate-limited: 10 req/min/IP)

```json
{ "email": "u@example.com", "password": "Secret123" }
```

- `200` same shape as register. `400` validation, `401 invalid credentials`.

### Refresh — `POST /api/v1/auth/refresh`

```json
{ "refreshToken": "<current>" }
```

- Rotates: old session revoked, new pair issued (`200`). Reuse of an old token → `401`.
- `400` validation, `401 invalid refresh token` (bad/expired/revoked/mismatched user).

### Logout — `POST /api/v1/auth/logout`

```json
{ "refreshToken": "<current>" }
```

(or `Authorization: Bearer <refreshToken>`). Revokes the session, `200 { "ok": true }`.
`400` when no token supplied (`refreshToken required`), `400 validation` on bad body.

### Me — `GET /api/v1/auth/me` (auth)

`200 { "id": 1, "email": "u@example.com", "role": "customer" }`, else `401`.

## Catalog (public)

### Categories — `GET /api/v1/categories`

`200` ordered by `sort`:

```json
[{ "id": 1, "name": "Clothing", "slug": "clothing", "icon": "checkroom" }]
```

### Products — `GET /api/v1/products?search=&category=<slug>&page=1&limit=12`

- Active only, `limit` clamped 1–50 (default 12), `page` ≥ 1.
- `category` filters by category slug; `search` matches name/description/slug (contains).
- `200 { "items": [...], "page": 1, "limit": 12, "total": 10 }`; each item embeds
  `category: { "slug", "name" }`.

### Product detail — `GET /api/v1/products/:id`

`200` product (+ category). `404 { "error": "not found" }` for bad id,
missing or inactive product.

## Profile & addresses (auth)

### Get profile — `GET /api/v1/profile`

Auto-creates profile row on first call. `200`:

```json
{ "user": { "id": 1, "email": "u@example.com", "role": "customer" },
  "profile": { "id": 1, "userId": 1, "fullName": null, "phone": null } }
```

### Update profile — `PATCH /api/v1/profile`

```json
{ "fullName": "Ayesha", "phone": "01700000000" }
```

`200` profile row. `400` validation, `401` for unknown user.

### List addresses — `GET /api/v1/addresses`

`200` array, defaults first then oldest.

### Create address — `POST /api/v1/addresses`

```json
{ "label": "home", "line1": "House 1, Road 2", "city": "Dhaka",
  "postal": "1205", "phone": "01700000000", "isDefault": true }
```

`label` defaults `"home"`; `line1`, `city`, `phone` required. `isDefault: true`
unsets other defaults in a transaction. `201` address, `400` validation.

## Checkout (auth) — `POST /api/v1/checkout`

```json
{ "addressId": 1,
  "items": [{ "productId": 1, "qty": 2 }],
  "idempotencyKey": "unique-key-min-8-chars" }
```

- `qty` 1–10, ≥ 1 item; client totals are **never trusted** — subtotal/total are
  server-calculated (`total = subtotal + DELIVERY_FEE_BDT`, default 60).
- `201` order with `items[]` + `payment { method: "COD", status: "unpaid" }`.
- Idempotent replay (same user + key) → `200` same order, no double stock decrement.
- Errors: `400 validation`, `403 forbidden` (someone else's address),
  `404 address/product not found`, `409 insufficient stock`
  (`{ insufficient: [{ productId, available }] }`),
  `409 idempotency key in use` (another user's key / concurrent race).

## Orders (auth, own only)

### List — `GET /api/v1/orders`

`200` array, newest first, each with `items`, `payment`, `_count.items`.
Another user's orders never appear (scoped by `userId`).

### Detail — `GET /api/v1/orders/:id`

`200` order with `items`, `payment`, `address`. Others' ids → `404`
(intentionally indistinguishable from missing). Bad id → `404`.

## Admin (`/admin`, auth + `role: admin`, else `401`/`403`)

### Dashboard — `GET /api/v1/admin/dashboard`

```json
{ "users": 5, "products": 10, "activeProducts": 9,
  "ordersByStatus": { "pending": 2 }, "orders": { "pending": 2 },
  "lowStock": [{ "id": 3, "name": "..", "slug": "..", "stock": 2, "priceBdt": 450, "isActive": true }],
  "lowStockCount": 1, "revenue": 2620, "totalRevenue": 2620 }
```

(`orders` and `totalRevenue` are aliases.) Low stock = `stock <= 5`, top 20.

### Create product — `POST /api/v1/admin/products`

```json
{ "name": "T-Shirt", "categoryId": 1, "description": "", "priceBdt": 499,
  "stock": 20, "imageUrl": "https://..", "isActive": true }
```

Slug auto-generated from name (unique-ified) unless supplied. `201` product;
`400` validation / `category not found`; `409 slug already exists`.

### Update product — `PATCH /api/v1/admin/products/:id`

Any subset of create fields. Same 400/409 rules; unknown id → `404`.

### Delete product — `DELETE /api/v1/admin/products/:id`

Soft delete (`isActive: false`; hidden from public catalog). `200` updated row; `404`.

### List orders — `GET /api/v1/admin/orders?page=1&limit=20`

All users, newest first, `limit` ≤ 100, items include `items`, `payment`,
`user { id, email }`. `200 { items, page, limit, total }`.

### Update order status — `PATCH /api/v1/admin/orders/:id/status`

```json
{ "status": "confirmed" }
```

Enum: `pending | confirmed | shipped | delivered | cancelled`.
`200` updated order (+ items/payment/user). `400` validation, `404` unknown id.
