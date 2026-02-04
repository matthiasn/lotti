# Interactive Audio Day Planning Implementation Plan

## Overview

Enable users to plan their day using voice commands. Users record audio, which gets transcribed, then processed by an LLM with function calling to manipulate the day plan (add/resize/move/delete time blocks, pin tasks).

## Architecture Decision

**Approach: Leverage existing infrastructure**

The codebase already has all the building blocks:
- `UnifiedDailyOsDataController` has mutation methods: `addPlannedBlock()`, `updatePlannedBlock()`, `removePlannedBlock()`, `pinTask()`
- `ConversationRepository` + `ConversationStrategy` pattern for function calling
- `ChatRecorderController` for recording + transcription with lifecycle/race-condition handling

We'll create a thin integration layer that connects these existing components.

---

## New Files to Create

```
lib/features/daily_os/
├── voice/
│   ├── day_plan_functions.dart           # Function definitions
│   ├── day_plan_voice_strategy.dart      # ConversationStrategy implementation
│   ├── day_plan_voice_service.dart       # Orchestrator
│   └── day_plan_voice_controller.dart    # UI state controller
└── ui/widgets/
    └── voice_day_plan_fab.dart           # FAB with voice recording
```

---

## Phase 1: Function Definitions

### File: `lib/features/daily_os/voice/day_plan_functions.dart`

Define 5 functions for the LLM:

```dart
class DayPlanFunctions {
  static const String addTimeBlock = 'add_time_block';
  static const String resizeTimeBlock = 'resize_time_block';
  static const String moveTimeBlock = 'move_time_block';
  static const String deleteTimeBlock = 'delete_time_block';
  static const String linkTaskToDay = 'link_task_to_day';

  static List<ChatCompletionTool> getTools() => [...];
}
```

**Function Schemas:**

| Function | Required Params | Optional Params | Notes |
|----------|-----------------|-----------------|-------|
| `add_time_block` | `categoryName`, `startTime`, `endTime` | `note` | |
| `resize_time_block` | `blockId`, at least one of: `newStartTime`, `newEndTime` | | Schema uses `anyOf` to require ≥1 |
| `move_time_block` | `blockId`, `newStartTime` | | Handler preserves duration (shifts endTime by same delta) |
| `delete_time_block` | `blockId` | | |
| `link_task_to_day` | `taskTitle` | `categoryName` | |

**Time format:** `HH:mm` (24-hour)

### Time Parsing Utility

```dart
/// Parses time strings defensively, handling various formats
DateTime? parseTimeForDate(String timeStr, DateTime date) {
  // Try HH:mm format first
  final hhmmMatch = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(timeStr.trim());
  if (hhmmMatch != null) {
    final hour = int.parse(hhmmMatch.group(1)!);
    final minute = int.parse(hhmmMatch.group(2)!);
    if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
  }

  // Try plain hour (e.g., "9" -> 09:00)
  final hourOnly = int.tryParse(timeStr.trim());
  if (hourOnly != null && hourOnly >= 0 && hourOnly < 24) {
    return DateTime(date.year, date.month, date.day, hourOnly);
  }

  return null;
}
```

---

## Phase 2: Conversation Strategy

### File: `lib/features/daily_os/voice/day_plan_voice_strategy.dart`

Implement `ConversationStrategy` to process tool calls:

```dart
class DayPlanVoiceStrategy extends ConversationStrategy {
  DayPlanVoiceStrategy({
    required this.date,
    required this.dayPlanController,
    required this.categoryResolver,
    required this.taskSearcher,
  });

  final DateTime date;
  final UnifiedDailyOsDataController dayPlanController;
  final CategoryResolver categoryResolver;
  final TaskSearcher taskSearcher;

  final List<DayPlanActionResult> results = [];

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    for (final toolCall in toolCalls) {
      final result = await _handleToolCall(toolCall);
      results.add(result);
      manager.addToolResponse(
        toolCallId: toolCall.id,
        response: result.toJsonString(),
      );
    }
    return ConversationAction.complete; // Single-turn for MVP
  }

  @override
  bool shouldContinue(ConversationManager manager) => false; // Single-turn

  @override
  String? getContinuationPrompt(ConversationManager manager) => null;
}
```

