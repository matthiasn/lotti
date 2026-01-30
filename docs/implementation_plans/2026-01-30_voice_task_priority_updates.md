# Voice-Controlled Task Priority Updates

## User Story

As a user managing tasks via voice, I want to be able to set task priority by speaking naturally (e.g., "priority P1", "this is urgent", "low priority task"), so that I can manage task importance without manual input.

## Overview

This plan adds a new AI function-calling tool to update task priority from voice transcripts:
- `update_task_priority` - Set/update priority level (P0-P3)

This integrates into the existing checklist processing flow alongside `update_task_estimate` and `update_task_due_date`, completing the voice-driven task property updates feature.

**Background:** Priority was explicitly listed as "Future Enhancement (Out of Scope)" in the original voice task property updates plan (`2026-01-10_voice_task_property_updates.md`). This plan promotes it to an implemented feature.

---

## Technical Approach

### Design Decisions

1. **Follows Existing Pattern**: Matches the architecture of `TaskEstimateHandler` and `TaskDueDateHandler` for consistency and maintainability.

2. **AI Handles Mapping**: The AI converts natural language ("urgent", "high priority", "not important") to structured priority levels (P0, P1, P2, P3). This leverages LLM capabilities and keeps Dart code simple.

3. **Dedicated Handler Class**: Use `TaskPriorityHandler` class for testability and separation of concerns.

4. **Update Logic**: Only set priority when it equals the default value (`TaskPriority.p2Medium`). Non-default values indicate explicit user choice and should not be overwritten by voice. This matches the preservation-of-manual-edits pattern from estimate/due date handlers.

---

## Proposed Function Signature

### `update_task_priority`

```json
{
  "type": "function",
  "function": {
    "name": "update_task_priority",
    "description": "Set the priority for the current task based on voice transcript. Call when the user mentions priority or urgency (e.g., 'priority P0', 'high priority', 'this is urgent', 'low priority task'). Only sets priority if not already explicitly set by user.",
    "parameters": {
      "type": "object",
      "properties": {
        "priority": {
          "type": "string",
          "enum": ["P0", "P1", "P2", "P3"],
          "description": "Priority level. P0=Urgent, P1=High, P2=Medium, P3=Low. Map spoken terms: 'urgent/critical'→P0, 'high/important'→P1, 'medium/normal'→P2, 'low/minor'→P3."
        },
        "reason": {
          "type": "string",
          "description": "Brief explanation of what was said that indicated this priority."
        },
        "confidence": {
          "type": "string",
          "enum": ["high", "medium", "low"],
          "description": "Confidence level. Use 'high' for explicit priority statements, 'medium' for implied urgency, 'low' for uncertain."
        }
      },
      "required": ["priority", "reason", "confidence"]
    }
  }
}
```

### Priority Mapping Guide (for AI)

| Spoken Input | Mapped Priority |
|--------------|-----------------|
| "urgent", "critical", "P0", "highest priority" | P0 (Urgent) |
| "high priority", "important", "P1" | P1 (High) |
| "medium", "normal", "P2", "default priority" | P2 (Medium) |
| "low priority", "minor", "P3", "not urgent" | P3 (Low) |

---

## Step-by-Step Implementation Guide

### Step 1: Add Function Definition to `task_functions.dart`

**File:** `lib/features/ai/functions/task_functions.dart`

Add new function name constant:

```dart
class TaskFunctions {
  static const String setTaskLanguage = 'set_task_language';
  static const String updateTaskEstimate = 'update_task_estimate';
  static const String updateTaskDueDate = 'update_task_due_date';
  static const String updateTaskPriority = 'update_task_priority';  // NEW
  // ...
}
```

Add new tool to `getTools()` list:

