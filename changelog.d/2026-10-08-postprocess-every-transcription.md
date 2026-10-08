### Changed

- **Every recording transcribed by a speech-to-text engine now gets its
  names right and a summary, not only recordings in a task.** Check-ins with
  a person or a goal, notes on a project or an event, and standalone voice
  notes go through the same step as a task's recordings: the transcript is
  corrected against your speech dictionary, judged against the person's,
  goal's, project's or event's current report where there is one, and the
  recording gets a one-line label, a TLDR and a summary. Without a profile of
  its own, a recording uses your default profile's audio post-processing
  model. "Summarize Recording" is now offered on every recording.

### Fixed

- **Goal check-ins are transcribed again.** A spoken check-in on a goal was
  saved but never turned into text automatically, so the goal's agent had
  nothing to read from it.
