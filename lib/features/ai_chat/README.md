# AI Chat Feature

An intelligent conversational interface for querying and interacting with Lotti tasks and productivity data. Users can ask questions about their task history, analyze patterns, and get AI‑powered insights through natural language.

## 🎯 Overview

The AI Chat feature enables users to:
- Query task summaries by date range using natural language
- Analyze productivity patterns and achievements
- Get AI-powered insights from their task history
- Interact through a streamlined chat interface with real-time streaming
- Speak instead of typing with built‑in voice input and transcription

## 🏗️ Architecture

The feature follows a clean, modular architecture with clear separation of concerns:

```
lib/features/ai_chat/
├── models/
│   ├── chat_message.dart               # Core message model
│   ├── chat_session.dart               # Domain model for chat sessions
│   └── task_summary_tool.dart          # OpenAI function calling schema
├── repository/
│   ├── chat_repository.dart            # Core business logic orchestrator
│   ├── chat_message_processor.dart     # Testable message processing
│   └── task_summary_repository.dart    # Task data retrieval
└── ui/
    ├── controllers/                    # Riverpod state management
    │   └── chat_recorder_controller.dart # Audio recording + state machine
    ├── models/chat_ui_models.dart      # UI-specific models
    ├── pages/chat_modal_page.dart      # Modal integration
    └── widgets/
        ├── chat_interface.dart         # Main chat UI with reasoning disclosure + voice controls
        ├── waveform_bars.dart          # Live waveform visualization of mic input
        └── thinking_parser.dart        # Streaming-friendly reasoning parser
├── services/
│   ├── audio_transcription_service.dart  # Batch audio transcription (Gemini, etc.)
│   └── realtime_transcription_service.dart # Real-time WebSocket transcription orchestrator
```

## 💡 Key Features

### ✅ Intelligent Task Querying
- **Natural Language Processing**: Ask questions like "What did I work on last week?" or "Show me my achievements this month"
- **Date Range Intelligence**: Automatically interprets time periods (today, yesterday, last week, etc.)
- **Context Awareness**: Filters results by the selected category from the tasks page

### ✅ Advanced AI Capabilities
- **Model Selection**: Users must explicitly select an AI model from configured providers (e.g., Ollama, OpenAI-compatible, Gemini, etc.) per chat session - no automatic fallback
- **Function Calling**: Uses the `get_task_summaries` tool to retrieve relevant data
- **Streaming Markdown**: Tokens stream from providers and render incrementally as Markdown with a typing indicator
- **Collapsible Reasoning**: Hidden “thinking” blocks are parsed and shown behind a collapsed disclosure. Multiple segments are aggregated with a subtle divider and rendered with the same Markdown widget for consistent typography. For Gemini providers, non‑flash models may include a single consolidated thinking block before the visible answer (when enabled); flash models never surface thinking.
- **Copy Behavior**: Copying assistant messages strips hidden thinking by default.

### ✅ Voice Input & Transcription
- **One‑tap Recording**: Tap the mic to start recording; see a live waveform
- **Accessible Controls**: Cancel (Esc shortcut) or Stop and transcribe
- **Smart Transcription**: Uses Gemini 2.5 Flash when available; falls back to the first audio‑capable model for the configured Gemini provider
- **Flexible Send**: If a model is selected, the transcript auto‑sends; otherwise it's inserted into the input field for review
- **Real‑Time Mode**: When both batch and realtime transcription models are configured, a mode toggle appears next to the mic button. In live mode, transcription text appears with ~2s latency while recording. Audio is saved as M4A via native platform channel conversion (iOS/macOS). App backgrounding gracefully stops the session.

### ✅ Sophisticated Data Processing
- **Complex Query Engine**: 4-step process to find work entries, resolve task relationships, and retrieve AI summaries
- **Duration Filtering**: Only includes meaningful work entries (15+ seconds for text entries, all audio entries)
- **Relationship Resolution**: Traces links between tasks and work entries through database relationships
- **Fallback Handling**: Provides basic summaries for tasks without AI-generated summaries

