# UI/UX Redesign Spec — Premium Minimal Reskin (2026-10-14)

## 1. Goal
Full visual reskin of the Flutter shopping app (`mobile_app/`) to a premium,
modern look referencing best-in-class Flutter e-commerce apps (Dribbble
furniture/fashion shots, FluxStore/Store Up patterns, afgprogrammer UI kit
structure). Backend, APIs, Riverpod state, GoRouter routes, and checkout
logic are UNTOUCHED — look changes, behavior does not.

## 2. Non-goals
- No new backend endpoints, no API contract change (backend 47/47 stays green).
- No new app features (no wishlist backend, no promos engine, no chat/AR).
- No heavy animation packages; no paid fonts/icons.
- Wishlist heart on cards is LOCAL-only visual (shared_preferences optional;
  default in-memory) — explicitly not a backend feature.

## 3. Design language: Premium Minimal
- Clean light canvas + tonal surfaces; Deep Teal primary `#0E7C6B`
  (elevates current brand); warm Amber reserved for price/CTA highlights
  and stock urgency; semantic success/error.
- Bengali + English bilingual labels kept on all user-facing strings.
- Light + derived dark palette (seed-matched, system-aware).
- Plus Jakarta Sans via google_fonts with system-font offline fallback.

## 4. Design tokens (`lib/design/`)
- `tokens/app_colors.dart` — light/dark `ColorScheme`-aligned constants.
- `tokens/app_text.dart` — Display/Headline/Title/Body/Label + `priceBdt`
  style; single font-family switch point.
- `tokens/app_space.dart` — 4/8/12/16/24 spacing constants.
- `tokens/app_radius.dart` — 12/16/24 + pill.
- `tokens/app_shadow.dart` — soft card shadow, lifted sheet shadow.
- `theme.dart` — Material 3 `ThemeData` light/dark built ONLY from tokens
  (no hex in screens).

## 5. Component library (`lib/design/components/`)
- `AppScaffold` (standard padding + app bar), `AppButton`
  (primary/outline/ghost + loading), `AppInput` (validated field).
- `AppCard`, `ProductCard` v2 (cached_network_image + shimmer placeholder,
  discount/stock badges, local wishlist heart, BDT price via `Config.bdt`).
- `AppChip` (category pills), `SectionHeader` (title + see-all).
- `StateViews`: shimmer-grid loading, empty (icon + CTA), error (retry).
- Bottom sheets: qty picker, filter panel, address picker, status timeline.
- Rule: screens compose these; no ad-hoc styling in screens.

## 6. Screen treatments (all 16 customer + admin)
- Splash/onboarding/login/register: branded gradient splash, static
  onboarding pages, validated inputs with friendly bilingual errors.
- Home: hero banner carousel (`carousel_slider`) + category pills +
  featured grid + best-sellers horizontal rail.
- Listing/search: filter bottom-sheet (category/price/in-stock/sort),
  responsive grid, shimmer skeletons.
- Product detail: image gallery + dots, price/stock header, qty stepper,
  sticky bottom Add-to-Cart bar, description/specs section.
- Cart → address → checkout → confirmation: line-item cards with steppers,
  address radio list + form, summary card showing SERVER totals only,
  COD confirm button, animated success state (no fake payment UI).
- Orders: status filter chips + order cards; detail: items + payment +
  vertical status timeline.
- Profile: stats header (orders count), menu rows, logout; light/dark toggle.
- Admin (role-gated, unchanged guard): stat cards dashboard, product
  editor with image-URL preview + deactivate/reactivate, orders list with
  status stepper bottom-sheet, payment status read-only.

## 7. Motion
Subtle only: hero image transitions, bottom-sheet slides, animated
success check, shimmer loading. No Lottie/Rive, no page-transition package.

## 8. Dependencies (stable, pinned)
Add: `cached_network_image ^3.4.0`, `shimmer ^3.0.0`,
`carousel_slider ^5.0.0`, `google_fonts ^6.2.0`.
No other new packages. Resolves with existing Riverpod/GoRouter/Dio.

## 9. Verification
- `flutter analyze` clean (CI gate, zero errors/warnings).
- `flutter test` existing widget tests pass; add ProductCard-v2 BDT test.
- Release APK via `.github/workflows/build-apk.yml`; install + smoke:
  browse → cart → COD order → admin status update.
- Backend suite re-run 47/47 (untouched, sanity only).

## 10. Rollout
Single PR-style change set on `main`: tokens → components → screens →
admin → CI build. Old widgets removed only when their last usage is gone
(no dead code). Root starter leftovers still untouched/deprecated.

## Self-review
- [x] No TBD/TODO; all values explicit (colors, packages, paths).
- [x] Consistent: bilingual labels everywhere; server-totals rule repeated;
      no backend change anywhere.
- [x] Scoped: one reskin, wishlist explicitly local-only to avoid feature
      creep; admin covered so scope matches approved "full reskin".
- [x] Unambiguous: token file paths, component names, and verification
      commands are exact.
