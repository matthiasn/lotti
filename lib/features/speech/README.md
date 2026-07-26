# Speech

Speech is how Lotti listens. It records voice notes, plays them back, and keeps
the transcript and language information attached to each recording.

Talking is often the fastest way to capture something, so this feature sits
behind the record button in the journal, on task pages, and in the Daily OS
check-in.

## What it does for the user

- **Records a voice note anywhere.** From the journal, from a task, or as part of
  a day check-in — with a live level meter (a classic VU meter or an energy orb,
  whichever the user picked in settings) so it is obvious the mic is working.
- **Never keeps a recording the user threw away.** Discarding during a recording
  deletes the partial file and creates nothing — nothing is transcribed and no
  agent is woken.
- **Plays recordings back properly.** Progress, playback speed, and a waveform to
  scrub through — with one player for the whole app, so a recording never plays
  over another.
- **Turns speech into text.** Transcription runs after the recording is saved,
  using whichever model the user configured, including local ones. There is no
  live "watch the words appear" mode — the recording is always saved first.
- **Learns the user's vocabulary.** Names, jargon and product terms can be added
  to a per-area speech dictionary that guides recognition, editable straight from
  the editor.
- **Keeps the language straight.** Each recording carries its language, so
  transcription and later AI work use the right one.

## What it owns

Audio capture and the recorder state machine; the app-wide playback controller;
waveform extraction and caching; the transcript-maintenance UI; and the
category speech-dictionary helper used from the editor.

It does **not** own provider configuration or the inference stack — transcription
calls into [ai](../ai/README.md) after the recording is on disk.

## Where the code lives

```text
lib/features/speech/
├── helpers/ · model/ · repository/
├── services/ · state/
└── ui/
```

## How it works

The recorder state machine, the save-versus-discard split, the app-wide player
and waveform cache, and why navigation is kept out of the modal's teardown are
documented in the knowledge bundle:

**→ [knowledge/features/speech/](../../../knowledge/features/speech/)**
