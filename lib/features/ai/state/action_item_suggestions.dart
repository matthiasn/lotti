import 'dart:async';
import 'dart:convert';

import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'action_item_suggestions.g.dart';

@riverpod
class ActionItemSuggestionsController
    extends _$ActionItemSuggestionsController {
  final JournalDb _db = getIt<JournalDb>();

  @override
  String build({
    required String id,
  }) {
    getActionItemSuggestion();
    return '';
  }

  Future<void> getActionItemSuggestion() async {
    final start = DateTime.now();
    final entry = await _db.journalEntityById(id);

    if (entry is! Task) {
      return;
    }

    final task = entry;

    final timeSpent = ref
            .read(taskProgressControllerProvider(id: task.id))
            .valueOrNull
            ?.progress ??
        Duration.zero;

    final logEntries = <AiInputLogEntryObject>[];
    final linkedEntities = await _db.getLinkedEntities(id);

    for (final linked in linkedEntities) {
      if (linked is JournalEntry ||
          linked is JournalImage ||
          linked is JournalAudio) {
        logEntries.add(
          AiInputLogEntryObject(
            creationTimestamp: linked.meta.dateFrom,
            loggedDuration: entryDuration(linked),
            text: linked.entryText?.plainText ?? '',
          ),
        );
      }
    }

    final checklistIds = task.data.checklistIds ?? [];

    final checklistItems = <ChecklistItemData>[];
    for (final checklistId in checklistIds) {
      final checklist = await _db.journalEntityById(checklistId);
      if (checklist != null && checklist is Checklist) {
        final checklistItemIds = checklist.data.linkedChecklistItems;
        for (final checklistItemId in checklistItemIds) {
          final checklistItem = await _db.journalEntityById(checklistItemId);
          if (checklistItem != null && checklistItem is ChecklistItem) {
            final data = checklistItem.data.copyWith(id: checklistItemId);
            checklistItems.add(data);
          }
        }
      }
    }

    final actionItems = checklistItems
        .map(
          (item) => AiActionItem(
            title: item.title,
            completed: item.isChecked,
          ),
        )
        .toList();

    final aiInput = AiInputTaskObject(
      title: task.data.title,
      status: task.data.status.map(
        open: (_) => 'OPEN',
        groomed: (_) => 'GROOMED',
        started: (_) => 'STARTED',
        inProgress: (_) => 'IN PROGRESS',
        blocked: (_) => 'BLOCKED',
        onHold: (_) => 'ON HOLD',
        done: (_) => 'DONE',
        rejected: (_) => 'REJECTED',
      ),
      creationDate: start,
      actionItems: actionItems,
      logEntries: logEntries,
      estimatedDuration: task.data.estimate ?? Duration.zero,
      timeSpent: timeSpent,
    );

    const encoder = JsonEncoder.withIndent('    ');
    final jsonString = encoder.convert(aiInput);

    final prompt = '''
**Prompt:**

"Based on the provided task details and log entries, identify potential action items that are mentioned in
the text of the logs but have not yet been captured as existing action items. These suggestions should be
formatted as a list of new `AiInputActionItemObject` instances, each containing a title and completion
status. Ensure that only actions not already listed under `actionItems` are included in your suggestions.
Provide these suggested action items in JSON format, adhering to the structure defined by the given classes."

**Example Response:**

```json
[
  {
    "title": "Review project documentation",
    "completed": false
  },
  {
    "title": "Schedule team meeting for next week",
    "completed": false
  }
]
```

**Task Details:**
```json
$jsonString
```

Provide these suggested action items in JSON format, adhering to the structure 
defined by the given classes.
Double check that the returned JSON ONLY contains action items that are not 
already listed under `actionItems` array in the task details. Do not simply
return the example response, but the open action items you have found. If there 
are none, return an empty array. Double check the items you want to return. If 
any is very similar to an item already listed in the in actionItems array of the 
task details, then remove it from the response. 

**Example Response:**

```json
[
  {
    "title": "Review project documentation",
    "completed": false
  },
  {
    "title": "Schedule team meeting for next week",
    "completed": true
  }
]
```
    ''';

    final buffer = StringBuffer();

    const model = 'deepseek-r1:14b'; // TODO: make configurable
    const temperature = 0.6;

    final stream = ref.read(ollamaRepositoryProvider).generate(
          prompt,
          model: model,
          temperature: temperature,
        );

    await for (final chunk in stream) {
      buffer.write(chunk.text);
      state = buffer.toString();
    }

    final completeResponse = buffer.toString();
    final [thoughts, response] = completeResponse.split('</think>');

    final exp = RegExp(r'\[(.|\n)*\]', multiLine: true);
    final match = exp.firstMatch(response)?.group(0) ?? '[]';
    final actionItemsJson = '{"items": $match}';
    final decoded = jsonDecode(actionItemsJson) as Map<String, dynamic>;
    final suggestedActionItems = AiInputActionItemsList.fromJson(decoded).items;

    final data = AiResponseData(
      model: model,
      temperature: temperature,
      systemMessage: '',
      prompt: prompt,
      thoughts: thoughts,
      response: response,
      suggestedActionItems: suggestedActionItems,
      type: 'ActionItemSuggestions',
    );

    await getIt<PersistenceLogic>().createAiResponseEntry(
      data: data,
      dateFrom: start,
      linkedId: id,
      categoryId: entry.categoryId,
    );
  }
}
