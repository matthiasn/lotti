---
type: Feature Module
title: Text-to-speech
description: On-device Supertonic TTS reading a task's AI TL;DR aloud, with a targeted CocoaPods workaround for a statically linked runtime.
resource: ../../lib/features/tts
tags: [tts, onnx, on-device, ios, macos]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T04:00:00Z }
stale_after: 2027-03-08
sources:
  - id: src
    resource: ../../lib/features/tts
    title: Text-to-speech source
    last_modified: 2026-07-26
---

On-device text-to-speech that reads a task's AI **TL;DR** aloud. It runs the
Supertonic 3 ONNX model (~99M params, 44.1 kHz 16-bit WAV) locally via
`flutter_onnxruntime` and plays the result through the app's existing `media_kit`
stack.

**Synthesis never leaves the device — but the model has to arrive first.** The
weights are not bundled. `TtsModelRepository` checks the model directory for the
six files in `kSupertonicModelFiles` (four `.onnx` graphs plus `tts.json` and
`unicode_indexer.json`) and downloads whichever are missing from
`https://huggingface.co/<repo>/resolve/main/onnx/<file>`. So the first speak on a
fresh install needs the network; every one after it does not, and no text or audio
is ever sent anywhere.

The engine sits behind a `TtsEngine` interface, with `SupertonicOnnxEngine` wired
on macOS, iOS, Linux and Android.

# The Apple linkage workaround

On Apple platforms onnxruntime ships as a **statically linked binary**, which
CocoaPods rejects under the project's dynamic `use_frameworks!`.

The global fix — `use_frameworks! :linkage => :static` — **breaks
`super_native_extensions`' Rust FFI**. So both `macos/Podfile` and `ios/Podfile`
instead use a **targeted `pre_install` hook** that forces static linkage for only
the `flutter_onnxruntime` plugin and its `onnxruntime-*` dependencies.

That narrowness is the point: the workaround is scoped to the one plugin that
needs it, so the rest of the project keeps dynamic frameworks.

# Gating

The task-card speak button is hidden unless `enable_ai_summary_tts` is enabled in
config flags. **It seeds off** while local TTS model quality and runtime behaviour
are still being evaluated — see [AI provider routing](ai/provider-routing.md).
