---
type: Feature Module
title: Text-to-speech
description: Speech for task summaries, goal reports and query answers — the on-device Supertonic voice, or the cloud voice a profile's read-aloud slot names — with cancellable preparation and temporary audio cleanup.
resource: ../../lib/features/tts
tags: [tts, onnx, on-device, cloud, voxtral, elevenlabs, ios, macos]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-11-04T12:00:00Z }
stale_after: 2027-04-26
sources:
  - id: src
    resource: ../../lib/features/tts
    title: Text-to-speech source
    last_modified: 2026-11-07
  - id: cloud-route
    resource: ../../lib/features/tts/cloud/tts_cloud_route.dart
    title: The cloud route a profile's read-aloud slot names
    last_modified: 2026-11-04
  - id: cloud-tts-http
    resource: ../../lib/features/tts/cloud/cloud_tts_http.dart
    title: The HTTP transport and typed failures every speech client shares
    last_modified: 2026-11-04
  - id: voxtral-service
    resource: ../../lib/features/tts/cloud/voxtral_tts_service.dart
    title: Voxtral speech and voice-catalog client
    last_modified: 2026-11-04
  - id: elevenlabs-service
    resource: ../../lib/features/tts/cloud/elevenlabs_tts_service.dart
    title: ElevenLabs speech and voice-catalog client
    last_modified: 2026-11-04
  - id: voice-catalog-repository
    resource: ../../lib/features/tts/cloud/cloud_voice_catalog_repository.dart
    title: The device cache of each provider's voice catalog
    last_modified: 2026-11-04
  - id: voice-catalog
    resource: ../../lib/features/tts/cloud/cloud_voice_catalog.dart
    title: Voice catalog and per-language voice resolution
    last_modified: 2026-11-04
  - id: cloud-voices-section
    resource: ../../lib/features/tts/ui/widgets/tts_cloud_voices_section.dart
    title: The Cloud voices section of Speech settings
    last_modified: 2026-10-30
  - id: cloud-voice-picker
    resource: ../../lib/features/tts/ui/widgets/tts_cloud_voice_picker.dart
    title: The per-language voice picker sheet and its previews
    last_modified: 2026-10-30
  - id: audio-focus
    resource: ../../lib/features/tts/state/tts_audio_focus.dart
    title: TtsAudioFocus, the phone's audio session while the voice speaks
    last_modified: 2026-11-04
  - id: cloud-voice-samples
    resource: ../../lib/features/tts/cloud/cloud_voice_samples.dart
    title: The sentence each language's voices preview with
    last_modified: 2026-10-30
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

# Speaking in the background

`media_kit` never configures the phone's audio session, so the app sat in
the default one — which falls silent the moment the app leaves the screen,
however `UIBackgroundModes` lists `audio`. A summary read aloud stopped when
its listener switched to another app.

`MediaKitTtsAudioPlayer` now holds a `TtsAudioFocus` while it plays. On iOS
and Android (`platformTtsAudioFocus`) that is `SessionTtsAudioFocus`, which
configures the `audio_session` once as spoken audio for playback
(`ttsAudioSessionConfiguration`: iOS `playback` / `spokenAudio`, ducking
other apps; Android speech, a transient focus that may duck) and activates
it; on a desktop it is `NoTtsAudioFocus`, which does nothing.

```mermaid
stateDiagram-v2
  [*] --> Free
  Free --> Held: play — after open and rate, before the player plays
  Held --> Free: stop
  Held --> Free: the clip plays to its end
  Held --> Free: dispose
  Held --> Free: a stop while the focus was being taken (never plays)
```

The session is configured afresh on every claim, not once: it is shared, and
the recorder (`record_ios`) sets it to play-and-record for each dictation,
which would otherwise leave the voice in the earpiece and out of the
background.

**The voice plays through the iPhone's silent switch.** The `playback`
category is what keeps it speaking in the background, and like every app
that speaks — a podcast player, navigation — it ignores the ring/silent
switch: a summary the listener asked to hear is heard. Only the ringer's
sounds obey that switch.

Releasing deactivates the session with `notifyOthersOnDeactivation`, so a
paused podcast resumes.

