### Changed
- **A cloud voice starts speaking in about half a second.** With a Voxtral or
  ElevenLabs voice, the companion and every other read-aloud used to wait
  until the whole text had been turned into audio — two and a half seconds
  for three sentences, longer for more. The audio is now played while it is
  still arriving, as one continuous take in one voice.

### Added
- **Eleven v4 Turbo for reading aloud.** An ElevenLabs provider now offers
  ElevenLabs' newest real-time voice, more expressive than the earlier ones
  and in 94 languages; it starts speaking in well under half a second.
- **Lotti sounds like a grandmother by default.** Without a voice chosen for
  a language, a cloud voice now prefers an older woman — including voices
  saved to your ElevenLabs account from its Voice Library — then a
  middle-aged one.

### Fixed
- **Reading aloud keeps working offline.** When a cloud voice cannot be
  reached and the on-device voice is installed, the on-device voice reads the
  text instead of showing an error.
