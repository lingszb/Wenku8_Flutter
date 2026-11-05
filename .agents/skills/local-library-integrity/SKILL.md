---
name: local-library-integrity
description: Use when changing local book categories, author/tag/series groupings, series merge or dissolve, book metadata and IDs, saved shelf preferences, bookmarks, progress, backups, or collection filtering.
---

# Local library and persisted state integrity

Read [shared rules](../../PROJECT_GUIDE.md), [local reading reference](../../../docs/READER.md), and [local-only scope](../../../docs/LOCAL_READER_REMOVAL.md). Verify claims against current code because some reader docs still describe upstream-only online features.

## Source map

- `lib/local_books.dart`: `LocalBookStore`, originals, derived series books, reading identity, source metadata, cover overrides.
- `lib/local_library_preferences.dart`: selected categories, user-created groups and assignments, saved view state and schema validation.
- `lib/book_dynamic_categories.dart`, `lib/book_tag_catalog.dart`: dynamic author/tag/series choices and tag normalization.
- `lib/local_book_series.dart`, `lib/local_series_actions.dart`, `lib/local_series_editor.dart`: series hints, ordering, explicit edit/merge/dissolve operations.
- `lib/local_library_page.dart`, `lib/bookshelf_scope.dart`, `lib/pages.dart`: shelf and list filtering. `lib/library_state.dart` and related reading/history stores own reading state.

## Invariants

1. **Dynamic categories** (`_author:`, `_tag:`, `_series:`, untagged/unseries views) are read-only projections. A book's named manual category is stored separately; filtering must not rewrite the assignment.
2. A series label is **not** an instruction to combine books. Prefer `LocalBookStore.seriesFor`, then stored `seriesHint`, then `inferLocalSeries(title)` for a suggestion only. A bare numeric title does not imply a series.
3. When filtering by series, pass local-store metadata to all shelf/list call sites; do not silently fall back to title-only inference for one surface.
4. Explicitly merged volumes retain source/original files. Do not treat a virtual series book as a disposable original; preserve stable IDs and chapter mapping when saving, editing or dissolving a series.
5. Preserve reading coordinates, annotations, bookmarks, reading history, custom covers, import/source identities and user settings across changes. Do not migrate, reassign or delete without a documented user-approved path and rollback/backup.
6. Treat missing files, malformed persisted JSON, partial imports and legacy stores as expected error paths. Report partial failures without invalidating unrelated books.

## Modification workflow

1. Draw the data flow: source file → `LocalBookStore` → visible `Novel`/series snapshot → organization filter → shelf/list → persisted state.
2. Note which state is authoritative versus derived. Inspect existing serialization validation and migration behavior before changing keys, group IDs or merge logic.
3. Modify the minimal layer; keep shelf/list and search consistent. Keep user-created categories independently editable.
4. Test at least: mixed author/tag/series metadata; no tags or series; long/ambiguous titles; manual category assignments; combine/reorder/dissolve; stale selections and app restart; duplicate imports; missing original file.
5. Confirm that deleting a manual group or removing a visible series never implicitly deletes the underlying original, bookmark or progress. Use controlled dummy books, not real personal libraries.

## Evidence and handoff

Report storage schema impact, data-migration/rollback need, source preservation, test matrix, CI results and any pending real-device/import regression. For UI changes also apply `flutter-ui-regression`; for import parsing also apply `book-import-pipeline`.
