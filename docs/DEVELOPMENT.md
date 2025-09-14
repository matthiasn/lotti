# Development Setup

This document outlines the recommended development workflow for Lotti.

## Tooling
- Flutter via FVM (recommended). The repo includes `.fvmrc` to pin the version.
- Makefile targets wrap common tasks.

## One-Time Setup
```
make deps
```

## Frequent Tasks
- Analyze: `make analyze`
- Format: `dart format .`
- Tests: `make test`
- Coverage report: `make coverage`
- Code generation: `make build_runner`
- Localization generation: `make l10n`

### Coverage tools (lcov/genhtml)
To generate the HTML report with `make coverage`, install lcov (includes `genhtml`):

- macOS: `brew install lcov`
- Ubuntu/Debian: `sudo apt-get update && sudo apt-get install -y lcov`
- Fedora: `sudo dnf install lcov`
- Arch: `sudo pacman -S lcov`

After installation, run `make coverage` and open `coverage/index.html`.

## Running the App
- macOS: `fvm flutter run -d macos`
- Other platforms: `flutter run -d <device>`

## Localization
- ARB files live under `lib/l10n/`
- Generate localizations: `make l10n`
- Optional: sort ARB files: `make sort_arb_files`

## Code Generation
- Run once: `make build_runner`
- Watch mode (optional): `make watch`

## Analyzer Policy
- Aim for zero warnings or infos before opening a PR. Address all analyzer messages; prefer fixes over ignores in production code.

## Commit & PR Guidelines
- Conventional Commits (e.g., `feat:`, `fix:`, `docs:`, `chore:`)
- Keep subjects concise and imperative.
- PRs should pass `make analyze` and `make test` and include a clear description (and screenshots/GIFs for UI changes where relevant).
