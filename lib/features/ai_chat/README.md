# AI Chat Feature

The `ai_chat` feature is Lotti's interactive question-and-answer surface over task history.

It is not the agent runtime, and it is not the general provider stack. It sits above the `ai` feature and below the chat UI, giving the user a session-scoped way to ask things like:

- what did I finish last week?
- what patterns show up in this category?
- what did I actually spend time on?

And, because typing is not always the mood, it also owns the chat-specific voice input path.

## What This Feature Owns

At runtime, the feature owns five concrete jobs:

1. session and message state for the chat UI
2. explicit model selection for each chat session
3. streaming assistant output, including tool-calling turns
4. the task-summary retrieval tool used by the assistant
5. batch and realtime transcription for chat input

It does not own:

- provider configuration and routing policy
- agent wake cycles or memory
- durable long-term chat persistence

That last point is important: `ChatRepository` currently stores sessions and messages in memory. This feature behaves like an interactive workbench, not like a durable knowledge base.

## Directory Shape

```text
lib/features/ai_chat/
├── models/
│   ├── chat_exceptions.dart            # Typed exceptions for chat failures
│   ├── chat_message.dart               # Core message model (freezed)
│   ├── chat_session.dart               # Domain model for chat sessions (freezed)
│   └── task_summary_tool.dart          # OpenAI function calling schema (freezed)
├── repository/
│   ├── chat_message_processor.dart     # Testable message processing
│   ├── chat_repository.dart            # Core business logic orchestrator
│   └── task_summary_repository.dart    # Task data retrieval for tool calls
├── services/
│   ├── audio_transcription_service.dart    # Batch audio transcription
│   ├── realtime_transcription_service.dart # Real-time transcription via WebSocket
│   └── system_message_service.dart        # System prompt construction
├── ui/
│   ├── controllers/
│   │   ├── chat_recorder_controller.dart    # Audio recording state machine
│   │   ├── chat_recorder_state.dart          # Recorder state/enum (part of controller)
│   │   ├── chat_session_controller.dart     # Active conversation state
│   │   ├── chat_sessions_controller.dart    # Session list management
│   │   ├── chat_stream_parser.dart          # Stream content/reasoning separator
│   │   └── chat_stream_utils.dart           # Stream processing utilities
│   ├── models/
│   │   └── chat_ui_models.dart              # UI-specific models
│   ├── pages/
│   │   └── chat_modal_page.dart             # Modal integration
│   ├── providers/
│   │   └── chat_model_providers.dart        # Model selection providers
│   └── widgets/
│       ├── ai_chat_icon.dart                # Chat icon widget
│       ├── chat_interface.dart              # Main chat UI
│       ├── chat_interface/                  # Chat interface sub-widgets
│       │   ├── assistant_settings_sheet.dart
│       │   ├── bubble_corner_action.dart
│       │   ├── chat_header.dart
│       │   ├── chat_voice_controls.dart
│       │   ├── error_banner.dart
│       │   ├── input_area.dart
│       │   ├── message_bubble.dart
│       │   ├── message_timestamp.dart
│       │   ├── messages_area.dart
│       │   ├── streaming_content.dart
│       │   ├── thinking_disclosure.dart
│       │   └── typing_indicator.dart
│       ├── thinking_parser.dart             # Streaming reasoning parser
│       └── waveform_bars.dart               # Live waveform visualization
└── README.md
```

## Architecture

```mermaid
flowchart LR
  User["User"] --> UI["ChatInterface / ChatModalPage"]
  UI --> Sessions["ChatSessionsController"]
  UI --> Session["ChatSessionController"]
  UI --> Recorder["ChatRecorderController"]

  Sessions --> Repo["ChatRepository"]
  Session --> Repo
  Recorder --> BatchTx["AudioTranscriptionService"]
  Recorder --> RtTx["RealtimeTranscriptionService"]

  Repo --> Processor["ChatMessageProcessor"]
  Repo --> System["SystemMessageService"]
  Processor --> ToolRepo["TaskSummaryRepository"]
  Processor --> Cloud["CloudInferenceRepository"]
  BatchTx --> Cloud
  RtTx --> RtProvider["MLX or Mistral realtime backend"]

  ToolRepo --> Journal["JournalDb / task + work-entry reads"]
  Cloud --> Providers["Configured provider adapters"]
```

The structure is intentionally split:

- controllers own UI-facing state
- `ChatRepository` orchestrates a chat turn
- `ChatMessageProcessor` holds the testable prompt, tool, and stream logic
- task retrieval stays in `TaskSummaryRepository`
- transcription paths are separated into batch and realtime services

## Runtime Model

### Session layer

There are two controllers, and they do different jobs:

