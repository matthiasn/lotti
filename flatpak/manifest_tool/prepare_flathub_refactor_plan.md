# Prepare Flathub Refactor Plan

## Goal
Refactor `flatpak/prepare_flathub_submission.sh` into a thin wrapper that delegates nearly all functionality to modular, testable Python code within `manifest_tool`.

## Milestones

### 1. Inventory Current Script Responsibilities
- Catalogue each logical block in `prepare_flathub_submission.sh` (environment/config resolution, workspace prep, flatpak-flutter orchestration, cache priming, artifact bundling, compliance checks, cleanup).
- Record inputs, outputs, side effects, and relevant environment variables to preserve behaviour.

### 2. Design Python-Orchestrated Workflow
- Define a new `manifest_tool` CLI entry point (e.g. `prepare-flathub`) that mirrors the full pipeline.
- Identify which steps reuse existing manifest_tool helpers and which need new modules (build setup, cache management, flatpak-flutter driver, artifact collectors).
- Specify logging strategy and error reporting expectations.

### 3. Extract Shell Logic into Modular Helpers
- Port individual phases into focused Python helpers under a new package namespace (e.g. `manifest_tool/build/prepare/`).
- Ensure each helper has clear contracts (arguments, return data, side effects) so they can be unit-tested.
- Add targeted pytest coverage for new modules, using fixtures to simulate workspace layouts.

### 4. Implement High-Level Orchestrator
- Implement the `prepare-flathub` CLI command that wires helpers together, honours env toggles (`CLEAN_AFTER_GEN`, `PIN_COMMIT`, `TEST_BUILD`, etc.), and surfaces meaningful exit codes.
- Provide progress logging that matches or improves upon the current shell output.
- Add integration-style tests around the orchestrator (e.g. pytest harness invoking the CLI against a temp workspace).

### 5. Replace Shell Script with Thin Wrapper
- Reduce `prepare_flathub_submission.sh` to prerequisite checks and delegation to `python3 manifest_tool/cli.py prepare-flathub "$@"`.
- Maintain backward-compatible environment variable handling and user-facing ergonomics.

### 6. Update Tooling and Documentation
- Update CI workflows and developer docs to reference the new CLI command.
- Remove obsolete shell-specific helpers or mark them for deletion once parity is confirmed.
- Run `make analyze`, relevant pytest suites, and an end-to-end prep run to validate the refactor.

### 7. Optional Enhancements Post-Refactor
- Introduce caching abstractions for Flutter artifacts and Cargo locks, richer telemetry, or dry-run capabilities within the Python implementation without changing the wrapper.

## Step 1 Notes – Responsibility Inventory

### Environment & Inputs
- Detects repo and script paths, defines work/output directories under `flatpak/flathub-build`.
- Assumes AppStream metadata ships with the release version/date already committed upstream (no placeholder substitution).
- Determines current git branch and validates remote presence (uses `GITHUB_HEAD_REF`, `GITHUB_REF_NAME`).
- Behaviour toggles via env vars: `CLEAN_AFTER_GEN`, `PIN_COMMIT`, `USE_NESTED_FLUTTER`, `DOWNLOAD_MISSING_SOURCES`, `NO_FLATPAK_FLUTTER`, `FLATPAK_FLUTTER_TIMEOUT`, `TEST_BUILD`, plus optional caches (`PUB_CACHE`, `LOTTI_ROOT`, etc.).

### Workspace Preparation
- Creates/cleans `flathub-build` work dir, copies source manifest, replaces branch/commit placeholders.
- Injects Flutter SDK source snippet into manifest for flatpak-flutter compatibility.

### Dependency Priming
- Locates cached Flutter SDK (`find_cached_flutter_dir`, Python CLI helper) and primes `.flatpak-builder/build/lotti/flutter`.
- Stages `pubspec.yaml`, `pubspec.lock`, and default `foreign_deps.json` placeholders into expected build dirs.

### flatpak-flutter Execution
- Ensures `flatpak-flutter` repo is cloned locally.
- Runs `flatpak-flutter.py` with optional timeout, teeing logs.
- Fails fast if flatpak-flutter is missing or fails.

### Artifact Collection & Post-processing
- Pins manifest to commit, validates absence of `branch`/`COMMIT_PLACEHOLDER`.
- Copies generated JSON files (flutter, pubspec, cargo, rustup) from workdir/build caches into `output/`.
- Generates missing artifacts via Python helpers or ad-hoc shell (e.g. reproduce cargo JSON, package_config).
- Normalises sqlite patch content.

### Compliance & Bundling
- Runs multiple `manifest_tool` CLI commands to enforce Flathub rules (remove network, ensure offline flags, apply offline fixes, convert flutter git to archive, bundle sources, bundle app archive, rewrite URLs, etc.).
  - Downloads Cargo.lock files via Python orchestrator helpers and regenerates `cargo-sources.json`.
- Bundles Flutter archive and other referenced sources; ensures helper patches copied.

### Verification & Cleanup
- Executes final compliance check, ensures manifest pinned.
- Optional test build (`TEST_BUILD=true`) using `flatpak-builder`.
- Optionally cleans `.flatpak-builder` directories when `CLEAN_AFTER_GEN=true`.
- Summarises output contents.

### Observations for Refactor
- Many steps already rely on manifest_tool Python helpers, but orchestration lives in bash.
- Shell handles complex control flow, error handling, and repeated filesystem traversal that would benefit from structured Python modules and unit tests.

## Progress Snapshot (Session)
- Added Python scaffolding under `manifest_tool.prepare` including option parsing, context construction, and CLI plumbing (`prepare-flathub` command).
- New CLI currently surfaces "conversion in progress" error until the remaining shell logic is migrated.
- Next concrete tasks: implement `_execute_pipeline` with modular helpers, add tests for each stage, and then replace the shell script body with a thin call into this command.

## Completion Notes
- Python orchestrator implemented in `flatpak/manifest_tool/prepare/orchestrator.py`, covering full pipeline (workspace prep, flatpak-flutter invocation, artifact collection, compliance, bundling, cleanup).
- CLI now exposes `prepare-flathub`; legacy shell script delegates directly to the Python command.
- Added unit tests in `flatpak/manifest_tool/tests/prepare/test_orchestrator.py` covering key helper utilities.
- Verified via `python3 -m unittest flatpak.manifest_tool.tests.prepare.test_orchestrator`.
