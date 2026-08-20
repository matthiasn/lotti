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
- Format before committing: `fvm dart format .`.
- Do not modify generated code (`*.g.dart`, `*.freezed.dart`); regenerate via `make build_runner`.

## Testing Guidelines
- Framework: `flutter_test`, helpers in `test/`. Name tests `*_test.dart` and co-locate by feature. **One test file per source file**, mirroring the path.
- Run tests via the dart-mcp server, **only for the files you actually touched**. Do not run the whole suite locally, and do not run a whole feature's suite either — `agents` alone takes minutes, worse in a Linux VM. CI runs everything ten-way sharded on every push, so let it. Broader local runs only when asked, or when a change genuinely cannot be scoped to the files you touched.
- **Never `Future.delayed`, `sleep()` or a real `Timer` in a test.** Use `fakeAsync` or `tester.pump(duration)`, and deterministic dates rather than `DateTime.now()`.
- **Reuse the shared harness**: mocks from `test/mocks/mocks.dart`, fallbacks from `test/helpers/fallbacks.dart`, `setUpTestGetIt()` / `tearDownTestGetIt()`, `makeTestableWidget()`. Never improvise a per-file equivalent.
- **Every test must assert something meaningful.** `findsOneWidget` alone proves only that the tree built; a constructor smoke test proves nothing at all.
- **Re-run every new regression test with the fix reverted.** If it still passes, it is not testing the fix.
- The full contract — the DRY rules, the infrastructure table, the quality bar, the vacuous-pass traps, property tests, time-driven UI — is [knowledge/conventions/testing.md](knowledge/conventions/testing.md), plus [test/README.md](test/README.md) for the fake-time policy and mocktail hygiene. Read them rather than working from this summary.

## Commit & Pull Request Guidelines
- Use Conventional Commits (e.g., `feat:`, `fix:`, `chore:`, `ci:`). Keep subjects concise and imperative.
- PRs must pass `make analyze` and `make test`; include a clear description and linked issues.
- **UI changes need a before/after screenshot pair per surface**, captured with the harness (see the `app-screenshots` skill). Capture `before/` from the base commit *first* — it cannot be reconstructed once the change is in. **Never commit images to any repo.** Publish the pair to the R2 bucket with `make pr_screenshots_publish` and link the printed public URLs from the PR body. The staging layout, the naming rules and the publish command are in [knowledge/conventions/screenshots.md](knowledge/conventions/screenshots.md).
- Update docs and localization as needed (run `make l10n`).

## Security & Configuration Tips
- Never commit secrets. Use `.env` for local config; keep it out of VCS.
- Use FVM (`.fvmrc`) to match the repo’s Flutter version: `fvm flutter ...`.

## Agent MCP Usage
- Prefer MCP tools over raw shell commands:
  - Use `dart-mcp` for analyzer, tests, formatting, fixes, pub, and build tasks.
    - Analyze: `dart-mcp.analyze_files`
    - Tests: `dart-mcp.run_tests` (set platforms as needed)
    - Format: `fvm dart format .`
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
  - Run `fvm dart format .` to normalize diffs. Do not use `dart-mcp.dart_format`.
  - Run targeted tests (single file or folder) via `dart-mcp.run_tests` before broad runs.
  - Iterate until the targeted tests pass, then run the full suite as needed.
- Do not edit generated files (`*.g.dart`, `*.freezed.dart`); run `dart-mcp.pub` + `make build_runner` (or `dart run build_runner`) via MCP when regeneration is required.
- Favor `rg` for searches and read files in chunks (≤250 lines) when using shell reads.

## Analyzer Zero‑Warning Policy
- Before opening a PR, the analyzer must report zero warnings or infos.
- Always run `dart-mcp.analyze_files` and address every message:
  - In tests, you may add line ignores for clarity (e.g., `// ignore: avoid_redundant_argument_values`).
  - In production code, fix the root cause rather than ignoring.
- Run `fvm dart format .` to normalize formatting prior to final checks. Do not use
  `dart-mcp.dart_format`.

## Documentation

Documentation is split by audience. **No fact is written twice.**

- **`lib/features/<x>/README.md` — product description.** What the feature does,
  what it owns versus what it delegates, and where the code sits. Roughly 40–100
  lines, ending with a link to its knowledge concept. If a README starts
  explaining provider routing or wake scheduling, that content belongs in
  `knowledge/`.
