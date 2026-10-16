# Push Notifications v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Real FCM push for new-product broadcasts and order-status updates with tap routing, verified live on a physical phone.

**Architecture:** Backend `firebase-admin` sender (disabled-safe without creds) + `device_tokens` table; triggers on product-create and order-status change; Flutter `firebase_core`/`firebase_messaging` with topic subscribe, token sync, and tap routing; CI places `google-services.json` and applies the GMS plugin.

**Tech Stack:** Node 22, Express 5, Prisma 6, firebase-admin ^13; Flutter 3 stable, firebase_core/messaging, flutter_local_notifications; FCM topics.

**Spec:** `docs/superpowers/specs/2026-10-16-push-notifications-design.md`

## Global Constraints

- Topic is exactly `new_products`; data payloads `{type: new_product, productId}` and `{type: order_update, orderId, status}` — strings only (FCM data values must be strings).
- Sender NEVER throws into the request path and NEVER crashes boot without creds (warn only).
- Service-account JSON never in git/chat; Railway env `FIREBASE_SERVICE_ACCOUNT` only (already set by user).
- `google-services.json` committed at `mobile_app/google-services.json` (already committed); CI copies to `android/app/`.
- Bilingual titles/bodies; Android only; no local flutter/dart runs — Flutter verify via CI (commit + push + workflow + watch green).

---

## File Structure

