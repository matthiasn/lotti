# AI Chat Feature

An intelligent conversational interface for querying and interacting with Lotti tasks and productivity data. Users can ask questions about their task history, analyze patterns, and get AI-powered insights through natural language.

## 🎯 Overview

The AI Chat feature enables users to:
- Query task summaries by date range using natural language
- Analyze productivity patterns and achievements
- Get AI-powered insights from their task history
- Interact through a streamlined chat interface with real-time streaming
- Experience enhanced responses through thinking mode

## 🏗️ Architecture

The feature follows a clean, modular architecture with clear separation of concerns:

```
lib/features/ai_chat/
├── domain/
│   ├── models/chat_session.dart        # Domain model for chat sessions
│   └── services/thinking_mode_service.dart  # AI thinking enhancement
├── models/
│   ├── chat_message.dart               # Core message model
│   └── task_summary_tool.dart          # OpenAI function calling schema
├── repository/
│   ├── chat_repository.dart            # Core business logic orchestrator
│   ├── chat_message_processor.dart     # Testable message processing
│   └── task_summary_repository.dart    # Task data retrieval
└── ui/
    ├── controllers/                    # Riverpod state management
    ├── models/chat_ui_models.dart      # UI-specific models
    ├── pages/chat_modal_page.dart      # Modal integration
    └── widgets/chat_interface.dart     # Main chat UI
```

## 💡 Key Features

### ✅ Intelligent Task Querying
- **Natural Language Processing**: Ask questions like "What did I work on last week?" or "Show me my achievements this month"
- **Date Range Intelligence**: Automatically interprets time periods (today, yesterday, last week, etc.)
- **Context Awareness**: Filters results by the selected category from the tasks page

### ✅ Advanced AI Capabilities
- **Thinking Mode**: AI uses `<thinking>` tags to analyze queries and provide more thoughtful responses
- **Function Calling**: Seamlessly calls `get_task_summaries` tool to retrieve relevant data
- **Streaming Responses**: Real-time response generation with typing indicators
- **Gemini Flash Integration**: Optimized for fast, contextual responses

### ✅ Sophisticated Data Processing
- **Complex Query Engine**: 4-step process to find work entries, resolve task relationships, and retrieve AI summaries
- **Duration Filtering**: Only includes meaningful work entries (15+ seconds for text entries, all audio entries)
- **Relationship Resolution**: Traces links between tasks and work entries through database relationships
- **Fallback Handling**: Provides basic summaries for tasks without AI-generated summaries

### ✅ Modern UI/UX
- **Material Design 3**: Consistent with app design language
- **Responsive Chat Interface**: Custom-built Flutter widgets with proper accessibility
- **Markdown Support**: Rich text rendering for AI responses with code syntax highlighting
- **Session Management**: Create new chats, manage conversation history
- **Error Resilience**: Graceful error handling with retry mechanisms

## 🔧 Core Components

### ChatRepository
Central orchestrator handling:
- Session CRUD operations (in-memory storage)
- Message streaming with proper error boundaries
- AI service integration through CloudInferenceRepository
- Tool calling orchestration for task summaries

### ChatMessageProcessor  
Extracted testable logic for:
- AI configuration management (Gemini Flash setup)
- Message format conversion (internal ↔ OpenAI formats)
- Stream processing with content accumulation
- Tool call processing and response handling
- Prompt building from conversation history

### TaskSummaryRepository
Complex data retrieval engine:
- Multi-step query process: Work Entries → Links → Tasks → AI Summaries
- Date range filtering with ISO 8601 timestamp precision
- Duration-based work entry validation
- Task relationship resolution through EntryLink database relations
- AI summary extraction from AiResponseEntry records

### ThinkingModeService
AI enhancement system:
- System prompt enhancement with thinking instructions
- Content processing (extraction and cleanup of thinking tags)
- Quality analysis of thinking patterns
- Configurable thinking depth per query

## 🚀 Integration Points

### Main App Integration
- **Entry Point**: Psychology icon (🧠) in tasks page app bar
- **Modal Design**: Bottom sheet taking 80% of screen height
- **Category Context**: Inherits selected category from tasks page for filtering
- **State Management**: Reactive integration with Riverpod providers

