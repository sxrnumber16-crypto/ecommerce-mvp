# mobile_app (Ecommerce MVP)

Fresh Flutter scaffold per Task 8. Repo-root `pubspec.yaml` / Flutter
leftovers are intentionally ignored (Task 11 removes/confines them).
Use this folder as the app root:

```powershell
cd mobile_app
flutter pub get
```

## API base URL (`--dart-define=API_BASE_URL`)

`lib/core/config.dart` reads `Config.apiBaseUrl` from
`--dart-define=API_BASE_URL`, default `http://10.0.2.2:3000`.
Effective API root is `Config.apiBaseUrl + /api/v1`.

| Target | Example |
|---|---|
| Android emulator (backend on host `:3000`) | `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000` |
| Physical phone, same LAN (host IP `192.168.1.10`) | `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000` |
| Prod | `flutter run --dart-define=API_BASE_URL=https://api.example.com` |

Optional store name: `--dart-define=STORE_NAME="Demo Shop"`.

## Structure

- `lib/main.dart` — `ProviderScope` root.
- `lib/app.dart` — Material3 + `GoRouter` (`/splash`, `/onboarding`,
  `/login`, `/register`, `/home` shell with Home/Search/Cart/Orders/Profile,
  hidden `/admin` guarded by `role == admin`).
- `lib/core/config.dart` — env config + `bdt()` Taka formatter.
- `lib/core/api_client.dart` — Dio + auth/refresh-401/logging interceptors.
- `lib/core/auth_store.dart` — Riverpod session store
  (`login`/`register`/`refresh`/`me`/`logout`).

## Verification

UNVERIFIED (no Flutter/Dart SDK on this machine — `flutter test` /
`flutter analyze` not run). `test/widget_test.dart` holds the api-base
default expectation for CI with a SDK.