### Category Resolution

```dart
class CategoryResolver {
  CategoryResolver(this.cacheService);
  final EntitiesCacheService cacheService;

  CategoryDefinition? resolve(String spokenName) {
    final normalized = spokenName.toLowerCase().trim();
    final categories = cacheService.sortedCategories;

    // Exact match
    for (final cat in categories) {
      if (cat.name.toLowerCase() == normalized) return cat;
    }
    // Prefix match
    for (final cat in categories) {
      if (cat.name.toLowerCase().startsWith(normalized)) return cat;
    }
    // Contains match
    for (final cat in categories) {
      if (cat.name.toLowerCase().contains(normalized)) return cat;
    }
    return null;
  }
}
```

### Task Searching

```dart
import 'package:lotti/features/tasks/ui/utils.dart' show openTaskStatuses;

class TaskSearcher {
  TaskSearcher(this.db, this.fts5Db);
  final JournalDb db;
  final Fts5Db fts5Db;

  Future<Task?> findByTitle(String titleQuery) async {
    // 1. FTS5 search returns matching UUIDs
    //    Use title: prefix to search title column specifically
    final matchingIds = await fts5Db.findMatching('title:$titleQuery*').get();
    if (matchingIds.isEmpty) return null;

    // 2. Load tasks by IDs and filter to open tasks only
    //    JournalDb.getTasks() returns List<JournalEntity>, filter to Task
    final entities = await db.getTasks(
      starredStatuses: [false, true], // Include both starred and unstarred
      taskStatuses: openTaskStatuses, // ['OPEN', 'GROOMED', 'IN PROGRESS', 'BLOCKED', 'ON HOLD']
      categoryIds: [],                // No category filter
      ids: matchingIds,
    );
    final tasks = entities.whereType<Task>().toList();

    // 3. Return best match (exact title match preferred, then first result)
    final normalized = titleQuery.toLowerCase().trim();
    return tasks.firstWhereOrNull(
          (t) => t.data.title.toLowerCase() == normalized,
        ) ??
        tasks.firstOrNull;
  }
}
```

---

## Phase 3: Orchestration Service

### File: `lib/features/daily_os/voice/day_plan_voice_service.dart`

```dart
@riverpod
class DayPlanVoiceService extends _$DayPlanVoiceService {

  Future<DayPlanVoiceResult> processTranscript({
    required String transcript,
    required DateTime date,
  }) async {
    // 1. Get current day plan state
    final unifiedData = await ref.read(
      unifiedDailyOsDataControllerProvider(date: date).future,
    );

    // 2. Build system prompt with context
    final systemPrompt = _buildSystemPrompt(
      date: date,
      currentPlan: unifiedData.dayPlan.data,
      categories: cacheService.sortedCategories,
      openTasks: await _fetchOpenTasks(),
    );

    // 3. Get inference provider (prefer Mistral or Gemini)
    final (model, provider, inferenceRepo) = await _getInferenceSetup();

    // 4. Create conversation and process
    final conversationRepo = ref.read(conversationRepositoryProvider.notifier);
    final conversationId = conversationRepo.createConversation(
      systemMessage: systemPrompt,
      maxTurns: 3,
    );

    final strategy = DayPlanVoiceStrategy(
      date: date,
      dayPlanController: ref.read(
        unifiedDailyOsDataControllerProvider(date: date).notifier,
      ),
      categoryResolver: CategoryResolver(cacheService),
      taskSearcher: TaskSearcher(db, fts5Db),
    );

    await conversationRepo.sendMessage(
      conversationId: conversationId,
      message: transcript,
      model: model.providerModelId,
      provider: provider,
      inferenceRepo: inferenceRepo,
      tools: DayPlanFunctions.getTools(),
      temperature: 0.1,
      strategy: strategy,
    );

    conversationRepo.deleteConversation(conversationId);

    return DayPlanVoiceResult(
      actions: strategy.results,
      hadErrors: strategy.results.any((r) => !r.success),
    );
  }
}
```

---

