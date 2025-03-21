import 'dart:async';
import 'dart:convert';

import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_summary_prompt.g.dart';

@riverpod
class TaskSummaryPromptController extends _$TaskSummaryPromptController {
  TaskSummaryPromptController() {
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

Create a task summary as a TLDR; for the provided task details and log entries. Imagine the
user has not been involved in the task for a long time, and you want to refresh
their memory. Summarize the task, the achieved results, and the remaining steps
that have not been completed yet, if any. Also note when the task is done. Note any 
learnings or insights that can be drawn from the task, if anything is 
significant. Talk to the user directly, instead of referring to them as "the user"
or "they". Don't start with a greeting, don't repeat the task title, get straight 
to the point. Keep it short and succinct. Assume the the task title is shown 
directly above in the UI, so starting with the title is not necessary and would 
feel redundant. While staying succinct, give the output some structure and 
organization. Use a bullet point list for the achieved results, and a numbered 
list for the remaining steps. If there are any learnings or insights that can be 
drawn from the task, include them in the output. If the task is done, end the 
output with a concluding statement.

**Task Details:**
```json
$jsonString
```
    ''';

    return prompt;
  }
}
