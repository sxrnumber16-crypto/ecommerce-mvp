# Botkeep deploy (backend)

Host the Express + Prisma API on a **Node.js slot** with a **MySQL** database.
(সংক্ষেপ: Node স্লট + MySQL ডাটাবেজ — নিচের env ও start command বসালেই চলবে।)

## 1. What to provision

- One **Node.js** hosting slot (Node 22) for `backend/`.
- One **MySQL** database (same provider/region ideally) + its connection URL.

## 2. Code upload

- **GitHub connect** (preferred): point Botkeep at the repo, service root `backend/`.
- Or **ZIP upload**: zip the `backend/` folder (include `prisma/`, exclude
  `node_modules/`, `.env`, `*.db`).

## 3. Environment variables (host panel)

| Key | Value |
|---|---|
| `DATABASE_URL` | `mysql://user:password@host:3306/ecommerce` |
| `JWT_ACCESS_SECRET` | strong random string (≥ 32 chars) |
| `JWT_REFRESH_SECRET` | strong random string, different from access |
| `STORE_NAME` | e.g. `Demo Shop` |
| `DELIVERY_FEE_BDT` | e.g. `60` |
| `ADMIN_EMAIL` | admin email |
| `ADMIN_PASSWORD` | strong admin password (≥ 8 chars) |
| `SERVER_PORT` or `PORT` | provided by host; app reads `SERVER_PORT` then `PORT`, default `3000` |

Placeholders only — never commit real values to git.

## 4. Build & start command

```bash
npm ci && npx prisma migrate deploy && npm start
```

- Uses the **MySQL schema**: ensure `backend/prisma/schema.prisma` is the MySQL
  variant — copy `prisma/schema.mysql.prisma` over it before/while deploying
  (see `database/setup.md`). `migrate deploy` applies `prisma/migrations/`.
- `npm start` runs `node dist/index.js`; if the host does not run `build`
  automatically, use `npm ci && npm run build && npx prisma migrate deploy && npm start`.
- App binds `HOST 0.0.0.0` and port `SERVER_PORT || PORT`, so host routing works.

## 5. After first deploy

1. Seed once: `npm run seed` (6 categories, 10 products, admin from env),
   or `npm run admin:create -- <email> <password>`.
2. Verify: `GET https://<your-domain>/health` → `{ "status": "ok" }`.
3. Point the app: `flutter build apk --release --dart-define API_BASE_URL=https://<your-domain>` (see `docs/apk.md`).

## 6. Domains, HTTPS, persistence, backups

- Attach your domain in the host panel and enable HTTPS (TLS cert) — required
  before pointing the production APK at it.
- SQLite is **not** suitable on hosts (ephemeral disk) — always MySQL in prod.
- Enable the provider's **MySQL automated backups**; before major changes take a
  manual snapshot/export. Uploaded product images are remote URLs (picsum seeds),
  so no volume persistence is needed for this MVP.

## 7. Could NOT be verified here (user supplies)

- Botkeep plan limits, private networking/VPC options, exact env-panel names,
  buildpack behaviour (whether `build` runs automatically), log/metrics views,
  backup UI and pricing. The steps above follow standard Node+MySQL PaaS
  conventions — adjust names/commands to Botkeep's actual panel.
