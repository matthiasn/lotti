Flatpak/Flathub Build Recovery – Progress Log

Summary
- Goal: Restore a reproducible Flathub submission build for Lotti, generate a submission‑ready manifest (urls + sha256 only), and pass local validation without ad‑hoc network during build.
- Status: Flatpak pipeline largely refactored. flatpak-flutter is now preferred and preserved; nested Flutter 3.35.6 is used; Rust toolchain resolves via SDK extension (with an offline rustup bootstrap for cargokit’s rustup calls); SQLite and mimalloc are provided via declared sources; cargokit patches are applied and ordered correctly. The build reaches the CMake/ninja stage and fails while building the flutter_vodozemac plugin (link/compile step).

Key Changes Implemented
- Prefer flatpak-flutter outputs; fail fast on failure
  - Preserve pubspec-sources.json and flutter-sdk-*.json if flatpak-flutter succeeds; do not overwrite with fallback generators.
  - Abort the run if flatpak-flutter fails, unless `ALLOW_FALLBACK=true` is set for local debugging (strict, submission-friendly default).
  - Code: manifest_tool/prepare/orchestrator.py

- Flutter 3.35.6 and nested SDK by default
  - Detect and use FVM tag 3.35.6 from repo (.fvmrc), generate `flutter-sdk-3.35.6.json`, and use nested SDK to avoid Dart SDK downloads during build.
  - Code: manifest_tool/cli.py, manifest_tool/prepare/orchestrator.py

- Eliminate build-time network for plugin toolchains
  - SQLite and mimalloc are supplied as manifest sources and a SQLite CMake patch is applied to use URL_HASH instead of re-downloading.
  - cargokit patches (run_build_tool.sh.patch) are injected only for super_native_extensions and flutter_vodozemac, and moved after pubspec/cargo sources in the manifest.
  - Code: manifest_tool/flutter/plugins.py, manifest_tool/flutter/patches.py, manifest_tool/prepare/orchestrator.py

- Rust toolchain and cargo config
  - Ensure `/usr/lib/sdk/rust-stable/bin` is on PATH; remove rustup install from build.
  - Stage cargo vendor config into CARGO_HOME; add helper commands for cargokit (mkdir .cargo, link vendor, copy config).
  - Code: manifest_tool/flutter/rust.py, manifest_tool/flutter/offline_fixes.py

- Handle local path dependency (tool/lotti_custom_lint)
  - flatpak-flutter clones the repo then runs `flutter pub get`; if the commit lacks the `tool` path, pub get fails.
  - Pre-stage `tool/lotti_custom_lint` into the flatpak-flutter build tree before pub get and later strip any local `dir` sources from the final manifest.
  - Code: manifest_tool/prepare/orchestrator.py

- Pub tool deps (pinned versions for cargokit tools)
  - Preserve flatpak-flutter’s pubspec-sources.json when available.
  - As a guarded fallback, inject specific pinned packages (e.g., yaml 3.1.2) into pubspec-sources.json as url+sha entries when missing.
  - Avoid path-based sources for submission; builder downloads from pub.dev using sha256.
  - Code: manifest_tool/prepare/orchestrator.py

Current Blocker
- The build completes Flutter assemble and then ninja stops with a subcommand failure while building flutter_vodozemac (no .so produced yet). super_native_extensions builds successfully.
- Failure details (captured from verbose build):
  - Target: `plugins/flutter_vodozemac/libvodozemac_bindings_dart.so`
  - Cargokit external command: `rustup run stable cargo build … --target aarch64-unknown-linux-gnu`
  - Cargo error: `error: no matching package found` searched package name: `ctr` location: `registry crates-io`, required by: `vodozemac_bindings_dart v0.1.0`
  - Interpretation: Cargo is configured to use vendored sources (crates-io replaced), but the vendored set is incomplete — crate `ctr` is missing.

 Root cause analysis
- Our `cargo-sources.json` was generated from an outdated Cargo.lock for dart‑vodozemac.
- We downloaded `flutter_vodozemac-Cargo.lock` from commit `a3446206…`, but the build actually uses `flutter_vodozemac-0.3.0` (tag commit `5319314e…`).
- The 0.3.0 lockfile includes `ctr = 0.9.2`; the older lockfile did not, so `ctr` never got vendored. Result: offline cargo cannot resolve `ctr` and fails.

 Fix plan
