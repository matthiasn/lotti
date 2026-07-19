# Speech Feature

The `speech` feature owns audio capture, audio playback, waveform extraction,
and transcript-adjacent tools for `JournalAudio` entries.

In the current implementation it does three concrete jobs:

1. capture audio and persist it as `JournalAudio`
2. play back `JournalAudio` entries with progress, speed, and waveform scrubbing
3. maintain speech-specific metadata around audio entries, including language,
   transcripts, and category speech dictionaries

It does not own provider configuration or the general AI inference stack.
Whenever realtime transcription or linked-task automation is involved, it calls
into AI-side services.

## Directory Shape

```text
lib/features/speech/
├── helpers/
├── model/
├── repository/
├── services/
├── state/
├── ui/
└── README.md
```

## Runtime Architecture

```mermaid
flowchart LR
  User["User"] --> RecordingUI["AudioRecordingModal / sidebar + mobile indicators"]
  User --> PlaybackUI["AudioPlayerWidget"]
  User --> TranscriptUI["SpeechModalContent"]
  User --> EditorUI["Editor context menu"]

  RecordingUI --> RecorderCtl["AudioRecorderController"]
  RecorderCtl --> RecorderRepo["AudioRecorderRepository"]
  RecorderCtl --> RtTx["RealtimeTranscriptionService"]
  RecorderCtl --> SpeechRepo["SpeechRepository"]
  RecorderCtl --> AutoPrompt["AutomaticPromptTrigger"]
  RecorderCtl --> Attribution["TranscriptAttributionCoordinator"]
  Attribution --> Consumption["AI consumption event"]

  PlaybackUI --> PlayerCtl["AudioPlayerController"]
  PlaybackUI --> WaveformProvider["audioWaveformProvider"]
  WaveformProvider --> WaveformSvc["AudioWaveformService"]

  TranscriptUI --> EntryCtl["EntryController.setLanguage()"]
  TranscriptUI --> SpeechRepo
  EditorUI --> DictSvc["SpeechDictionaryService"]

  SpeechRepo --> Persist["PersistenceLogic + JournalDb"]
  DictSvc --> CategoryRepo["CategoryRepository + JournalRepository"]
  RtTx --> AiConfig["AI config + Mistral or MLX-audio realtime backend"]
  Persist --> JournalAudio["JournalAudio"]
  Attribution --> JournalAudio
```

The feature is not only a recorder. It also owns the app-wide playback
controller, waveform cache, transcript maintenance UI, and the category speech
dictionary helper used from the editor.

## Recording

### Standard recording path

Standard recording goes through `AudioRecorderRepository`, which wraps the
`record` package and is responsible for:

- permission checks
- starting file-backed recording at `48kHz`
- pause and resume
- stop and dispose
- amplitude sampling every `20ms`

`AudioRecorderController` sits above that repository and adds:

- Riverpod state for recording UI
- VU calculation from dBFS samples via the standalone
  [`VuMeter`](./state/vu_meter.dart) (a self-contained sliding-window RMS→VU
  unit, unit-tested directly in `vu_meter_test.dart`)
- live dBFS exposure for the modal's level visualizer and the mobile recording
  pill (the desktop sidebar row no longer visualizes dBFS — see below). The
  modal itself renders the skeuomorphic VU meter or the energy orb depending
  on `recordingStyleProvider` (`lib/features/onboarding/state/recording_style.dart`,
  settable in Settings › Recording Style) — same dBFS feed either way.
- linked-entry and category context
- coordination with app-wide playback
- persistence through `SpeechRepository`
- optional hand-off to profile-driven transcription automation

`record()` is a toggle-style entry point:

- if the repository is paused, it resumes
- if the repository is already recording, it stops and saves
- otherwise it starts a new recording

The current recording modal exposes `record`, `stop`, and `cancel`. `stop()`
keeps the recording (creates a `JournalAudio` entry and fires automatic
prompts); `cancel()` discards it (stops the recorder, deletes the partial
audio file, and creates no entry — nothing is transcribed and no task agent is
woken). The controller also has `pause()` and `resume()`, but that branch is
not surfaced by the current modal UI.

