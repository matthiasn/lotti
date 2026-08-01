# AI chat support

This module contains the small set of voice-input and reasoning-display
primitives that are still shared by AI-assisted surfaces. It no longer owns a
standalone chat screen or an in-memory chat-session stack.

## What it does for the user

- **Accepts spoken input.** AI-assisted flows can record a short voice note,
  show live amplitude feedback, and transcribe the finished recording.
- **Shows transcription progress.** Callers can consume streamed transcript
  chunks while a configured audio-capable model processes the recording.
- **Displays model reasoning safely.** Shared parsing and disclosure widgets
  separate hidden thinking blocks from visible assistant text.

These primitives currently support evolution chat and Daily OS audio
processing. They are not a separate navigation destination.

## What it owns

- batch audio transcription through configured AI providers;
- temporary-file recording state and cleanup;
- waveform history and rendering helpers;
- parsing and disclosure of reasoning blocks.

It does not own provider configuration or routing
([ai](../ai/README.md)), agent conversations and wake memory
([agents](../agents/README.md)), or durable transcript persistence.

The retired standalone chat implementation is not retained here: there are no
chat sessions, chat repository, task-summary tool, model-selection controller,
or top-level chat UI in this module.

## Where the code lives

```text
lib/features/ai_chat/
├── services/audio_transcription_service.dart
└── ui/
    ├── controllers/ · recorder state and amplitude history
    └── widgets/ · waveform, thinking parser, and disclosure
```

## Architecture

The provider selection, recorder lifecycle, attribution boundary, and reasoning
rendering flow are documented in the knowledge bundle:

**→ [knowledge/features/ai_chat.md](../../../knowledge/features/ai_chat.md)**
