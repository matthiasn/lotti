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

## Agent MCP Usage
- Prefer MCP tools over raw shell commands:
  - Use `dart-mcp` for analyzer, tests, formatting, fixes, pub, and build tasks.
    - Analyze: `dart-mcp.analyze_files`
    - Tests: `dart-mcp.run_tests` (set platforms as needed)
    - Format: `dart-mcp.dart_format`
    - Apply fixes: `dart-mcp.dart_fix`
    - Pub: `dart-mcp.pub` (e.g., `get`, `add`, `upgrade`)
    - Hot reload/runtime hooks: connect to the Dart Tooling Daemon first
  - Use `context7` for up-to-date docs. Resolve with `context7.resolve-library-id`, then fetch via `context7.get-library-docs`.
- Register the repo root before using `dart-mcp` commands: `dart-mcp.add_roots` with the workspace URI.
- For runtime/Flutter app introspection, request a DTD URI from the user and connect via `dart-mcp.connect_dart_tooling_daemon`.
- Follow the planning and preamble conventions:
  - Send a brief preamble before grouped tool calls.
  - Maintain a concise step-by-step plan using `update_plan` for multi-step work.
- Test-first workflow when adding/fixing tests:
  - Run `dart-mcp.analyze_files` to catch lints quickly.
  - Run `dart-mcp.dart_format` to normalize diffs.
  - Run targeted tests (single file or folder) via `dart-mcp.run_tests` before broad runs.
  - Iterate until the targeted tests pass, then run the full suite as needed.
- Do not edit generated files (`*.g.dart`, `*.freezed.dart`); run `dart-mcp.pub` + `make build_runner` (or `dart run build_runner`) via MCP when regeneration is required.
- Favor `rg` for searches and read files in chunks (≤250 lines) when using shell reads.

## Analyzer Zero‑Warning Policy
- Before opening a PR, the analyzer must report zero warnings or infos.
- Always run `dart-mcp.analyze_files` and address every message:
  - In tests, you may add line ignores for clarity (e.g., `// ignore: avoid_redundant_argument_values`).
  - In production code, fix the root cause rather than ignoring.
- Run `dart-mcp.dart_format` to normalize formatting prior to final checks.

## Misc
- Maintain feature READMEs and update them alongside code changes.
- Only report completion after code compiles and all tests pass; verify via analyze and test via the dart-mcp server.
- Invest in making tests work; avoid deleting or abandoning failing tests prematurely.
- When old and new feature versions coexist, create no dependencies from the new code to the old.
- Uphold high standards: DRY where sensible, proper modularity, and strong testability.
- Use `fvm` for all `flutter` commands.
- Read `test/README.md` at session start and update it with relevant new information.