### ✅ Modern UI/UX
- **Material Design 3**: Consistent with app design language
- **Responsive Chat Interface**: Custom-built Flutter widgets with proper accessibility
- **Markdown Support**: Rich text rendering for AI responses with code syntax highlighting
- **Real-time Streaming**: Live token-by-token rendering; spacing tuned for readability
- **Session Management**: Create new chats, manage conversation history
- **Error Resilience**: Graceful error handling with retry and dismiss actions
- **Accessibility**: Disclosure is keyboard-accessible (Enter/Space) and exposed to screen readers. Avatars removed; user vs. assistant differentiated via asymmetric margins.

## 🔧 Core Components

### ChatRepository
Central orchestrator handling:
- Session CRUD operations (in-memory storage)
- Real-time streaming: forwards content deltas to the UI while accumulating tool calls
- AI service integration through CloudInferenceRepository (provider‑aware routing)
- Tool calling orchestration for task summaries and streaming of final responses

### ChatMessageProcessor
Extracted testable logic for:
- AI configuration management (provider + model resolution with caching for specific models)
- Message format conversion (internal ↔ OpenAI formats)
- Stream processing: accumulate tool calls; expose streaming of final responses after tools
- Tool call processing and response handling
- Prompt building from conversation history
- No fallback mechanism - requires explicit model selection

### Reasoning & Copy Behavior

- Hidden reasoning is never rendered inline. The UI provides a single collapsed
  disclosure per assistant message. Multiple reasoning segments are concatenated
  with a Markdown horizontal rule (---) for readability.
- Copying assistant messages strips reasoning by default (only visible answer is
  copied). Copying from the reasoning disclosure copies the reasoning text.
- Gemini mapping: For non‑flash models (when enabled), at most one consolidated
  `<thinking>` block may appear before the visible answer; flash models never
  surface thinking. See `thinking_parser.dart` for the exact patterns supported
  and streaming/open‑ended handling.

### TaskSummaryRepository
Complex data retrieval engine:
- Multi-step query process: Work Entries → Links → Tasks → AI Summaries
- Date range filtering with ISO 8601 timestamp precision
- Duration-based work entry validation
- Task relationship resolution through EntryLink database relations
- AI summary extraction from AiResponseEntry records


## 🚀 Integration Points

### Main App Integration
- **Entry Point**: Psychology icon (🧠) in tasks page app bar
- **Modal Design**: Bottom sheet taking ~80% of screen height
- **Category Context**: Inherits selected category from tasks page for filtering
- **Model Selection**: Required dropdown in the chat header; users must explicitly select a model before sending messages - no automatic fallback
- **State Management**: Reactive integration with Riverpod providers
- **Microphone UI**: Input area shows a mic button when empty; switches to waveform + Cancel/Stop controls while recording

### Permissions & Platform Notes
- **Microphone Access**: Requires microphone permission on supported platforms
- **Temporary Files**: Audio is recorded into an app‑scoped temp directory and removed after processing or cancel
- **Keyboard Shortcuts**: Escape key cancels recording (focus requested when controls are visible)

### Data Layer Integration
- **JournalDb**: Direct database access for task and work entry retrieval
- **CloudInferenceRepository**: Leverages existing AI provider abstraction
- **AiConfigRepository**: Uses configured Gemini Flash model settings
- **LoggingService**: Comprehensive error tracking and debugging support

### AI Infrastructure Integration
- **Providers**: Unified interface for multiple providers (Ollama, OpenAI-compatible, Gemini, etc.)
- **Function Calling**: OpenAI-compatible tool definitions
- **Streaming**: Provider streams are forwarded as deltas to the UI
- **Error Handling**: Consistent with existing AI error patterns

### Provider Integration

The chat feature is provider‑agnostic at the UI layer and routes inference via a shared orchestration layer:

- `CloudInferenceRepository` selects the appropriate adapter per provider:
  - Gemini → `GeminiInferenceRepository` (native REST) with a robust streaming parser that handles SSE `data:` lines, NDJSON, and array framing. Emits OpenAI‑compatible deltas and enforces the thinking visibility policy (non‑flash may include a single consolidated `<thinking>` block before visible content; flash models never include thinking).
  - Ollama → `OllamaInferenceRepository` using the `/api/chat` endpoint for streaming and function calling.
  - OpenAI‑compatible → direct `openai_dart` streaming.
- The chat UI consumes OpenAI‑compatible content deltas and uses `thinking_parser.dart` to hide/show reasoning without altering provider semantics.

## 📊 Technical Specifications