## Phase 4: System Prompt

```dart
String _buildSystemPrompt({
  required DateTime date,
  required DayPlanData currentPlan,
  required List<CategoryDefinition> categories,
  required List<Task> openTasks,
}) {
  final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(date);

  return '''
You are a day planning assistant helping organize the schedule for $dateStr.

## Available Categories
${_formatCategories(categories)}

## Current Day Plan (blocks with IDs for reference)
${_formatCurrentPlan(currentPlan, _buildCategoryMap(categories))}

## Open Tasks (for pinning)
${_formatTasks(openTasks.take(20))}

## Instructions
- Match category names case-insensitively
- Use 24-hour HH:mm format for times (e.g., "09:00", "14:30")
- Reference existing blocks by their ID from "Current Day Plan"
- Search tasks by partial title match
- Execute ALL relevant actions from the user's request

## Examples
"Add 2 hours of work starting at 9" → add_time_block(categoryName="Work", startTime="09:00", endTime="11:00")
"Move the exercise block to 7 AM" → move_time_block(blockId="[id]", newStartTime="07:00")
"Shrink the meeting to just one hour" → resize_time_block(blockId="[id]", newEndTime="[startTime + 1hr]")
"Pin the API task to today" → link_task_to_day(taskTitle="API")
''';
}

Map<String, String> _buildCategoryMap(List<CategoryDefinition> categories) {
  return {for (final cat in categories) cat.id: cat.name};
}

String _formatCurrentPlan(
  DayPlanData? plan,
  Map<String, String> categoryIdToName,
) {
  if (plan == null || plan.plannedBlocks.isEmpty) {
    return 'No blocks scheduled yet.';
  }
  final buffer = StringBuffer();
  for (final block in plan.plannedBlocks) {
    final start = DateFormat.Hm().format(block.startTime);
    final end = DateFormat.Hm().format(block.endTime);
    final categoryName = categoryIdToName[block.categoryId] ?? 'Unknown';
    // Format: [block-id] HH:mm-HH:mm CategoryName (optional note)
    buffer.writeln('- [${block.id}] $start-$end $categoryName'
        '${block.note != null ? " (${block.note})" : ""}');
  }
  return buffer.toString();
}
```

---

## Phase 5: UI State Controller

### Reuse `ChatRecorderController` + Add LLM Processing State

Instead of creating a new recording controller, reuse `ChatRecorderController` (which already handles recording lifecycle, amplitude streaming, transcription, race conditions, and cleanup) and add a separate provider for LLM processing state.

### File: `lib/features/daily_os/voice/day_plan_voice_controller.dart`

```dart
/// Tracks LLM processing state after transcription completes.
/// Recording/transcription is handled by ChatRecorderController.
@freezed
sealed class DayPlanLlmState with _$DayPlanLlmState {
  const factory DayPlanLlmState.idle() = _Idle;
  const factory DayPlanLlmState.processing() = _Processing;
  const factory DayPlanLlmState.completed({
    required List<DayPlanActionResult> actions,
  }) = _Completed;
  const factory DayPlanLlmState.error({
    required String message,
  }) = _Error;
}

@riverpod
class DayPlanVoiceController extends _$DayPlanVoiceController {
  @override
  DayPlanLlmState build({required DateTime date}) {
    // Listen to ChatRecorderController for completed transcripts
    ref.listen(chatRecorderControllerProvider, (prev, next) {
      if (next.transcript != null && prev?.transcript != next.transcript) {
        // Transcript ready - process with LLM
        _processTranscript(next.transcript!);
        // Clear the transcript so it's not re-processed
        ref.read(chatRecorderControllerProvider.notifier).clearResult();
      }
    });
    return const DayPlanLlmState.idle();
  }

  Future<void> _processTranscript(String transcript) async {
    state = const DayPlanLlmState.processing();
    try {
      final result = await ref.read(dayPlanVoiceServiceProvider.notifier)
          .processTranscript(transcript: transcript, date: date);
      state = DayPlanLlmState.completed(actions: result.actions);
    } catch (e) {
      state = DayPlanLlmState.error(message: e.toString());
    }
  }

  void reset() => state = const DayPlanLlmState.idle();
}
```