**One claim or release at a time.** `SessionTtsAudioFocus` runs its claims
and releases in turn on one queue: a clip's end releases the session without
anyone awaiting it, and a claim for the next clip made meanwhile would
otherwise reach the platform first and be undone by the stale deactivation.
A stop queues its release the moment it is called, before awaiting the
native stop, so a play started during that stop claims after it. Because a
stop's release always queues after any claim it must undo, a
play cancelled while its claim is pending never releases on its own: by the
time its claim returns, a newer play may hold the session, and that release
would deactivate it. `settled` completes once every step so far has run, and the player exposes
it (`TtsAudioPlayer.settled`). `stopReadAloudForRecording` awaits it before
a microphone opens — also after a clip that already ended, when there is no
voice to stop — so a late deactivation never lands under the recording. It
never builds the player just to wait for it. The focus is best effort: a session that cannot be
configured or activated is absorbed, and the voice plays in the foreground
as it did before — it never stops speaking for it; the failure is logged
(`LogDomain.speech`, `ttsAudioFocus.acquire` / `.release`) with the logger
the provider hands in. A release only gives back a session it holds.

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
| Day briefing | the Daily OS planner's resolved setup | the app's |
| Companion's spoken reply ([front agent](front_agent.md#her-voice)) | her own resolved setup: the profile chosen for her, else the Settings default; her built-in fallback model names no voice | the app's |
| Onboarding companion | none: she speaks unasked, so only the on-device voice | — |

`fromProfile` returns a route only for a provider with a speech client here —
`cloudSpeechProviderTypes`: Mistral (Voxtral TTS) and ElevenLabs. Another
provider joins by adding its type there and its `CloudTtsClient` to
`cloudTtsClientsProvider`. Every
other outcome, including an empty slot or one that no longer resolves, is the
on-device voice. The on-device voice is never replaced silently by a cloud one,
and a cloud voice never falls back to sending the text somewhere else.

```mermaid
flowchart TD
  Surface["Read-aloud surface"] --> Profile{"Resolved profile names a read-aloud model?"}
  Profile -->|no, or it did not resolve| Local["On-device Supertonic voice"]
  Profile -->|yes| Client{"Provider has a speech client?"}
  Client -->|no| Local
  Client -->|Mistral or ElevenLabs| Cloud["TtsCloudRoute: the provider's voice in the text's language"]
  Cloud --> Voice{"Voice for the language?"}
  Voice -->|user's choice, else first female preset, else any| Speak["provider's speech endpoint → temporary WAV"]
  Voice -->|none, on-device voice supported| Local
  Voice -->|none, no on-device voice| NoVoice["error: noVoice — nothing sent"]
  Local --> Play["Shared playback, cancellation and cleanup"]
  Speak --> Play
```

A cloud route needs neither the on-device model nor platform support for it,
so a surface shows its control when **either** the on-device engine is
supported **or** a cloud route exists.

# Cloud voices

Each speaking provider has a `CloudTtsClient` — `synthesize` returns a WAV,
`fetchVoices` a `CloudVoiceCatalog` for a model — and `cloudTtsClientsProvider`
holds one per type in `cloudSpeechProviderTypes`. The provider's base URL and
API key come from its inference provider config on every call.

- **`VoxtralTtsService` (Mistral)** posts `model`, `input`, `voice_id` and
  `response_format: wav` to `audio/speech` with a bearer token and decodes the
  base64 `audio_data`; `fetchVoices` pages `audio/voices` with `type=all` at
  `limit=100` — the API's maximum, a larger page is a 422. The catalog is the
  account's, whatever the model.
- **`ElevenLabsTtsService`** authenticates with the `xi-api-key` header.
  `synthesize` posts `text` and `model_id` to
  `text-to-speech/{voice_id}?output_format=wav_24000` and checks the answer
  is RIFF/WAVE audio — 24 kHz WAV is on every plan, 44.1 kHz needs Pro. No
  `language_code` is sent: `eleven_multilingual_v2` does not take it, and the
  multilingual models read the language from the text. `fetchVoices` reads
  `GET models` for the languages the model speaks, then `GET voices` (premade,
  cloned and saved voices in one list). Every ElevenLabs voice speaks every
  language of a multilingual model, so each is offered for all of them — the
  per-language choice below works exactly as for Mistral. A model the list
  does not name falls back to each voice's `verified_languages`. Its labels
  become the voice's `gender` and `tags` (accent, character, age, use case);
  `category: premade` is a preset, any other category a custom voice.

Both run on `CloudTtsHttp`, the shared transport. Failures are typed
(`CloudTtsFailure`: network, timeout, unauthorized, rate limited with
`Retry-After`, rejected, server, invalid response, no voice) with
`isRetryable`; ElevenLabs answers a used-up quota with a 401, so it reads as
unauthorized with the server's reason attached. A non-200 answer also keeps
the server's own reason (`apiError`: its `message`, ElevenLabs'
`detail.message`, or each validation detail as `loc: msg`, so a 422 names the
field) and its request id. Every failure is logged with the call it ended —
endpoint, text length, voice, model, format or catalog page. Its logs carry
text lengths, voice and model ids and byte counts — never the text, the key,
or the raw response body: a validation detail's `input` is dropped because it
echoes the rejected value, and a body that is not JSON is not kept at all.
Failures the client does not log itself — a missing voice, the on-device
engine, the player — are logged by `TtsPlaybackController` before it turns to
the error state the toast reports. It refuses redirects, which would carry the
credential to another host, and plain HTTP anywhere but loopback.

