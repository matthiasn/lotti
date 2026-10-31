# Check-in transcripts — one look for Goals and People

Assessment and decisions, 2026-10-31, against base `4b7f1605fc`. The
architecture the result settles into is described in
[Recording UI](../../../knowledge/features/speech/recording-ui.md#the-words-under-a-recording);
this note records why it looks the way it does.

## What was mapped

| | Goals | People |
|---|---|---|
| Capture | `GoalCheckInComposer`: Record **or** Write; Record opens the app's recording sheet (`AudioRecordingModal`), and stopping closes the composer | `CheckInCaptureForm`: one field holding the note and its recordings ("takes"); Dictate records in place (`CheckInInlineRecorder`) |
| Recorder anatomy | `RecordingStage` + `RecordingTransportControls` | the same — already shared |
| Who transcribes | the recorder's automatic-prompt trigger, goal fallback | `CheckInTranscriptionService`, waited on by the composer |
| History | `GoalCheckInTimeline` on the shared `TimelineView` rail | `PersonTimelineSliver` on `DesignSystemTimelineRow` |
| Words in history | `_ClampedText`: 2 lines, `bodyMedium`, medium ink; a typed note in `bodyLarge`, never folded | `PersonFoldedWords`: 3 lines, `bodySmall`, full ink, quiet-ink *Show more* with expanded semantics, kept alive while open |
| Waiting | italic caption *Transcribing…* | composer: spinner glyph + *0:23 · Transcribing…* + reassurance; timeline: grey *Transcribing…* forever |
| Missing / failed | caption + a hand-built `InkWell` *Retry* link (rail); a quiet `DesignSystemButton` *Retry* (charter) | warning glyph, *Transcript not received*, body, tertiary *Try again* with a refresh glyph |
| Gave up waiting | after 10 min idle: *Not transcribed* + Retry | never — a recording from last week still read *Transcribing…* |

Captures of the six surfaces before and after are linked from the pull request.

## Panel findings

Ranked by how much a user notices them.

1. **The same fact had four renderings.** *A recording has no words yet* was an
   italic caption, a spinner line, a grey row text and a status in a take
   header, with three different labels and two different retry controls.
   Someone who checks in on a goal and then on a person learned the state
   twice.
2. **People's history lied about old recordings.** Without Goals' grace
   window, a recording whose transcription failed days ago still said
   *Transcribing…*.
3. **The user's words had two voices on one Goals rail.** A typed note was
   18 px at full ink and never folded; a spoken one was 16 px at medium ink and
   folded at two lines. Spoken words looked secondary to typed ones.
4. **Hand-built controls next to design-system ones.** The rail's *Retry* and
   *Show more* were a raw `InkWell` with no expanded semantics. People's fold
   used `DsQuietInk` and announced its state.
5. **Capture differs, and that is right.** A goal check-in *is* one recording or
   one note. A person check-in is a container whose recordings are entries of
   their own (ADR 0062). The recorder was already the same widget in both, so
   forcing one composer shape would have changed what the two features mean.

## Decisions

- **People's patterns win where they differ.** They had had the more recent
  design passes: glyph-led status, full ink for the user's words, a
  design-system fold with semantics, and a real retry button.
- **One status vocabulary, one widget.** `TranscriptStatus` (`heard`,
  `transcribing`, `notTranscribed`, `failed`) and `transcriptStatusOf` replace
  Goals' `TimelineTranscriptStatus` and its status rule. People's timeline
  applies the same 10-minute grace, so a stale recording says *Not
  transcribed*. `RecordingTranscript` draws every non-heard state the same way:
  a glyph (spinner / warning), the one caption label, an optional detail line
  and a tertiary *Retry*.
- **One fold.** `FoldedWords`, the former `PersonFoldedWords`, is the only fold:
  three lines in `bodySmall` at full ink, quiet-ink *Show more*, and an optional
  summary to lead with. It is used for the Goals rail's transcripts and typed
  notes, the People timeline and the events rail.
- **One copy set.** *Transcribing…*, *Not transcribed*, *Transcription failed*,
  *Retry*. The People-only *Transcript not received* and the second
  *Transcribing…* key are gone. The composer keeps its own reassurance (*You
  can save now — the words follow.*) as a detail line under the shared
  status.
- **A take's header is the recording; the status is its body.** The take row
  leads with the waveform glyph and the length, the way a Goals beat leads
  with its kind and time. Where the words are is said once, by the shared
  status beneath.
- **Not changed:** data models, who transcribes, privacy and sync, the two
  capture flows, and the history row shells (`TimelineView` vs
  `DesignSystemTimelineRow`). Merging the row shells would restyle every
  People row and every event beat for no transcript gain. It is the next
  candidate if the two rails are to read as one.

## Success criteria

- Every surface that shows a check-in recording's words shows the same states
  with the same glyph, label, ink, size and retry control. That covers the
  Goals rail and charter, the People composer and timeline, and the events
  rail.
- No surface shows *Transcribing…* for a recording older than the grace window
  that nothing is working on.
- Typed and spoken words share one tier and one fold within a rail.
- Widget tests pin each of the above: the status widget, the fold and the
  status rule have their own suites, and each host's suite asserts that it
  renders through them.
