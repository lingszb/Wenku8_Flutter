---
name: reader-rendering
description: Use when changing reader pagination, horizontal or vertical writing, reflow, page turns, font and paragraph layout, embedded images, text selection, reading anchors, or rendering performance.
---

# Reader rendering and position stability

Read [shared rules](../../PROJECT_GUIDE.md), [reader behavior](../../../docs/READER.md), [visual specification](../../../docs/DESIGN.md), and [local implementation scope](../../../docs/SOURCE_BUILD.md). The historical reader guide is broader than the current public Fork.

## Code map

- `lib/reader_pagination.dart`, `lib/reader_reflow.dart`, `lib/reader_paged_view.dart`, `lib/reader_scroll_stream.dart`: page measurement, reflow and mode presentation.
- `lib/reader_book_style.dart`, `lib/reader_preferences.dart`, `lib/reader_content.dart`, `lib/reader_rich_content.dart`: per-book style, configuration and rich text.
- `lib/reader_vertical_text.dart`, `lib/reader_embedded_vertical.dart`, `lib/reader_illustrations.dart`: vertical/CJK text and embedded images.
- `lib/reader_coordinate_map.dart`, `lib/reader_page_anchor.dart`, `lib/reader_book_progress.dart`, `lib/reader_annotations.dart`: exact positions, bookmarks and text references.
- `lib/performance_preferences.dart`: reduced visual workload; a setting to disable heavy effects must not disable reading.

## Invariants

1. Source paragraph/chapter offsets are the durable coordinate system; pixels and page indices change with font, screen width, device rotation and rendering mode. Do not persist visual page number as the only reading position.
2. Changing font, line height, margins, rich text or direction should remap from a source anchor; preserve current reading location, bookmarks, annotation ranges and search hits.
3. Respect text scaling, line breaks, Ruby/annotation placement where available, mixed CJK/Latin, long unbroken runs, RTL/vertical preferences and image sizing. Avoid silent removal of source content to make page fitting easier.
4. Incomplete/missing external source files should remain explicit failure states. Do not fabricate chapter bytes, network-fetch missing online content or change the book ID.
5. Keep batching/yields and bounded layout/cache behavior; do not eagerly paginate an entire large book on the UI isolate.

## Work procedure

1. Identify whether the bug is in parsing/source coordinates, style calculation, pagination, scroll/paged presentation or compositor animation. Trace the anchor through each layer.
2. Create a small, redistribution-safe text fixture that exposes the issue: line wrapping, CJK punctuation, long text, vertical orientation, inline illustration, or chapter boundary.
3. Implement a narrow fix while retaining backward-compatible serialized preferences and anchors. Confirm mode switches and device rotation remap correctly.
4. Run available Dart/Flutter tests and Android CI. For performance claims measure the relevant view/device rather than extrapolating from CI duration.
5. Manually verify: first/last page of chapter, long chapter, progress, bookmarks, highlights, search return, font changes, portrait/landscape, scrolling vs paged vs vertical mode where supported.

## Report

Describe original-coordinate impact, changed visual modes, cache invalidation, tests run, unresolved device-only behaviors and whether user reading history is preserved.