### Data Layer Integration
- **JournalDb**: Direct database access for task and work entry retrieval
- **CloudInferenceRepository**: Leverages existing AI provider abstraction
- **AiConfigRepository**: Uses configured Gemini Flash model settings
- **LoggingService**: Comprehensive error tracking and debugging support

### AI Infrastructure Integration
- **Function Calling**: Extends existing tool calling infrastructure
- **Streaming Events**: Built on existing event-based streaming system
- **Error Handling**: Consistent with existing AI error patterns
- **Provider Management**: Integrates with unified AI provider system

## 📊 Technical Specifications

### Performance Characteristics
- **Response Initiation**: < 200ms typical response start time
- **Streaming Updates**: Real-time content delivery as AI generates responses
- **Memory Efficiency**: Minimal overhead with proper stream disposal
- **Database Optimization**: Efficient queries with proper relationship traversal

### Data Processing Flow
1. **Work Entry Filtering**: Date range → Duration validation → Category filtering
2. **Link Resolution**: EntryLink relationships to find connected tasks
3. **Task Batch Retrieval**: Efficient bulk loading of related task entities
4. **AI Summary Extraction**: Latest AI responses with metadata preservation

### Model Integration
- **Primary Model**: Gemini Flash (optimized for speed and context)
- **Function Calling**: OpenAI-compatible tool definitions
- **Context Management**: Proper conversation history maintenance
- **Token Efficiency**: Optimized prompts for cost-effective usage

## 🧪 Testing

Comprehensive test suite with **9 test files** covering all components:

### Repository Tests (46 tests)
- **ChatRepository**: Integration tests for session management and message handling
- **ChatMessageProcessor**: Unit tests for message processing logic  
- **TaskSummaryRepository**: Complex data retrieval scenarios

### UI Tests (32 tests)
- **ChatInterface**: Widget testing for UI components
- **ChatModalPage**: Page-level integration tests
- **Controllers**: State management validation

### Service Tests (61 tests)
- **ThinkingModeService**: Comprehensive thinking mode functionality
- **UI Models**: Data model validation and conversion

**Total: 139 passing tests** ensuring robust functionality across all components.

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
3. **Natural Queries**: Ask questions in natural language about tasks
4. **Real-time Responses**: Watch AI responses stream in real-time
5. **Session Management**: Continue conversations or start new chats

### Example Interactions
```
User: "What did I work on yesterday?"
AI: *Analyzes date range, retrieves work entries, finds linked tasks*
Response: "Yesterday you focused on [specific tasks with summaries]..."

User: "Show me my achievements this week"
AI: *Processes weekly timeframe, analyzes completed tasks*  
Response: "This week you accomplished [categorized achievements]..."

User: "What patterns do you see in my work?"
AI: *Uses thinking mode to analyze productivity patterns*
Response: "Looking at your work patterns, I notice [insights]..."
```

## 🔮 Future Enhancements

### Planned Improvements
- **Database Persistence**: Replace in-memory session storage with SQLite persistence
- **Multi-Category Support**: Enable querying across multiple categories simultaneously  
- **Export Functionality**: Export chat conversations as markdown or PDF
- **Voice Integration**: Add speech-to-text input and text-to-speech output
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
- **OpenAI Dart**: Function calling and chat completion support
- **Freezed**: Immutable data models with JSON serialization
- **Riverpod**: State management and dependency injection
- **GPT Markdown**: Rich text rendering for AI responses
- **MockTail**: Comprehensive testing framework

### Architecture Principles
- **Clean Architecture**: Clear separation between domain, data, and presentation layers
- **SOLID Principles**: Single responsibility, dependency inversion, interface segregation
- **Testability**: All business logic is unit testable with dependency injection
- **Type Safety**: Full null safety with Freezed immutable models
- **Error Handling**: Comprehensive error boundaries with proper logging

### Code Quality Standards
- **Test Coverage**: Comprehensive test suite with 139 passing tests
- **Static Analysis**: Zero analyzer issues with strict linting rules
- **Documentation**: Inline documentation for all public APIs
- **Formatting**: Consistent code formatting with dart format
- **Modularity**: Loosely coupled components with clear interfaces

---

*This AI Chat feature represents a sophisticated integration of natural language processing, complex data querying, and modern Flutter UI patterns, providing users with an intelligent interface to explore their productivity data.*