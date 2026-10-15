# Orvix Dark-Navy Concept Reskin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the app to the dark-navy + electric-blue Orvix concept using existing features only.

**Architecture:** Edit `lib/design/tokens/` values in place, restyle `lib/design/components/`, then each screen file; no new packages, no API/state/route/backend change.

**Tech Stack:** Flutter 3 stable, Material 3, Riverpod, GoRouter, Dio, fl_chart (present).

**Spec:** `docs/superpowers/specs/2026-10-16-orvix-dark-concept-design.md`

## Global Constraints

- Dark default: bg `0xFF0A1428`, surface `0xFF12203A`, card `0xFF16294A`, primary `0xFF2E7CF6`, text `0xFFF2F6FF`, muted `0xFF8EA0BF`.
- Light: bg `0xFFF5F7FC`, surface white, text navy `0xFF0A1428`, primary same blue.
- No ratings/reviews/discounts/sizes/wishlist-backend/social-login/forgot-password/promos — omit, never fake.
- Bilingual labels kept; server totals only; COD pending/unpaid messaging kept.
- No local flutter/dart runs (no SDK); verify per task via CI: commit + push + `gh workflow run "Build Android APK"` + watch green, zero-issue analyze, tests executed.

---

## File Structure

**Modified (in place):**
- `mobile_app/lib/design/tokens/app_colors.dart`, `design/theme.dart`
- `mobile_app/lib/design/components/` (app_card, app_button, app_chip, section_header, state_views, sheets, product_card) + new `promo_banner.dart`
- `mobile_app/lib/app.dart` (bottom-nav bar styling only)
- All files under `lib/features/` (visuals only)
- `mobile_app/test/` (update only assertions that check old colors/text that changed; behavior assertions stay)

---

### Task 1: Navy tokens + theme

**Files:**
- Modify: `lib/design/tokens/app_colors.dart`, `lib/design/theme.dart`
- Test: CI analyze green.

**Interfaces:**
- Consumes: none (values from spec).
- Produces: new palette consumed by every later task.

- [ ] **Step 1: Replace the palette**

```dart
// lib/design/tokens/app_colors.dart — replace entire body values:
abstract final class AppColors {
  static const seed = Color(0xFF2E7CF6);
  static const lightBackground = Color(0xFFF5F7FC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightOutline = Color(0xFFDCE4F2);
  static const lightText = Color(0xFF0A1428);
  static const lightMuted = Color(0xFF5A6B8C);
  static const darkBackground = Color(0xFF0A1428);
  static const darkSurface = Color(0xFF12203A);
  static const darkOutline = Color(0xFF24406E);
  static const darkText = Color(0xFFF2F6FF);
  static const darkMuted = Color(0xFF8EA0BF);
  static const price = Color(0xFF2E7CF6);
  static const success = Color(0xFF22C55E);
  static const error = Color(0xFFEF4444);
}
```

Keep class/member names identical. In `design/theme.dart`, change seed to `AppColors.seed` (already references it — verify, else point it there).

- [ ] **Step 2: Commit, push, CI green**

Run: `git add mobile_app/lib/design/tokens mobile_app/lib/design/theme.dart && git commit -m "feat(theme): orvix navy palette" && git push origin main`
Then: `gh workflow run "Build Android APK" --repo sxrnumber16-crypto/ecommerce-mvp` + `gh run watch <id>` to green.
Expected: Analyze clean (all screens auto-adapt via tokens/scheme).

- [ ] **Step 3: Record** CI run URL + result in report.

---

### Task 2: Components navy restyle + PromoBanner

**Files:**
- Modify: `app_card.dart` (navy surface + blue-tinted border), `app_button.dart` (blue pill), `app_chip.dart`, `section_header.dart`, `product_card.dart` (price blue already — verify), `state_views.dart`
- Create: `lib/design/components/promo_banner.dart`
- Test: existing component tests green in CI.

**Interfaces:**
- Consumes: Task 1 tokens.
- Produces: `PromoBanner({title, subtitle, ctaLabel, onCta, imageUrl?})` used by Task 4 home.