**Benefits of this approach:**
- Avoids duplicating recording/transcription logic
- `ChatRecorderController` is battle-tested with proper race condition handling
- Separation of concerns: recording vs. LLM processing
- Easier to test each component independently

---

## Phase 6: UI Widget

### File: `lib/features/daily_os/ui/widgets/voice_day_plan_fab.dart`

**Option: Long-press FAB**

> **Discoverability:** Consider adding a tooltip on first use or after the user taps the FAB multiple times without long-pressing. Could store a flag in shared preferences to show a hint like "Hold to use voice input".

```dart
class VoiceDayPlanFab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);
    // Recording/transcription state from ChatRecorderController
    final recorderState = ref.watch(chatRecorderControllerProvider);
    // LLM processing state
    final llmState = ref.watch(
      dayPlanVoiceControllerProvider(date: selectedDate),
    );

    final isRecording = recorderState.status == ChatRecorderStatus.recording;
    final isTranscribing = recorderState.status == ChatRecorderStatus.processing;
    final isProcessingLlm = llmState.maybeWhen(
      processing: () => true,
      orElse: () => false,
    );

    return GestureDetector(
      onTap: () => AddBlockSheet.show(context, selectedDate),
      onLongPress: () => ref.read(chatRecorderControllerProvider.notifier).start(),
      onLongPressEnd: (_) => ref.read(chatRecorderControllerProvider.notifier).stopAndTranscribe(),
      child: FloatingActionButton(
        backgroundColor: isRecording ? Colors.red : null,
        child: switch ((isRecording, isTranscribing, isProcessingLlm)) {
          (true, _, _) => const Icon(Icons.mic),
          (_, true, _) => const CircularProgressIndicator(),
          (_, _, true) => const CircularProgressIndicator(),
          _ => const Icon(Icons.add),
        },
      ),
    );
  }
}
```

### Result Feedback

Add a listener to show snackbar feedback on completion/error:

```dart
// In VoiceDayPlanFab or parent widget
ref.listen(
  dayPlanVoiceControllerProvider(date: selectedDate),
  (prev, next) {
    final l10n = context.messages; // Use app's l10n
    next.maybeWhen(
      completed: (actions) {
        final successCount = actions.where((a) => a.success).length;
        final failCount = actions.where((a) => !a.success).length;
        final message = failCount > 0
            ? l10n.voicePlanActionsWithErrors(successCount, failCount)
            : l10n.voicePlanActionsCompleted(successCount);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
      error: (message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.voicePlanError(message)),
            backgroundColor: Colors.red,
          ),
        );
      },
      orElse: () {},
    );
  },
);
```

**Required l10n keys** (add to ALL arb files: `app_en.arb`, `app_en_GB.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_ro.arb`):

```json
// app_en.arb
"voicePlanActionsCompleted": "{count} actions completed",
"@voicePlanActionsCompleted": {
  "placeholders": {
    "count": { "type": "int", "example": "3" }
  }
},
"voicePlanActionsWithErrors": "{success} actions completed, {failed} failed",
"@voicePlanActionsWithErrors": {
  "placeholders": {
    "success": { "type": "int", "example": "2" },
    "failed": { "type": "int", "example": "1" }
  }
},
"voicePlanError": "Error: {message}",
"@voicePlanError": {
  "placeholders": {
    "message": { "type": "String", "example": "Network error" }
  }
}
```

Translations for other locales:
- **de**: `"{count} Aktionen abgeschlossen"`, `"{success} Aktionen abgeschlossen, {failed} fehlgeschlagen"`, `"Fehler: {message}"`
- **es**: `"{count} acciones completadas"`, `"{success} acciones completadas, {failed} fallaron"`, `"Error: {message}"`
- **fr**: `"{count} actions terminées"`, `"{success} actions terminées, {failed} échouées"`, `"Erreur: {message}"`
- **ro**: `"{count} acțiuni finalizate"`, `"{success} acțiuni finalizate, {failed} eșuate"`, `"Eroare: {message}"`

### Modify: `lib/features/daily_os/ui/pages/daily_os_page.dart`

