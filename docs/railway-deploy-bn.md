# Railway Deploy — ক্লিক-বাই-ক্লিক গাইড (বাংলা)

> Backend Railway-ready: `backend/railway.toml` (start + `/health` check), কোডে কোনো change লাগেনি।
> Trial: $5 credit, 30 দিন, card ছাড়া। **Trial শেষে ~$5/month (Hobby) লাগবে** — এটা আগে জেনে রাখুন।

## পথ ১ — CLI দিয়ে (সবচেয়ে সহজ, Recommended)

1. Node 16+ থাকলে CLI install করুন:
   `npm i -g @railway/cli`
2. Backend folder-এ যান:
   `cd backend`
3. এক command-এ signup + deploy:
   `railway up -y`
   (ব্রাউজার খুলে login/signup হবে; account না থাকলে ওখানেই বানিয়ে নিন)
4. Domain বানান:
   `railway domain`
   → `https://xxxx.up.railway.app` পাবেন।

## পথ ২ — GitHub দিয়ে

1. এই repo GitHub-এ push করুন।
2. Railway dashboard → New Project → Deploy from GitHub → repo select করুন।
3. Service-এর **Settings → Root Directory** = `backend` বসান।
4. Redeploy করুন।

## তারপর — MySQL লাগান (দুই পথেই)

1. Project Canvas → **+ New → Database → MySQL**।
2. Backend service → **Variables** → যোগ করুন:
   `DATABASE_URL` = `${{MySQL.DATABASE_URL}}`
   (service-এর নাম ভিন্ন হলে সেই নাম ব্যবহার করুন)
3. বাকি variables (Secrets — কাউকে দেবেন না):

| Key | মান |
|---|---|
| `JWT_ACCESS_SECRET` | লম্বা random string |
| `JWT_REFRESH_SECRET` | আরেকটা আলাদা random string |
| `STORE_NAME` | `Demo Shop` |
| `DELIVERY_FEE_BDT` | `60` |
| `ADMIN_EMAIL` | `admin@demo.com` |
| `ADMIN_PASSWORD` | শক্ত password (এটাই admin login) |

4. Redeploy করুন। প্রথমবার ২–৪ মিনিট লাগবে। Seed auto-চলবে (categories + products + admin)।
   ⚠️ প্রতিটি deploy-এ seed চলে — admin password সবসময় `ADMIN_PASSWORD`-এর মানই থাকবে।

## Verify (আমাকে URL দিন)

1. ব্রাউজারে: `https://আপনার-domain/health` → `{"status":"ok"}`
2. `https://আপনার-domain/api/v1/categories` → ৬টা category JSON
3. URL টা আমাকে পাঠান — live verify করে দেবো।
4. তারপর APK:
   `flutter build apk --release --dart-define API_BASE_URL=https://আপনার-domain`

## সমস্যা হলে

| Logs-এ যা দেখবেন | করণীয় |
|---|---|
| `DATABASE_URL is required` | Variables-এ `DATABASE_URL` বসেনি |
| `Can't reach database` | MySQL service stopped, বা reference নাম ভুল |
| Healthcheck fail | Deploy logs দেখুন; আমাকে পাঠালে বলে দেবো |
| Trial credit শেষ | Hobby $5/mo-তে upgrade (payment method লাগবে) |