`AudioRecordingModal.show()` hosts the Wolt sheet on the root navigator by
default; callers can explicitly opt into their local navigator. Its content
inset comes from the shared modal design-system spacing, with the bottom inset
reduced for the recording controls. Finishing a recording returns the created
entry ID through that modal route. The content pops the route exactly once, and
an unlinked recording navigates to its new journal entry only after the Wolt
route has completed. Keeping navigation out of the sheet's teardown prevents
nested task navigators from trying to reactivate an element that has already
been removed.

### Recorder state

`AudioRecorderState` currently carries:

- `status`
- `progress`
- `vu`
- `dBFS`
- `modalVisible`
- `linkedId`
- `enableSpeechRecognition`
- `partialTranscript`
- `isRealtimeMode`

The enum still includes `AudioRecorderStatus.initializing`, but
`AudioRecorderController.build()` returns `stopped` immediately and uses the
asynchronous initialization step only for permission probing and logging.

```mermaid
stateDiagram-v2
  [*] --> Stopped
  Stopped --> Recording: record() starts a file recording
  Recording --> Paused: pause()
  Paused --> Recording: resume()
  Recording --> Stopped: record() or stop()
  Recording --> Stopped: cancel() discards (no entry)
  Paused --> Stopped: stop()
  Paused --> Stopped: cancel() discards (no entry)
```

Both `stop()` and `cancel()` land in `Stopped`, but only `stop()` persists a
`JournalAudio` and triggers downstream transcription/automatic prompts.
`cancel()` deletes the partial file via `AudioRecorderRepository.deleteRecording`
and resets the state as if the recording never happened.

One implementation detail worth calling out: the state object still has
`showIndicator`, but the current desktop `SidebarAudioRecordingSection` and
mobile `AudioRecordingIndicator` derive visibility from
`status == recording && !modalVisible` rather than that field.

### Standard recording flow

```mermaid
sequenceDiagram
  participant User as "User"
  participant Presenter as "AudioRecordingModal.show"
  participant Modal as "AudioRecordingModalContent"
  participant Navigator as "selected Navigator"
  participant Sidebar as "SidebarAudioRecordingSection"
  participant Ctl as "AudioRecorderController"
  participant Repo as "AudioRecorderRepository"
  participant Speech as "SpeechRepository"
  participant Persist as "PersistenceLogic"
  participant AppNav as "NavService"

  Presenter->>Navigator: show Wolt sheet (root by default)
  User->>Modal: tap record
  Modal->>Ctl: record(linkedId)
  Ctl->>Ctl: pause active AudioPlayerController if needed
  Ctl->>Repo: hasPermission()
  Ctl->>Repo: startRecording()
  Repo-->>Ctl: AudioNote + amplitude stream
  Ctl->>Ctl: update dBFS, RMS-based VU, progress
  Ctl-->>Modal: level (VU meter or energy orb, per recordingStyleProvider) + elapsed time
  Ctl-->>Sidebar: red accent card + pulsing record dot + elapsed time (no dBFS reaction)
  User->>Modal: tap stop
  Modal->>Ctl: stop()
  Ctl->>Repo: stopRecording()
  Ctl->>Speech: createAudioEntry(audioNote, linkedId, categoryId)
  Speech->>Persist: createDbEntity(JournalAudio)
  Ctl->>Ctl: reset recorder state
  Ctl-->>Modal: created entry ID
  Modal->>Navigator: pop(created entry ID) once
  Navigator-->>Presenter: Wolt route completed
  opt recording is not linked to an existing entry
    Presenter->>AppNav: open /journal/created-entry-ID
  end
```

The persisted `JournalAudio` is created from `AudioData` and stored through
`PersistenceLogic`. The audio file lives under `/audio/YYYY-MM-DD/`.

The modal also offers a discard (✕) control next to Stop while recording, in
both standard and realtime modes. It asks for confirmation before discarding. In
standard mode it calls `cancel()`, which stops the recorder, deletes the
partially-written `/audio/YYYY-MM-DD/` file, and resets state without creating a
`JournalAudio` — so the page returns to exactly how it looked before recording.
In realtime mode it calls `cancelRealtime()` (see below).

## Realtime Recording

