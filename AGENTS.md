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
- Run: `flutter test` or better via mcp. Integration: `make integration_test`.
- Aim to maintain/improve coverage; open report with `make coverage`.
- Do not run all tests unless specifically asked to do so. Takes too long, uses too much context.
- In CI, tests are run with `very_good test` in the same thread. This runs faster on low-end machines such as the CI runner, but requires extra careful cleanup of resources to avoid causes issues in other tests.

### Keeping tests DRY
- **Extract pump/setup helpers**: When multiple tests in a file share `ProviderScope` + `MaterialApp` + localization + `Scaffold` wrapping, extract a file-level helper (e.g. `_pumpWidget(tester, {...})`) that takes only the varying parts as parameters.
- **Extract mock stub helpers**: When the same `when(...)` stub appears in 3+ tests, extract a helper like `_stubCreateSession(repo, categoryId: ...)`.
- **Use test bench classes for complex state**: When tests share a lot of setup (containers, fake channels, services, stream controllers), group them into a `_TestBench` class with a `create()` factory and convenience methods (e.g. `startTranscription()`, `sendPcm()`, `stop()`).
- **Parameterise varying inputs**: Helpers should accept the parts that differ between tests as named parameters (e.g. `selectedCategoryIds`, `extraOverrides`, `onDelta`) and keep the boilerplate fixed internally.
- **Avoid copy-pasting test bodies**: If two tests differ only in a parameter value, consider whether they can share the same helper with different arguments instead of duplicating the entire setup.

### Test Infrastructure Rules
- **Use centralized mocks.** Import from `test/mocks/mocks.dart`. Never define a mock class inline in a test file if it already exists in the central file. If a new mock is needed, add it to `test/mocks/mocks.dart` first, then import it.
- **Use centralized fallback values.** Import from `test/helpers/fallbacks.dart` and call `registerFallbackValue(...)` with values defined there. If a new fallback is needed, add it to the central file.
- **Use `setUpTestGetIt()` / `tearDownTestGetIt()`.** Import from `test/widget_test_utils.dart`. Never write inline `getIt.isRegistered` / `getIt.unregister` / `getIt.registerSingleton` boilerplate. If additional services are needed beyond what the helper registers, extend the helper or register them after calling it.
- **Use `makeTestableWidget()` for widget tests.** Import from `test/widget_test_utils.dart`. Do not create ad-hoc `MaterialApp` / `ProviderScope` / `MediaQuery` wrappers. Use the `overrides` parameter for Riverpod overrides.
- **Use test data factories** where they exist (e.g., `test/features/categories/test_utils.dart`, `test/features/ai/test_utils.dart`). When creating test entities for a feature that already has a factory, use it. When touching a new feature, consider creating one.
- **One test file per source file.** Test file paths must mirror source file paths (`lib/features/foo/bar.dart` → `test/features/foo/bar_test.dart`). Never split tests for one source file across multiple test files.

### Test Quality Rules
- **Every test must assert something meaningful.** `findsOneWidget` alone is not a valid test — it only proves the widget tree built without crashing. Always verify at least one of: displayed content/values, state changes after interaction, callback invocations, or error handling.
- **No copy-paste test permutations.** If you need to test the same widget with different flag combinations (e.g., `private: true/false`, `favorite: true/false`), use a loop or parameterized helper, not N nearly-identical test bodies.
- **No constructor smoke tests.** Tests that only instantiate an object and check `isNotNull` have zero value. Test behavior, not existence.
- **Mock setup must not dwarf test logic.** If a test has 100 lines of mock setup and 5 lines of assertions, the test is either testing the wrong thing or needs a shared helper. Prefer extracting setup into `setUp()` or a helper function.

### Async & Performance Rules
- **Never use `Future.delayed()`, `sleep()`, or real `Timer` in tests.** See `test/README.md` for the fake time policy.
- **Prefer `tester.pump(duration)` over `tester.pumpAndSettle()`.** `pumpAndSettle` has a default 10-second timeout and will hang if animations never settle. Use it only when you genuinely need all animations to complete, and never pass a duration > 1 second.
- **Use `fakeAsync` for unit/service tests** that involve timers, delays, retries, or debounce. See `test/test_utils/retry_fake_time.dart` and `test/test_utils/pump_retry_time.dart` for helpers.
- **Use deterministic dates.** Never use `DateTime.now()` in tests. Use specific dates like `DateTime(2024, 3, 15)`.

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
- Whenever touching any function, consider its docstring and if it needs updating
- Only report completion after code compiles and all tests pass; verify via analyze and test via the dart-mcp server.
- Invest in making tests work; avoid deleting or abandoning failing tests prematurely.
- When old and new feature versions coexist, create no dependencies from the new code to the old.
- Uphold high standards: DRY where sensible, proper modularity, and strong testability.
- Use `fvm` for all `flutter` commands.

## Localization (l10n)
- All user-visible label texts MUST be localized using arb files in `lib/l10n/`.
- Never hardcode strings that users will see — add them to the arb files instead.
- Add new labels to all arb files: `app_en.arb` (primary), `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_ro.arb`.
- Only add to `app_en_GB.arb` if the spelling differs from US English.
- Access localized strings via `context.messages.labelName` (import `app_localizations_context.dart`).
- After adding labels, run `make l10n` to generate the Dart files.
- Run `make sort_arb_files` to keep arb files consistently sorted.
- **NEVER edit the generated `lib/l10n/app_localizations_*.dart` files directly** — always edit the `.arb` source files and regenerate.

## Implementation discipline

- Always ensure the analyzer has no complaints and everything compiles. Also run the formatter
  frequently.
- Prefer running commands via the dart-mcp server.
- Only move on to adding new files when already created tests are all green.
- Write meaningful tests that actually assert on valuable information. Refrain from adding BS
  assertions such as finding a row or whatnot. Focus on useful information. See the
  "Test Infrastructure Rules", "Test Quality Rules", and "Async & Performance Rules"
  subsections under Testing Guidelines for specifics.
- Aim for full coverage of every code path.
- Every widget we touch should get as close to full test coverage as is reasonable, with meaningful
  tests.
- Add CHANGELOG entry under the current version from `pubspec.yaml` (not under [Unreleased]).
- Update `flatpak/com.matthiasn.lotti.metainfo.xml` alongside CHANGELOG — these two files go hand in hand.
- Do not mention bugfixes in CHANGELOG for bugs that were never released. E.g. when working on a 
  feature that comprises many commits, and the bug was fixed before being merged, then there is 
  no reason to mention that bug in the CHANGELOG.
- Update the feature README files we touch such that they match reality in the codebase, not only
  for what we touch but in their entirety.
- In most cases we prefer one test file for one implementation file.
- Maintain READMEs for product features and keep them up-to-date and relevant as you change code.
- Don't report that you've successfully implemented anything unless you've actually verified that the code compiles and tests succeed. Do not be overly confident without checking.
- When writing tests, do not give up too easily and delete what doesn't work right away, instead put some more thought into getting the tests to work.
- When rewriting a feature and instructed to leave both in place, do not create ANY dependencies on the old code, as the goal will usually be to remove the old code once the new code has feature parity, or surpasses it.
- Aim for high engineering standards, such as honoring the DRY principle where sensible, proper modularity, and good testability. Your goal is to create code that people would and should be proud of.
- Do no ever report that you're done with anything when not all tests pass. They must, as no PR can be merged when there are failing tests.
- Use fvm when running any flutter command
- Read test/README.md on every session start and keep it up to date when gaining relevant new information
- Do not hoard code. We do not keep unused code around. Also, this is no library, there are no known mysterious callers for whom we would keep any code around.
