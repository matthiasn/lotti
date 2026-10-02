### Fixed
- **A voice note could lose its transcript without saying so.** When another
  device edited the recording at the moment its transcript was being saved, or
  the save failed, the transcription still reported success: no error, no
  words, and a check-in spinner that waited for minutes. The save is now
  checked and retried, and a transcript that cannot be saved shows as a failed
  transcription you can retry.
- **Text you typed into a recording while it was being transcribed was
  replaced by the transcript.** Your edit now stays, and the transcript is kept
  in the recording's transcript history.
- **Asking for a transcript while one was already running paid for a second
  one.** A second request for the same recording now waits for the run in
  progress. A failed transcription also no longer starts an audio summary or
  wakes the task's agent.
