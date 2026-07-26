# Contributing to Lotti

Thanks for your interest in contributing! Lotti is built by and for people who value privacy and data ownership.

## Ways to Contribute
- Report bugs and request features via Issues: https://github.com/matthiasn/lotti/issues
- Improve test coverage (see Codecov badge in README)
- Add or improve translations
- Submit pull requests for fixes and features
- Join discussions: https://github.com/matthiasn/lotti/discussions

## Current Focus Areas
- Improving local inference performance

## Future Improvements
- Chat persistence and richer AI conversation features
- Enhanced reporting and analytics
- Easier cross-platform synchronization setup
- AI-enhanced habit monitoring with custom notifications

## Development Workflow
- Setup and day-to-day commands are documented in `docs/DEVELOPMENT.md`.
- Typical flow:
  - `make deps` → `make analyze` → `make test` (and `make coverage`)
  - `make l10n` and `make build_runner` when changing ARB files or generated sources

## Coding Standards
- Conventional Commits for messages (e.g., `feat:`, `fix:`, `docs:`, `chore:`)
- Keep analyzer at zero warnings/info before opening a PR
- Prefer `const`/`final`; 2-space indentation; follow `analysis_options.yaml`
- Format code: `dart format .`
- Don’t modify generated files (`*.g.dart`, `*.freezed.dart`); use `make build_runner`
- Tests live under `test/` as `*_test.dart`

## Pull Requests
- Include a clear description of the change
- **For UI changes, attach a before *and* after screenshot** for each surface you
  touched — one picture of the new state cannot tell a reviewer an improvement from
  a regression. Capture the "before" from the base commit, before your change
  exists; reconstructing it later is the step people skip.
- **Do not commit images to this repository.** Attach them to the pull request
  through GitHub's upload. (Maintainers put them in the sibling `lotti-docs` repo
  and link the raw URLs; that repo is not writable from a fork.) See
  [knowledge/conventions/screenshots.md](knowledge/conventions/screenshots.md).
- Ensure `make analyze` and `make test` pass
- Update documentation and localization as needed (`make l10n`)
- Keep changes focused; avoid unrelated refactors

## Security
- See `SECURITY.md` for vulnerability reporting.

We appreciate your help making Lotti better!