```dart
const ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(
    name: updateTaskPriority,
    description:
        'Set the priority for the current task based on voice transcript. '
        'Call when the user mentions priority or urgency (e.g., "priority P0", '
        '"high priority", "this is urgent", "low priority task"). '
        'Only sets priority if not already explicitly set by user.',
    parameters: {
      'type': 'object',
      'properties': {
        'priority': {
          'type': 'string',
          'enum': ['P0', 'P1', 'P2', 'P3'],
          'description': 'Priority level. P0=Urgent, P1=High, P2=Medium, P3=Low. '
              'Map spoken terms: "urgent/critical"→P0, "high/important"→P1, '
              '"medium/normal"→P2, "low/minor"→P3.',
        },
        'reason': {
          'type': 'string',
          'description':
              'Brief explanation of what was said that indicated this priority.',
        },
        'confidence': {
          'type': 'string',
          'enum': ['high', 'medium', 'low'],
          'description':
              'Confidence level. Use "high" for explicit priority statements, '
                  '"medium" for implied urgency, "low" for uncertain.',
        },
      },
      'required': ['priority', 'reason', 'confidence'],
    },
  ),
),
```

### Step 2: Create Priority Handler Class

**File:** `lib/features/ai/functions/task_priority_handler.dart` (NEW)

```dart
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:openai_dart/openai_dart.dart';

/// Parses a priority string from AI input to TaskPriority enum.
///
/// Handles P0, P1, P2, P3 strings (case-insensitive). Returns null if
/// parsing fails.
TaskPriority? parsePriority(dynamic value) {
  if (value == null) return null;
  if (value is! String) return null;

  final normalized = value.trim().toUpperCase();
  return switch (normalized) {
    'P0' => TaskPriority.p0Urgent,
    'P1' => TaskPriority.p1High,
    'P2' => TaskPriority.p2Medium,
    'P3' => TaskPriority.p3Low,
    _ => null,
  };
}

/// Result of processing a priority update tool call.
///
/// Contains detailed information about the outcome for testing and logging.
class TaskPriorityResult {
  const TaskPriorityResult({
    required this.success,
    required this.message,
    this.updatedTask,
    this.requestedPriority,
    this.reason,
    this.confidence,
    this.error,
  });

  /// Whether the priority was successfully updated.
  final bool success;

  /// Human-readable message describing the outcome.
  final String message;

  /// The updated task if successful, null otherwise.
  final Task? updatedTask;

  /// The priority value requested by the AI.
  final TaskPriority? requestedPriority;

  /// The AI's explanation for why this priority was detected.
  final String? reason;

  /// The AI's confidence level ('high', 'medium', 'low').
  final String? confidence;

  /// Error message if the operation failed.
  final String? error;

  /// Whether the update was skipped (not an error, just not applied).
  bool get wasSkipped => !success && error == null;
}

/// Handler for updating task priority via AI function calls.
///
/// This handler processes `update_task_priority` tool calls from the AI,
/// converting natural language priority expressions (e.g., "urgent",
/// "high priority") into structured task priority levels.
///
/// ## Behavior
///
/// - **Only sets if not already set**: If the task has a non-default priority
///   (anything other than p2Medium), the update is skipped to preserve manual
///   edits. The default p2Medium is treated as "not explicitly set".
///
/// - **Validates input**: Rejects invalid priority values from the AI.
///
/// - **Updates task state**: On success, updates the task in the database and
///   notifies listeners via the [onTaskUpdated] callback.
///
/// See also:
/// - `TaskEstimateHandler` for time estimate updates
/// - `TaskDueDateHandler` for due date updates
/// - `TaskFunctions` for function definitions
class TaskPriorityHandler {
  /// Creates a handler for processing task priority updates.
  TaskPriorityHandler({
    required this.task,
    required this.journalRepository,
    this.onTaskUpdated,
  });

  /// The task being processed.
  Task task;

  /// Repository for persisting task updates to the database.
  final JournalRepository journalRepository;

  /// Optional callback invoked when the task is successfully updated.
  final void Function(Task)? onTaskUpdated;

  /// Processes an `update_task_priority` tool call from the AI.
  Future<TaskPriorityResult> processToolCall(
    ChatCompletionMessageToolCall call, [
    ConversationManager? manager,
  ]) async {
    try {
      final args = jsonDecode(call.function.arguments) as Map<String, dynamic>;
      final rawPriority = args['priority'] as String?;
      final confidence = args['confidence'] as String?;
      final reason = args['reason'] as String?;

      final priority = parsePriority(rawPriority);

      developer.log(
        'Processing update_task_priority: raw=$rawPriority, parsed=$priority '
        '(confidence: $confidence, reason: $reason)',
        name: 'TaskPriorityHandler',
      );

      if (priority == null) {
        final message = 'Invalid priority: must be P0, P1, P2, or P3. '
            'Received: $rawPriority';
        _sendResponse(call.id, message, manager);
        return TaskPriorityResult(
          success: false,
          message: message,
          reason: reason,
          confidence: confidence,
          error: message,
        );
      }

      // Check if priority was explicitly set (not default p2Medium)
      final currentPriority = task.data.priority;
      final wasExplicitlySet = currentPriority != TaskPriority.p2Medium;

      if (wasExplicitlySet) {
        final message =
            'Priority already set to ${currentPriority.short}. Skipped.';
        developer.log(
          'Task already has priority: ${currentPriority.short}',
          name: 'TaskPriorityHandler',
        );
        _sendResponse(call.id, message, manager);
        return TaskPriorityResult(
          success: false,
          message: message,
          requestedPriority: priority,
          reason: reason,
          confidence: confidence,
        );
      }

      // Update the task
      final updatedTask = task.copyWith(
        data: task.data.copyWith(priority: priority),
      );

      try {
        await journalRepository.updateJournalEntity(updatedTask);

        task = updatedTask;
        onTaskUpdated?.call(updatedTask);

        final message = 'Task priority updated to ${priority.short}.';
        developer.log(
          'Successfully set task priority to ${priority.short}',
          name: 'TaskPriorityHandler',
        );
        _sendResponse(call.id, message, manager);

        return TaskPriorityResult(
          success: true,
          message: message,
          updatedTask: updatedTask,
          requestedPriority: priority,
          reason: reason,
          confidence: confidence,
        );
      } catch (e) {
        const message =
            'Failed to set priority. Continuing without priority update.';
        developer.log(
          'Failed to update task priority',
          name: 'TaskPriorityHandler',
          error: e,
        );
        _sendResponse(call.id, message, manager);
        return TaskPriorityResult(
          success: false,
          message: message,
          requestedPriority: priority,
          reason: reason,
          confidence: confidence,
          error: e.toString(),
        );
      }
    } catch (e) {
      const message = 'Error processing task priority update.';
      developer.log(
        'Error processing update_task_priority: $e',
        name: 'TaskPriorityHandler',
        error: e,
      );
      _sendResponse(call.id, message, manager);
      return TaskPriorityResult(
        success: false,
        message: message,
        error: e.toString(),
      );
    }
  }

  void _sendResponse(
    String toolCallId,
    String response,
    ConversationManager? manager,
  ) {
    manager?.addToolResponse(
      toolCallId: toolCallId,
      response: response,
    );
  }
}
```