- **`knowledge/` — the architecture, in OKF v0.2 form.** Runtime flows, state
  machines, invariants, key classes, gotchas. This is the durable, agent-readable
  map of how the app actually works. Read the relevant concept *before* changing
  a subsystem, and update it in the same change.
  [knowledge/index.md](knowledge/index.md) is the entry point: it carries the
  reading order and the code-to-concept map.
- **`docs/adr/` — decisions.** An ADR records a choice at a point in time and is
  not rewritten; concepts cite ADRs rather than restating them.

**These concepts are derived maps, not authority.** The source code outranks
them: if a concept contradicts the code, the concept is the defect, and fixing it
is part of your change. Verify a claim before you depend on it.

Rules for `knowledge/`:

- Every concept carries required OKF frontmatter, and `make okf_check` fails on a
  missing or malformed field. The field-by-field contract is in
  [knowledge/conventions/knowledge-bundle.md](knowledge/conventions/knowledge-bundle.md)
  — follow it there rather than from memory.
- Do **not** set `verified` on a concept you wrote. That field records
  independent confirmation by someone other than the author.
- Use Mermaid diagrams generously for flows, architecture, data movement and
  lifecycles. If the code contains a real lifecycle or state machine, the
  concept must include a diagram for it — prefer `stateDiagram-v2`, and never
  invent states that are not implemented.
- Every path a concept references must exist. `make okf_check` fails the build
  on a dangling code pointer, which is the mechanism that keeps the map honest.
- Run `make knowledge_check` after touching anything under `knowledge/`. It runs the Dart validator *and* parses every Mermaid diagram — `make okf_check` alone cannot see a diagram that fails to render.

## Misc
- Whenever touching any function, consider its docstring and if it needs updating
- Only report completion after code compiles and all tests pass; verify via analyze and test via the dart-mcp server.
- Invest in making tests work; avoid deleting or abandoning failing tests prematurely.
- When old and new feature versions coexist, create no dependencies from the new code to the old.
- Uphold high standards: DRY where sensible, proper modularity, and strong testability.
- Use `fvm` for all `flutter` commands.

## Localization (l10n)
- All user-visible label texts MUST be localized using arb files in `lib/l10n/`.
- Never hardcode strings that users will see — add them to the arb files instead.
- **Add every new label to every catalog in `lib/l10n/`**, translated — not a
  subset. The catalog list, the `app_en_GB.arb` exception and the per-language
  register table live in
  [knowledge/conventions/localization.md](knowledge/conventions/localization.md).
  Read it rather than working from a count or a list quoted anywhere else,
  including here.
- Access localized strings via `context.messages.labelName` (import `app_localizations_context.dart`).
- After adding labels, run `make l10n` to generate the Dart files.
- Run `make sort_arb_files` to keep arb files consistently sorted.
- **NEVER edit the generated `lib/l10n/app_localizations_*.dart` files directly** — always edit the `.arb` source files and regenerate.
- **Use the informal register** in every translation, with Romanian as the one deliberate exception. Which pronouns that means per language is in the concept linked above.

## Implementation discipline

Every UI change is bound by the design system. Read
[knowledge/features/design_system/](knowledge/features/design_system/) before
touching visual code — the token pipeline and its naming, the component contracts,
and what is enforced at construction rather than by review.

