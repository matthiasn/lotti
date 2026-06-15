# Lotti fork of `flutter_onnxruntime`

Vendored copy of [`flutter_onnxruntime`](https://pub.dev/packages/flutter_onnxruntime)
**1.8.0**, wired in via a `path` `dependency_override` in the repo root
`pubspec.yaml`.

## Why we fork

On-device Supertonic TTS runs ~32 ONNX inference calls per utterance. The
plugin intends to run inference on a background thread (CHANGELOG 1.7.0) via
Flutter's platform-channel **task queue**, but **macOS Flutter does not
implement `makeBackgroundTaskQueue`** — see
[flutter/flutter#162613](https://github.com/flutter/flutter/issues/162613)
(open) and the related Swift-6 variant
[#184737](https://github.com/flutter/flutter/issues/184737) (open). The plugin's
`MessengerHelper.safeMakeBackgroundTaskQueue` therefore returns `nil` on macOS
(it catches the `unrecognized selector` crash —
[masicai/flutter_onnxruntime#58](https://github.com/masicai/flutter_onnxruntime/issues/58)),
so the channel falls back to the **main thread**. The result: synthesis freezes
the UI (a stuttering "preparing" spinner).

## The patch

**One file:**
`macos/flutter_onnxruntime/Sources/flutter_onnxruntime/FlutterOnnxruntimePlugin.swift`

It adds a dedicated **serial** `DispatchQueue` (`workQueue`) and dispatches the
plugin's method-call handler onto it, instead of running on the calling
(main) thread. The queue is serial, so the shared `sessions` / `ortValues`
maps are never accessed concurrently; the pre-existing `NSLock` still guards
against `cleanupResources` on app termination. The reply is delivered via the
normal `result(...)` callback, which `FlutterMethodChannel` marshals back to
the engine from any thread.

Search the file for `LOTTI FORK PATCH` to find the exact changes. Only the
**macOS** implementation is patched; iOS/Android/Linux/Windows are byte-for-byte
upstream (iOS already offloads correctly via its working task queue).

TTS now also targets **Linux**, but the Linux plugin is still upstream for
threading and runs `runInference` synchronously on the GTK main thread (no
background-task-queue API in the Linux desktop embedder to offload to). So Linux
synthesis blocks the UI thread the same way macOS did before this patch —
functional, but not yet smooth. Porting the `workQueue` offload to the Linux
plugin (dispatch `runInference` to a `GTask`/worker thread, reply from the
worker) is the analogous fix; see `lib/features/tts/README.md` → "Platform
threading caveat".

### Linux: offline-build runtime resolution

**File:** `linux/CMakeLists.txt` (search for `LOTTI FORK PATCH`).

Upstream's Linux CMake downloads the ONNX Runtime binary at configure time when
no system copy is found. That fails in offline/sandboxed builds (Flathub), where
the network is unavailable during the build. The patch seeds the
`ONNXRUNTIME_ROOT_DIR` cache variable from the environment variable of the same
name, so the build can point at a pre-provided runtime (`lib/` + `include/`
under a prefix such as `/app`) and skip the download. Unset → empty → upstream
system-search-then-download behaviour is preserved. The Flathub manifest sets
`ONNXRUNTIME_ROOT_DIR=/app` and vendors the runtime there; see
`flatpak/README.md` → "ONNX Runtime (on-device TTS)".

## Upgrading

When bumping `flutter_onnxruntime`, re-vendor the new version and re-apply the
`LOTTI FORK PATCH` edits:

- **macOS** (`FlutterOnnxruntimePlugin.swift`): the `workQueue` property + the
  `handle` → `handleLocked` split. Ideally this lands upstream once macOS gains
  task-queue support (or as an opt-in `DispatchQueue` fallback); drop it then.
- **Linux** (`linux/CMakeLists.txt`): the `ONNXRUNTIME_ROOT_DIR` env seeding.

If the bundled ONNX Runtime **version** changes, also update the pinned binary
URL + per-arch `sha256` in the Flathub manifest's `onnxruntime` module
(`flatpak/com.matthiasn.lotti.flatpak-flutter.yml`).
