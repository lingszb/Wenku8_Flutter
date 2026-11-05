---
name: source-boundary-audit
description: Use when adding files or tests, touching upstream-only or missing modules, third-party assets, credentials, distribution/release files, public-source inventory, or investigating unavailable functionality in this Flutter fork.
---

# Public-source boundary and provenance audit

Read [shared rules](../../PROJECT_GUIDE.md), [source build scope](../../../docs/SOURCE_BUILD.md), [local-only removal](../../../docs/LOCAL_READER_REMOVAL.md), [release constraints](../../../docs/RELEASING.md), and [third-party licenses](../../../docs/THIRD_PARTY.md).

## Actual publication gate

- `tools/check_public_source.py` scans the **exact commit** against `tools/public-source-files.txt`. Merely adding an entry to the inventory does not waive local-only names, private components, sensitive paths or secret checks.
- The scanner explicitly classifies `AGENTS.md` as **local-only**, even if tracked elsewhere. **Do not commit it or weaken the checker** as part of a routine feature/skill change; public shared guidance lives in `.agents/PROJECT_GUIDE.md`.
- Only currently accepted public Dart tests in the `test/` directory and listed in the inventory are eligible for public export; other private/dev test materials remain excluded.
- Treat Android preview source and upstream distribution as different products. A successful local Debug APK does not imply every upstream feature, platform or asset is published.

## Audit procedure

1. Confirm that every proposed path exists, is new, or has a known license. Check the tracked tree rather than guessing from Dart imports or screenshots.
2. If runtime references a missing file or module, record **both** the source call site and actual published file inventory. Distinguish "not in this Git tree" from "proprietary" or "not available anywhere".
3. For a new source file, adjust `tools/public-source-files.txt` and ensure the filename/path is not independently rejected. For third-party assets, record provenance, license and redistribution rights before adding bytes.
4. Avoid restoring removed online account/cloud browsing, private runtime bindings or unapproved distribution code as a side effect of fixing local reading.
5. Run the checked-out working-tree checker where available:
   ```sh
   python3 tools/check_public_source.py
   ```
   Once committed, use the exact-revision gate:
   ```sh
   python3 tools/check_public_source.py --revision "$(git rev-parse HEAD)"
   ```
6. Verify the committed tree and inventory match; inspect CI source-check status. Do not describe an unrun check as passing.

## Safe alternatives and handoff

- For missing illustrations, implement a deterministic, non-asset fallback shared by preview and export instead of inventing or extracting artwork of uncertain license.
- For unavailable native features, keep an honest disabled/unavailable UX rather than introducing a fake implementation.
- Report newly exposed files, policy impacts, third-party rights, attempted checks and any unresolved provenance. Never print secrets or personal path/device identifiers in logs.
