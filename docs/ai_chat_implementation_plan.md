# AI Chat Feature Implementation Plan

## Executive Summary

This document outlines a comprehensive plan for refactoring the AI chat feature in Lotti to achieve better modularity, testability, and documentation standards. The plan includes implementing a thinking mode for Gemini Flash to provide more thoughtful responses when querying task data.

## Current State Analysis

### Existing Architecture
- **UI Layer**: ChatModalPage → ChatInterface with streaming support
- **State Management**: ChatController using Riverpod
- **Repository Layer**: AiChatRepository → CloudInferenceRepository
- **Data Access**: TaskSummaryRepository with function calling support
- **Integration**: Accessible via app bar icon in tasks view

### Key Issues Identified
1. Debug print statements instead of proper logging
2. No test coverage for the AI chat feature
3. Limited to single category selection
4. No thinking mode implementation despite infrastructure support
5. Tight coupling between layers

## Refactoring Plan

### Phase 1: Modular Architecture Refactoring

#### 1.1 Domain Layer Separation
Create clear domain models and interfaces:

```
lib/features/ai_chat/
├── domain/
│   ├── models/
│   │   ├── chat_message.dart
│   │   ├── chat_session.dart
│   │   ├── task_query.dart
│   │   └── task_summary.dart
│   ├── repositories/
│   │   ├── chat_repository.dart (interface)
│   │   └── task_query_repository.dart (interface)
│   └── services/
│       ├── chat_service.dart
│       └── thinking_mode_service.dart
```

#### 1.2 Data Layer Refactoring
Separate data access from business logic:

```
lib/features/ai_chat/
├── data/
│   ├── repositories/
│   │   ├── chat_repository_impl.dart
│   │   └── task_query_repository_impl.dart
│   ├── datasources/
│   │   ├── local/
│   │   │   └── task_datasource.dart
│   │   └── remote/
│   │       └── ai_datasource.dart
│   └── models/
│       └── task_summary_dto.dart
```

#### 1.3 Presentation Layer Organization
Clean separation of UI concerns:

```
lib/features/ai_chat/
├── presentation/
│   ├── controllers/
│   │   └── chat_controller.dart
│   ├── pages/
│   │   └── chat_modal_page.dart
│   ├── widgets/
│   │   ├── chat_interface.dart
│   │   ├── message_bubble.dart
│   │   ├── typing_indicator.dart
│   │   └── error_display.dart
│   └── providers/
│       └── chat_providers.dart
```

### Phase 2: Core Improvements

#### 2.1 Logging System
- Replace all print statements with structured logging
- Implement log levels (debug, info, warning, error)
- Add context to logs for better debugging

#### 2.2 Error Handling
- Create custom exception classes
- Implement proper error boundaries
- Add retry mechanisms for network failures

#### 2.3 Configuration Management
- Extract hardcoded values to configuration
- Support environment-specific settings
- Enable feature flags for gradual rollout

### Phase 3: Thinking Mode Implementation

#### 3.1 System Prompt Enhancement
```dart
class ThinkingModeService {
  static const String THINKING_INSTRUCTION = '''
<thinking_mode>
You are an AI assistant helping users understand their task history and productivity patterns.
Before responding, use the <think> tags to analyze the query and plan your response.

Inside <think> tags:
1. Identify the time period and categories being queried
2. Consider what insights would be most valuable
3. Look for patterns, achievements, and learnings
4. Plan a structured, helpful response

After thinking, provide a clear, insightful summary.
</thinking_mode>
''';

  String enhanceSystemPrompt(String basePrompt, bool useThinking) {
    if (!useThinking) return basePrompt;
    return '$basePrompt\n\n$THINKING_INSTRUCTION';
  }
}
```

#### 3.2 Response Processing
- Extract and store thinking content
- Optionally display thinking process to users
- Log thinking content for analysis

#### 3.3 Model Configuration
- Add thinking mode toggle in settings
- Configure per-query thinking requirements
- Support different thinking depths

## Testing Strategy

### Unit Tests

#### 1. Domain Layer Tests
- **ChatMessage Tests**
  - Message creation validation
  - Serialization/deserialization
  - Type safety checks

- **TaskQuery Tests**
  - Date range validation
  - Category filtering logic
  - Query parameter validation

#### 2. Repository Tests
- **ChatRepository Tests**
  - Message sending with mocked AI service
  - Streaming response handling
  - Error propagation
  - Retry logic

- **TaskQueryRepository Tests**
  - Task retrieval with various filters
  - Empty result handling
  - Database query optimization
  - Link resolution accuracy

