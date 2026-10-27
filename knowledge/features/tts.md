---
type: Feature Module
title: Text-to-speech
description: Speech for task summaries, goal reports and query answers — the on-device Supertonic voice, or the cloud voice a profile's read-aloud slot names — with cancellable preparation and temporary audio cleanup.
resource: ../../lib/features/tts
tags: [tts, onnx, on-device, cloud, voxtral, ios, macos]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-10-28T09:00:00Z }
stale_after: 2027-04-26
sources:
  - id: src
    resource: ../../lib/features/tts
    title: Text-to-speech source
    last_modified: 2026-10-28
  - id: cloud-route
    resource: ../../lib/features/tts/cloud/tts_cloud_route.dart
    title: The cloud route a profile's read-aloud slot names
    last_modified: 2026-10-28
  - id: voxtral-service
    resource: ../../lib/features/tts/cloud/voxtral_tts_service.dart
    title: Voxtral speech and voice-catalog client
    last_modified: 2026-10-28
  - id: voice-catalog
    resource: ../../lib/features/tts/cloud/voxtral_voice_catalog.dart
    title: Voice catalog and per-language voice resolution
    last_modified: 2026-10-28
---

Text-to-speech that reads a task's AI **TL;DR**, a goal report or a saved
query answer aloud. By default it runs the Supertonic 3 ONNX model (~99M
params, 44.1 kHz 16-bit WAV) locally via `flutter_onnxruntime`; when the
profile that resolved for the surface names a read-aloud model, that cloud
voice speaks instead (see [which voice speaks](#which-voice-speaks)). Either
way the result plays through the app's existing `media_kit` stack.

**On-device synthesis never leaves the device — but the model has to arrive
first.** The
weights are not bundled. `TtsModelRepository` checks the model directory for the
six files the model's `TtsModelOption.files` lists (four `.onnx` graphs plus
`tts.json` and `unicode_indexer.json`) and downloads whichever are missing from
`https://huggingface.co/<repo>/resolve/<revision>/onnx/<file>`. So the first
synthesis on a fresh install needs the network; every one after it does not, and
no text or audio is sent anywhere.

# Which voice speaks

An inference profile has an optional **Read aloud** slot
(`AiConfigInferenceProfile.speechModelId`, resolved into
`ResolvedProfile.speechProvider` / `speechModel` — see
[profile resolution](ai/profile-resolution.md)). A surface resolves the
profile it already uses and hands `TtsCloudRoute.fromProfile` the result
together with the text's language:

| Surface | Profile | Language |
|---|---|---|
| Task summary card and its companion stage | the task agent's resolved setup | the task's `languageCode`, else the app's |
| Goal report | the goal agent's resolved setup | the app's |
| Query answer | `queryProfileProvider` for the chat | the scope task's `languageCode`, else the app's |
| Day briefing, onboarding companion | none | — |

`fromProfile` returns a route only for a provider with a speech client here —
Mistral (Voxtral TTS) today; another provider joins by adding its case. Every
other outcome, including an empty slot or one that no longer resolves, is the
on-device voice. The on-device voice is never replaced silently by a cloud one,
and a cloud voice never falls back to sending the text somewhere else.

```mermaid
flowchart TD
  Surface["Read-aloud surface"] --> Profile{"Resolved profile names a read-aloud model?"}
  Profile -->|no, or it did not resolve| Local["On-device Supertonic voice"]
  Profile -->|yes| Client{"Provider has a speech client?"}
  Client -->|no| Local
  Client -->|Mistral| Cloud["TtsCloudRoute: Voxtral TTS in the text's language"]
  Cloud --> Voice{"Voice for the language?"}
  Voice -->|user's choice, else first female preset, else any| Speak["POST /v1/audio/speech → temporary WAV"]
  Voice -->|none| NoVoice["error: noVoice — nothing sent"]
  Local --> Play["Shared playback, cancellation and cleanup"]
  Speak --> Play
```

A cloud route needs neither the on-device model nor platform support for it,
so a surface shows its control when **either** the on-device engine is
supported **or** a cloud route exists.

# Cloud voices

`VoxtralTtsService` is the client: `synthesize` posts `model`, `input`,
`voice_id` and `response_format: wav` to the provider's `audio/speech` and
decodes the base64 `audio_data`; `fetchVoices` pages `audio/voices` with
`type=all`. The provider's base URL and API key come from its inference
provider config on every call. Failures are typed (`VoxtralTtsFailure`:
network, timeout, unauthorized, rate limited with `Retry-After`, rejected,
server, invalid response, no voice) with `isRetryable`. Its logs carry text
lengths, voice and model ids and byte counts — never the text, the key or a
response body. It refuses redirects, which would carry the bearer token to
another host, and plain HTTP anywhere but loopback.

`CloudSpeechSynthesizer` turns a route and a text into the same temporary WAV
the on-device engine writes, so everything after synthesis — playback,
`canPlay`, stop, deletion — is the path described below.

**Voices.** `VoxtralVoiceCatalogRepository` caches each provider's catalog in
`SettingsDb` (`TTS_VOXTRAL_VOICES_<providerId>`), device-locally like the
provider's credentials. A cached catalog younger than a day answers without a
request; an older one is refreshed and kept if the refresh fails, so voices
still resolve offline. `VoxtralVoiceCatalog.resolve` picks the voice for a
language: the user's choice for that language while the catalog still has it
(`TtsSettings.cloudVoiceByLanguage`, `TTS_CLOUD_VOICES`), else the language's
first female preset, else its first voice. The API has no voice-per-language
default of its own. A language with no voice fails with `noVoice` before any
text is sent, rather than reading German in an English voice. Speech settings
list each catalog language with that choice and a test that speaks
`speechSettingsCloudVoiceSample` from that language's own ARB catalog.

**Model and speed.** There is one hosted TTS family and no quality or speed
parameter to tune; the curated model is `voxtral-mini-tts-3-0` (Mistral
documents no `-latest` alias for it). WAV keeps the uncompressed format's
lower time to first audio. Speed stays a playback rate, as for the on-device
voice.

**Catalog classification.** Voxtral ships transcription and TTS models under
one prefix. `isSpeechSynthesisModelId` (a dash-separated `tts` segment) marks
the TTS ones text in / audio out in the live Mistral catalog and keeps them off
the transcription route — see [provider routing](ai/provider-routing.md).

# The download is always asked for

The model is about 398.4 MB, and App Store guideline 4.2.3(ii) requires the app
to disclose that size and let the user choose before fetching it. So nothing
downloads it implicitly:

- **The size ships with the app.** `TtsModelOption` pins the Hugging Face
  `revision` (`kSupertonic3Revision`) and lists every file with its byte count
  at that commit (`kSupertonic3Files`); `totalBytes` sums them. Pinning keeps
  the disclosed size true however the repository's default branch moves —
  moving the pin means re-measuring the files.
- **Only `speak` downloads, and only on a yes.** With the model missing it asks
  its `confirmModelDownload` callback (a `TtsModelDownloadConsent`), which every
  read-aloud control fills with
  [`confirmTtsModelDownload`](../../lib/features/tts/ui/tts_model_download_prompt.dart):
  a confirmation modal showing the size, rounded up by `formatDownloadMegabytes`.
  Without a callback, or on a no, nothing is fetched and the utterance ends
  quietly in `stopped`, with no error.
- **`prepare` never downloads.** With the model missing it does nothing.
- **The onboarding companion** only speaks when the model is already installed.
- **Speech settings** show the size under the model name.

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

Task-card and query-answer speak buttons are hidden unless `enable_ai_summary_tts` is enabled in
config flags. **It seeds off** while local TTS model quality and runtime behaviour
are still being evaluated — see [AI provider routing](ai/provider-routing.md).

# Preparation and cancellation

`TtsPlaybackController` owns one utterance. It reserves its busy state before
awaiting model discovery, serializes preparation through the shared ONNX
session, and uses a generation check after asynchronous work. Stop invalidates
that generation immediately. Native synthesis can finish after cancellation,
but the resulting file is deleted without playback. A caller may provide a
`canPlay` callback for a fresh visibility check after synthesis; query chat's
[privacy and lifecycle rules](agents/query-chat.md#audio-evidence-and-spoken-answers)
use that boundary. Source-specific stopping cannot stop another surface's
utterance. `MediaKitTtsAudioPlayer` also invalidates in-flight open/rate changes
on stop or disposal. Temporary utterance WAV files are removed after playback,
cancellation or disposal; model weights remain installed. Cleanup reports
native shutdown failures and still attempts file deletion. It ignores only a
confirmed missing-file error; other filesystem failures are reported through
the speech logging domain without including the temporary file path or content.

Speech settings also expose **Prepare chat audio automatically**, off by default.
`TtsSettingsController` persists this device-local opt-in under
`TTS_AUTO_PREPARE_CHAT_AUDIO`; the existing TTS feature flag still applies.
It enables synthesis, never autoplay, and never downloads: until the user has
agreed to the model download on an explicit play, preparation does nothing.
It never calls a cloud voice either: with a cloud route, `prepare` returns at
once, and query chat's `canPrepare` declines when the chat's profile names one,
so answer text reaches a provider only on an explicit play.

`prepare` keeps at most one disposable result outside playback state, sharing
`_preparation` with explicit speech so the ONNX session is never used concurrently.
Its key includes source ID, exact answer text, voice, model and language. Speed
is applied at playback and does not invalidate the WAV. `speak` waits for a
matching job and takes ownership of its file instead of synthesizing again;
`canPlay` still rechecks live access. A speculative failure remains silent and a
later tap retries normally. `discardPrepared` invalidates a pending job and
removes a completed result, without interrupting an explicitly playing utterance.
A plain playback `stop` leaves this separate cache available for the query
controller's stop-before-play handoff; the chat owner explicitly discards it on
cancellation and navigation.

```mermaid
stateDiagram-v2
  [*] --> empty
  empty --> preparing: permitted published reply and opt-in
  preparing --> ready: synthesis and fresh access check succeed
  preparing --> discarded: cancel or replacement or failed check
  ready --> discarded: navigation or revocation or settings change
  ready --> consumed: explicit Play takes WAV
  preparing --> consumed: explicit Play waits for matching WAV
  discarded --> empty: delete any late result
  consumed --> empty: playback owns cleanup
```

The selected query chat owns scheduling and access checks; see its
[audio lifecycle](agents/query-chat.md#audio-evidence-and-spoken-answers).
Model weights remain installed when prepared answer audio is discarded.

```mermaid
stateDiagram-v2
  [*] --> idle
  idle --> synthesizing: Speak reserves preparation
  synthesizing --> downloadingModel: weights missing and user agreed
  synthesizing --> stopped: weights missing, download declined or not offered
  downloadingModel --> synthesizing: model ready
  synthesizing --> playing: WAV ready and caller allows playback
  playing --> stopped: completion or Stop
  synthesizing --> stopped: Stop or caller denies playback
  downloadingModel --> stopped: Stop
  synthesizing --> error: preparation failure
  downloadingModel --> error: download failure
  playing --> error: playback call fails
  stopped --> synthesizing: Speak
  error --> synthesizing: Retry
```

# Who else listens to an utterance

`TtsPlaybackState` is the one thing a surface reads about an utterance: its
status, its `sourceId`, the playhead `position`, and — while it is `playing`,
and only then — `clip`, the WAV being played together with the text it was
synthesized from. The two travel as one record, so a reader never pairs a clip
with words the screen shows now but the voice was never given. The
[companion](companion.md) reads that clip once to shape her mouth and follows
`position` each frame. The voice imports nothing of hers. `clip` is cleared on
stop, completion and error, because the file is deleted then, and a reader
that gets there late finds no file — the companion falls back to the words
alone.

A failure never reaches the caller of `speak` as an exception: it is the
`error` status above. A surface that asks the voice to speak calls
`listenForPlaybackFailure` (`ui/playback_failure_toast.dart`) from its build,
which shows one error toast per failure of *its* `sourceId` — the AI summary
card and the Daily OS day briefing both do.
