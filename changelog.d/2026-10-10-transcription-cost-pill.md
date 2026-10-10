### Changed
- **An AI cost pill now appears only when the cost is known.** A transcript
  from Melious's speech-to-text models carried a pill reading "Cost unknown"
  on every recording, because that service does not report what a
  transcription costs. Pills now show only where a cost was reported; the full
  attribution details are unchanged.

### Fixed
- **The correction of a Daily OS voice capture is counted with its
  transcript.** The model call that fixes misheard speech-dictionary words was
  recorded as separate work of its own. It is now part of the transcription it
  corrects, so its cost appears alongside that transcript.