### Performance Characteristics
- **Response Initiation**: Fast first-token latency where supported by the provider
- **Streaming Updates**: Real-time content delivery as tokens arrive
- **Memory Efficiency**: Minimal overhead with proper stream disposal
- **Database Optimization**: Efficient queries with proper relationship traversal

### Data Processing Flow
1. **Work Entry Filtering**: Date range → Duration validation → Category filtering
2. **Link Resolution**: EntryLink relationships to find connected tasks
3. **Task Batch Retrieval**: Efficient bulk loading of related task entities
4. **AI Summary Extraction**: Latest AI responses with metadata preservation

### Model Integration
- **Model Selection**: Explicit selection required - select an eligible model per session (function-calling + text input required)
- **No Fallback**: System enforces model selection before sending messages - no automatic defaults
- **Providers**: Works with Ollama (local), OpenAI-compatible APIs, Gemini, and more (via unified config)
 - **Providers**: Works with Ollama (local), OpenAI-compatible APIs, Gemini, and more (via unified config and provider‑aware adapters)
- **Function Calling**: OpenAI-compatible tool definitions
- **Context Management**: Prompt includes prior conversation context
- **Token Efficiency**: Optimized prompts for cost-effective usage

## 🧪 Testing

Comprehensive test suite covering all components:

### Repository Tests
- **ChatRepository**: Integration tests for session management and message handling
- **ChatMessageProcessor**: Unit tests for message processing logic  
- **TaskSummaryRepository**: Complex data retrieval scenarios

### UI Tests
- **ChatInterface**: Widget testing for UI components
- **Voice Controls**: Chat input mic → waveform → cancel/stop flow with tooltips, keyboard handling, and disabled states while processing
- **WaveformBars**: Robust rendering tests (empty, large sets, bounds, sizing, theming)
- **ChatModalPage**: Page-level integration tests
- **Controllers**: State management validation

### Service Tests
- **UI Models**: Data model validation and conversion
- **AudioTranscriptionService**: Stream aggregation, model fallback, and error conditions

### Controller Tests
- **ChatRecorderController**: Permission handling, concurrent starts, temp file lifecycle, cleanup on cancel/dispose, timeout and error surfacing, amplitude normalization

### Test Coverage Highlights
- ✅ All business logic paths covered
- ✅ Error conditions and edge cases tested
- ✅ UI state management validation
- ✅ Database integration scenarios
- ✅ AI service integration mocking
- ✅ Complex data transformation testing

## 📱 User Experience

### Chat Flow
1. **Initiation**: Tap brain icon (🧠) in tasks page app bar
2. **Context Setup**: Chat automatically inherits selected category context
3. **Model Selection**: Required - must pick a model in the chat header before sending any messages
4. **Natural Queries**: Ask questions in natural language about tasks
5. **Real-time Responses**: Watch AI responses stream as formatted Markdown
6. **Session Management**: Continue conversations or start new chats

### Voice Flow (Batch)
1. **Start**: Tap the mic when the input is empty
2. **Recording**: Waveform appears; use Cancel (or Esc) or Stop
3. **Processing**: Spinner shows while transcribing; input disabled
4. **Result**: Transcript is auto‑sent if a model is selected, otherwise it's inserted into the input field

### Voice Flow (Real-Time)
1. **Toggle**: When both batch and realtime models are configured, tap the mode toggle (waveform icon) next to the mic button
2. **Start**: Tap the filled mic/waveform button to begin live transcription
3. **Recording**: Waveform + live transcript text appear simultaneously; text updates with ~2s latency
4. **Stop/Cancel**: Stop finalizes the transcript (waits for `transcription.done`); Cancel discards everything
5. **Result**: Same as batch — auto-sends or inserts into the input field

### Example Interactions
```
User: "What did I work on yesterday?"
AI: *Analyzes date range, retrieves work entries, finds linked tasks*
Response: "Yesterday you focused on [specific tasks with summaries]..."

User: "Show me my achievements this week"
AI: *Processes weekly timeframe, analyzes completed tasks*  
Response: "This week you accomplished [categorized achievements]..."

User: "What patterns do you see in my work?"
AI: *Analyzes productivity patterns*
Response: "Looking at your work patterns, I notice [insights]..."
```

## 🔮 Future Enhancements

### Planned Improvements