- `ChatSessionsController` manages the session list, recent sessions, creation, deletion, and switching
- `ChatSessionController` manages one active conversation, including streaming flags, selected model, visible messages, and errors

`ChatRepository` sits underneath both and currently stores:

- `_sessions`
- `_messages`

in memory only.

That means:

- recent sessions survive only for the current app lifetime
- there is no database-backed transcript history yet
- deleting or switching sessions is cheap because there is no persistence layer to migrate

### Chat turn flow

```mermaid
sequenceDiagram
  participant User as "User"
  participant UI as "ChatSessionController"
  participant Repo as "ChatRepository"
  participant Proc as "ChatMessageProcessor"
  participant Tool as "TaskSummaryRepository"
  participant Cloud as "CloudInferenceRepository"

  User->>UI: send message
  UI->>UI: require explicit model selection
  UI->>Repo: sendMessage(message, history, modelId, categoryId)
  Repo->>Proc: resolve model + provider config
  Repo->>Proc: convert history + build prompt
  Repo->>Cloud: generate(...)
  Cloud-->>UI: stream visible content deltas
  Cloud-->>Repo: stream tool call deltas
  Repo->>Proc: accumulate tool calls

  alt tool calls present
    Proc->>Tool: fetch task summaries for requested range
    Tool-->>Proc: structured task summary payload
    Proc->>Cloud: generate final answer with tool results
    Cloud-->>UI: stream final answer deltas
  end

  UI->>UI: finalize assistant messages
  UI->>Repo: save updated session in memory
```

The important operational detail is that tool calls are accumulated while visible content is already streaming. This keeps the UI responsive even when the model is still building a tool request behind the curtain.

## The Only Built-In Tool: Task Summaries

The chat feature is deliberately narrow. It does not expose the whole app as an unbounded tool playground.

Right now the assistant's main structured retrieval tool is `get_task_summaries`.

`TaskSummaryRepository` resolves that tool request in several steps:

1. find relevant work entries in the requested date range
2. filter for meaningful work spans
3. resolve linked task relationships
4. load tasks in bulk
5. resolve agent reports for all tasks in one batch
6. build fallback summaries where they do not

```mermaid
flowchart TD
  ToolCall["get_task_summaries"] --> Work["Find work entries in date range"]
  Work --> Filter["Filter by duration and category"]
  Filter --> Links["Resolve linked tasks"]
  Links --> Tasks["Load tasks in bulk"]
  Tasks --> Summaries["Batch agent reports, then legacy fallback"]
  Summaries --> ToolResult["Return tool payload to model"]
```

This is one of the reasons the feature feels smarter than a plain chat wrapper. It is not just handing the model a giant pile of journal text and wishing it luck.

## Streaming, Reasoning, and Message Segmentation

`ChatSessionController` does not treat the provider stream as one dumb text blob.

It uses:

- `ChatStreamParser`
- `ChatStreamUtils`

to separate:

- visible answer text
- hidden reasoning blocks

Separately, the chat UI widgets (`message_bubble.dart`, `streaming_content.dart`)
use `thinking_parser.dart` (`ThinkingUtils`) at display time to hide or strip
reasoning blocks from rendered/copied output. The controller itself does not
reference `thinking_parser.dart`.

Behavior that matters:

- visible answer text streams into a dedicated assistant bubble
- reasoning segments are finalized as separate assistant messages
- opening and closing reasoning markers can arrive split across provider chunks;
  the parser carries partial markers until they are complete instead of leaking
  them into either the visible answer or reasoning text
- pending visible soft breaks are flushed at thinking boundaries and at stream
  completion, so chunk boundaries do not drop the final line break
- copying assistant output strips hidden reasoning by default
- Gemini-specific "thinking" behavior is normalized at the provider layer and then hidden or shown by the chat UI

This keeps the UX cleaner than the classic "model dumped its chain-of-thought into the answer and now the user has to scroll past a small novel."

## Chat Recorder State Machine

The chat recorder has its own controller and its own state machine. It is separate from the general speech feature because the chat flow has different output semantics: the transcript either becomes chat input or is auto-sent.

```mermaid
stateDiagram-v2
  [*] --> Idle
  Idle --> Recording: start batch recording
  Idle --> RealtimeRecording: start realtime mode
  Recording --> Processing: stop and transcribe
  Recording --> Idle: cancel
  RealtimeRecording --> Idle: stop realtime and finalize transcript
  RealtimeRecording --> Idle: cancel
  Processing --> Idle: transcript ready
  Processing --> Idle: transcription error
  Processing --> Idle: cancel
```

Controller states are:

- `idle`
- `recording`
- `realtimeRecording`
- `processing`

The controller also tracks:

