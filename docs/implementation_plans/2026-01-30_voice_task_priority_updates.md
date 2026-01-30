# Voice-Controlled Task Priority Updates

## User Story

As a user managing tasks via voice, I want to be able to set task priority by speaking naturally (e.g., "priority P1", "this is urgent", "low priority task"), so that I can manage task importance without manual input.

## Overview

Adds `update_task_priority` AI function-calling tool to set task priority (P0-P3) from voice transcripts. Integrates into the checklist processing flow alongside `update_task_estimate` and `update_task_due_date`.

**Background:** Priority was listed as "Future Enhancement (Out of Scope)" in the original voice task property updates plan (`2026-01-10_voice_task_property_updates.md`).

## Function Signature

```json
{
  "name": "update_task_priority",
  "parameters": {
    "priority": "P0|P1|P2|P3",
    "reason": "string",
    "confidence": "high|medium|low"
  }
}
```

## Priority Mapping

| Spoken Input | Mapped Priority |
|--------------|-----------------|
| "urgent", "critical", "P0", "highest priority" | P0 (Urgent) |
| "high priority", "important", "P1" | P1 (High) |
| "medium", "normal", "P2", "default priority" | P2 (Medium) |
| "low priority", "minor", "P3", "not urgent" | P3 (Low) |

## Design Decisions

1. **Follows Existing Pattern**: Matches `TaskEstimateHandler` and `TaskDueDateHandler` architecture.

2. **AI Handles Mapping**: AI converts natural language to P0-P3 levels.

3. **Preserves Manual Edits**: Only sets priority when it equals default (`p2Medium`). Non-default values indicate explicit user choice.

## Implementation

| File | Description |
|------|-------------|
| `lib/features/ai/functions/task_functions.dart` | Function definition |
| `lib/features/ai/functions/task_priority_handler.dart` | Handler class |
| `lib/features/ai/functions/lotti_conversation_processor.dart` | Integration |
| `test/features/ai/functions/task_priority_handler_test.dart` | Unit tests |
| `test/features/ai/functions/lotti_conversation_processor_task_properties_test.dart` | Integration tests |