#### **High Priority - Persistence**
- **Database Persistence**: Replace in-memory session storage with SQLite persistence
  - **Current Limitation**: Chat sessions are lost when the app restarts
  - **Implementation Needed**: 
    - Create database schema for chat sessions and messages
    - Implement ChatRepository persistence layer
    - Add migration scripts for existing database
    - Maintain backward compatibility with current in-memory implementation
  - **Benefits**: Persistent chat history, better user experience, ability to resume conversations

#### **Performance Optimizations Completed** ✅

The AI Chat feature has been optimized for production use with several key performance improvements:

- **✅ AI Configuration Caching**: Efficient caching of AI provider and model configurations in `ChatMessageProcessor` (5‑minute cache)
- **✅ Reduced DB Roundtrips**: Batch relationship lookups and bulk queries in `TaskSummaryRepository`
- **✅ Session Search Performance**: Optimized in-memory filtering and null‑safe guards in session controllers

#### **Remaining Performance Considerations**

- **Task Query Volume**: Current implementation uses `limit: 10000` for work entry processing
  - **Current Status**: Acceptable for typical usage patterns, no immediate performance issues reported
  - **Future Enhancement**: Consider pagination if large datasets become problematic
  - **Monitoring**: Performance metrics show acceptable response times under normal load

#### **Feature Enhancements**
- **External Library Integration**: Consider migrating to `flutter_gen_ai_chat_ui` to reduce maintenance while keeping customization options
  
- **Multi-Category Support**: Enable querying across multiple categories simultaneously  
- **Export Functionality**: Export chat conversations as markdown or PDF
- **Text‑to‑Speech**: Add read‑back for assistant responses
- **Advanced Analytics**: Pattern recognition and productivity insights
- **Task Modification**: Enable task creation and editing through chat commands

### Technical Enhancements
- **Caching Layer**: Implement query result caching for improved performance
- **Pagination**: Add pagination for large task result sets
- **Search Integration**: Connect with existing app search functionality
- **Offline Support**: Basic chat functionality when offline
- **Push Notifications**: Proactive insights and reminders

### UI/UX Improvements
- **Theme Customization**: Additional chat theme options
- **Message Search**: Search within chat conversation history
- **Quick Actions**: Predefined query templates for common questions
- **Accessibility**: Enhanced screen reader support and keyboard navigation
- **Mobile Optimization**: Improved responsive design for smaller screens

## 🛠️ Development

### Key Dependencies
- **openai_dart**: OpenAI-compatible streaming, function calling
- **freezed_annotation**: Immutable data models with JSON serialization
- **flutter_riverpod**: State management and dependency injection
- **gpt_markdown**: Rich text rendering for AI responses
- **mocktail**: Comprehensive testing framework
- **record**: Cross‑platform audio capture
- **path_provider**: App‑scoped temporary directories for audio files

### Architecture Principles
- **Clean Architecture**: Clear separation between domain, data, and presentation layers
- **SOLID Principles**: Single responsibility, dependency inversion, interface segregation
- **Testability**: All business logic is unit testable with dependency injection
- **Type Safety**: Full null safety with Freezed immutable models
- **Error Handling**: Comprehensive error boundaries with proper logging

### Code Quality Standards
- **Test Coverage**: Comprehensive test suite ensuring robust functionality across all components
- **Static Analysis**: Strict linting rules
- **Documentation**: Inline documentation for public APIs
- **Formatting**: Consistent code formatting with `dart format`
- **Modularity**: Loosely coupled components with clear interfaces

## 🔧 How To Use
1. Configure at least one AI provider and add eligible models (function calling + text input) in settings.
2. Open the AI chat via the brain icon (🧠) in the tasks page.
3. **Required**: Select a model from the header dropdown before sending any messages - there is no automatic fallback.
4. Ask a question in natural language; responses stream in as Markdown. If a response contains hidden reasoning, a collapsed “Show reasoning” toggle appears above the message. Clicking it reveals the reasoning rendered as Markdown; multiple segments are separated by a subtle divider.

## ♿ Accessibility & UX Notes

- Model selection is mandatory - the system will show an error if you try to send a message without selecting a model.
- Dropdown is disabled while the model is streaming to avoid accidental context changes.
- Error banner includes retry and dismiss actions when something goes wrong.
- Clear error messages guide users to select a model when attempting to send without one.

---

*This AI Chat feature represents a sophisticated integration of natural language processing, complex data querying, and modern Flutter UI patterns, providing users with an intelligent interface to explore their productivity data.*
