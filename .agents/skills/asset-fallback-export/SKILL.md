---
name: asset-fallback-export
description: Use when fixing missing artwork or image asset errors, theme previews, reading-moment graphics, PNG screenshots, bookmark/reading-report exports, gallery saving, share sheets, or image rights and fallback issues.
---

# Missing image assets, preview and export consistency

Read [shared rules](../../PROJECT_GUIDE.md), [source build constraints](../../../docs/SOURCE_BUILD.md), [third-party and media rights](../../../docs/THIRD_PARTY.md), and the [design reference](../../../docs/DESIGN.md).

## Current gap and source map

- `lib/reading_export_theme.dart` resolves theme artwork paths under `assets/report/`.
- The public Fork's tracked tree does **not** include that report-art directory; do not assume its images are bundled just because Dart references them. Upstream's published tree is also incomplete in this area.
- `lib/reading_moment_content.dart` renders `Image.asset` content; `lib/reading_moment_export.dart` warms an `AssetImage` before rendering offscreen PNG.
- `lib/reading_visual_theme_picker.dart` has a preview `errorBuilder`, but that alone does **not** protect the reading-moment composition or export.
- `lib/reading_moments_ui.dart` and `lib/gallery_save_button.dart` bridge preview, Save and Share. `lib/local_platform.dart` supplies device operations.

## Repair workflow

1. Check the **tracked asset tree**, `pubspec.yaml` declarations and the resolved asset name for the selected theme; distinguish a missing asset from corrupt bytes, decode failure and gallery permission failure.
2. Make preview, offscreen rendering and export use one resolved artwork/fallback decision. A colored placeholder is acceptable only if the exported PNG reproduces the same design and remains meaningful.
3. Use a deterministic Flutter-rendered/owned illustration or layered color/geometry fallback for missing images. Do not simply hide a red exception on screen while `precacheImage` still throws on export.
4. Bound the art frame and text so Flutter error widgets, large fonts and absent covers cannot cause `RenderFlex` overflow. Retain semantics, clipping and frame aspect ratios.
5. Preserve actual book covers if available; missing optional artwork must not erase text, dates, share metadata or completion measurements.
6. Do not extract images from an unlicensed installation package or claim absent artwork is definitely proprietary. Only add distributable assets with verified provenance and an inventory entry.
7. Test each theme in preview, PNG save and share, with/without source art, missing/corrupted book cover, and relevant permissions. Check resulting PNG dimensions and content, not only the button callback.

## Validation

- Run Flutter analysis/tests and Android CI for code changes.
- Confirm **three distinct layers**: no red placeholder in UI; offscreen render succeeds; platform gallery/share succeeds on a real device. Record any layer not verified.
- Use `flutter-ui-regression` for responsive overflows and `source-boundary-audit` for new asset files or licenses.