- waveform amplitude history
- `partialTranscript` for live mode
- final `transcript`
- structured error type
- whether realtime mode is selected

## Voice Input Paths

### Batch transcription path

`AudioTranscriptionService`:

- reads AI configs
- finds audio-capable models
- prefers Mistral offline transcription models first, so their `context_bias`
  parameter can receive the category speech dictionary terms
- then any configured Mistral audio model
- then local MLX Qwen3-ASR models, which receive the same speech dictionary as
  prompt context
- otherwise uses a `gemini-2.5-flash` model, or the first audio-capable model
- excludes realtime-only Mistral models
- sends MLX Audio model files directly to the native Swift bridge
- otherwise base64-encodes the local audio file and calls `CloudInferenceRepository.generateWithAudio(...)`
- yields text chunks as they arrive

```mermaid
sequenceDiagram
  participant UI as "ChatRecorderController"
  participant File as "Temporary audio file"
  participant Batch as "AudioTranscriptionService"
  participant Cloud as "CloudInferenceRepository"
  participant MLX as "MlxAudioChannel"

  UI->>File: record m4a in temp dir
  UI->>Batch: transcribeStream(filePath)
  Batch->>Batch: resolve audio-capable model
  alt MLX Audio provider
    Batch->>MLX: transcribeFile(filePath, modelId)
    MLX-->>Batch: final transcript
  else HTTP provider
    Batch->>Cloud: generateWithAudio(...)
    Cloud-->>Batch: text chunks
  end
  Batch-->>UI: text chunks
  UI->>UI: accumulate transcript
```

### Realtime transcription path

`RealtimeTranscriptionService` bypasses the normal HTTP inference path entirely.
The code path is kept in place, but `realtimeTranscriptionUiEnabled` is
currently `false`, so chat input surfaces do not show the live-mode toggle.
Realtime can be exposed again once the local realtime path supports the same
dictionary/biasing behavior as batch transcription.

It:

- resolves a Mistral realtime transcription model when configured, otherwise a
  local MLX Qwen3-ASR realtime model
- opens the native MLX realtime session or Mistral WebSocket session
- streams PCM audio chunks
- computes local amplitude values from PCM
- accumulates text deltas
- on stop, waits for `transcription.done`
- writes buffered audio to WAV and converts it to M4A

```mermaid
sequenceDiagram
  participant UI as "ChatRecorderController"
  participant RT as "RealtimeTranscriptionService"
  participant Backend as "MLX or Mistral realtime backend"

  UI->>RT: startRealtimeTranscription(pcmStream)
  RT->>Backend: open realtime session
  UI->>RT: stream PCM chunks
  RT->>Backend: append PCM
  Backend-->>RT: transcription deltas
  RT-->>UI: onDelta(delta)
  UI->>UI: update partialTranscript
  UI->>RT: stop(...)
  RT->>Backend: end audio
  Backend-->>RT: transcription.done
  RT-->>UI: final transcript + audio file path
```

### What happens after transcription

The chat feature deliberately distinguishes between:

- "I already selected a model, send this transcript straight into the chat"
- "I have not selected a model yet, put the transcript into the input field so I can inspect it first"

That is a better failure mode than guessing on the user's behalf.

## Model Selection Rules

The feature is strict here on purpose.

- model selection is explicit
- no automatic fallback is used for chat turns
- the selected model must support function calling
- `categoryId` is required for the send path

If the selected model cannot satisfy the tool contract, the chat turn fails early instead of pretending everything is fine and then hallucinating a summary from thin air.

## Privacy and Data Flow

The chat feature does not invent its own privacy policy. It inherits routing from the configured provider/model path:

- batch chat messages and batch transcription go through the selected provider path
- MLX Audio batch transcription stays in-process through the native Apple bridge when supported
- realtime transcription is currently hidden in the UI; the retained service
  path can use either local MLX Qwen3-ASR or a configured Mistral realtime
  endpoint
- task retrieval happens locally from Lotti's databases before any tool result is sent upstream

That means the privacy posture depends on the chosen provider configuration, not on the chat UI.

## Current Constraints

- sessions are in-memory only
- the built-in tool surface is intentionally narrow
- chat requires explicit model selection
- realtime transcription is gated by `realtimeTranscriptionUiEnabled` and can be
  re-enabled once its dictionary/biasing behavior matches the batch path
- hidden reasoning behavior is normalized, but provider quirks still matter at the stream level

## Relationship to Other Features

- `ai_chat` owns the interactive question/answer surface
- `ai` owns providers, model metadata, routing, and multimodal transport
- `speech` owns the app-wide audio entry recorder and player
- `agents` owns long-running autonomous analysis

If `agents` is the part that thinks on its own schedule, `ai_chat` is the part that waits politely for the user to ask first.