### Step 3: Integrate in Conversation Processor

**File:** `lib/features/ai/functions/lotti_conversation_processor.dart`

Add import at top of file:

```dart
import 'package:lotti/features/ai/functions/task_priority_handler.dart';
```

Add handling in `processToolCalls()` after the due date handler branch (~line 503):

```dart
} else if (call.function.name == TaskFunctions.updateTaskPriority) {
  // Delegate to TaskPriorityHandler
  final priorityHandler = TaskPriorityHandler(
    task: checklistHandler.task,
    journalRepository: journalRepository,
    onTaskUpdated: (updatedTask) {
      checklistHandler = checklistHandler.copyWith(task: updatedTask);
    },
  );
  await priorityHandler.processToolCall(call, manager);
}
```

---

## Files to Modify/Create

| File | Action | Change |
|------|--------|--------|
| `lib/features/ai/functions/task_functions.dart` | Modify | Add `updateTaskPriority` constant and tool definition |
| `lib/features/ai/functions/task_priority_handler.dart` | **Create** | New handler class with `TaskPriorityResult` |
| `lib/features/ai/functions/lotti_conversation_processor.dart` | Modify | Add import and delegation branch |
| `test/features/ai/functions/task_priority_handler_test.dart` | **Create** | Unit tests for handler |

**Note:** `checklist_tool_selector.dart` does NOT need modification - `TaskFunctions.getTools()` is already included in `unified_ai_inference_repository.dart`.

