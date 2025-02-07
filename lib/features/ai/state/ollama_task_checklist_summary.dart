import 'dart:async';
import 'dart:convert';

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
        'The prompt is a markdown document describing a task, with the '
        'logbook of the completion of the task, including transcripts of '
        'audio recordings, and images, for example screenshots. '
        'Also, there is a array of already defined and tracked checklist items, '
        'as JSON. Your job is to find new TODOs that are not mentioned here yet, '
        'but only in the logbook of the task. '
        'This may be empty if the task has no checklist items yet. '
        'Summarize the task and the achieved results, and the remaining steps '
        'that have not been completed yet. '
        'Note any learnings or insights that can be drawn from the task, if any. '
        'Note that the logbook is in reverse chronological order. '
        'Keep it short and succinct. '
        'At the end of the response, add an unordered markdown list of '
        'TODOs/checklist items that are new and not already tracked, where '
        'each item is prefixed with the String "TODO: ". ';

    final buffer = StringBuffer();

    const model = 'deepseek-r1:14b'; // TODO: make configurable
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
    print('match $match');
    final responseList = json.decode(match?.group(0) ?? '[]') as List<dynamic>;
    print('responseList $responseList');

    final checklistItems = responseList.map((e) {
      print(e);
      return ChecklistItemData(
        // ignore: avoid_dynamic_calls
        title: e['title'] as String,
        isChecked: false,
        linkedChecklists: [],
      );
    }).toList();

    state = state.copyWith(
      checklistItems: checklistItems,
    );
  }
}
