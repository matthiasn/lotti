import 'dart:async';

import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:lotti/features/ai/state/task_markdown_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ollama_task_summary.g.dart';

class AiTaskSummaryControllerState {
  String? summary;
  List<ChecklistItemData>? checklistItems;
}

@riverpod
class AiTaskSummaryController extends _$AiTaskSummaryController {
  final JournalDb _db = getIt<JournalDb>();

  @override
  String build({
    required String id,
  }) {
    summarizeEntry();
    return '';
  }

  Future<void> summarizeEntry() async {
    final start = DateTime.now();
    final entry = await _db.journalEntityById(id);

    final markdown = await ref.read(
      taskMarkdownControllerProvider(id: id).future,
    );

    state = '';

    if (markdown == null) {
      return;
    }

    const systemMessage =
        'The prompt is a markdown document describing a task, '
        'with logbook of the completion of the task. '
        'Also, there might be checklist items with a status of either '
        'COMPLETED or TO DO. '
        'Summarize the task, the achieved results, and the remaining steps '
        'that have not been completed yet. '
        'Note any learnings or insights that can be drawn from the task, if any. '
        'If there are images, include their content in the summary. '
        'Consider that the content of the images, likely screenshots, '
        'are related to the completion of the task. '
        'Note that the logbook is in reverse chronological order. '
        'Keep it short and succinct. ';

    final buffer = StringBuffer();

    const model = 'deepseek-r1:8b'; // TODO: make configurable
    const temperature = 0.6;

    final stream = ref.read(ollamaRepositoryProvider).generate(
          markdown,
          model: model,
          system: systemMessage,
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
      systemMessage: systemMessage,
      prompt: markdown,
      thoughts: thoughts.replaceAll('<think>', ''),
      response: response,
    );

    await getIt<PersistenceLogic>().createAiResponseEntry(
      data: data,
      dateFrom: start,
      linkedId: id,
      categoryId: entry?.categoryId,
    );
  }
}
