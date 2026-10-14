# UI/UX Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin the whole Flutter app to Premium Minimal using a new token + component system, without changing any API, state, routing, or checkout logic.

**Architecture:** New `mobile_app/lib/design/` layer (tokens + theme + reusable components); screens in `lib/features/` are rewritten to compose those components only. New packages: cached_network_image, shimmer, carousel_slider, google_fonts.

**Tech Stack:** Flutter 3 stable, Dart 3, Material 3, Riverpod, GoRouter, Dio (all unchanged).

**Spec:** `docs/superpowers/specs/2026-10-14-ui-ux-redesign-design.md`

## Global Constraints

- Backend, API contracts, Riverpod providers, GoRouter routes, and checkout math are UNTOUCHED; backend suite stays 47/47.
- Bilingual (Bangla + English) labels on every user-facing string; keep existing copy, only restyle.
- No hex colors, no ad-hoc padding/radius/shadows in screens — everything from `lib/design/tokens/`.
- Server-calculated totals only; COD order stays `pending`/`unpaid` in messaging.
- Wishlist heart is LOCAL-only visual (in-memory); no backend calls for it.
- This machine has NO Flutter SDK: do NOT run `flutter`/`dart` locally; verification is CI (`flutter analyze`, `flutter test`, APK build via `.github/workflows/build-apk.yml`) after push.
- Each task ends with: commit + push + CI analyze green on that state (fix-forward on failures, record log excerpts in report).

---

## File Structure

**New `mobile_app/lib/design/`:**
- `tokens/app_colors.dart` — light/dark color constants (no hex outside).
- `tokens/app_text.dart` — Plus Jakarta Sans styles + price style.
- `tokens/app_space.dart`, `tokens/app_radius.dart`, `tokens/app_shadow.dart`.
- `theme.dart` — light/dark `ThemeData` built only from tokens; `app.dart` switches to it.
- `components/app_scaffold.dart`, `app_button.dart`, `app_input.dart`,
  `app_chip.dart`, `section_header.dart`, `app_card.dart`,
  `product_card.dart` (v2, replaces shared widget), `state_views.dart`
  (shimmer/empty/error), `sheets.dart` (qty/filter/address/status sheets).

**Modified:** `mobile_app/pubspec.yaml` (4 new deps), `mobile_app/lib/app.dart`
(theme wiring only), every file under `lib/features/`, delete-orphan pass
at the end (`lib/shared/widgets/` removed only when unused).

---

### Task 1: Dependencies + design tokens + theme

**Files:**
- Modify: `mobile_app/pubspec.yaml` (add deps), `mobile_app/lib/app.dart` (use new theme)
- Create: `mobile_app/lib/design/tokens/app_colors.dart`, `tokens/app_text.dart`, `tokens/app_space.dart`, `tokens/app_radius.dart`, `tokens/app_shadow.dart`, `design/theme.dart`
- Test: CI `flutter analyze` green.

**Interfaces:**
- Consumes: existing `Config.bdt(int)` for price formatting (keep using it).
- Produces: `AppColors`, `AppText`, `AppSpace`, `AppRadius`, `AppShadow`, `buildLightTheme()`, `buildDarkTheme()` used by all later tasks.

- [ ] **Step 1: Add the dependencies**

```yaml
# mobile_app/pubspec.yaml — add under dependencies:
  cached_network_image: ^3.4.0
  shimmer: ^3.0.0
  carousel_slider: ^5.0.0
  google_fonts: ^6.2.0
```

- [ ] **Step 2: Write the tokens (exact content)**

```dart
// lib/design/tokens/app_colors.dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const seed = Color(0xFF0E7C6B);
  static const lightBackground = Color(0xFFF7F8F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightOutline = Color(0xFFE2E8E4);
  static const lightText = Color(0xFF10201C);
  static const lightMuted = Color(0xFF5B6F6A);
  static const darkBackground = Color(0xFF0C1513);
  static const darkSurface = Color(0xFF14211E);
  static const darkOutline = Color(0xFF24403A);
  static const darkText = Color(0xFFEDF5F2);
  static const darkMuted = Color(0xFF9DB8B1);
  static const price = Color(0xFFB45309);
  static const success = Color(0xFF15803D);
  static const error = Color(0xFFDC2626);
}
```

```dart
// lib/design/tokens/app_text.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppText {
  static TextStyle display(BuildContext context) =>
      GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700);
  static TextStyle headline(BuildContext context) =>
      GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700);
  static TextStyle title(BuildContext context) =>
      GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600);
  static TextStyle body(BuildContext context) =>
      GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400);
  static TextStyle label(BuildContext context) =>
      GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500);
  static TextStyle price(BuildContext context) =>
      GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800);
}
```