Replace the current FAB with `VoiceDayPlanFab`.

---

## Critical Files to Modify

| File | Change |
|------|--------|
| `lib/features/daily_os/ui/pages/daily_os_page.dart` | Replace FAB with VoiceDayPlanFab |

---

## Reusable Components

| Component | Location | Usage |
|-----------|----------|-------|
| `UnifiedDailyOsDataController` | `lib/features/daily_os/state/unified_daily_os_data_controller.dart` | Block mutations via `addPlannedBlock`, `updatePlannedBlock`, `removePlannedBlock`, `pinTask` |
| `ConversationRepository` | `lib/features/ai/conversation/conversation_repository.dart` | Conversation management |
| `ConversationStrategy` | `lib/features/ai/conversation/conversation_manager.dart:314` | Strategy interface |
| `AudioTranscriptionService` | `lib/features/ai_chat/services/audio_transcription_service.dart` | Transcription |
| `ChatRecorderController` | `lib/features/ai_chat/ui/controllers/chat_recorder_controller.dart` | Recording + transcription with lifecycle management |
| `EntitiesCacheService` | `lib/services/entities_cache_service.dart` | Category lookup via `sortedCategories` |
| `JournalDb.getTasks()` | `lib/database/database.dart` | Task filtering by IDs, status, category |
| `Fts5Db.findMatching()` | `lib/database/fts5_db.drift` | Full-text search, returns matching UUIDs |

---

## Model Selection

For fast, responsive experience:

1. **Primary:** Mistral `mistral-small-2501` (fast, good function calling)
2. **Fallback:** Gemini `gemini-2.5-flash` (already used for transcription)

Select model that supports function calling from user's configured providers.

---

## Testing Strategy

### Unit Tests

1. **Function schema tests** (`test/features/daily_os/voice/day_plan_functions_test.dart`)
   - Validate JSON schemas parse correctly
   - Test parameter extraction
   - Test `parseTimeForDate()` with formats: "09:00", "9:00", "14:30", "9", "23"

2. **Category resolver tests** (`test/features/daily_os/voice/category_resolver_test.dart`)
   - Exact match, prefix match, contains match
   - Case insensitivity
   - No match returns null

3. **Task searcher tests** (`test/features/daily_os/voice/task_searcher_test.dart`)
   - Exact title match preferred
   - Partial match returns result
   - Filters to open/in-progress tasks only
   - Returns null when no matches

4. **Strategy tests** (`test/features/daily_os/voice/day_plan_voice_strategy_test.dart`)
   - Each function type processes correctly
   - Error handling for invalid block IDs
   - Category not found handling

5. **Service tests** (`test/features/daily_os/voice/day_plan_voice_service_test.dart`)
   - Mock transcription + inference
   - Verify correct controller methods called

### Widget Tests

1. **FAB state tests** (`test/features/daily_os/ui/widgets/voice_day_plan_fab_test.dart`)
   - Long press starts recording
   - Release stops and processes
   - Visual feedback for each state
   - Snackbar shown on completion with action count
   - Error snackbar shown on failure

### Integration Test

1. **End-to-end flow** (manual or with mocked LLM)
   - Record → Transcribe → Process → Verify plan updated

---

## Verification Checklist

1. [ ] Run `fvm flutter analyze` - all green
2. [ ] Run `fvm flutter test test/features/daily_os/voice/` - all pass
3. [ ] Manual test: Long-press FAB, speak "Add 2 hours of work at 9 AM", verify block appears
4. [ ] Manual test: Speak "Move the work block to 10", verify block moves
5. [ ] Manual test: Speak "Pin the [task name] task", verify task pinned

---

## Implementation Order

1. `day_plan_functions.dart` - Function definitions
2. `day_plan_voice_strategy.dart` - Strategy + CategoryResolver + TaskSearcher
3. `day_plan_voice_service.dart` - Orchestration
4. `day_plan_voice_controller.dart` - UI state
5. `voice_day_plan_fab.dart` - UI widget
6. Modify `daily_os_page.dart` - Integrate FAB
7. Write tests
8. Manual verification
