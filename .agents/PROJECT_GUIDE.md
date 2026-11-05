# Wenku8 Flutter Fork: agent project guide

> This guide is the **public, reusable project-level contract** for coding agents. Check the current source and CI before acting. It does not assert that every upstream feature is present.

## Project scope and source of truth

- This Fork is an Android-first **local** reading app. Current public-source preview supports manual TXT/EPUB import, local library, reading, bookmarks and settings. Online Wenku browsing, account and cloud bookshelf UI were intentionally removed; do not reintroduce them without a separate requirement.
- Use **current code** as the source of truth, then [`docs/SOURCE_BUILD.md`](../docs/SOURCE_BUILD.md), [`docs/LOCAL_READER_REMOVAL.md`](../docs/LOCAL_READER_REMOVAL.md), [`docs/DESIGN.md`](../docs/DESIGN.md), [`docs/READER.md`](../docs/READER.md) as context. Some upstream-facing docs still describe features unavailable in this Fork. Record discrepancies rather than assuming the docs are executable.
- Preserve local originals, book identity, reading anchors, bookmarks, annotations and serialized preferences. Never silently wipe or migrate user data; require an explicit migration, backup and regression plan.
- Treat incomplete upstream snapshots and missing artwork as **known boundaries**, not a reason to fabricate source or embed unlicensed assets.
- Preserve existing Archive/Glass visual language; reuse existing widgets, icons, motion, theme and accessibility switches. An analyzer pass does not prove the absence of runtime layout overflows.
- New tracked files must be registered in `tools/public-source-files.txt` and pass `tools/check_public_source.py`. This repository's public-source policy explicitly rejects a tracked root `AGENTS.md`; do not bypass the policy to add one. This guide is the checked-in shared instructions alternative.
- Do not commit secrets, local device paths, APKs, logs, private fixtures or restricted connectivity modules. See [`docs/RELEASING.md`](../docs/RELEASING.md) and [`docs/THIRD_PARTY.md`](../docs/THIRD_PARTY.md).

## Task routing: read the relevant skill first

| Change touches | Skill |
| --- | --- |
| Widgets, responsive layouts, typography, shelf, animations | [flutter-ui-regression](skills/flutter-ui-regression/SKILL.md) |
| Categories, series, IDs, collection state, saved reading state | [local-library-integrity](skills/local-library-integrity/SKILL.md) |
| Flutter/Gradle toolchain, Actions, APK artifacts, signing | [android-build-ci](skills/android-build-ci/SKILL.md) |
| Public export, missing upstream code, assets, licenses | [source-boundary-audit](skills/source-boundary-audit/SKILL.md) |
| TXT/EPUB import, metadata, chapters, local file access | [book-import-pipeline](skills/book-import-pipeline/SKILL.md) |
| Pagination, layout, scroll, vertical text, coordinate anchoring | [reader-rendering](skills/reader-rendering/SKILL.md) |
| Image preview, missing art, screenshot/PNG export, gallery | [asset-fallback-export](skills/asset-fallback-export/SKILL.md) |

Read **more than one skill** if a change crosses those boundaries.

## Default implementation loop

1. Identify the actual entry point and current behavior. Trace state from UI to storage, and state any known public-source gaps.
2. Select the narrowest patch; preserve existing persisted formats and interfaces unless migration is requested.
3. Add or update focused **public** tests when the source policy permits. Do not fabricate test results, device logs or screenshots.
4. Run what the environment supports, reporting each check separately:
   ```sh
   flutter pub get
   flutter analyze lib test --no-fatal-infos
   flutter test --no-pub
   ```
   On committed source, the CI policy runs `python3 tools/check_public_source.py --revision "$(git rev-parse HEAD)"`. The Android job also builds an ARM64 Debug APK and uploads an Artifact. See [`docs/CI_CD.md`](../docs/CI_CD.md).
5. For UI or data changes, define **manual** Android verification: narrow screens, real fonts, TXT/EPUB fixtures, saved state across restart, and offline behavior as applicable. Do not call a green CI badge a device UI pass.
6. In the PR, state changed files, risk to user data, checks actually run, missing checks and follow-up. Never merge or publish a release without explicit instruction.

## Agent-specific entry points

- Claude Code reads [`CLAUDE.md`](../CLAUDE.md), which points here.
- GitHub Copilot reads [`.github/copilot-instructions.md`](../.github/copilot-instructions.md), which points here.
- Tools supporting project-level skills can use the seven `SKILL.md` files directly. If the agent does not automatically load this shared guide, open it before changing the project.
