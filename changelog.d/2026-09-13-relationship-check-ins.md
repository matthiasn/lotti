### Fixed
- **Spoken check-ins now report recording and transcription failures.**
  Permission errors are visible, repeated taps cannot start overlapping
  recordings, and fast transcription failures no longer leave the form waiting.
  Automatic model discovery prefers configured cloud speech services and limits
  on-device fallback to installed Whisper tiny/base models.
- **Person photos can be dragged vertically while zoomed.** The crop surface
  keeps the surrounding sheet from stealing the pan gesture.

### Changed
- **Choose how to capture a check-in.** Start with writing or audio, review the
  narrative first, and find optional sentiment and notes under More.
