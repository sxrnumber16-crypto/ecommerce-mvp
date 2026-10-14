# Setup (Ecommerce MVP)

## Prereqs

- **Node.js 22** (backend; see `backend/package.json` engines/usage).
- **npm** (ships with Node).
- **Flutter SDK + Android SDK** for the mobile app / APK (see `docs/apk.md`).
- **MySQL** only for production (Botkeep). Local dev uses SQLite, no server needed.

## Backend

```powershell
cd backend
npm ci
Copy-Item .env.example .env   # fill placeholders, never real secrets
npx prisma migrate deploy
npm run seed                  # 6 categories, 10 products, demo admin (admin@demo.com)
npm run dev                   # http://localhost:3000
```

Other commands:

```powershell
npm start                     # prod start: node dist/index.js (after `npm run build`)
npm run admin:create -- <email> <password>   # upsert admin (password >= 8 chars)
npm test                      # full suite, expect 41/41 (see docs/testing.md)
```

Env vars (`backend/.env.example`): `PORT`, `SERVER_PORT`, `DATABASE_URL`
(`file:./dev.db` local, `mysql://…` prod example), `JWT_ACCESS_SECRET`,
`JWT_REFRESH_SECRET`, `STORE_NAME`, `DELIVERY_FEE_BDT`, `ADMIN_EMAIL`,
`ADMIN_PASSWORD`. Placeholders only — never commit real secrets.

## Mobile app

Canonical app root is **`mobile_app/`**:

```powershell
cd mobile_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000   # Android emulator
```

- `10.0.2.2` routes to the host PC from the Android emulator.
- Physical phone on the same Wi-Fi: use your PC's LAN IP, e.g.
  `--dart-define=API_BASE_URL=http://192.168.1.10:3000`
  (replace with your real IPv4; backend binds `0.0.0.0` so LAN works).
- Find the LAN IP with `ipconfig` (look for `IPv4 Address` on Wi-Fi).

> **Repo-root leftovers:** `pubspec.yaml`, `analysis_options.yaml`, etc. at the
> repo root are deprecated starter leftovers. **Do not delete them** (kept as-is);
> `mobile_app/` is the canonical app — always run flutter commands inside it.

## Full-stack smoke (10 steps)

Covered in `docs/testing.md`: register → login → categories → products →
address → checkout COD → order readback → admin login → status PATCH →
customer sees update, against a migrated+seeded SQLite DB on a test port.
