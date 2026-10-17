# Orvix UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox syntax.

**Goal:** Redesign the Orvix Shop Flutter app to a premium dark-navy look using the
Master Prompt tokens, batch by batch, with zero feature changes.

**Architecture:** Update design tokens + theme + shared components first, then restyle
screens in batches. Each batch is a commit + push + green CI.

**Tech Stack:** Flutter (Material 3), Riverpod, GoRouter, cached_network_image, shimmer.

**Spec:** docs/superpowers/specs/2026-10-17-orvix-redesign-design.md

## Global Constraints

- No backend/API/DB changes.
- No new features; keep system-following ThemeMode.
- Keep bilingual copy.
- `flutter analyze` zero issues; `flutter test` green.
- Verify via GitHub Actions CI (no local Flutter SDK).
- No image input available; rely on token values only.

---

## Task 1: Foundation — tokens, theme, shared components

**Files:**
- Modify: `mobile_app/lib/design/tokens/app_colors.dart`
- Modify: `mobile_app/lib/design/theme.dart`
- Modify: `mobile_app/lib/design/components/app_card.dart`
- Modify: `mobile_app/lib/design/components/app_button.dart`
- Modify: `mobile_app/lib/design/components/app_input.dart`
- Modify: `mobile_app/lib/design/components/app_chip.dart`
- Modify: `mobile_app/lib/design/components/section_header.dart`
- Modify: `mobile_app/lib/design/components/state_views.dart`

- [ ] **Step 1:** Update `AppColors` constants to new token values and add `cyan`.
- [ ] **Step 2:** Update `buildDarkTheme`/`buildLightTheme` to use new ColorScheme.
- [ ] **Step 3:** Restyle shared components (card border/shadow, button fill, input outline, chip).
- [ ] **Step 4:** Run `flutter analyze` via CI after commit+push.
- [ ] **Step 5:** Commit.

## Task 2: Home + Search

**Files:**
- Modify: `mobile_app/lib/features/home/home_screen.dart`
- Modify: `mobile_app/lib/features/catalog/search_screen.dart`
- Modify: `mobile_app/lib/design/components/promo_banner.dart`

- [ ] Full-width slider (viewportFraction 1.0, height ~200), token-based card.
- [ ] Category circles + featured grid restyled.
- [ ] Search field/chips/grid restyled.

## Task 3: Product detail

**Files:**
- Modify: `mobile_app/lib/features/catalog/product_detail_screen.dart`

- [ ] Gallery, price, badges, sticky bar restyled with tokens.

## Task 4: Cart flow

**Files:**
- Modify: `mobile_app/lib/features/cart/cart_screen.dart`
- Modify: `mobile_app/lib/features/cart/address_screen.dart`
- Modify: `mobile_app/lib/features/cart/checkout_screen.dart`
- Modify: `mobile_app/lib/features/cart/confirmation_screen.dart`

## Task 5: Orders

**Files:**
- Modify: `mobile_app/lib/features/orders/orders_screen.dart`
- Modify: `mobile_app/lib/features/orders/order_detail_screen.dart`

## Task 6: Profile + Admin

**Files:**
- Modify: `mobile_app/lib/features/profile/profile_screen.dart`
- Modify: `mobile_app/lib/features/admin/*.dart` (admin_screen, products_admin_screen, product_editor_screen, orders_admin_screen, customers_admin_screen, customer_detail_screen)
- Modify: `mobile_app/lib/features/splash/splash_screen.dart`
- Modify: `mobile_app/lib/features/onboarding/onboarding_screen.dart`
- Modify: `mobile_app/lib/features/auth/login_screen.dart`
- Modify: `mobile_app/lib/features/auth/register_screen.dart`

## Task 7: Final verification

- [ ] Push final batch, run CI, download APK to `apk-output/app-release.apk`.
- [ ] Report results.
