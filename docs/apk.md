# APK (mobile_app)

> **APK NOT built here** — no Flutter/Android SDK on this machine
> (`flutter` not recognized). Steps below are for a machine with the SDK.

## 1. Install tooling

1. Install the **Flutter SDK** (3.12+) and accept licenses.
2. Install **Android Studio + Android SDK + platform tools** (or command-line tools);
   set `ANDROID_HOME` / `ANDROID_SDK_ROOT`.
3. Verify: `flutter doctor --android-licenses && flutter doctor`.

## 2. Build release APK (production)

```powershell
cd mobile_app
flutter pub get
flutter build apk --release --dart-define API_BASE_URL=https://<your-domain>
```

- Replace `https://<your-domain>` with the deployed backend (HTTPS, see
  `docs/botkeep-deploy.md`). Optional: `--dart-define STORE_NAME="Demo Shop"`.
- Output: `mobile_app/build/app/outputs/flutter-apk/app-release.apk`.
- Install on phone: copy APK and open it (allow install-unknown-apps), or
  `flutter install` / `adb install -r <apk>`.

## 3. LAN-IP dev variant (test backend on PC from a physical phone)

```powershell
cd mobile_app
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
```

- Replace `192.168.1.10` with your PC's LAN IPv4 (`ipconfig` → Wi-Fi).
  Backend binds `0.0.0.0`, so LAN devices can reach it.
- Android emulator instead: `http://10.0.2.2:3000` (default in
  `lib/core/config.dart` — no flag needed).

## Notes

- Effective API root is always `API_BASE_URL + /api/v1`.
- Price display uses ASCII-digit Taka formatting (`Config.bdt()`), safe on all devices.
