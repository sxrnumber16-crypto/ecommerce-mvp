# Botkeep Deploy — ক্লিক-বাই-ক্লিক গাইড (বাংলা)

> কোড প্রস্তুত, টেস্ট 47/47 পাস। নিচের ধাপগুলো Botkeep প্যানেল থেকে আপনাকেই করতে হবে (আনুমানিক ১৫ মিনিট)।

## যা যা লাগবে
- Botkeep অ্যাকাউন্ট (Founder Free — ৫টা slot)
- এই repo-র `botkeep-backend.zip` ফাইলটা (৫০KB, secret-mukt যাচাইকৃত)
- নিচের Env তালিকার মানগুলো (password/secret আপনি নিজে বানাবেন, কাউকে দেবেন না)

## ধাপ ১ — MySQL সার্ভার বানান
1. Botkeep প্যানেল → Create → Database → **MySQL** (MariaDB দেখালে সেটাও চলবে)।
2. RAM/CPU ছোট allocation দিন (শুরুতে সর্বনিম্নটাই যথেষ্ট)।
3. তৈরি হলে **Database tab** থেকে connection details নোট করুন: host, port, user, password, database নাম।
4. `DATABASE_URL` বানান এই ফরম্যাটে:
   `mysql://USER:PASSWORD@HOST:PORT/DBNAME`

## ধাপ ২ — Node.js সার্ভার বানান
1. Create → Application → **Node.js** (22.x দেখালে সেটাই নিন)।
2. Source: **ZIP upload** → `botkeep-backend.zip` আপলোড করুন।
3. Start command দিন ঠিক এটা:
   `npm run deploy:start`
   (এটা নিজে নিজে করবে: MySQL schema চালু → migrate → build → seed → API start)
4. প্রথমবার deploy-এ ২–৪ মিনিট লাগতে পারে (npm install হয়)।

## ধাপ ৩ — Environment variables বসান (Secrets, কখনো কোডে নয়)
| Key | মান (example — নিজেরটা বানান) |
|---|---|
| `DATABASE_URL` | ধাপ ১-এর `mysql://...` |
| `JWT_ACCESS_SECRET` | লম্বা random string (যেমন ৩২+ অক্ষর) |
| `JWT_REFRESH_SECRET` | আরেকটা আলাদা লম্বা random string |
| `STORE_NAME` | `Demo Shop` (নিজের দোকানের নাম দিতে পারেন) |
| `DELIVERY_FEE_BDT` | `60` |
| `ADMIN_EMAIL` | `admin@demo.com` (নিজের ইমেইল দিতে পারেন) |
| `ADMIN_PASSWORD` | শক্ত password (এটাই admin login password) |
| `PORT` | খালি রাখুন (Botkeep `SERVER_PORT` দেয়, কোড সেটাই ধরবে) |

⚠️ Seed প্রতিবার deploy-এ চলে — admin password সবসময় `ADMIN_PASSWORD`-এর মানই থাকবে। এটা জেনে রাখুন।

## ধাপ ৪ — Domain (HTTPS URL) নিন
1. সার্ভারের **Domains** section থেকে public HTTPS URL নিন/বানান, যেমন `https://xxxx.botkeep.cloud`।
2. সার্ভার Start করুন, **Console**-এ দেখুন: `API on 0.0.0.0:PORT` এসেছে কিনা।

## ধাপ ৫ — Verify (আমাকে URL টা দিন)
1. ব্রাউজারে খুলুন: `https://আপনার-domain/health` → `{"status":"ok"}` আসতে হবে।
2. URL টা আমাকে পাঠান — আমি verify করে দেবো API live কিনা, categories/products আসছে কিনা।
3. তারপর Flutter-এ বসাবেন:
   `flutter build apk --release --dart-define API_BASE_URL=https://আপনার-domain`

## সমস্যা হলে
| Console-এ যা দেখবেন | মানে ও করণীয় |
|---|---|
| `DATABASE_URL is required` | Env-এ DATABASE_URL বসেনি — ধাপ ৩ চেক করুন |
| `Can't reach database` | MySQL সার্ভার stopped, বা host/port ভুল |
| `migration failed` | Database খালি নয়/ভিন্ন schema — MySQL service-এর Data tab থেকে চেক করুন |
| Build error (`tsc`) | ZIP-টা ঠিকঠাক upload হয়েছে কিনা দেখুন; আমাকে Console output পাঠান |

## যাচাই হয়নি যা
- Plan limits (RAM/CPU) ও private networking — প্যানেলে দেখে ছোট allocation দিয়ে শুরু করুন।
- প্রথম deploy-এর পর backup নিয়ে রাখুন (প্যানেলের Backup section)।
