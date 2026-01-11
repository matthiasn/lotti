# Voice-Controlled Task Property Updates

## User Story

As a user managing tasks via voice, I want to be able to update task time estimates and due dates by speaking naturally (e.g., "this will take about 2 hours" or "due by Friday"), so that I can manage task metadata without manual input.

## Overview

This plan adds two new AI function-calling tools to update task properties from voice transcripts:
- `update_task_estimate` - Set/update time estimates
- `update_task_due_date` - Set/update due dates

These integrate into the existing checklist processing flow, enabling voice-driven task property updates during audio recording sessions linked to tasks.

---

## Technical Approach

### Design Decisions

1. **Two Separate Functions** (not combined): Clearer AI decision-making, simpler validation, follows existing pattern (`set_task_language` is separate from checklist functions)

2. **AI Handles Parsing**: The AI converts natural language ("2 hours", "next Friday") to structured data (minutes, ISO dates). This leverages LLM capabilities and keeps Dart code simple.

3. **Separate Handler Classes**: Use dedicated `TaskEstimateHandler` and `TaskDueDateHandler` classes for better testability and separation of concerns. The conversation processor delegates to these handlers.

4. **Update Logic**: Only set values when currently empty. For due dates, this means null. For estimates, both null and `Duration.zero` are treated as "not set" (since a zero-duration estimate is meaningless). This prevents voice updates from overwriting manually-set values. If a value already exists, respond with a skip message informing the AI the value was not changed.

---

## Proposed Function Signatures

### `update_task_estimate`

```json
{
  "type": "function",
  "function": {
    "name": "update_task_estimate",
    "description": "Set the time estimate for the current task based on voice transcript. Call when the user mentions duration (e.g., '30 minutes', '2 hours', 'half a day', 'a week'). Only sets the estimate if not already set.",
    "parameters": {
      "type": "object",
      "properties": {
        "minutes": {
          "type": "integer",
          "minimum": 1,
          "maximum": 525600,
          "description": "Time estimate in minutes. Convert: 1 hour = 60, 1 day = 480 (work) or 1440 (full), 1 week = 2400 (work)."
        },
        "reason": {
          "type": "string",
          "description": "Brief explanation of what was said that indicated this estimate."
        },
        "confidence": {
          "type": "string",
          "enum": ["high", "medium", "low"],
          "description": "Confidence level. Use 'high' for explicit statements, 'medium' for implied, 'low' for uncertain."
        }
      },
      "required": ["minutes", "reason", "confidence"]
    }
  }
}
```

### `update_task_due_date`

```json
{
  "type": "function",
  "function": {
    "name": "update_task_due_date",
    "description": "Set the due date for the current task based on voice transcript. Current date is injected at runtime. Call when the user mentions a deadline (e.g., 'due tomorrow', 'by Friday', 'needs to be done by January 15th'). Only sets the date if not already set.",
    "parameters": {
      "type": "object",
      "properties": {
        "dueDate": {
          "type": "string",
          "format": "date",
          "description": "Due date in ISO 8601 format (YYYY-MM-DD). Resolve relative dates to absolute dates based on current date."
        },
        "reason": {
          "type": "string",
          "description": "Brief explanation of what was said that indicated this due date."
        },
        "confidence": {
          "type": "string",
          "enum": ["high", "medium", "low"],
          "description": "Confidence level. Use 'high' for explicit deadlines, 'medium' for implied, 'low' for uncertain."
        }
      },
      "required": ["dueDate", "reason", "confidence"]
    }
  }
}
```

---

## Step-by-Step Implementation Guide

### Step 1: Add Function Definitions to `task_functions.dart`

**File:** `lib/features/ai/functions/task_functions.dart`

Add new function names and tool definitions alongside `set_task_language`:

```dart
class TaskFunctions {
  static const String setTaskLanguage = 'set_task_language';
  static const String updateTaskEstimate = 'update_task_estimate';
  static const String updateTaskDueDate = 'update_task_due_date';

  static List<ChatCompletionTool> getTools() {
    return [
      // Existing set_task_language tool...

      // New: update_task_estimate
      ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: updateTaskEstimate,
          description: 'Set or update the time estimate for the current task...',
          parameters: { /* schema from above */ },
        ),
      ),

      // New: update_task_due_date
      ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: updateTaskDueDate,
          description: 'Set or update the due date for the current task...',
          parameters: { /* schema from above */ },
        ),
      ),
    ];
  }
}
```