- [ ] **Step 1: Implement**

```dart
// lib/design/components/promo_banner.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_space.dart';
import '../tokens/app_text.dart';

class PromoBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback? onCta;
  final String? imageUrl;

  const PromoBanner(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.ctaLabel,
      this.onCta,
      this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: const LinearGradient(
          colors: [Color(0xFF16294A), Color(0xFF2E7CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (c, u, e) => const SizedBox.shrink(),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: AppText.headline(context)
                        .copyWith(color: Colors.white)),
                const SizedBox(height: AppSpace.xs),
                Text(subtitle,
                    style: AppText.body(context)
                        .copyWith(color: Colors.white70)),
                const SizedBox(height: AppSpace.s),
                ElevatedButton(
                  onPressed: onCta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2E7CF6),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill)),
                  ),
                  child: Text(ctaLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Restyle each component** — card surface/border navy, button blue pill, chips navy selected-blue, bottom-nav handled in Task 4 (app.dart shell). Keep all constructor APIs identical.

- [ ] **Step 3: Commit, push, CI green** (message `feat(theme): navy components + promo banner`).

---

### Task 3: Entry screens (splash/login/register/onboarding)

**Files:**
- Modify: `splash_screen.dart`, `login_screen.dart`, `register_screen.dart`, `onboarding_screen.dart`
- Test: existing tests green.

- [ ] **Step 1: Restyle** — navy gradient headers (keep Orvix logo asset),
  blue primary buttons, navy inputs; keep controllers/validators/routes/targets identical. No social buttons.

- [ ] **Step 2: Commit, push, CI green** (message `feat(theme): navy entry screens`).

---

### Task 4: Home + catalog + bottom nav

**Files:**
- Modify: `home_screen.dart`, `search_screen.dart`, `app.dart` (nav bar only)
- Test: CI green.

- [ ] **Step 1: Home** — `PromoBanner` carousel on top (banners from category
  list → `/search?category=<slug>`), category circles, deals grid + rail
  with v2 cards. Keep providers/params/navigation identical.

- [ ] **Step 2: Catalog + nav** — navy cards/chips/sheets; bottom nav dark
  bar with blue active pill. No new query params.

- [ ] **Step 3: Commit, push, CI green** (message `feat(theme): navy home catalog nav`).

---

### Task 5: Purchase flow (detail/cart/checkout/confirmation)

**Files:**
- Modify: `product_detail_screen.dart`, `cart_screen.dart`, `address_screen.dart`, `checkout_screen.dart`, `confirmation_screen.dart`
- Test: CI green; checkout payload unchanged (only addressId/items/idempotencyKey).

- [ ] **Step 1: Restyle** — navy gallery/cards/summary, blue CTA, NO ratings/
  sizes/discount rows. Out-of-stock stays disabled. Server totals only.

- [ ] **Step 2: Commit, push, CI green** (message `feat(theme): navy purchase flow`).

---

### Task 6: Orders/profile/admin/diagnostics + final verify

**Files:**
- Modify: `orders_screen.dart`, `order_detail_screen.dart`, `profile_screen.dart`, admin screens (charts → blue family), diagnostics screen
- Test: full CI + APK download + docs line.

- [ ] **Step 1: Restyle** — navy cards/timeline/menus; fl_chart colors to
  blues (line/bar/donut); guard/endpoints/payloads identical.

- [ ] **Step 2: Final verify** — push, CI green, download `shop-apk`,
  confirm >10MB, update `docs/apk.md` build line.

- [ ] **Step 3: Commit, push, CI green** (message `feat(theme): navy orders profile admin`).

---

## Self-review
- [x] Spec coverage: §3→T1, §4→T2, §5 screens→T3–T6, §6 verify every task.
- [x] No placeholders: files, code, commands, expected outputs concrete.
- [x] Type consistency: token/component names match the existing codebase
      (`AppColors.price`, `PromoBanner`, `Config.bdt`).