Realtime recording is a separate transport path. It does not reuse
`AudioRecorderRepository`. The implementation remains in the controller and
service layer, but the product toggle is currently hidden because
`realtimeTranscriptionUiEnabled` is `false`; the active user-facing path is
post-recording transcription with dictionary/context biasing.

`AudioRecorderController.recordRealtime()`:

- creates a raw `record.AudioRecorder`
- starts `pcm16bits`, `16kHz`, mono streaming
- resolves realtime configuration through `RealtimeTranscriptionService`
- prefers a configured Mistral realtime model/provider pair, falling back to a
  local MLX-audio model/provider pair when only that is wired up
- subscribes to the realtime amplitude stream for the same level visualizer
- accumulates transcript deltas into `partialTranscript`

The realtime toggle in `AudioRecordingModal` is only shown when
`realtimeAvailableProvider` resolves to `true`. With the current feature gate
that provider always resolves to `false`, even if a realtime-capable model is
configured.

```mermaid
sequenceDiagram
  participant User as "User"
  participant Modal as "AudioRecordingModal"
  participant Ctl as "AudioRecorderController"
  participant RT as "RealtimeTranscriptionService"
  participant Attr as "TranscriptAttributionCoordinator"
  participant Speech as "SpeechRepository"
  participant Persist as "PersistenceLogic"

  User->>Modal: enable realtime and tap record
  Modal->>Ctl: recordRealtime(linkedId)
  Ctl->>Ctl: pause active AudioPlayerController if needed
  Ctl->>RT: resolveRealtimeConfig()
  Ctl->>Attr: begin(provider, model, task/category)
  Ctl->>RT: startRealtimeTranscription(pcmStream)
  RT-->>Ctl: amplitudeStream dBFS updates
  RT-->>Ctl: transcript deltas
  Ctl->>Ctl: update partialTranscript
  User->>Modal: tap stop
  Modal->>Ctl: stopRealtime()
  Ctl->>RT: stop(stopRecorder, outputPath)
  RT-->>Ctl: transcript + detectedLanguage + saved audio file path
  Ctl->>Speech: createAudioEntry(...)
  Speech-->>Ctl: JournalAudio carrier
  Ctl->>Attr: recordInteraction(realtime digest, usage/status)
  Ctl->>Attr: prepareOutput(audio id, transcript id)
  Attr-->>Ctl: attribution record
  Ctl->>Persist: save transcript + attribution onto JournalAudio and entryText
  Persist-->>Ctl: write accepted
  Ctl->>Attr: finalize local projection
  Ctl->>Ctl: reset recorder state
```

Two important implementation details:

1. `stopRealtime()` only creates a `JournalAudio` entry if the realtime service
   actually produced an audio file. Very short recordings can still return
   transcript text from the service, but the controller does not persist
   anything unless an audio artifact exists.
2. Before realtime inference starts, the controller asks
   `TranscriptAttributionCoordinator` for an in-memory attribution session.
   When a transcript exists, the coordinator records interaction metadata and
   token usage, then appends an `AudioTranscript` with a stable id and embedded
   attribution to `JournalAudio.data.transcripts`; it also mirrors the text
   into `entryText`. The carrier is authoritative. After the journal update
   succeeds, the coordinator upserts the local attribution projection. Missing
   audio, empty transcript, or rejected persistence records a failed or
   cancelled outcome without inventing provider cost.

`cancelRealtime()` is the realtime discard path (the ✕ button in real-time
mode). It records a terminal cancelled attribution, then tears down the recorder
and realtime service without creating or updating a `JournalAudio` entry. The
standard-mode discard path is `cancel()`,
which mirrors this for file-based recordings (stop + delete the partial file,
no entry).

## Playback And Waveforms

`AudioPlayerController` is a keep-alive Riverpod notifier backed by
`media_kit.Player`.

It owns:

- the active `JournalAudio`
- playback progress
- buffered progress
- playback speed
- pause position
- native player setup and cleanup

The controller subscribes to `media_kit` position, buffer, and completion
streams. It also exposes `disposeActivePlayer()` so `WindowService` can shut
the native player down before process exit.

Audio entry-level actions are assembled by the journal Actions sheet. The
desktop file-manager reveal action resolves persisted `/audio/YYYY-MM-DD/...`
asset paths through `AudioUtils.getFullAudioPath()`.