`CloudSpeechSynthesizer` turns a route and a text into the same temporary WAV
the on-device engine writes, so everything after synthesis — playback,
`canPlay`, stop, deletion — is the path described below.

**Voices.** `CloudVoiceCatalogRepository` caches each catalog in `SettingsDb`,
device-locally like the provider's credentials: per provider for Mistral
(`TTS_VOXTRAL_VOICES_<providerId>`), per provider and model for ElevenLabs
(`TTS_ELEVENLABS_VOICES_<providerId>/<modelId>`), whose voices' languages are
the model's. A cached catalog younger than a day answers without a
request; an older one is refreshed and kept if the refresh fails, so voices
still resolve offline. Each cache records the account it was fetched for —
`accountFingerprint`, the first 16 hex digits of the SHA-256 of base URL and
key, never either itself. A provider edited to another account or base URL
never answers from the old account's voices, fresh or offline; a cache
written before accounts were recorded is refreshed at once and answers only
when that refresh fails. `CloudVoiceCatalog.resolve` picks the voice for a
language: the user's choice for that language while the catalog still has it
(`TtsSettings.cloudVoiceByLanguage`, `TTS_CLOUD_VOICES`), else the language's
first female preset, else its first voice. No provider names a voice per
language, so this default is ours. Choices are kept per provider
(`cloudVoiceChoiceKey`): Mistral's under the bare language — the format from
before a second provider type spoke, so earlier picks stay — every other
provider's under `<providerId>/<language>`, so a voice of one account (a
cloned voice, say) never stands in for another's, of the same type or not. A language with no voice raises `noVoice` before any
text is sent, rather than reading German in an English voice; where the
device has the on-device voice, which infers the language from the text,
`TtsPlaybackController` speaks with it instead, and only a device without one
ends in the error. Each voice
keeps the API's mood `tags` (cached with it) so voices of one language can
be told apart before they are heard.

**Speech settings → Cloud voices.** `cloudVoiceServicesProvider` names one
service per catalog — per provider for Mistral, per provider and model for
ElevenLabs, so two profiles on different ElevenLabs models each keep their
languages; a provider listed twice is captioned with its model.
`TtsCloudVoicesSection` lists, per service, the user's own languages — the app's and every language with a
pick — then folds the rest of the catalog behind one "Other languages (N)"
header, which says how many of them have a choice of voices. Each row names the voice in use, "Your pick" when chosen, and the
number of voices when there is a choice; its speaker plays the voice in use.
A language with several voices opens `showCloudVoicePicker`; a language with
one plays it from the row. Grouping holds while the page is open: a language
picked from the open list keeps its row until the list is collapsed, so an
edited row never jumps.

The picker sheet (`CloudVoicePicker`) pins the default voice and the pick it
opened with (labelled "Your pick" while in use, "Previous" once another is
tapped) above a Female/Male filter (`TtsGenderFilter`, shared with the
on-device list, shown for more than eight voices of both genders). A tap
picks a voice and plays it; picking the default clears the choice. The
sheet stays open, and closing it on a different voice than it opened with
shows a toast with Undo back to that voice. Previews go through a
`TtsCloudRoute` carrying the previewed `voiceId`, which wins over the user's
choice and is part of the route's cache key, so a preview never plays as
another voice. The sentence is `cloudVoiceSample`: the app's own
`speechSettingsCloudVoiceSample` for a shipped language, a native sentence
for the other languages Voxtral speaks, else English (also for an
ElevenLabs language without either) — every voice can be
heard before it is picked. The on-device voice list and the picker share one
row, `TtsVoiceRadioRow`.

**Model and speed.** Mistral has one hosted TTS family and no quality or
speed parameter to tune; the curated model is `voxtral-mini-tts-3-0` (Mistral
documents no `-latest` alias for it). ElevenLabs' curated models are
`eleven_multilingual_v2` (its default, the most natural) and
`eleven_flash_v2_5` (low latency, half the price); an ElevenLabs provider is
speech-only, so these fill the *Read aloud* slot and nothing else. The text
goes in one request, unsplit, so `eleven_v3` — a few thousand characters per
request against their 10k and 40k — is not curated; added by hand, a long
report read with it is rejected. WAV keeps the uncompressed format's lower
time to first audio. Speed stays a playback rate, as for the on-device voice,
so changing it never costs a new request.