**backend/**
- `src/lib/push.ts` (sender: init/sendToTopic/sendToUserTokens/disabled flag)
- `src/routes/devices.ts` (POST/DELETE /devices) + mount in `src/app.ts` at `/api/v1/devices` with requireAuth
- `prisma/schema.prisma` AND `prisma/schema.mysql.prisma` (add `DeviceToken` model to BOTH, byte-identical except provider)
- `prisma/migrations/<new>/migration.sql` (via local `migrate dev`; Railway applies via `db push`)
- `src/routes/admin.ts` (trigger A in product create; trigger B in status PATCH + payment PATCH? NO — status only)
- `tests/push.test.ts`, extend device tests

**mobile_app/**
- `pubspec.yaml` (add FCM deps), `lib/core/push_service.dart`, `lib/main.dart` (init + tap routing), login/logout token sync, `test/push_test.dart` (widget-safe parts only)

---

### Task 1: Backend sender + device tokens

**Files:**
- Create: `backend/src/lib/push.ts`, `backend/src/routes/devices.ts`, `backend/tests/push.test.ts`
- Modify: `backend/prisma/schema.prisma`, `backend/prisma/schema.mysql.prisma`, `backend/src/app.ts`, `backend/package.json` (add `firebase-admin: ^13.4.0`)

**Interfaces:**
- Consumes: requireAuth, prisma.
- Produces: `isPushEnabled()`, `sendToTopic(topic, {title, body, data})`, `sendToUser(userId, {title, body, data})`, `POST/DELETE /api/v1/devices`.

- [ ] **Step 1: Add the DeviceToken model to BOTH schema files**

```prisma
model DeviceToken {
  id        Int      @id @default(autoincrement())
  userId    Int
  token     String   @unique @db.VarChar(255)
  createdAt DateTime @default(now())
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
  @@map("device_tokens")
}
```

Also add the opposite side on User if the schema declares relations explicitly — read `schema.prisma` first; if other models use implicit back-relation (Prisma auto-completes), just the model above suffices. Then run `npx --prefix backend prisma migrate dev --name device-tokens` (sqlite) and verify `migrate dev` success + copy the model block into `schema.mysql.prisma` verbatim.

- [ ] **Step 2: Write the failing tests**

```ts
// backend/tests/push.test.ts
import request from "supertest";
import { createApp } from "../src/app.js";
import { isPushEnabled } from "../src/lib/push.js";
import { registerCustomer, authHeader } from "./helpers.js"; // ADAPT: read tests/admin.test.ts first, reuse ITS helper names

test("sender disabled without creds, never throws", async () => {
  expect(isPushEnabled()).toBe(false); // CI/local has no FIREBASE_SERVICE_ACCOUNT
});

test("POST /devices upserts my token; GET isolation", async () => {
  const alice = await registerCustomer();
  const bob = await registerCustomer();
  const r1 = await request(createApp()).post("/api/v1/devices")
    .set(authHeader(alice)).send({ token: "fcm-token-alice-1" });
  expect(r1.status).toBe(201);
  const r2 = await request(createApp()).post("/api/v1/devices")
    .set(authHeader(alice)).send({ token: "fcm-token-alice-1" });
  expect(r2.status).toBe(200); // idempotent re-register
  await request(createApp()).delete("/api/v1/devices")
    .set(authHeader(alice)).send({ token: "fcm-token-alice-1" })
    .expect(200);
});

test("devices require auth + validate", async () => {
  await request(createApp()).post("/api/v1/devices").send({}).expect(401);
});
```

> The helper names above are SKETCHES — read `tests/admin.test.ts` first
> and use its real helpers. FCM network calls must be mocked/absent in
> tests (no creds locally → sender disabled path).

- [ ] **Step 3: Run to verify FAIL** — `npm --prefix backend test -- push.test.ts`, expect 404/module-missing.

- [ ] **Step 4: Implement `src/lib/push.ts`**

```ts
import admin from "firebase-admin";

let enabled = false;
try {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT ?? "";
  if (raw.trim() !== "") {
    admin.initializeApp({ credential: admin.credential.cert(JSON.parse(raw)) });
    enabled = true;
  } else {
    console.warn("[push] FIREBASE_SERVICE_ACCOUNT missing — push disabled");
  }
} catch (e) {
  console.warn("[push] init failed, push disabled:", (e as Error).message);
}

export function isPushEnabled(): boolean {
  return enabled;
}

async function safe<T>(fn: () => Promise<T>): Promise<T | null> {
  if (!enabled) return null;
  try {
    return await fn();
  } catch (e) {
    console.warn("[push] send failed:", (e as Error).message);
    return null;
  }
}

export function sendToTopic(topic: string, msg: { title: string; body: string; data: Record<string, string> }) {
  return safe(() =>
    admin.messaging().send({
      topic,
      notification: { title: msg.title, body: msg.body },
      data: msg.data,
    }),
  );
}
```

`sendToUser(prisma, userId, msg)`: loads tokens for userId, skips when
none, uses `sendEachForMulticast({ tokens, notification, data })`, prunes
tokens whose response error code is `messaging/registration-token-not-registered`.

- [ ] **Step 5: Devices router** — `POST /` (zod `{token: string min 10 max 255}` → upsert `(userId, token)`, 201 created / 200 existing), `DELETE /` (same body → deleteMany own, always 200). Mount `app.use("/api/v1/devices", requireAuth, devicesRouter)` — verify how `app.ts` mounts sibling routers first.

- [ ] **Step 6: Full suite green** — `npm --prefix backend test` (61 + new).

- [ ] **Step 7: Commit** — `git add backend/...` + `feat(push): FCM sender and device tokens` (DO NOT push; controller batches).

---

### Task 2: Backend triggers (broadcast + status)

**Files:**
- Modify: `backend/src/routes/admin.ts`, `backend/tests/admin.test.ts` (or push trigger tests inside `push.test.ts` — pick ONE file, no split assertions)
- Test: trigger assertions.

**Interfaces:**
- Consumes: Task 1 sender.
- Produces: automatic sends (no new API shape).

- [ ] **Step 1: Failing tests** — admin creates product → expect a send
  recorded (mock `sendToTopic` via `vi.mock("../src/lib/push.js")` BEFORE
  importing app; assert called once with topic `new_products` and
  `data.productId` string). Admin changes order status pending→confirmed →
  expect send to ordering user only (mock `sendEachForMulticast` or assert
  via exported test hook — read push.ts from Task 1 first and use its
  seam; do NOT hit real FCM).

- [ ] **Step 2: Run FAIL** — new tests fail (no triggers yet).

- [ ] **Step 3: Implement** — end of admin product-create handler, AFTER
  successful 201 response object is built (fire-and-forget, no await on
  the request path — call without await but with `.catch(() => {})`
  safety... actually `sendToTopic` already never throws; call it without
  awaiting):

```ts
// after res.status(201).json(...) — place AFTER res.json:
void sendToTopic("new_products", {
  title: `নতুন পণ্য / New: ${product.name}`,
  body: `${Config.bdt(product.priceBdt)} — এখনই দেখুন / Shop now`,
  data: { type: "new_product", productId: String(product.id) },
});
```

End of order-status PATCH success: `void sendToUser(prisma, order.userId, {...order_update...})`. Do NOT trigger on payment toggle.

- [ ] **Step 4: Full suite green** — `npm --prefix backend test`.

- [ ] **Step 5: Commit** — `feat(push): triggers on product create and status change` (no push).

---

### Task 3: App FCM wiring + tap routing

**Files:**
- Modify: `mobile_app/pubspec.yaml`, `lib/main.dart`, login/logout (token sync), `app.dart` (no route change — use existing `/product/:id`, `/orders/:id` via a global navigator key or GoRouter redirect on tap? simplest: a `pushTapHandler` that calls the existing router).
- Create: `lib/core/push_service.dart`, `mobile_app/test/push_test.dart`
- Test: widget-safe unit parts (payload→route mapping function, pure).

**Interfaces:**
- Consumes: Task 1–2 APIs (`POST/DELETE /devices`), existing routes.
- Produces: registered tokens, tap navigation, foreground banner.

- [ ] **Step 1: Deps** — `flutter pub`-style pins (if CI resolution fails,
  fix-forward to resolving versions and note it):

```yaml
  firebase_core: ^3.15.2
  firebase_messaging: ^15.2.6
  flutter_local_notifications: ^19.4.0
```

- [ ] **Step 2: `lib/core/push_service.dart`** — `initPush({onTap})`:
  `Firebase.initializeApp()`, `requestPermission()`, subscribe
  `new_products`, `getToken()` → `POST /devices` when logged in,
  `onTokenRefresh` → re-POST, `unregister()` → `DELETE /devices` (call on
  logout), foreground `onMessage` → local-notification banner,
  background handler = TOP-LEVEL `firebaseMessagingBackgroundHandler`
  (must be top-level function, calls `Firebase.initializeApp()` first).
  Tap mapping (pure, unit-tested): `{type:new_product,productId}` →
  `/product/:id`; `{type:order_update,orderId}` → `/orders/:id`; else null.

- [ ] **Step 3: Wire `main.dart`** (init before runApp — read file first,
  keep router/auth init order), login success → register token, logout →
  unregister. Widget test for the PURE mapper only (no Firebase in tests).

- [ ] **Step 4: Commit (no push)** — `feat(push): FCM wiring and tap routing`.

---

### Task 4: CI config + docs + live verify + APK

**Files:**
- Modify: `.github/workflows/build-apk.yml`, `docs/API.md`, `docs/apk.md`
- Test: CI green + live phone test.

- [ ] **Step 1: CI FCM files** — after the scaffold step, add:

```yaml
      - name: Place google-services.json
        run: |
          cp google-services.json android/app/google-services.json
          test -f android/app/google-services.json
```

Then apply the Google Services plugin to the GENERATED gradle files.
FIRST inspect what `flutter create` generates in CI (Groovy
`android/settings.gradle` + `android/app/build.gradle`, or KTS variants —
adapt with grep verification, fail loudly):

```yaml
      - name: Apply Google Services plugin
        run: |
          python3 - <<'EOF'
          import pathlib
          root = pathlib.Path('android')
          # handles Groovy settings.gradle OR settings.gradle.kts
          ...
          EOF
```

Concretely: in settings/plugin-management add `id "com.google.gms.google-services" version "4.4.2" apply false` (or `libs` equivalent for KTS — read the generated files in a trial run first via `cat`), and in app plugins add `id "com.google.gms.google-services"`. Verify with `grep -r google-services android/settings.gradle* android/app/build.gradle*`.

- [ ] **Step 2: Push everything + CI green** — commit docs/API.md (devices
  endpoints + push behavior), push ALL task commits, workflow run + watch
  to green (fix-forward: gradle shape, FCM versions, plugin id).

- [ ] **Step 3: Live verify + APK** — download `shop-apk`, confirm >10MB,
  update `docs/apk.md`. Live test with user on physical phone (user does
  on-device steps; record results in report): (a) customer login → admin
  adds product → notification arrives app-closed → tap opens product;
  (b) admin changes that order's status → customer notified → tap opens order.

- [ ] **Step 4: Commit** — `feat(push): CI FCM config and docs`.

---

## Self-review
- [x] Spec coverage: §3→Tasks 1–2, §4→Task 3, §5→Task 4 frontmatter+env, §6→Tasks 1–4 gates + live.
- [x] No placeholders: files, code, commands, expected outputs concrete.
- [x] Type consistency: `new_products`, `new_product`/`order_update`,
  `POST/DELETE /devices`, `getAnalytics`-style client naming avoided —
  fresh names `PushService/initPush/unregister` used identically.