**Note:** Result classes are not needed - the inline handler pattern parses JSON directly (matching how `set_task_language` works). `TaskFunctions.getTools()` is already included in `unified_ai_inference_repository.dart`, so no changes to `checklist_tool_selector.dart` are needed.

### Step 2: Add Handler Logic in `lotti_conversation_processor.dart`

**File:** `lib/features/ai/functions/lotti_conversation_processor.dart`

Add handling in `LottiChecklistStrategy.processToolCalls()`, following the `set_task_language` pattern:

```dart
} else if (call.function.name == TaskFunctions.updateTaskEstimate) {
  await _processUpdateTaskEstimate(call, manager);
} else if (call.function.name == TaskFunctions.updateTaskDueDate) {
  await _processUpdateTaskDueDate(call, manager);
}
```

Add the handler methods:

```dart
Future<void> _processUpdateTaskEstimate(
  ChatCompletionMessageToolCall call,
  ConversationManager manager,
) async {
  try {
    final args = jsonDecode(call.function.arguments) as Map<String, dynamic>;
    final minutes = args['minutes'] as int?;
    final confidence = args['confidence'] as String?;
    final reason = args['reason'] as String?;

    developer.log(
      'Processing update_task_estimate: $minutes min (confidence: $confidence, reason: $reason)',
      name: 'LottiConversationProcessor',
    );

    if (minutes == null || minutes <= 0) {
      manager.addToolResponse(
        toolCallId: call.id,
        response: 'Invalid estimate: minutes must be a positive integer.',
      );
      return;
    }

    // Only set if currently null (matches set_task_language pattern)
    final currentEstimate = checklistHandler.task.data.estimate;
    if (currentEstimate != null) {
      manager.addToolResponse(
        toolCallId: call.id,
        response: 'Estimate already set to ${currentEstimate.inMinutes} minutes. Skipped.',
      );
      return;
    }

    final newEstimate = Duration(minutes: minutes);
    final updatedTask = checklistHandler.task.copyWith(
      data: checklistHandler.task.data.copyWith(estimate: newEstimate),
    );

    final journalRepo = ref.read(journalRepositoryProvider);
    await journalRepo.updateJournalEntity(updatedTask);

    // Update handler references
    checklistHandler.task = updatedTask;
    batchChecklistHandler.task = updatedTask;
    checklistHandler.onTaskUpdated?.call(updatedTask);

    manager.addToolResponse(
      toolCallId: call.id,
      response: 'Task estimate updated to $minutes minutes.',
    );
  } catch (e) {
    developer.log('Error processing update_task_estimate: $e',
        name: 'LottiConversationProcessor', error: e);
    manager.addToolResponse(
      toolCallId: call.id,
      response: 'Error updating estimate: $e',
    );
  }
}

Future<void> _processUpdateTaskDueDate(
  ChatCompletionMessageToolCall call,
  ConversationManager manager,
) async {
  try {
    final args = jsonDecode(call.function.arguments) as Map<String, dynamic>;
    final dueDateStr = args['dueDate'] as String?;
    final confidence = args['confidence'] as String?;
    final reason = args['reason'] as String?;

    developer.log(
      'Processing update_task_due_date: $dueDateStr (confidence: $confidence, reason: $reason)',
      name: 'LottiConversationProcessor',
    );

    if (dueDateStr == null || dueDateStr.isEmpty) {
      manager.addToolResponse(
        toolCallId: call.id,
        response: 'Invalid due date: date string is required.',
      );
      return;
    }

    final dueDate = DateTime.tryParse(dueDateStr);
    if (dueDate == null) {
      manager.addToolResponse(
        toolCallId: call.id,
        response: 'Invalid due date format. Use ISO 8601 (YYYY-MM-DD).',
      );
      return;
    }

    // Only set if currently null (matches set_task_language pattern)
    final currentDue = checklistHandler.task.data.due;
    if (currentDue != null) {
      manager.addToolResponse(
        toolCallId: call.id,
        response: 'Due date already set to ${currentDue.toIso8601String().split('T')[0]}. Skipped.',
      );
      return;
    }

    final updatedTask = checklistHandler.task.copyWith(
      data: checklistHandler.task.data.copyWith(due: dueDate),
    );

    final journalRepo = ref.read(journalRepositoryProvider);
    await journalRepo.updateJournalEntity(updatedTask);

    // Update handler references
    checklistHandler.task = updatedTask;
    batchChecklistHandler.task = updatedTask;
    checklistHandler.onTaskUpdated?.call(updatedTask);

    manager.addToolResponse(
      toolCallId: call.id,
      response: 'Task due date updated to ${dueDateStr}.',
    );
  } catch (e) {
    developer.log('Error processing update_task_due_date: $e',
        name: 'LottiConversationProcessor', error: e);
    manager.addToolResponse(
      toolCallId: call.id,
      response: 'Error updating due date: $e',
    );
  }
}
```

