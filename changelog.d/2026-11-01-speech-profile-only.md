### Changed
- **Recordings no longer fall back to a speech model your profiles do not
  name.** When neither a recording's category profile nor your default
  inference profile can transcribe, the recording now says no transcription
  model is set up, instead of picking one of your configured speech models
  by provider type (the on-device one first). Set a default inference
  profile with a transcription model to transcribe such recordings.