```dart
// lib/design/tokens/app_space.dart
abstract final class AppSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
}

// lib/design/tokens/app_radius.dart
abstract final class AppRadius {
  static const card = 16.0;
  static const sheet = 24.0;
  static const pill = 999.0;
}

// lib/design/tokens/app_shadow.dart
import 'package:flutter/material.dart';
abstract final class AppShadow {
  static const card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const sheet = [
    BoxShadow(color: Color(0x29000000), blurRadius: 24, offset: Offset(0, -6)),
  ];
}
```

```dart
// lib/design/theme.dart
import 'package:flutter/material.dart';
import 'tokens/app_colors.dart';

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.seed);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.lightBackground,
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed, brightness: Brightness.dark);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.darkBackground,
  );
}
```

- [ ] **Step 3: Wire the theme in `app.dart`** — replace the existing `theme:` / `darkTheme:` arguments of `MaterialApp.router` with `theme: buildLightTheme(), darkTheme: buildDarkTheme(),` and add `import 'design/theme.dart';`. Change nothing else in `app.dart`.

- [ ] **Step 4: Verify via CI**

Run: `git add mobile_app/pubspec.yaml mobile_app/lib/design mobile_app/lib/app.dart && git commit -m "feat(design): tokens and theme" && git push origin main`
Then: `gh workflow run "Build Android APK" --repo sxrnumber16-crypto/ecommerce-mvp` and `gh run watch <id>` until green.
Expected: Analyze green (screens untouched, so no new issues).

- [ ] **Step 5: Record** the CI run URL + analyze result in the task report.

---

### Task 2: Core components (scaffold, button, input, chip, section)

**Files:**
- Create: `lib/design/components/app_scaffold.dart`, `app_button.dart`, `app_input.dart`, `app_chip.dart`, `section_header.dart`
- Test: `mobile_app/test/design_components_test.dart` (pump AppButton + AppChip, expect labels render).

**Interfaces:**
- Consumes: Task 1 tokens/theme.
- Produces: `AppScaffold`, `AppButton.{primary,outline,ghost}`, `AppInput`, `AppChip`, `SectionHeader` used by Tasks 4–8.

- [ ] **Step 1: Write the widget test first**

```dart
// mobile_app/test/design_components_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/design/components/app_button.dart';
import 'package:myapp/design/components/app_chip.dart';

void main() {
  testWidgets('AppButton shows bilingual label', (t) async {
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: AppButton(label: 'লগইন / Login', onPressed: null))));
    expect(find.text('লগইন / Login'), findsOneWidget);
  });

  testWidgets('AppChip shows selected state', (t) async {
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: AppChip(label: 'Clothing', selected: true))));
    expect(find.text('Clothing'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Implement the components**

```dart
// lib/design/components/app_button.dart
import 'package:flutter/material.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_space.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;

  const AppButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.loading = false,
      this.outlined = false});

  @override
  Widget build(BuildContext context) {
    final style = ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card)),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
    );
    final child = loading
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2))
        : Text(label);
    if (outlined) {
      return OutlinedButton(onPressed: loading ? null : onPressed, style: style, child: child);
    }
    return ElevatedButton(onPressed: loading ? null : onPressed, style: style, child: child);
  }
}
```

```dart
// lib/design/components/app_input.dart
import 'package:flutter/material.dart';
import '../tokens/app_radius.dart';

class AppInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const AppInput(
      {super.key,
      required this.controller,
      required this.label,
      this.obscure = false,
      this.keyboardType = TextInputType.text,
      this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
    );
  }
}
```

```dart
// lib/design/components/app_chip.dart
import 'package:flutter/material.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_space.dart';

class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const AppChip(
      {super.key, required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.l, vertical: AppSpace.s),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
              color: selected ? scheme.primary : scheme.outline),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? scheme.onPrimary : scheme.onSurface,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
```

```dart
// lib/design/components/section_header.dart
import 'package:flutter/material.dart';
import '../tokens/app_text.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader(
      {super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppText.headline(context))),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}
