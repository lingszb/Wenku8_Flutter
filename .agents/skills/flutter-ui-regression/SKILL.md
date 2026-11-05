---
name: flutter-ui-regression
description: Use when changing Flutter widgets, typography, book shelf/carousel captions, responsive layout, touch targets, theme or motion behavior, or diagnosing RenderFlex, clipping and text overflows.
---

# Flutter UI and layout regression

Read [shared rules](../../PROJECT_GUIDE.md) and the canonical [design reference](../../../docs/DESIGN.md). Consult [haptics](../../../docs/HAPTICS.md), [icons](../../../docs/ICON_SYSTEM.md), and [touch guidance](../../../docs/TOUCH_FINGERPRINT.md) only when relevant.

## Visual system and code map

- `lib/app_ui.dart`, `lib/archive_design.dart`, `lib/archive_icons.dart`, `lib/app_typography.dart`: existing controls, tokens, icons and text.
- `lib/archive_wave.dart`, `lib/archive_shelf_geometry.dart`: responsive 3D shelf and live book captions.
- `lib/motion_ui.dart`, `lib/performance_preferences.dart`: animations and user-controlled low-performance behavior.
- `lib/local_library_page.dart`, `lib/pages.dart`: local navigation, shelf and list entry points.
- Do not replace the app with generic Material components or hard-code a new color palette when an existing Archive/Glass component works.

## Responsive repair checklist

1. Reproduce the real constraints, not just full device width: parent `Row`/`Column`, viewport, padding, text scaler, keyboard inset, `SafeArea`, landscape and split panes.
2. For long Chinese/Japanese book titles, handle one/two lines plus ellipsis, author/status captions, icon widths and font fallback. Avoid assigning a fixed total height from `fontSize * lineHeight` when real glyph metrics vary.
3. Prefer `Flexible`, `Expanded`, intrinsic/content-driven height or justified minimum constraints to clipping or global text-scale suppression. Consider unbounded scroll constraints before adding nested flex widgets.
4. Keep touch areas reachable and semantics legible with reduce-motion, accessibility text scaling, dark/light and user themes.
5. Maintain existing `LoadingHandoff`, Hero identity, haptic triggers and book-opening routes while making geometry changes; inspect both loading and steady-state UI.
6. If assets may be missing, do not allow Flutter's error widget to expand the layout. Also apply `asset-fallback-export` when preview images or saved captures are involved.

## Verification matrix

- Narrow phone, typical phone, landscape/tablet if applicable; text scaling 1.0, 1.25, 1.5 or device-equivalent.
- Short title, two-line CJK title, extremely long title; missing/long author; empty and populated shelves.
- Loading handoff, rapid switching, scroll/tap, accessibility labels, high contrast, reduced-motion and low-performance flags.
- Run `flutter analyze lib test --no-fatal-infos` and available Widget tests; compile an Android Debug APK via CI for a code PR.
- **A successful analyzer or APK compile does not prove visual correctness.** Report manual device/screenshot checks separately, including whether `RenderFlex overflow` is absent.

## Handoff

State exact component/constraint cause, retained design behavior, what was exercised automatically vs on-device, and any open rendering risks.