- **Design-system tokens are mandatory.** For colors, spacing, radii, typography, elevation, and other visual styling values, always use the exported design-system tokens or existing design-system abstractions first.
- **Spacings and font styles MUST come from the Design System.** Never hardcode spacing values (raw numbers in `EdgeInsets`/`SizedBox`/local `const double` constants) or font styles (raw `fontSize`/`fontWeight`/`TextStyle` constructors). Use `tokens.spacing.stepN` (or `cardPadding`/`cardItemSpacing`/`sectionGap`) and `tokens.typography.styles.{display,heading,subtitle,body,others}.<name>`. If no suitable token exists, stop and ask before introducing one.
- **Do not invent ad hoc visual values by default.** Before adding a hard-coded color, spacing value, radius, opacity, or a one-off semantic alias for a visual token, first check the design-system token export and existing design-system components/palettes.
- **Ask before introducing new visual tokens or hard-coded values.** If no suitable design-system token exists, stop and ask for permission before creating an ad hoc fallback, local palette entry, or other non-token visual value.
- **Never flash established UI during background refresh.** When an async provider reloads because of sync, database notifications, or another background dependency change, preserve the last rendered data (`skipLoadingOnReload`, stale-while-revalidate state, or equivalent) instead of swapping the page to a full-screen loading, empty, or error shell. Full loading shells are for initial loads and deliberate route/date changes only; background refresh should use local/subtle progress affordances.
- **Prefer fixing the token source over patching the widget.** If a Figma export flattened or obscured a semantic token name, prefer tracing it back to the exported token set or improving the import/export path instead of hard-coding a widget-level substitute.
- **Check the token name in the actual Figma node inspect panel first.** Even when the Variables API is incomplete or unavailable, the selected node often shows the bound token name directly under Colors, e.g. `background/02`.
- **Know the naming path across tools.** The same token is named differently in Figma, `tokens.json` and Dart — the table is in [design tokens and theming](knowledge/features/design_system/tokens-and-theming.md#one-token-three-names). Treat them as one token with normalised naming, not as different concepts.
- **Verifying a visual token, in order:** inspect the selected node in Figma Desktop Bridge, confirm the entry in `assets/design_system/tokens.json`, then map it to the generated token. If the inspect panel already shows the name, do not conclude it is unavailable just because the Variables API returned empty data.
- Always ensure the analyzer has no complaints and everything compiles. Also run the formatter
  frequently.
- Prefer running commands via the dart-mcp server.
- Only move on to adding new files when already created tests are all green.
- Write meaningful tests that actually assert on valuable information. Refrain from adding BS
  assertions such as finding a row or whatnot. Focus on useful information.
  [knowledge/conventions/testing.md](knowledge/conventions/testing.md) has the
  specifics — the infrastructure rules, the quality bar and the async rules.
- Aim for full coverage of every code path.
- Every widget we touch should get as close to full test coverage as is reasonable, with meaningful
  tests.
- Add CHANGELOG entry under the current version from `pubspec.yaml` (not under [Unreleased]).
- Update `flatpak/com.matthiasn.lotti.metainfo.xml` alongside CHANGELOG — these two files go hand in hand.
- Do not mention bugfixes in CHANGELOG for bugs that were never released. E.g. when working on a 
  feature that comprises many commits, and the bug was fixed before being merged, then there is 
  no reason to mention that bug in the CHANGELOG.
- CHANGELOG entries are only required for things a user would actually notice. Skip them for
  invisible work: dependency bumps with no behavior change, internal refactors, test-only
  changes, build/CI tweaks, doc updates. If in doubt, ask — but default to "no entry" when the
  user wouldn't see a difference at runtime.
- Update the documentation we touch such that it matches reality in the codebase, not only
  for what we touch but in its entirety. See "Documentation" below for which file gets what.
- In most cases we prefer one test file for one implementation file.
- Don't report that you've successfully implemented anything unless you've actually verified that the code compiles and tests succeed. Do not be overly confident without checking.
- When writing tests, do not give up too easily and delete what doesn't work right away, instead put some more thought into getting the tests to work.
- When rewriting a feature and instructed to leave both in place, do not create ANY dependencies on the old code, as the goal will usually be to remove the old code once the new code has feature parity, or surpasses it.
- Aim for high engineering standards, such as honoring the DRY principle where sensible, proper modularity, and good testability. Your goal is to create code that people would and should be proud of.
- Do no ever report that you're done with anything when not all tests pass. They must, as no PR can be merged when there are failing tests.
- Use fvm when running any flutter command
- Read test/README.md on every session start and keep it up to date when gaining relevant new information
- Do not hoard code. We do not keep unused code around. Also, this is no library, there are no known mysterious callers for whom we would keep any code around.

## Issue Tracking

- Public bugs, feature requests, and contributor coordination belong in
  [GitHub Issues](https://github.com/matthiasn/lotti/issues).
- Authorized maintainers may use the private Beads tracker for implementation
  plans, dependencies, handoffs, and durable agent memory. Follow
  `.agents/skills/beads/SKILL.md`.
- Public contributors are not expected to install Beads or have access to the
  private tracker. PR descriptions and GitHub issue links must contain all
  context needed for public review.
- Agent-local planning tools remain appropriate for the current turn. Beads is
  the durable maintainer record, not a replacement for a short execution plan.
- Beads sync, Git commits, and pushes require explicit user or orchestrator
  authority. Never store secrets in Beads.
- Do not install repository-controlled Git, Codex, or Claude hooks for Beads.
  Maintainers run `bd prime`, `bd dolt pull`, and `bd dolt push` explicitly.