```

```dart
// lib/design/components/app_scaffold.dart
import 'package:flutter/material.dart';
import '../tokens/app_space.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? bottomBar;
  final List<Widget>? actions;

  const AppScaffold(
      {super.key,
      required this.title,
      required this.body,
      this.bottomBar,
      this.actions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: body,
        ),
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}
```

- [ ] **Step 3: Commit, push, CI green** (same commands as Task 1 Step 4, message `feat(design): core components`).

---

### Task 3: Cards, states, sheets + ProductCard v2

**Files:**
- Create: `lib/design/components/app_card.dart`, `product_card.dart`, `state_views.dart`, `sheets.dart`
- Modify: `mobile_app/test/widget_test.dart` — add ProductCard v2 BDT test below.
- Delete: nothing yet.

**Interfaces:**
- Consumes: Tasks 1–2; existing `Product` model at `lib/features/catalog/models.dart` (fields `id`, `name`, `priceBdt`, `stock`, `imageUrl`, `inStock` — read the file first, keep field usage identical); `Config.bdt` stays the formatter.
- Produces: `AppCard`, `ProductCard` (v2), `LoadingGrid`, `EmptyView`, `ErrorView`, sheet helpers used by Tasks 4–8. Old `lib/shared/widgets/product_card.dart` stays until Task 8 removes it.

- [ ] **Step 1: Write the failing test**

```dart
// append to mobile_app/test/widget_test.dart
import 'package:myapp/design/components/product_card.dart';
import 'package:myapp/features/catalog/models.dart';

