# Manifest Tool Unused Code Cleanup Plan

## Usage Analysis Summary

- Only `prepare_flathub_submission.sh` and `create_local_manifest.sh` invoke the Python CLI today. `download_cargo_locks.sh` operates independently.
- Active CLI commands cover manifest pinning, offline manifest adjustments, artifact bundling, and Flutter SDK discovery.
- The following CLI commands appear solely in documentation/tests and have no shell consumers: `pr-aware-pin`, `prepare-build-dir`, `generate-setup-helper`, `add-sqlite3-patch`, `add-offline-build-patches`.
- Corresponding implementations (`operations/ci.pr_aware_environment`, `build_utils.prepare_build_directory` / `copy_flutter_sdk`, `flutter.plugins.add_sqlite3_patch`, `flutter.patches.add_offline_build_patches`, etc.) become orphaned when those commands are removed.
- Tests such as `tests/test_build_utils.py`, `tests/test_ci_ops.py`, and the patch-specific suites exclusively cover the unused code paths.

## Cleanup Plan

1. **Cull unused CLI surfaces** – remove parser entries, `_run_*` adapters, README sections, and CLI tests for the five unused commands.
2. **Delete orphaned implementations** – drop the backing modules and helpers (including deprecated utilities like `replace_url_with_path_text`) that lose all call sites after step 1.
3. **Prune redundant tests** – remove unit suites that only exercise the dead code, keeping coverage focused on active features.
4. **Update exports & docs** – tidy `__all__` lists, package `__init__` barrels, and README command references to match the streamlined CLI.
5. **Verification** – run `pytest manifest_tool/tests` and perform a dry run of `prepare_flathub_submission.sh` (or an equivalent smoke test) to confirm the remaining workflow still succeeds.

Executing this plan keeps the manifest tool aligned with real-world usage and trims maintenance overhead from dormant code paths.
