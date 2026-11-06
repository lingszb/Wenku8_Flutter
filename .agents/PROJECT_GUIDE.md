# Wenku8 Flutter Fork: agent project guide

> This guide is the **public, reusable project-level contract** for coding agents. Check the current source and CI before acting. It does not assert that every upstream feature is present.

## Project scope and source of truth

- This Fork is an Android-first **local** reading app. Current public-source preview supports manual TXT/EPUB import, local library, reading, bookmarks and settings. Online Wenku browsing, account and cloud bookshelf UI were intentionally removed; do not reintroduce them without a separate requirement.
- Use **current code** as the source of truth, then [`docs/SOURCE_BUILD.md`](../docs/SOURCE_BUILD.md), [`docs/archive/2026-11-04-local-reader-removal.md`](../docs/archive/2026-11-04-local-reader-removal.md), [`docs/DESIGN.md`](../docs/DESIGN.md), [`docs/READER.md`](../docs/READER.md) as context. Some upstream-facing docs still describe features unavailable in this Fork. Record discrepancies rather than assuming the docs are executable.
- Preserve local originals, book identity, reading anchors, bookmarks, annotations and serialized preferences. Never silently wipe or migrate user data; require an explicit migration, backup and regression plan.
- Treat incomplete upstream snapshots and missing artwork as **known boundaries**, not a reason to fabricate source or embed unlicensed assets.
- Preserve existing Archive/Glass visual language; reuse existing widgets, icons, motion, theme and accessibility switches. An analyzer pass does not prove the absence of runtime layout overflows.
- New tracked files must be registered in `tools/public-source-files.txt` and pass `tools/check_public_source.py`. This repository's public-source policy explicitly rejects a tracked root `AGENTS.md`; do not bypass the policy to add one. This guide is the checked-in shared instructions alternative.
- Do not commit secrets, local device paths, APKs, logs, private fixtures or restricted connectivity modules. See [`docs/RELEASING.md`](../docs/RELEASING.md) and [`docs/THIRD_PARTY.md`](../docs/THIRD_PARTY.md).

## Collaboration and documentation maintenance

- Use Simplified Chinese for collaboration; preserve original code, commands, API names and diagnostics. On this Windows workspace prefer PowerShell 7 and native tools; verify actual tool paths and versions rather than copying historical machine settings.
- Before edits, run `git status --short`. Preserve existing changes and keep the patch within the requested scope. Reuse current code and dependencies; do not add speculative abstractions, compatibility layers or unrelated upgrades.
- Do not change package identity, signing identity, versions, update sources, dependencies or persisted formats unless requested. Preserve file grants, validation, accessibility, failure reporting and user-data recovery.
- Start documentation discovery at [the documentation index](../docs/README.md). It separates current guides, upstream references and archived PR records. Historical checks and feature descriptions do not establish current behavior or permission to repeat device operations.
- Follow the documentation lifecycle in that index: extract lasting conclusions into the current guide, archive dated implementation evidence, update callers when moving paths, and register exact public paths. Never weaken the source gate to publish local material.
- Keep common rules here and task-specific procedures in [the skill index](skills/README.md). Local `AGENTS.md` remains a local entrypoint; do not treat its availability as guaranteed in public clones or child worktrees. The main agent must pass applicable local constraints to child agents.
- Put temporary evidence in existing output directories or `.tmp/verification/`; remove only disposable files created by the current task. Do not record long-term memory without an explicit user request.

## Herdr and parallel agent worktrees

1. Herdr manages the primary worktree. Before parallel work, the main agent must confirm its actual path, target branch and `git status --short`; preserve existing uncommitted changes and do not assume a branch name.
2. Use Codex's built-in Worktree isolation for independent parallel tasks. Each task uses its own branch and worktree for changes, appropriate checks and task commits. Create a task branch before committing if the worktree starts with a detached HEAD.
3. Child agents may operate only on their assigned worktree and branch. They must not merge into, switch, reset or otherwise modify Herdr's current work branch or another task's worktree.
4. Return the worktree path, branch, ordered commit SHAs, change summary, checks actually run and their results, unverified items and known risks to the main agent.
5. Only the main agent reviews and integrates changes into Herdr's current worktree using Git cherry-pick or squash and resolves integration conflicts. For the required single final commit, use `git cherry-pick --no-commit <SHA...>` or an equivalent squash flow; do not rewrite unrelated history.
6. After integration, rerun risk-appropriate static checks, focused tests and necessary builds. Resolve conflicts and verify relevant regressions, then record the final changes as one conventional Git commit, such as `feat(scope): description`. Task commit authorization does not authorize pushing or publishing; ordinary tasks still require a request to commit.
7. Before cleanup, confirm that the final commit is retained on the intended target branch, all task changes are included and required checks passed. Squashing changes SHAs, so `git branch --merged` alone is insufficient evidence.
8. Only then remove temporary worktrees and task branches created for this work. Keep them if integration is incomplete or uncertain, or if uncommitted changes or conflicts remain. Never force-delete a worktree merely to clear a dirty state.

## Device testing authorization

- Without explicit user permission, do not perform physical-device tests or in-emulator functional tests. The currently permitted device operations are fetching an APK, starting an emulator, and installing/opening that APK.
- Do not extend launch permission to taps, swipes, imports, saves, sharing, speech requests or device automation. Post-integration retesting does not grant device-testing permission. Report device acceptance as unverified when permission has not been granted; static checks, unit/Widget tests and builds remain distinct verification categories.

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
5. For UI or data changes, define **manual** Android verification: narrow screens, real fonts, TXT/EPUB fixtures, saved state across restart, and offline behavior as applicable. Execute device checks only within the authorization above. Do not call a green CI badge a device UI pass.
6. In the PR, state changed files, risk to user data, checks actually run, missing checks and follow-up. Never merge or publish a release without explicit instruction.

## Agent-specific entry points

- A local Claude Code `CLAUDE.md` may route through local `AGENTS.md`. These entrypoints are not part of the public export; in a public checkout, read this shared guide directly.
- GitHub Copilot reads [`.github/copilot-instructions.md`](../.github/copilot-instructions.md), which points here.
- Tools supporting project-level skills can use the seven `SKILL.md` files directly. If the agent does not automatically load this shared guide, open it before changing the project.
