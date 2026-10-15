# Orvix Dark-Navy Concept Reskin Spec (2026-10-16)

## 1. Goal
Restyle the Flutter app to the approved Orvix concept: dark-navy-first
theme with electric-blue accents, concept layouts (hero banner, category
circles, deal cards, dark login/splash, bottom nav), using EXISTING
features only. Replaces the teal Premium-Minimal look.

## 2. Non-goals (explicit)
- NO ratings/reviews, NO discounts engine, NO size selector, NO wishlist
  backend, NO social login, NO forgot-password, NO promos/coupons.
  Concept elements without backend backing are OMITTED, not faked.
- Backend zero change. No new packages (fl_chart etc. already present).

## 3. Palette & type
- Dark (default): bg `#0A1428`, surface `#12203A`, card `#16294A`,
  primary `#2E7CF6`, onPrimary white, text `#F2F6FF`, muted `#8EA0BF`,
  success/amber/error unchanged semantics.
- Light: bg `#F5F7FC`, surface white, text navy `#0A1428`,
  primary same blue.
- Plus Jakarta Sans throughout; price bold; bilingual labels kept.

## 4. Tokens & components (edit in place)
- `AppColors`: new navy/blue values (light + dark); teal seed REPLACED.
- `theme.dart`: dark-first (system-aware both modes as today).
- `AppCard`: navy surface + 1px blue-tinted border, radius 16.
- `AppButton`: electric-blue pill; ghost = blue outline.
- Bottom nav (`ScaffoldWithNav`): dark bar, blue active pill.
- New `PromoBanner` component (gradient navy→blue + title + CTA).
- Category circles + deal-card styles in home/catalog screens.

## 5. Screens (same routes, data, logic)
- Splash/login/register: navy gradient + Orvix logo asset + blue buttons.
- Home: banner carousel + category circles + deals grid + best-sellers.
- Search/category/detail/cart/checkout/orders/profile: same info/calls,
  navy cards, blue accents; stock badges kept; NO ratings/sizes/discounts.
- Admin: navy stat cards; fl_chart line/bar/donut recolored blue family.
- Diagnostics + network test: navy styling only.

## 6. Verification
- `flutter analyze` zero-issue; `flutter test` green (existing widget tests
  updated only if text/color assertions break — behavior assertions stay).
- Full CI APK; install smoke: login → browse → cart → COD → admin.
- Backend suite untouched (no backend change).

## Self-review
- [x] No TBD; hex values, files, and omissions explicit.
- [x] Consistent: look-only — every omitted concept element named in §2.
- [x] Scoped: single re-theme; no feature creep.
- [x] Unambiguous: token file paths and component changes fixed.
