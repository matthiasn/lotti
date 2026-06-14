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
upstream (iOS already offloads correctly via its working task queue, and TTS is
macOS-only for now).

## Upgrading

When bumping `flutter_onnxruntime`, re-vendor the new version and re-apply the
two `LOTTI FORK PATCH` edits (the `workQueue` property + the `handle` →
`handleLocked` split). Ideally this lands upstream once macOS gains task-queue
support (or as an opt-in `DispatchQueue` fallback); drop the fork then.