### Actual player state transitions

The player state is simpler than the README used to claim. In the current
implementation:

- `build()` returns `AudioPlayerStatus.initializing`
- `setAudioNote()` moves the state to `stopped`
- `play()` moves it to `playing`
- `pause()` moves it to `paused`
- completion updates `progress` to the clip duration and flips `status` back to
  `stopped` after a short delay, then tears down the live `Player` (state such
  as `audioNote`/`totalDuration` is preserved so the next `play()` transparently
  reopens the file)

```mermaid
stateDiagram-v2
  [*] --> Initializing
  Initializing --> Stopped: setAudioNote(audio)
  Stopped --> Playing: play()
  Playing --> Paused: pause()
  Paused --> Playing: play()
  Playing --> Stopped: setAudioNote(new audio)
  Paused --> Stopped: setAudioNote(new audio)
  Playing --> Stopped: completion sets progress = duration, status = stopped
```

This diagram reflects the code as written, not an idealized player state
machine.

### Waveform extraction

`AudioPlayerWidget` uses `audioWaveformProvider`, which delegates to
`AudioWaveformService`.

`AudioWaveformService`:

- resolves the local audio file path
- extracts waveform data with `just_waveform`
- downsamples it into UI bucket counts
- caches normalized waveform payloads on disk
- prunes the cache when it grows beyond the configured limit

The cache key includes the audio entry ID and requested bucket count, and the
cache payload is validated against file path, file size, and modified time.

## Transcript Tools

The feature also owns the small speech-specific tools around an existing audio
entry.

### Speech modal

`SpeechModalContent` is a thin composition of:

- `LanguageDropdown`
- `TranscriptsList`

`LanguageDropdown` does not talk to `SpeechRepository` directly. It calls
`EntryController.setLanguage()`, which delegates to
`SpeechRepository.updateLanguage()`.

`TranscriptsList` renders existing `AudioTranscript` entries from
`JournalAudio.data.transcripts`. Each `TranscriptListItem` can remove one
transcript through `SpeechRepository.removeAudioTranscript()`.

Today the language dropdown is hard-coded to:

- `auto`
- `en`
- `de`

That is worth documenting because it is a product constraint in the current UI,
not just a placeholder detail.

### Speech dictionary service

`SpeechDictionaryService` is a separate path from recording and playback.

It supports adding a selected term to a category speech dictionary by:

- looking up the entry from `JournalRepository`
- resolving the category from the task itself or from a task linked to a
  `JournalAudio` or `JournalImage`
- updating the category through `CategoryRepository`

This is why the `speech` feature is wider than "audio recording". It also owns
the category-level speech vocabulary helper used from the editor.

## Automatic Transcription Hand-Off

The helper is still named `AutomaticPromptTrigger`, but the current behavior is
more specific than that name suggests.

What it actually does today:

- only runs when a recording is linked to a task
- asks `profileAutomationServiceProvider` whether that task has an automated
  transcription skill
- optionally forwards the saved audio entry to `SkillInferenceRunner`
- leaves the failed inference status and detailed provider error attached to
  both the audio entry and linked task; their AI activity surfaces replace the
  disappearing animation with an error toast containing the diagnostic detail

What it does not do:

- it does not run for unlinked recordings
- it does not expose a general menu of prompt automations in the modal
- it does not batch-transcribe a realtime recording that already produced its
  own transcript

The checkbox UI in `AudioRecordingModal` is consistent with that behavior:
`checkboxVisibilityProvider` only exposes a speech-recognition checkbox when
the linked task has profile-driven transcription available.

## Boundaries

- `journal` owns entry detail surfaces and supplies `JournalAudio`
- `ai_chat` owns realtime transcription transport orchestration
  (`RealtimeTranscriptionService`)
- `ai` owns the Mistral realtime WebSocket repository
  (`MistralRealtimeTranscriptionRepository`), the MLX-audio backend
  (`MlxAudioChannel`), profile automation, and skill execution
- `categories` owns the speech dictionary persistence target
- `speech` owns the audio-specific runtime, playback, waveform cache, and
  transcript maintenance layer that connects those systems
