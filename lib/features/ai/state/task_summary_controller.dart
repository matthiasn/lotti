import 'dart:async';
import 'dart:convert';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_summary_controller.g.dart';

@riverpod
class TaskSummaryController extends _$TaskSummaryController {
  @override
  String build({
    required String id,
  }) {
    getActionItemSuggestion();
    return '';
  }

  Future<void> getActionItemSuggestion() async {
    final start = DateTime.now();
    final entry = await ref.read(aiInputRepositoryProvider).getEntity(id);

    if (entry is! Task) {
      return;
    }

    final aiInput = await ref.read(aiInputRepositoryProvider).generate(id);
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
or "they". Don't start with a greeting, get straight to the point. Keep it short 
and succinct.

**Task Details:**
```json
$jsonString
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

    final data = AiResponseData(
      model: model,
      temperature: temperature,
      systemMessage: '',
      prompt: prompt,
      thoughts: thoughts,
      response: response,
      type: 'TaskSummary',
    );

    await ref.read(aiInputRepositoryProvider).createAiResponseEntry(
          data: data,
          start: start,
          linkedId: id,
          categoryId: entry.categoryId,
        );
  }
}
