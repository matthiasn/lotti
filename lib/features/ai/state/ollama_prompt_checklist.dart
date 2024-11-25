import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_ollama/langchain_ollama.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';

final aiChecklistResponseProvider =
    NotifierProvider<AiChecklistResponse, List<ChecklistItemData>>(
  AiChecklistResponse.new,
);

class AiChecklistResponse extends Notifier<List<ChecklistItemData>> {
  @override
  List<ChecklistItemData> build() {
    return [];
  }

  Future<void> createChecklistItems(
    JournalEntity? journalEntity, {
    String? linkedFromId,
  }) async {
    state = [];
    final promptText = journalEntity?.entryText?.plainText;

    if (promptText == null || journalEntity == null) {
      return;
    }

    var response = '';

    final llm = Ollama(
      defaultOptions: const OllamaOptions(
        model: 'llama3.1',
        temperature: 3,
        system:
            'Assume that the input is describing a task that needs to be completed. '
            'Create a checklist for that task, in the best order to complete it. '
            'The checklist should be a list of items, in JSON format, as an array '
            'of objects, with each checklist item having a short title, which '
            'goes in the "title" field. '
            'Come up with up to 10 checklist items.',
      ),
    );

    final prompt = PromptValue.string(promptText);

    await llm.stream(prompt).forEach((res) {
      response += res.outputAsString;
    });

    final exp = RegExp(
      r'(\[[^[]*\])',
      multiLine: true,
    );

    debugPrint(response);

    final match = exp.firstMatch(response);
    final responseList = json.decode(match?.group(0) ?? '[]') as List<dynamic>;

    state = responseList
        .map(
          (e) => ChecklistItemData(
            // ignore: avoid_dynamic_calls
            title: e['title'] as String,
            isChecked: false,
            linkedChecklists: [],
          ),
        )
        .toList();

    debugPrint(responseList.toString());
  }
}
