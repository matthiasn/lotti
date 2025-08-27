# AI Chat Integration for Lotti Tasks - Implementation Plan

## Overview
This document outlines the implementation plan for adding an AI chat interface to the Lotti tasks page. The chat will allow users to query and interact with their tasks through natural language, leveraging task summaries and the existing AI infrastructure.

## Goals
- Enable conversational interaction with tasks data
- Allow querying task summaries by date range
- Support streaming responses for real-time feedback
- Integrate with existing AI infrastructure
- Use flutter_gen_ai_chat_ui for the UI components

## Implementation Phases

### Phase 1: Setup & Infrastructure

#### 1. Add flutter_gen_ai_chat_ui dependency
- Update pubspec.yaml with the chat UI library
- Run `fvm flutter pub get`
- Verify compatibility with existing dependencies

#### 2. Create AI Chat feature module
- Create new directory structure: `lib/features/ai_chat/`
- Follow existing feature structure pattern:
  ```
  lib/features/ai_chat/
  ├── ui/
  │   ├── pages/
  │   └── widgets/
  ├── state/
  ├── repository/
  └── models/
  ```

### Phase 2: Core Implementation

#### 3. Implement ChatController
- Create `ChatController` class to manage chat state
- Integrate with existing `ConversationManager` for multi-turn conversations
- Support streaming responses using existing event system
- Configure Gemini Flash as the default model for chat interactions
- Handle message history and context management

#### 4. Create task summary retrieval tool
- Implement function to query task summaries by date range
- Leverage existing AI response storage (AiResponseEntry)
- Support filtering by:
  - Date range (start/end dates)
  - Task status (future enhancement)
- Return formatted data suitable for LLM context
- Implement as a tool/function that can be called by the AI

### Phase 3: UI Integration

#### 5. Add chat UI to tasks page
- Integrate flutter_gen_ai_chat_ui components
- Position chat interface appropriately on the tasks page
- Support markdown rendering for AI responses
- Ensure responsive design for different screen sizes
- Add toggle/show/hide functionality for the chat panel

#### 6. Enable streaming responses
- Use existing streaming infrastructure from UnifiedAIController
- Display real-time AI responses as they're generated
- Show typing indicators and loading states
- Handle error states gracefully

### Phase 4: Configuration & Testing

#### 7. Configure Gemini Flash as default model
- Set up Gemini Flash configuration in AI settings
- Ensure proper API key management
- Configure model parameters for optimal chat performance

#### 8. Test chat functionality
- Test task summary retrieval with various date ranges
- Verify streaming response functionality
- Test error handling and edge cases
- Ensure proper integration with existing task features

## Key Integration Points

### Existing Infrastructure to Leverage:
- **ConversationManager**: Already handles multi-turn conversations
- **UnifiedAIController**: Manages all AI provider interactions
- **Function Calling**: Extend existing infrastructure for task operations
- **AI Response Storage**: Reuse patterns for storing chat history
- **Streaming Support**: Build on existing event-based streaming

### Technical Considerations:
- Maintain consistency with existing UI patterns
- Ensure proper state management with Riverpod
- Follow existing error handling patterns
- Respect user's language preferences for multilingual support
- Consider performance implications of loading many task summaries

## Future Enhancements (Not in initial scope)
- Agent-based system for complex queries
- Filtering by task status
- Deep-dive into specific tasks
- Task modification through chat
- Voice input/output support
- Export chat conversations

## Success Criteria
- Users can ask questions about their tasks
- System retrieves relevant task summaries based on date ranges
- Responses stream in real-time
- Chat UI is intuitive and follows Material Design
- Integration doesn't break existing task functionality