import 'dart:async';
import 'dart:convert';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_summary_controller.g.dart';

@riverpod
class TaskSummaryController extends _$TaskSummaryController {
  @override
  String build({
    required String id,
  }) {
    ref.cacheFor(inferenceStateCacheDuration);
    Future<void>.delayed(const Duration(milliseconds: 10)).then((_) {
      getTaskSummary();
    });
    return '';
  }

  Future<void> getTaskSummary() async {
    final start = DateTime.now();
    final entry = await ref.read(aiInputRepositoryProvider).getEntity(id);

    final inferenceStatusNotifier = ref.read(
      inferenceStatusControllerProvider(
        id: id,
        aiResponseType: taskSummary,
      ).notifier,
    );

    getIt<LoggingService>().captureEvent(
      'Starting task summary for $id',
      subDomain: 'getTaskSummary',
      domain: 'TaskSummaryController',
    );

    if (entry is! Task) {
      return;
    }

    try {
      final aiInput = await ref.read(aiInputRepositoryProvider).generate(id);
      inferenceStatusNotifier.setStatus(InferenceStatus.running);

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
      inferenceStatusNotifier.setStatus(InferenceStatus.idle);
    } catch (e, stackTrace) {
      inferenceStatusNotifier.setStatus(InferenceStatus.error);
      getIt<LoggingService>().captureException(
        e,
        domain: 'TaskSummaryController',
        subDomain: 'getTaskSummary',
        stackTrace: stackTrace,
      );
    }
  }
}