### Step 3: Run Code Generation (if needed)

```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

Note: This step is only needed if you add freezed classes. The handler classes use plain Dart result classes (`TaskEstimateResult`, `TaskDueDateResult`) which don't require code generation.

---

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/ai/functions/task_functions.dart` | Add function definitions |
| `lib/features/ai/functions/task_estimate_handler.dart` | New handler class with `TaskEstimateResult` |
| `lib/features/ai/functions/task_due_date_handler.dart` | New handler class with `TaskDueDateResult` |
| `lib/features/ai/functions/lotti_conversation_processor.dart` | Delegate to handler classes in `LottiChecklistStrategy` |

**Note:** `checklist_tool_selector.dart` does NOT need modification - `TaskFunctions.getTools()` is already included in `unified_ai_inference_repository.dart` (lines 570, 594, 1556).

---

## Verification Plan

### 1. Unit Tests

**File:** `test/features/ai/functions/task_property_functions_test.dart`

```dart
group('update_task_estimate', () {
  test('should parse valid minutes', () async {
    // Create mock tool call with valid arguments
    // Verify result parsing succeeds
  });

  test('should reject negative minutes', () async {
    // Verify error response for invalid input
  });

  test('should update task when estimate is null', () async {
    // Create task with null estimate
    // Process tool call
    // Verify task updated via repository
  });

  test('should skip update when estimate already exists', () async {
    // Create task with existing estimate
    // Process tool call
    // Verify task NOT updated, skip message returned
  });
});

group('update_task_due_date', () {
  test('should parse valid ISO 8601 date', () async {
    // Verify date parsing succeeds
  });

  test('should reject invalid date format', () async {
    // Verify error response for invalid format
  });

  test('should update task when due date is null', () async {
    // Create task with null due
    // Process tool call
    // Verify task updated
  });

  test('should skip update when due date already exists', () async {
    // Create task with existing due date
    // Process tool call
    // Verify task NOT updated, skip message returned
  });
});
```

### 2. Integration Tests

**File:** `test/features/ai/functions/lotti_conversation_processor_task_properties_test.dart`

Test the full conversation flow:

```dart
test('should process update_task_estimate in conversation', () async {
  // Setup mock inference provider returning tool call
  // Process conversation
  // Verify task estimate updated
});

test('should handle mixed tool calls (checklist + estimate)', () async {
  // Verify both checklist items created AND estimate updated
});
```

### 3. Manual Verification

1. **Setup**: Create a task with no estimate or due date
2. **Record audio**: Link recording to task, say "This will take about 2 hours and is due Friday"
3. **Verify**: After processing completes:
   - Task estimate shows 120 minutes
   - Task due date shows next Friday's date
4. **Edge case**: Record with existing values, verify voice updates are skipped (values not overwritten)

### 4. Analyzer & Formatter

```bash
fvm flutter analyze
fvm dart format lib test --set-exit-if-changed
```

---

## Edge Cases & Error Handling

1. **Invalid minutes**: Return error, do not update
2. **Invalid date format**: Return error with format guidance
3. **Past due dates**: Accept (user may legitimately set past dates for tracking)
4. **Existing value**: Skip update regardless of confidence, inform AI with skip message
5. **Repository errors**: Log and return error response, conversation continues
6. **Missing task context**: This shouldn't happen as we're in `LottiChecklistStrategy` which requires a task

---

## Future Enhancements (Out of Scope)

- Combined `update_task_properties` function for atomic multi-property updates
- Task status updates via voice
- Task priority updates via voice
- Undo/history for voice-initiated changes