- Update the Cargo.lock source for dart‑vodozemac to match the plugin version used in the build (0.3.0):
  - Replace the lockfile URL for `flutter_vodozemac` with: `https://raw.githubusercontent.com/famedly/dart-vodozemac/5319314eb397bc3c8de06baddbe64fa721596ce0/rust/Cargo.lock`.
  - Regenerate `cargo-sources.json` so it includes `ctr 0.9.2` (and any other newly required crates) and rebundle.
- Keep cargokit’s `run_build_tool.sh` patch to force `dart pub get --offline` (already applied). Cargo offline is handled via CARGO_HOME/.cargo/config and vendored sources; no change is required there.
- Ensure the offline rustup bootstrap module is included (we already include `rustup-1.83.0.json`) so `rustup run stable cargo …` works without network.

 Quick verification steps
- Recreate submission payload (strict mode): `./prepare_flathub_submission.sh`
- Validate: `./validate_flathub.sh`
- Inspect `flathub-build/output/cargo-sources.json` and confirm entries for `ctr-0.9.2` are present (archive + .cargo-checksum.json inline).
- Re-run the failing target inside the builder directory for quick feedback:
  - `cd flathub-build/output/.flatpak-builder/build/lotti-1/build/linux/arm64/release`
  - `ninja -v install`

How To Reproduce Locally
1) Prepare Flathub submission artifacts (strict mode):
   - `./prepare_flathub_submission.sh` (fails if `flatpak-flutter` fails)
2) Validate with offline manifest:
   - `./validate_flathub.sh`
3) Debug the CMake/ninja failure (verbose):
   - `cd flathub-build/output/.flatpak-builder/build/lotti-1/build/linux/arm64/release`
   - `ninja -v install` (ensure `ninja` is installed on the host)

What The Submission Manifest Should Contain
- Only url+sha256 entries for 3rd‑party sources (GitHub, pub.dev, sqlite.org, etc.).
- Local assets (desktop, metainfo, icons, screenshot, pubspec-sources.json, cargo-sources.json, flutter-sdk-*.json, small patches) remain `type: file`.
- No `dir` sources (we strip them in post-processing).
  - File: flathub-build/output/com.matthiasn.lotti.yml

Relevant Files (for quick navigation)
- Generator/Orchestrator: manifest_tool/prepare/orchestrator.py
- Flatpak-flutter wrapper/tools: flatpak-flutter/flatpak-flutter.py
- Plugins and patches:
  - manifest_tool/flutter/plugins.py
  - manifest_tool/flutter/patches.py
  - manifest_tool/flutter/offline_fixes.py
  - manifest_tool/flutter/rust.py

Notes / Decisions
- We now fail fast on flatpak-flutter failures by default to mirror Flathub behavior and keep reproducibility.
- `ALLOW_FALLBACK=true` can be set to continue with local fallback generation during investigation, but outputs must remain submission‑safe.
- We prefer flatpak-flutter outputs (pubspec-sources.json, flutter-sdk-*.json) to stay aligned with Flathub’s pipeline.

Addendum: Rust toolchain/rustup
- Cargokit shells out to `rustup run …`. To avoid build-time network, we include an offline rustup bootstrap (`rustup-1.83.0.json`) that seeds `RUSTUP_HOME=/var/lib/rustup` with the toolchain from static.rust-lang.org artifacts bundled as files. PATH includes `/usr/lib/sdk/rust-stable/bin` so `cargo`/`rustc` are available; `rustup run stable …` resolves to the seeded toolchain without network.

Next Planned Steps
- Regenerate `cargo-sources.json` using the 0.3.0 dart‑vodozemac lockfile and retry. If further crates are reported missing, iterate until `ninja install` succeeds for `flutter_vodozemac`.

Next Planned Steps
- Capture verbose ninja output for flutter_vodozemac and patch the manifest/env as needed (e.g., pkg-config, linker flags, feature toggles).
- If its cargokit rust build requires additional vendored crates/config, extend cargo vendor staging (already partly in place via cargo-sources.json).
