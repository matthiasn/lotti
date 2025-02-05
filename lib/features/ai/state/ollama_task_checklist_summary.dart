import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:lotti/features/ai/state/summary_checklist_state.dart';
import 'package:lotti/features/ai/state/task_markdown_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ollama_task_checklist_summary.g.dart';

@riverpod
class AiTaskChecklistSummaryController
    extends _$AiTaskChecklistSummaryController {
  final JournalDb _db = getIt<JournalDb>();

  @override
  SummaryChecklistState build({
    required String id,
  }) {
    summarizeEntry();
    return const SummaryChecklistState();
  }

  Future<void> summarizeEntry() async {
    final start = DateTime.now();
    final entry = await _db.journalEntityById(id);

    final markdown = await ref.read(
      taskMarkdownControllerProvider(id: id).future,
    );

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
        'Keep it short and succinct. '
        'If there a TODOs that are mentioned in free text for which there are '
        'no checklist items yet then create checklist items for each of these TODOs, '
        'in the best order to complete it. '
        'The checklist should be a list of items, in JSON format, as an array '
        'of objects, with each checklist item having a short title, which '
        'goes in the "title" field, and "isChecked" field of type boolean, '
        'which is checked when the checklist item is completed. ';

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
      state = state.copyWith(
        summary: buffer.toString(),
      );
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

    final exp = RegExp(
      r'(\[[^[]*\])',
      multiLine: true,
    );

    final match = exp.firstMatch(response);
    final responseList = json.decode(match?.group(0) ?? '[]') as List<dynamic>;

    final checklistItems = responseList
        .map(
          (e) => ChecklistItemData(
            // ignore: avoid_dynamic_calls
            title: e['title'] as String,
            isChecked: false,
            linkedChecklists: [],
          ),
        )
        .toList();

    state = state.copyWith(
      checklistItems: checklistItems,
    );

    debugPrint(responseList.toString());
  }
}
