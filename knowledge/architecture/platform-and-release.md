---
type: Architecture
title: Platform targets, CI and release
description: Five platform targets from one codebase, the checks every branch runs, and the tag that triggers seven release pipelines.
resource: ../..
tags: [architecture, ci, release, platforms, build]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T16:00:00Z }
stale_after: 2027-01-11
sources:
  - id: workflows
    resource: ../../.github/workflows
    title: GitHub Actions workflows
    last_modified: 2026-07-26
  - id: makefile
    resource: ../../Makefile
    title: Developer and build entry points
    last_modified: 2026-07-26
  - id: pubspec
    resource: ../../pubspec.yaml
    title: Version, SDK constraints, dependencies
    last_modified: 2026-07-26
  - id: fvmrc
    resource: ../../.fvmrc
    title: Pinned Flutter version
    last_modified: 2026-07-22
  - id: codemagic
    resource: ../../codemagic.yaml
    title: Windows release pipeline
    last_modified: 2026-07-30
---

# One codebase, five targets

| Platform | Distribution |
|----------|--------------|
| macOS | TestFlight and direct release build |
| iOS | TestFlight |
| Android | APK / AAB |
| Linux | Flatpak (Flathub) and tarball |
| Windows | MSIX |

The Flutter SDK is **pinned in `.fvmrc`** (currently 3.44.7) and every command
is expected to run through FVM — `fvm flutter …`, `fvm dart …`.

Dart SDK constraint: `>=3.12.0 <4.0.0`; Flutter `>=3.44.0`.

## Bumping the Flutter version

`.fvmrc` is the source of truth, but it is not the only place the version is
written down. Most consumers follow it automatically; one does not:

| Consumer | Follows `.fvmrc`? |
|----------|-------------------|
| GitHub Actions lanes | Yes — `kuhnroyal/flutter-fvm-config-action` reads it |
| Codemagic Windows release | Yes — `environment.flutter: fvm` reads it |
| [`flatpak/com.matthiasn.lotti.flatpak-flutter.yml`](../../flatpak/com.matthiasn.lotti.flatpak-flutter.yml) | **No — hand-edit the Flutter `tag:`** |

So a Flutter bump is `.fvmrc` **plus** the Flatpak manifest's Flutter `tag:`.
That tag currently reads 3.44.0 against a 3.44.7 pin; it still resolves because
the constraint floor is `>=3.44.0`, which is precisely why the drift is easy to
miss.

A stale pin does not announce itself. It surfaces one layer down, as
`pub get` failing version solving — "the current Dart SDK version is X, because
lotti requires SDK version >=3.12.0 <4.0.0, version solving failed" — which
reads like a dependency problem rather than a toolchain one. The Windows lane
sat broken this way across a dozen consecutive release tags.

# Continuous integration

Every push to every branch runs:

| Workflow | What it enforces |
|----------|------------------|
| `flutter-analyze.yml` | `flutter analyze` — the zero-warning policy |
| `flutter-test-linux-faster.yml` | The fast unit/widget test lane on Linux |
| `flutter-matrix-test.yml` | Sync tests against a real Matrix homeserver |
| `okf-validate.yml` | This knowledge bundle stays conformant and its code pointers still resolve |

Two more run on **every** branch push despite looking scoped:

- `type-check.yml` — mypy, with **no path filter at all**. Advisory: it runs
  with `continue-on-error`.
- `flatpak-foreign-deps.yml` — path-filtered on *pull requests*, but unfiltered
  on branch pushes.

Genuinely path-filtered, both on pushes *and* pull requests to `main`:
`python-tools-ci.yml` (the Python tools) and `manual.yml` (docs-site) — the latter
also runs on a nightly cron (`23 2 * * *`) and on manual dispatch.

The ten-way shard belongs to `flutter-test-linux-faster.yml` above: it runs
`very_good test` across a ten-job matrix. **Buildkite is not sharded** — the
pipelines under `.buildkite/` run a bare `flutter test` for the Linux and Windows
lanes plus the JUnit upload. What the sharded lane means for how tests must be
written is in [testing conventions](../conventions/testing.md).

# Release

Release is triggered by **pushing a git tag whose name is the `pubspec.yaml`
version**. Seven GitHub workflows listen on `push: tags: ['**']`, and Windows
fans out from the same tag on a different provider:

```mermaid
flowchart TD
  Bump["Bump version in pubspec.yaml + CHANGELOG.md + flatpak metainfo"] --> Tag["git tag <version> && git push origin <version>"]
  Tag --> A["flutter-macos-testflight.yml"]
  Tag --> B["flutter-macos-release.yml"]
  Tag --> C["flutter-ios-testflight.yml"]
  Tag --> D["flutter-android-release.yml"]
  Tag --> E["flutter-linux-release.yml"]
  Tag --> F["flathub-release-pr.yml"]
  Tag --> G["python-services-release.yml"]
  Tag --> H["codemagic.yaml — Windows MSIX"]
```

**Windows is the one target not built on GitHub Actions.** It runs on
[Codemagic](../../codemagic.yaml), on a `windows_x2` instance, triggered by the
same `*.*.*+*` tag pattern, and it reports back as a `Windows Release` check on
the tagged commit. Because it lives outside `.github/workflows/`, it is easy to
overlook when auditing CI — its failures show up only on tag commits and in the
build-notification email, never on a pull request.

`flathub-release-pr.yml` also accepts `workflow_dispatch` with an explicit
commit SHA and version override, for re-cutting a Flathub PR without moving the
tag.

Two files must move together with every user-visible change, and the repo treats
them as a pair:

- `CHANGELOG.md` — an entry under the **current** `pubspec.yaml` version, not
  under `[Unreleased]`.
- `flatpak/com.matthiasn.lotti.metainfo.xml` — the same release, in AppStream
  form, which is what Flathub renders.

Entries are only for things a user would notice. Dependency bumps, refactors,
test-only changes and CI tweaks get none.

# Local commands

| Task | Command |
|------|---------|
| Install dependencies | `make deps` |
| Static analysis | `make analyze` |
| Unit tests | `make test` (coverage report: `make coverage`) |
| Code generation | `make build_runner` (watch: `make watch`) |
| Localization | `make l10n`, `make sort_arb_files` |
| Integration tests | `make integration_test` |
| Knowledge bundle check | `make knowledge_check` (validator + mermaid) |
| Run the app | `fvm flutter run -d <device>` |

Generated files — `*.g.dart`, `*.freezed.dart` — are checked in and must never
be hand-edited; regenerate with `make build_runner`. One build-runner flag
combination is actively destructive; see
[code style and analysis](../conventions/code-style.md) for it, which is where the
generated-code rules live.

# Where to look

| Concern | File |
|---------|------|
| CI and release pipelines | [`.github/workflows/`](../../.github/workflows) |
| Windows release (Codemagic) | [`codemagic.yaml`](../../codemagic.yaml) |
| Buildkite lanes | [`.buildkite/`](../../.buildkite) |
| Build, test, packaging targets | [`Makefile`](../../Makefile) |
| Flatpak manifest and metainfo | [`flatpak/`](../../flatpak) |
| Pinned SDK | [`.fvmrc`](../../.fvmrc) |
