### Added
- **Listen to the recording behind a quoted answer.** Query chats can prepare
  timestamps using Melious Whisper or a compatible Mistral Voxtral model in
  the agent's transcription profile, then play the matching excerpt from the original recording. Saved
  quotes and notes keep their wording. Answers can also be read aloud using
  local text-to-speech when enabled; switching chats or hiding private content
  stops playback.

### Fixed
- **Stopping speech preparation now prevents late playback.** Cancelling while
  a voice model is preparing or opening audio no longer lets that audio start
  afterward.