**Previews cost characters.** A preview synthesizes the sample sentence
through the provider, as a read does — on ElevenLabs about 60 characters of
the plan's quota per voice heard. A sample that played to its end is kept
like any utterance, so replaying the one just heard sends nothing.

**Catalog classification.** Voxtral ships transcription and TTS models under
one prefix. `isSpeechSynthesisModelId` (a `tts` segment, separated by `-`, `_`, `.`,
`/` or `:`) marks
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
on stop or disposal. Temporary utterance WAV files are removed on
cancellation, error or disposal; one that plays to its end, or is stopped
once made, is kept as the prepared result (below) for a replay. Model weights remain installed. Cleanup reports
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
Its key includes source ID, exact answer text, voice, model and language; on a
cloud route the model is the route's `cacheKey` and the voice the route's own or
the one chosen for its language, so another voice never replays the old one's
clip. Speed is applied at playback and does not invalidate the WAV.

**A replay plays the kept clip.** The same slot holds the WAV of an utterance
that played to its end — or was stopped once its clip was made — under that
utterance's key, so pressing play again on the same words starts at once — no
second synthesis and, for a cloud voice, no second upload of the text. When
playback ends or is stopped (`_keepForReplay`) the clip goes into the slot at
once, so a discard, other speech and disposal reach it from then on, and the
utterance's own `canPlay` is asked again; a no takes it out and deletes it. An
owner that lost access or let go of the utterance never leaves a clip behind,
however its cleanup and the completion interleave, and a question that is
never answered leaves the clip where disposal still deletes it. A replay
rechecks `canPlay` too, and a denied replay deletes the clip. Anything else spoken or prepared, `discardPrepared`
and disposal delete it like any prepared result. A stop keeps the clip it
stopped: stopping the voice and asking for the same words again plays them at
once, in the voice they were made in, rather than making them again (the
companion's *Say it again*). A stop that lands between synthesis and play
leaves the file to the slot, which `speak` then never deletes. `speak` waits for a
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
  consumed --> ready: played to its end or stopped, kept for replay
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

# A microphone stops the voice

A recording must never capture Lotti speaking. `stopReadAloudForRecording`
(in `state/tts_playback_controller.dart`) stops the voice when it is
downloading, synthesizing or playing, and is awaited before a microphone
opens: by `AudioRecorderController.record()` — every record button that opens
the recording sheet, so a task's summary read aloud stops at the press — and
by Daily OS Capture's `CaptureController`, so the Day briefing does too.

The voice is stopped, not paused: it has no pause, and its control only plays
and stops. The helper leaves a quiet voice alone, never builds the controller
just to silence it (`ref.exists`), and logs and swallows a failure to stop,
since the recording must start regardless. The agent chat's microphone and the
front agent's voice guard their own starts the same way.

# Who else listens to an utterance

`TtsPlaybackState` is the one thing a surface reads about an utterance: its
status, its `sourceId`, the playhead `position`, and — while it is `playing`,
and only then — `clip`, the WAV being played together with the text it was
synthesized from. The two travel as one record, so a reader never pairs a clip
with words the screen shows now but the voice was never given. The
[companion](companion.md) reads that clip once to shape her mouth and follows
`position` each frame. The voice imports nothing of hers. `clip` is cleared on
stop, completion and error, because the utterance is over — on stop and error
its file is deleted, on completion it is only kept for a replay — and a reader
that gets there late may find no file; the companion then falls back to the
words alone.

A failure never reaches the caller of `speak` as an exception: it is the
`error` status above. A surface that asks the voice to speak calls
`listenForPlaybackFailure` (`ui/playback_failure_toast.dart`) from its build,
which shows one error toast per failure of *its* `sourceId` — the AI summary
card and the Daily OS day briefing both do.

# Bundled clips

`playClip` plays a clip shipped with the app instead of speech made for the
moment: onboarding uses it to let a new user hear the on-device, Voxtral and
ElevenLabs voices before any of them is set up. It needs neither the model nor
the network. The asset is copied to a temporary file of its own
(`state/tts_bundled_clip.dart`), then played through the same player and
`TtsPlaybackState` as a synthesized utterance: the companion lip-syncs to it,
and stop, completion and error clean the file up as they clean up any clip.

A clip plays at its natural speed, since it is a sample of how a voice sounds,
and is a no-op while another utterance is busy, like `speak`. Its key carries
its own model slot, so a finished sample is never replayed in place of real
speech. The clips themselves are 16-bit PCM WAV, which is what the companion's
lip-sync reads exactly; `tool/onboarding_voice_samples.py` renders them.