#### 3. Service Tests
- **ThinkingModeService Tests**
  - Prompt enhancement logic
  - Thinking tag extraction
  - Configuration handling

### Integration Tests

#### 1. AI Integration Tests
- Function calling flow
- Streaming response handling
- Context preservation across messages
- Rate limiting and quotas

#### 2. Database Integration Tests
- Complex query scenarios
- Performance with large datasets
- Transaction handling
- Data consistency

### Widget Tests

#### 1. UI Component Tests
- **ChatInterface Tests**
  - Message rendering
  - Scroll behavior
  - Input field validation
  - Send button states

- **MessageBubble Tests**
  - Markdown rendering
  - Code block formatting
  - Link handling
  - Timestamp display

#### 2. Controller Tests
- State management flows
- Loading states
- Error states
- Message history management

### End-to-End Test Scenarios

#### Scenario 1: Basic Task Query
```
Given: User has tasks in "Learning" category for the past month
When: User asks "What did I learn last month?"
Then: 
  - AI calls get_task_summaries with correct date range
  - Returns structured summary of learning tasks
  - Displays formatted response with markdown
```

#### Scenario 2: Achievement Summary
```
Given: User has completed tasks across multiple categories
When: User asks "What were my achievements in Q3?"
Then:
  - AI identifies Q3 date range
  - Retrieves tasks from all relevant categories
  - Provides categorized achievement summary
```

#### Scenario 3: Pattern Analysis
```
Given: User has recurring tasks with time tracking
When: User asks "What patterns do you see in my work habits?"
Then:
  - AI analyzes task frequency and duration
  - Identifies productivity patterns
  - Suggests insights about work habits
```

#### Scenario 4: Error Handling
```
Given: Network connection is unstable
When: User sends a message
Then:
  - Shows appropriate loading state
  - Retries on transient failures
  - Displays clear error message on permanent failure
  - Allows manual retry
```

#### Scenario 5: Thinking Mode
```
Given: Thinking mode is enabled
When: User asks complex analytical question
Then:
  - AI spends time analyzing in thinking tags
  - Provides more thoughtful, structured response
  - Response quality is measurably better
```

### Test Data Management

#### 1. Test Fixtures
- Predefined task sets for consistent testing
- Date-relative test data generation
- Category and tag combinations

#### 2. Mock Strategies
- AI response mocking for deterministic tests
- Database mocking for unit tests
- Network layer mocking

#### 3. Performance Benchmarks
- Response time targets
- Memory usage limits
- Database query performance

## Documentation Requirements

### 1. API Documentation
- Clear interface documentation with examples
- Parameter descriptions and constraints
- Return value specifications

### 2. Architecture Documentation
- System design diagrams
- Data flow documentation
- Integration points

### 3. User Documentation
- Feature overview
- Usage examples
- Troubleshooting guide

### 4. Developer Documentation
- Setup instructions
- Testing guidelines
- Contribution guide

## Implementation Timeline

### Week 1-2: Foundation
- Domain model creation
- Interface definitions
- Basic refactoring

### Week 3-4: Core Features
- Repository implementations
- Service layer development
- Thinking mode implementation

### Week 5-6: Testing
- Unit test implementation
- Integration test setup
- E2E test scenarios

### Week 7-8: Polish
- Documentation completion
- Performance optimization
- Bug fixes and refinements

## Success Metrics

1. **Code Quality**
   - 80%+ test coverage
   - Zero critical lint issues
   - All functions documented

2. **Performance**
   - < 200ms response initiation
   - Smooth streaming updates
   - Efficient database queries

3. **User Experience**
   - Clear, helpful responses
   - Graceful error handling
   - Intuitive interaction flow

4. **Maintainability**
   - Modular, decoupled architecture
   - Clear separation of concerns
   - Comprehensive documentation

## Risk Mitigation

1. **AI API Changes**
   - Abstract AI interactions behind interfaces
   - Version lock dependencies
   - Implement fallback strategies

2. **Performance Issues**
   - Implement query result caching
   - Optimize database indexes
   - Add pagination for large results

3. **Testing Complexity**
   - Start with critical path tests
   - Use test doubles effectively
   - Automate test data generation

## Next Steps

1. Review and approve this plan
2. Create detailed technical design documents
3. Set up testing infrastructure
4. Begin incremental refactoring
5. Implement thinking mode as proof of concept

This plan ensures the AI chat feature becomes a robust, well-tested, and maintainable component of the Lotti application while introducing thoughtful AI responses through thinking mode implementation.