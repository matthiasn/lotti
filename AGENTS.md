# Repository Guidelines

## Project Structure & Module Organization
- `lib/` — Flutter/Dart source (features, services, widgets). Do not edit generated files (`*.g.dart`, `*.freezed.dart`).
- `test/` and `integration_test/` — unit and integration tests; keep test files as `*_test.dart`.
- `assets/` — images, icons, and other static assets.
- Platform targets: `android/`, `ios/`, `macos/`, `linux/`, `windows/`.
- Tooling & CI: `Makefile`, `.buildkite/`, `analysis_options.yaml`, `l10n.yaml`.
- Localization: `lib/l10n/*.arb` with `missing_translations.txt` for gaps.

## Build, Test, and Development Commands
- Install deps: `make deps` (uses FVM on macOS if available).
- Static analysis: `make analyze` (Very Good Analysis rules).
- Unit tests + coverage: `make test` • HTML report: `make coverage`.
- Code generation: `make build_runner` • Watch mode: `make watch`.
- Localization generation: `make l10n` (prints missing translations) • Sort ARB: `make sort_arb_files`.
- Run locally: `fvm flutter run -d macos` (or `flutter run -d <device>`).
- Integration tests: `make integration_test`.
- Packaging (examples): `make ios`, `make macos`, or `make bundle` (see Makefile for more).

## Coding Style & Naming Conventions
- Follow `analysis_options.yaml` (Very Good Analysis). 2‑space indent, prefer `const` and `final`.
- Files: `lower_snake_case.dart`; types (classes/enums): `PascalCase`; members: `lowerCamelCase`.
- Format before committing: `dart format .`.
- Do not modify generated code (`*.g.dart`, `*.freezed.dart`); regenerate via `make build_runner`.

## Testing Guidelines
- Framework: `flutter_test` with helpers in `test/`. Name tests `*_test.dart` and co‑locate by feature (e.g., `test/features/...`).
- Run: `make test` or `flutter test`. Integration: `make integration_test`.
- Aim to maintain/improve coverage; open report with `make coverage`.

## Commit & Pull Request Guidelines
- Use Conventional Commits (e.g., `feat:`, `fix:`, `chore:`, `ci:`). Keep subjects concise and imperative.
- PRs must pass `make analyze` and `make test`; include a clear description, linked issues, and screenshots/GIFs for UI changes.
- Update docs and localization as needed (run `make l10n`).

## Security & Configuration Tips
- Never commit secrets. Use `.env` for local config; keep it out of VCS.
- Use FVM (`.fvmrc`) to match the repo’s Flutter version: `fvm flutter ...`.
