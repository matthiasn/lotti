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
