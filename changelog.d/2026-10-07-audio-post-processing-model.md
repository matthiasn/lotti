### Added

- **Inference profiles can name their own model for audio post-processing.**
  The step after a transcription — correcting the transcript against the
  speech dictionary and writing the recording's one-liner, TLDR and summary —
  can now run on a model of its own, chosen in the profile under "Audio
  post-processing", instead of always on the thinking model your agents use.
  Profiles without one keep using the thinking model.

### Fixed

- **A summary with a long one-liner is no longer thrown away.** When the model
  wrote a one-line label of more than 140 characters, the whole summary was
  rejected with an error, and a recording transcribed in a task kept its
  uncorrected text. The longer label is now kept as written.
