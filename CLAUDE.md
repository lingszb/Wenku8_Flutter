# Claude Code project instructions

Read [`.agents/PROJECT_GUIDE.md`](.agents/PROJECT_GUIDE.md) before making changes. Treat it as the shared project-level instructions.

For a task touching a domain below, also read its skill before editing:
- UI and layout: `.agents/skills/flutter-ui-regression/SKILL.md`
- Book metadata, categories, series and saved state: `.agents/skills/local-library-integrity/SKILL.md`
- Android build, Gradle or GitHub Actions: `.agents/skills/android-build-ci/SKILL.md`
- Public-source boundary and third-party materials: `.agents/skills/source-boundary-audit/SKILL.md`
- TXT / EPUB import: `.agents/skills/book-import-pipeline/SKILL.md`
- Pagination and reading engine: `.agents/skills/reader-rendering/SKILL.md`
- Missing artwork and image export: `.agents/skills/asset-fallback-export/SKILL.md`

The current source and executable checks take precedence over historical feature claims in documentation. Do not mark a device test as passed based only on a build. Do not merge PRs without instruction.
