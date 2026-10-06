### Added
- **One speech dictionary for the whole app.** Names, places and jargon that
  speech recognition gets wrong now live in *Settings → Definitions → Speech
  dictionary*, entered once and used everywhere. A term can be limited to
  some areas, so a word from one project never "corrects" a recording about
  another, and it can list the spellings it tends to come out as. The terms
  kept on areas before are carried over, limited to those areas.
- **Recordings in a task come back with names spelled right.** When a task's
  recording is transcribed by a speech-to-text engine such as Whisper, the
  step that writes its one-liner and summary now also corrects the
  dictionary terms the transcript misheard, judging from the task and the
  surrounding words. The recording's text appears once, already corrected,
  and stays editable; corrections it makes are remembered as misheard
  spellings for next time.

### Changed
- **Suggestions to transcribe or analyse no longer appear while that is
  still happening.** A new recording or photo is given ten minutes to be
  processed — on this device or the one it came from — before the task
  offers to run it, unless processing failed.
- **A recording's summary reads less of its task.** It is framed by the
  task's title and current report instead of the whole task log, so a task
  with many recordings no longer sends all of them along with each new one.
