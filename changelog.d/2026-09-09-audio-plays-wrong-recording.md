### Fixed
- **A second recording added to a task played the first one instead of
  itself.** Once one voice note in a task had been played through, every
  recording tapped after it started the earlier one's audio — the card lit up
  as the one you had picked, but the wrong recording came out of it, and
  transcribing from that card handed the model the wrong audio too. The only
  way around it was to start a fresh task for every recording. Selecting a
  recording and starting playback are now a single ordered step, so each one
  plays and transcribes on its own.
- **Importing a recording could overwrite one already in the journal.**
  Dropped audio was filed under a name derived purely from its timestamp, and
  a name that was merely *close* to Lotti's own — `…-203 2.m4a`, or a copy —
  was read as that exact timestamp. Two such files landed on one path, the
  second silently replacing the first while the first entry kept pointing at
  it. Imports now keep every recording as its own file.
