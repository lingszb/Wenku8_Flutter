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

## Source baseline and APK provenance

- Before editing, building or installing, record the resolved Git root, branch, full HEAD, `git status --short`, worktree list and intended target branch. Verify that branch's current remote head with a successful fetch or authenticated repository API read; a local branch name, old fetch or previous PR result is not evidence of the latest baseline.
- When building the target branch, reconcile a stale local head with the intended remote commit first. A clean fast-forward is allowed within the task; preserve and report dirty or divergent state instead of resetting it. For a task branch, identify its agreed base and review incoming target changes before claiming the task includes them. An explicitly requested historical rollback is the exception and must name its commit.
- Tie every delivered or installed APK to its actual source commit, dirty state, ABI, build mode, build time and SHA-256 in local verification evidence. Distinguish a CI artifact from a local rebuild. Do not infer "latest" from an APK filename, modification time or unchanged app version alone; verify the installed APK hash when selecting a replacement build.
- Use the designated primary worktree for final integration and delivery. Historical worktrees are not alternative current build roots. Recheck the root and baseline even after opening an old task or restarting a session; cleanup alone does not enforce this rule. A worktree lock protects retained work from removal and does not prevent building it.

## Native Git worktrees and multi-agent collaboration

1. Use native `git worktree` for this project, not Codex or another client's built-in worktree creation/management APIs. Git is the shared inventory across Herdr, Claude Code, Codex and other agents. Check the primary root, intended branch, current remote baseline, `git status --short` and `git worktree list --porcelain` before starting; preserve existing changes.
2. Each independent development task gets its own branch and worktree, normally under `.worktrees/<task>` in the primary checkout. Create it with `git worktree add -b feat/<task> <path> <verified-base-sha>` (choose the appropriate branch prefix). Do not develop directly in the primary checkout or reuse an unchecked old tree. Create a task branch before any authorized commit from detached HEAD.
3. Give each agent the primary path, baseline SHA, task path, branch and applicable constraints; copy existing local ignored entrypoints (`AGENTS.md` / `CLAUDE.md`) into new trees as needed. An agent edits only its assigned tree and branch and must not switch, reset, merge or modify the primary branch or another agent's tree.
4. Return the worktree path, branch, baseline SHA, any authorized commit SHAs, change summary, checks, unverified items and risks. Do not commit without task authorization; permission for task commits does not authorize pushing or publishing.
5. Only the primary agent reviews and integrates verified task changes using cherry-pick or squash, preserving unrelated work. When a single final commit is required, use `git cherry-pick --no-commit <SHA...>` or equivalent squash. Do not rewrite unrelated history; rerun risk-appropriate checks after integration.
6. After integration, inventory old worktrees and task branches. Verify every change is accounted for in the intended target and necessary checks passed. Squash changes commit identities: compare actual diffs or final PR trees instead of relying only on `git branch --merged`.
7. Cleanup in order: inspect dirty/untracked and valuable ignored files and back them up; verify exact absolute targets and integration evidence; run `git worktree remove <path>`; delete confirmed obsolete local task branches; run `git worktree prune`; verify the remaining inventory, paths and primary branch. Never remove the primary checkout, another agent's active tree, unintegrated work or retained backups.
8. Keep dirty, conflicted or uncertain trees and explain why. Only explicit user permission to discard permits unlocking and forced removal after a complete verified backup. Do not use `--force` merely to make a tree clean. Recheck exact targets before removing Windows long-path leftovers and do not compose recursive deletion across shells.
9. Keep an unintegrated feat tree for review until integration is complete. A lock prevents accidental removal, not stale builds; source-baseline and APK-provenance checks still apply. Keep local cleanup evidence out of public source; do not commit personal paths, logs or APKs.

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
