# Database setup

## Local (SQLite)

```powershell
cd backend
npm ci
Copy-Item .env.example .env   # then edit placeholders
npx prisma migrate deploy     # applies prisma/migrations (dev.db created on first run)
npm run seed                  # 6 categories, 10 products, demo admin
```

Useful variants:

```powershell
npm run dev                   # tsx watch src/index.ts (hot reload)
npm start                     # node dist/index.js (run `npm run build` first)
npm run admin:create -- <email> <password>   # upsert an admin user
```

`DATABASE_URL` for local dev:

```
DATABASE_URL=file:./dev.db
```

(path is relative to `backend/prisma/`.)

## Production (MySQL, e.g. Botkeep)

1. Create an empty MySQL database and obtain its connection URL, e.g.
   `mysql://user:password@host:3306/ecommerce`.
2. Copy the MySQL schema over the default one **on the server** (or set your
   deploy to use it):
   ```bash
   cp backend/prisma/schema.mysql.prisma backend/prisma/schema.prisma
   ```
3. Set `DATABASE_URL` to the MySQL URL in the host's env panel.
4. Deploy with:
   ```bash
   npm ci && npx prisma migrate deploy && npm start
   ```
5. Seed catalog/admin once (`npm run seed` with `ADMIN_EMAIL` /
   `ADMIN_PASSWORD` set), or create the admin via `npm run admin:create`.

> Do not point a production host at a `file:` SQLite URL — SQLite files are
> ephemeral on most PaaS hosts (see `docs/botkeep-deploy.md`).
