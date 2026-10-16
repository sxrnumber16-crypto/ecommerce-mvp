# Push Notifications v1 Spec (2026-10-16)

## 1. Goal
Real push via FCM: (A) admin adds product → ALL customers notified
(tap opens the product); (B) admin changes order status → THAT customer
notified (tap opens the order). Works whether app is open or not, as
long as the phone has internet. Android only.

## 2. Non-goals
- No iOS. No admin-new-order alerts. No promotional scheduling.
- No chat/marketing console; topics fixed: `new_products` only.

## 3. Backend (`firebase-admin`)
- Init from `FIREBASE_SERVICE_ACCOUNT` env (full service-account JSON
  string). Absent/invalid → sender disabled + startup warn, NEVER crash.
- New table `device_tokens(id, userId FK, token UNIQUE, createdAt)` +
  migration.
- `POST /api/v1/devices` (requireAuth, `{token}` zod string min 10) →
  upsert (userId, token). `DELETE /api/v1/devices` (requireAuth,
  `{token}`) → delete own token (logout path).
- Trigger A: after successful admin product CREATE → `sendToTopic(
  new_products, {title: 'নতুন পণ্য / New product: <name>',
  body: '<price>৳', data: {type: new_product, productId}})`; failures
  logged, never fail the request.
- Trigger B: after admin order-status PATCH success → tokens of
  `order.userId` → `sendEach` `{type: order_update, orderId, status}`
  with bilingual title. No tokens → skip silently.
- Tests: sender unit (mocked admin SDK), trigger-called-on-create,
  disabled-without-creds, token CRUD + cross-user isolation, status send
  targets only the ordering user.

## 4. App
- Deps: `firebase_core`, `firebase_messaging`,
  `flutter_local_notifications` (foreground banner).
- `google-services.json` committed at `mobile_app/google-services.json`;
  CI copies to `android/app/` + applies GMS plugin to generated gradle
  (verified step, fails loudly).
- `main.dart`: `Firebase.initializeApp()` → permission request →
  subscribe `new_products` → if logged in, register token via
  `POST /devices`; re-register on login, `DELETE /devices` on logout,
  token-refresh listener updates backend.
- Tap routing: `new_product` → `/product/:id`; `order_update` →
  `/orders/:id`; handled for foreground/background/terminated.
- Foreground: local-notification banner + badge-safe; no sound定制.

## 5. Secrets & config
- `google-services.json` in git (public IDs only — accepted practice).
- Service-account JSON NEVER in git/chat — Railway env only (done).
- FCM server key not used anywhere (Admin SDK only).

## 6. Verification
- Backend Vitest green (incl. new sender/trigger/token tests).
- CI: analyze + widget tests + APK (FCM build proven by green build).
- LIVE (user, physical phone): admin adds product → customer phone buzzes
  (app closed too); tap → product opens. Admin changes status → customer
  notified; tap → order opens. Screenshot-confirmed.

## Self-review
- [x] No TBD; topics, routes, payloads, packages exact.
- [x] Consistent: tap targets are existing routes; triggers never fail
      the originating request; disabled-mode never crashes.
- [x] Scoped: two triggers only; no console/scheduling/iOS.
- [x] Unambiguous: table shape, endpoints, CI file moves fixed.
