---
name: book-import-pipeline
description: Use when modifying local TXT/EPUB import, file selection, encoding, chapter/volume parsing, metadata, covers, linked files, import batch warnings, source retention or import maintenance.
---

# Local book import pipeline

Read [shared rules](../../PROJECT_GUIDE.md), [current source build scope](../../../docs/SOURCE_BUILD.md), [reader/import reference](../../../docs/READER.md), and [local-only changes](../../../docs/LOCAL_READER_REMOVAL.md).

## Current scope is narrower than upstream docs

- `lib/book_import_limits.dart` currently limits this public preview's **manual import to TXT and EPUB** (`supportsBookImport`); it defines TXT 128 MiB and EPUB 512 MiB byte limits.
- Historical `docs/READER.md` also describes Kindle, PDF, folder scans and DOC conversion. Do **not** promise those formats work in this public Fork without tracing their actual enabled entry points.
- A linked original and an app-managed copy have different lifetimes. Neither mode authorizes rewriting or deleting an external source file as a side effect of metadata edits.

## Code map

- `lib/local_book_importer.dart`, `lib/local_import_page.dart`, `lib/local_import_batch.dart`, `lib/local_import_review.dart`: import UI, queue and reporting.
- `lib/local_books.dart`, `lib/local_text_import.dart`, `lib/local_text_rules.dart`, `lib/book_text_encoding.dart`: data ingestion, text parsing, decoding and chapter index.
- `lib/local_epub_markup.dart`, `lib/local_epub_navigation.dart`, `lib/local_epub_media.dart`: EPUB layout, TOC, images and rich content.
- `lib/local_document_reference.dart`, `lib/local_document_input.dart`, `lib/local_book_media.dart`: persistent file access and media lookup.
- `lib/local_book_import_issues.dart`, `lib/local_book_maintenance.dart`, `lib/local_coordinate_upgrade.dart`: validation feedback and repair/upgrade.
- `lib/local_book_series.dart` and `lib/local_library_preferences.dart`: hints and organization, not automatic merging.

## Pipeline invariants

1. Validate extension, byte size, readable source and file-provider authorization before import. Limit allocations; decode/parse large books away from expensive synchronous UI work.
2. TXT encoding (including BOM and legacy Chinese encodings), heading recognition and custom rules must not drop body text on a failed pattern. A bad preview cannot rewrite a previously imported book.
3. EPUB reading order, anchor fragments, embedded images, book cover, nested navigation and text style metadata must survive the import. Report broken resources rather than inventing content.
4. Preserve stable book identity and reading coordinates during reimport/upgrade. Never migrate bookmarks/annotations blindly when the underlying text differs.
5. Preserve the user's original file by default and distinguish linked vs copied/import-managed storage. Fail with guidance when external permission or file access is missing.
6. Do not auto-merge books solely because series hints match. Respect existing manual categories and independent series actions.
7. In a batch, isolate failures, keep successful imports intact and make warnings actionable without exposing private local paths in published diagnostics.

## Regression cases

- Small and large TXT, UTF-8/UTF-16 BOM and GB-family encodings; with/without explicit chapter rules.
- EPUB 2/3 with nested TOC, relative image references, cover, inline formatting, language tags and missing resource.
- Duplicate reimport, interrupted batch, corrupt archive, size limit, external permission revoked, file moved, and insufficient storage.
- Reopen after restart, update a linked file, retain reading position/bookmarks and verify no unrequested deletion.

Run available Flutter tests/CI and explicitly identify which cases still require device file-provider testing. Also apply `local-library-integrity` for state changes and `reader-rendering` for text layout changes.