---

## Verification Plan

### 1. Unit Tests

**File:** `test/features/ai/functions/task_priority_handler_test.dart`

```dart
group('parsePriority', () {
  test('should parse valid priority strings', () {
    expect(parsePriority('P0'), TaskPriority.p0Urgent);
    expect(parsePriority('P1'), TaskPriority.p1High);
    expect(parsePriority('P2'), TaskPriority.p2Medium);
    expect(parsePriority('P3'), TaskPriority.p3Low);
  });

  test('should be case-insensitive', () {
    expect(parsePriority('p0'), TaskPriority.p0Urgent);
    expect(parsePriority('p1'), TaskPriority.p1High);
  });

  test('should return null for invalid values', () {
    expect(parsePriority(null), isNull);
    expect(parsePriority(''), isNull);
    expect(parsePriority('P4'), isNull);
    expect(parsePriority('urgent'), isNull); // Only P0-P3 accepted
  });
});

group('TaskPriorityHandler', () {
  test('should update priority when default (p2Medium)', () async {
    // Create task with default priority
    // Process tool call with P1
    // Verify task updated to P1
  });

  test('should skip update when priority already set', () async {
    // Create task with P0
    // Process tool call with P1
    // Verify task NOT updated, wasSkipped is true
  });

  test('should reject invalid priority values', () async {
    // Process tool call with invalid priority
    // Verify error result
  });

  test('should invoke onTaskUpdated callback on success', () async {
    // Verify callback called with updated task
  });

  test('should handle repository errors gracefully', () async {
    // Mock repository to throw
    // Verify error result, no crash
  });
});
```

### 2. Integration Tests

**File:** `test/features/ai/functions/lotti_conversation_processor_task_properties_test.dart`

Add tests for priority alongside existing estimate/due date tests:

```dart
test('should process update_task_priority in conversation', () async {
  // Setup mock inference provider returning priority tool call
  // Process conversation
  // Verify task priority updated
});

test('should handle mixed tool calls (checklist + priority)', () async {
  // Verify both checklist items created AND priority updated
});
```

### 3. Manual Verification

1. **Setup**: Create a task with default priority (P2)
2. **Record audio**: Link recording to task, say "This is urgent, priority P0"
3. **Verify**: After processing completes, task priority shows P0
4. **Edge case**: Create task, manually set P1, record "priority P0" - verify P0 is NOT applied (manual edit preserved)

### 4. Analyzer & Formatter

```bash
fvm flutter analyze
fvm dart format lib test --set-exit-if-changed
```

---

## Edge Cases & Error Handling

1. **Invalid priority string**: Return error, do not update
2. **Non-default priority exists**: Skip update, inform AI with skip message
3. **Repository errors**: Log and return error response, conversation continues
4. **Missing task context**: Not possible - we're in `LottiChecklistStrategy` which requires a task

---

## Design Decision: Default Priority Handling

The handler treats `TaskPriority.p2Medium` as "not explicitly set" because:

1. **It's the default**: New tasks are created with p2Medium by default
2. **User intent**: If the user manually changed priority to P0, P1, or P3, they made an explicit choice
3. **Consistency**: Matches how estimate (null/zero = not set) and due date (null = not set) work
4. **Edge case**: If user explicitly wants P2 via voice and task is already P2, no change needed anyway

---

## Implementation Checklist

- [ ] Add `updateTaskPriority` constant to `TaskFunctions`
- [ ] Add tool definition to `TaskFunctions.getTools()`
- [ ] Create `task_priority_handler.dart` with `TaskPriorityHandler` class
- [ ] Create `TaskPriorityResult` class
- [ ] Create `parsePriority()` helper function
- [ ] Add import to `lotti_conversation_processor.dart`
- [ ] Add delegation branch in `processToolCalls()`
- [ ] Create unit tests for `parsePriority()`
- [ ] Create unit tests for `TaskPriorityHandler`
- [ ] Add integration tests
- [ ] Run analyzer (all green)
- [ ] Run formatter
- [ ] Run existing tests (all pass)
- [ ] Manual verification
