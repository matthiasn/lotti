### Fixed
- **A cloud voice could speak twice as fast as it should.** Mistral and
  ElevenLabs voices arrive at 24 kHz, and an audio output that plays at the
  device's own rate without converting them sped them up to double speed, an
  octave high. Every read-aloud clip is now converted to 48 kHz before it is
  played.

### Added
- **Reading speed in the companion chat.** The chat's drawer has a *Reading
  speed* row under *Spoken answers*: a tap steps from 0.5x to 2x. It is the
  same setting as Settings → Speech, and a change is heard at once, in the
  middle of an answer too.
