import 'dart:async';
import 'dart:convert';

import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'action_item_suggestions_prompt.g.dart';

@riverpod
class ActionItemSuggestionsPromptController
    extends _$ActionItemSuggestionsPromptController {
  ActionItemSuggestionsPromptController() {
    listen();
  }

  final watchedIds = <String>{};
  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();

  void listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((affectedIds) async {
      if (affectedIds.intersection(watchedIds).isNotEmpty) {
        final prompt = await _buildPrompt(id: id);
        state = AsyncData(prompt);
      }
    });
  }

  @override
  Future<String?> build({
    required String id,
  }) async {
    ref.onDispose(() => _updateSubscription?.cancel());

    final links = await ref.watch(journalRepositoryProvider).getLinksFromId(id);
    watchedIds
      ..add(id)
      ..addAll(links.map((link) => link.toId));

    final prompt = await _buildPrompt(id: id);
    return prompt;
  }

  Future<String?> _buildPrompt({required String id}) async {
    final repository = ref.read(aiInputRepositoryProvider);
    final aiInput = await repository.generate(id);

    if (aiInput == null) {
      return null;
    }

    const encoder = JsonEncoder.withIndent('    ');
    final jsonString = encoder.convert(aiInput);

    final prompt = '''
**Prompt:**

"Based on the provided task details and log entries, identify potential action items that are mentioned in
the text of the logs but have not yet been captured as existing action items. These suggestions should be
formatted as a list of new `AiInputActionItemObject` instances, each containing a title and completion
status. Ensure that only actions not already listed under `actionItems` are included in your suggestions.
Provide these suggested action items in JSON format, adhering to the structure defined by the given classes."

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

    return prompt;
  }
}