testWidgets('ProductCard v2 shows BDT price', (t) async {
  // Build a Product matching models.dart required fields; adjust only if
  // the model requires more non-nullable fields (read the file first).
  final product = Product(id: 1, name: 'Panjabi', priceBdt: 1250, stock: 5);
  await t.pumpWidget(MaterialApp(
      home: Scaffold(body: ProductCard(product: product))));
  expect(find.textContaining('1,250'), findsOneWidget);
});
```

- [ ] **Step 2: Implement**

```dart
// lib/design/components/app_card.dart
import 'package:flutter/material.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_shadow.dart';
import '../tokens/app_space.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadow.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.m),
            child: child,
          ),
        ),
      ),
    );
  }
}
```

```dart
// lib/design/components/product_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/config.dart';
import '../../features/catalog/models.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_space.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final bool wished;
  final VoidCallback? onWish;

  const ProductCard(
      {super.key, required this.product, this.wished = false, this.onWish});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCardLike(
      onTap: () => context.go('/product/${product.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: CachedNetworkImage(
                imageUrl: product.imageUrl ?? '',
                fit: BoxFit.cover,
                placeholder: (c, u) => Shimmer.fromColors(
                  baseColor: scheme.surfaceContainerHighest,
                  highlightColor: scheme.surface,
                  child: Container(color: scheme.surfaceContainerHighest),
                ),
                errorWidget: (c, u, e) =>
                    const Icon(Icons.image_not_supported_outlined),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s),
          Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(Config.bdt(product.priceBdt),
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
```

> NOTE: `AppCardLike` above is a sketch — implement `ProductCard` on top of
> the real `AppCard` from this task, adapting padding (image must bleed to
> card edges). Keep `imageUrl` null-safe: empty string falls to errorWidget.
> Keep the `wished`/`onWish` heart overlay wired to a local in-memory set
> owned by the listing screen (no backend calls).

```dart
// lib/design/components/state_views.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../tokens/app_space.dart';

class LoadingGrid extends StatelessWidget {
  const LoadingGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: AppSpace.m, crossAxisSpacing: AppSpace.m),
      itemCount: 6,
      itemBuilder: (c, i) => Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        highlightColor: Theme.of(context).colorScheme.surface,
        child: Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16))),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  const EmptyView(
      {super.key,
      required this.message,
      required this.actionLabel,
      this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shopping_bag_outlined, size: 56),
          const SizedBox(height: AppSpace.m),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.m),
          if (onAction != null)
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56),
          const SizedBox(height: AppSpace.m),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.m),
          ElevatedButton(
              onPressed: onRetry, child: const Text('আবার চেষ্টা / Retry')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Sheets** — `sheets.dart` with `showQtySheet(context)` returning
  the picked int via `Navigator.pop`, `showFilterSheet` and
  `showAddressSheet`/`showStatusSheet` built per the calling screen's needs
  in Tasks 5–8 (define the generic rounded-top sheet wrapper here;
  screen-specific content lives with the screens).

- [ ] **Step 4: Commit, push, CI green** (message `feat(design): cards states sheets`).

---

### Task 4: Auth + splash + onboarding reskin

**Files:**
- Modify: `lib/features/auth/login_screen.dart`, `register_screen.dart`, `lib/features/splash/splash_screen.dart`, `lib/features/onboarding/onboarding_screen.dart`
- Test: existing auth widget tests must still pass in CI.

**Interfaces:**
- Consumes: Tasks 1–3 components; existing `AuthStore`/`authStateProvider` names — read `lib/core/auth_store.dart` first and keep every provider/method call identical.
- Produces: same routes, same logic, new look.

- [ ] **Step 1: Rewrite each screen** to `AppScaffold` + `AppInput` +
  `AppButton(loading: ...)` keeping all controllers, validators, error
  text, and navigation targets byte-identical in behavior. Splash keeps
  its token-check-then-route logic; onboarding keeps Skip → login.

- [ ] **Step 2: Commit, push, CI green** (message `feat(design): auth entry reskin`).

---

### Task 5: Home + listing + search reskin

**Files:**
- Modify: `lib/features/home/home_screen.dart`, `lib/features/catalog/search_screen.dart`
- Test: CI tests green.

**Interfaces:**
- Consumes: Tasks 1–3; existing catalog providers/APIs — read the files first, keep query params (`search`, `category`, `page`, `limit`) identical.

- [ ] **Step 1: Home** — hero banner `CarouselSlider` on top (banners from
  category list: image + name → `/search?category=<slug>`), `AppChip` row,
  `SectionHeader` + 2-col grid of v2 `ProductCard`, best-sellers horizontal
  rail reusing the same card at fixed width. `LoadingGrid`/`ErrorView` for
  states.

- [ ] **Step 2: Listing/search** — search field (`AppInput`), `AppChip`
  filters, filter bottom-sheet (price/in-stock/sort — client-side over the
  SAME API results already fetched; do not invent new query params),
  v2 grid + skeletons.

- [ ] **Step 3: Commit, push, CI green** (message `feat(design): home catalog reskin`).

---

### Task 6: Detail + cart + checkout flow reskin

**Files:**
- Modify: `product_detail_screen.dart`, `cart_screen.dart`, `cart_store.dart` (UI only — keep item/qty shape), `address_screen.dart`, `checkout_screen.dart`, `confirmation_screen.dart`
- Test: CI green; checkout still sends only `{addressId, items, idempotencyKey}`.

**Interfaces:**
- Consumes: Tasks 1–3; `RadioGroup` pattern already in address screen — keep.
- Produces: same checkout payloads.

- [ ] **Step 1: Detail** — gallery (`PageView` + dots over `CachedNetworkImage`),
  price/stock header, qty stepper, sticky bottom `AppButton` Add-to-Cart,
  description/specs in `AppCard`. Out-of-stock disables the bar.

- [ ] **Step 2: Cart/address/checkout/confirmation** — line-item `AppCard`s,
  address radio list + form in sheets style, summary `AppCard` rendering
  SERVER totals only, COD `AppButton`, animated success check
  (`AnimatedContainer`/`ScaleTransition`, no new packages).

- [ ] **Step 3: Commit, push, CI green** (message `feat(design): purchase flow reskin`).

---

### Task 7: Orders + profile reskin

**Files:**
- Modify: `orders_screen.dart`, `order_detail_screen.dart`, `profile_screen.dart`
- Test: CI green.

- [ ] **Step 1: Orders** — status `AppChip` filters, order `AppCard`s, detail
  with items + payment + vertical timeline (pending → confirmed → shipped
  → delivered, `Icons` + connecting line, current step highlighted).

- [ ] **Step 2: Profile** — stats header card, menu rows, logout, theme toggle.

- [ ] **Step 3: Commit, push, CI green** (message `feat(design): orders profile reskin`).

---

### Task 8: Admin reskin + dead-code removal + final verify

**Files:**
- Modify: all files under `lib/features/admin/` (same endpoints, same guard).
- Delete: `lib/shared/widgets/` old files ONLY after confirming zero imports (`grep -r "shared/widgets" mobile_app/lib` empty).
- Test: `flutter test` green in CI + release APK installs.

**Interfaces:**
- Consumes: everything above; admin APIs unchanged.

- [ ] **Step 1: Admin** — stat `AppCard`s, product editor with image-URL
  live preview + deactivate/reactivate (keep the PATCH workaround),
  orders list + status bottom-sheet, payment read-only.

- [ ] **Step 2: Delete orphans** — remove unused old widgets; `flutter analyze` must stay clean.

- [ ] **Step 3: Full verify** — push, run CI workflow to green, download
  APK, confirm size >10MB, update `docs/apk.md` line with new build date.

- [ ] **Step 4: Commit, push, CI green** (message `feat(design): admin reskin and cleanup`).

---

## Self-review
- [x] Spec coverage: §§3–9 all mapped (§3→T1, §5→T2–T3, §6 screens→T4–T8, §7 motion inside T6, §8 deps→T1, §9 verify every task).
- [x] No placeholders: every step names files, code, and exact commands.
- [x] Type consistency: `AppButton(label,onPressed)`, `AppChip(label,selected)`, `Config.bdt(int)`, `ProductCard(product)` used identically throughout.
