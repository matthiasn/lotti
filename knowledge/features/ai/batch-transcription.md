---
type: Feature Module
title: Shared batch audio transcription
description: Audio model discovery, streaming transcription, and usage attribution for agent voice input and Daily OS processing.
resource: ../../../lib/features/ai/services/audio_transcription_service.dart
tags: [ai, transcription, audio, attribution]
status: stable
generated: { by: codex/gpt-6, at: 2026-09-10T20:25:15Z }
stale_after: 2026-10-19
sources:
  - id: service
    resource: ../../../lib/features/ai/services/audio_transcription_service.dart
    title: AudioTranscriptionService
    last_modified: 2026-09-10
  - id: provider
    resource: ../../../lib/features/ai/repository/cloud_inference_repository.dart
    title: Audio inference routing
    last_modified: 2026-09-06
---

# Ownership

`AudioTranscriptionService` transcribes an existing local file through configured
AI providers. It is shared by [agent voice input](../agents/chat-input-and-reasoning.md)
and Daily OS capture/outbox processing. It does not record audio, persist journal
transcripts, or own a chat session. `audioTranscriptionServiceProvider` supplies
the service through Riverpod.

# Request flow

```mermaid
sequenceDiagram
  participant Caller as Recorder or Daily OS
  participant Service as AudioTranscriptionService
  participant Config as AiConfigRepository
  participant Usage as AiInteractionCapture
  participant Provider as CloudInferenceRepository
  Caller->>Service: transcribeStream(file, optional target/session)
  alt No explicit target
    Service->>Config: load configured models and providers
    Config-->>Service: compatible batch audio candidates
  end
  Service->>Usage: capture attributed interaction when registered
  Service->>Provider: generateWithAudio
  Provider-->>Service: text chunks or failure
  Service-->>Caller: transcript chunks or typed failure
```

An explicit model/provider target bypasses discovery. Otherwise discovery
loads models and providers, keeps audio-capable models, excludes Mistral
realtime-only models, and excludes unavailable embedded speech models. The
selection order is available embedded models, Mistral chat/transcription/batch
candidates, then Melious Whisper/transcription/chat candidates, then the Gemini
fallback match or first remaining model. Provider-specific routing stays in
[provider routing](provider-routing.md).

The file is encoded and submitted with the batch transcription prompt. The
service yields provider text chunks; `transcribe` joins them for callers that
need one string. A successful request containing no non-whitespace transcript
is treated as a transcription failure.

# Attribution and errors

When `AiInteractionCapture` is registered, it records audio-transcription work
with provider/model, text, usage, and available impact evidence. A caller may
supply an existing attribution session and control failure terminalization;
success is terminalized here only when the service owns the session.

`AttributedTranscriptionException` distinguishes a recorded provider failure
from an uncertain attribution-publication outcome. Callers can therefore avoid
terminalizing the same attributed failure twice. Without capture, provider
failures retain their underlying exception/state-error behavior. See
[AI work attribution](attribution.md) for the ledger contract.

# Invariants

- Discovery does not select realtime-only Mistral models for batch requests.
- Explicit targets do not silently fall back to another model.
- Transcription yields text; source persistence and timed transcript alignment
  are responsibilities outside this service.
