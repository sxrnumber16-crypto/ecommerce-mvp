# Orvix UI/UX Redesign — Design Spec

Date: 2026-10-17
Status: Approved (user: "হ্যাঁ, spec লিখুন")
Scope: mobile app only; backend untouched.

## 1. Goal

Redesign the existing Orvix Shop Flutter app to a premium dark-navy look guided by
the Master Prompt's suggested color tokens and screen-by-screen requirements,
without changing any feature, business logic, API contract, navigation, or state
management. Earlier three feature requests (slider sizing, language selector,
multi-image) are explicitly out of scope for this pass.

## 2. Non-goals

- No backend / Prisma / API changes.
- No new features, no theme-toggle mechanism (keep system-following ThemeMode).
- No removal of bilingual "বাংলা / English" copy.
- No redesign of admin logic; admin screens get visual pass only.
- No dependency additions unless strictly necessary.

## 3. Approach (Approach B — batch-wise full redesign)

Batches, each committed + pushed + CI green before the next:

1. Foundation: color tokens, theme, shared components (AppCard, AppButton, AppInput, chips, section header, state views).
2. Home + Search (slider full-width, category circles, product grid).
3. Product detail (gallery, sticky bar).
4. Cart + Address + Checkout + Confirmation.
5. Orders list + detail.
6. Profile + Admin screens.

Each batch must keep `flutter analyze` zero-issue and tests green in CI.

## 4. Color tokens (replace AppColors values)

| Token | Hex | Usage |
|---|---|---|
| background | #06111F | scaffold bg |
| surface | #0B1B2D | cards/surfaces |
| elevated | #10243A | elevated cards/nav bar |
| primary | #087BFF | primary actions/links |
| cyan | #25D8F5 | accent highlights |
| text | #F5F8FF | primary text |
| muted | #A7B7CA | secondary text |
| border | #203750 | dividers/borders |
| success | #22C55E | success |
| error | #F87171 | error |

Implementation: update existing `AppColors` constants in place (seed→primary,
darkBackground→background, navyCard→elevated, darkText→text, darkMuted→muted,
darkOutline→border, error→#F87171) and add `cyan`. Light theme keeps a light
variant built from the same seed.

## 5. Theme

`buildDarkTheme()`: ColorScheme with primary #087BFF, secondary #25D8F5,
background #06111F, surface #0B1B2D, onSurface #F5F8FF, outline #203750,
brightness dark, Material 3. `buildLightTheme()`: light scheme from same seed.
Scaffold background uses token.

## 6. Shared components

- AppCard: rounded (AppRadius.card), subtle border (border token), restrained
  shadow, surface bg.
- AppButton: primary blue fill, white text, pill radius, loading state.
- AppInput: outlined, border token, focus primary.
- AppChip: surface bg + border, selected primary.
- SectionHeader/StateViews: token-based colors.

## 7. Screen requirements (per Master Prompt §5)

Each existing screen keeps data flow, validation, loading/error/empty states,
navigation, and permissions identical. Only visual presentation changes:
splash/onboarding, login/register, home, search, category, product detail,
cart/checkout/address/confirmation, orders, profile, admin.

## 8. Verification

- `flutter analyze` must report zero issues.
- `flutter test` must pass.
- Each batch pushed and CI workflow "Build Android APK" green.
- APK downloaded to `apk-output/app-release.apk` after final batch.

## 9. Risks

- Token rename may miss hardcoded colors in screens; grep for hex/Color(0x)
  during each batch.
- Layout overflow on small devices; test with constrained widths in code review.
- CI is the only build verification (no local Flutter SDK).

## 10. Approval

Approved by user on 2026-10-17. Proceed to writing-plans.
