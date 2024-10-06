import 'dart:convert';

import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_ollama/langchain_ollama.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/file_utils.dart';

final aiResponseProvider = NotifierProvider<AiResponse, String>(AiResponse.new);

class AiResponse extends Notifier<String> {
  @override
  String build() {
    return '';
  }

  Future<void> prompt(
    JournalEntity? journalEntity, {
    String? linkedFromId,
  }) async {
    state = '';
    final promptText = journalEntity?.entryText?.plainText;

    if (promptText == null || journalEntity == null) {
      return;
    }
    final llm = Ollama(
      defaultOptions: const OllamaOptions(
        model: 'llama3:8b',
        temperature: 1,
      ),
    );

    final prompt = PromptValue.string(promptText);

    await llm.stream(prompt).forEach((res) {
      state += res.outputAsString;
    });

    await getIt<PersistenceLogic>().createTextEntry(
      EntryText(
        plainText: state,
        markdown: state,
        quill: markdownToDelta(state),
      ),
      id: uuid.v1(),
      linkedId: linkedFromId ?? journalEntity.meta.id,
      started: DateTime.now(),
    );
  }

  Future<void> createChecklistItems(
    JournalEntity? journalEntity, {
    String? linkedFromId,
  }) async {
    state = '';
    final promptText = journalEntity?.entryText?.plainText;

    if (promptText == null || journalEntity == null) {
      return;
    }
    final llm = Ollama(
      defaultOptions: const OllamaOptions(
        model: 'llama3:8b',
        temperature: 3,
        system:
            'Assume that the input describing a task that needs to be completed. '
            'Create a checklist for that task, in the best order to complete it. '
            'The checklist should be a list of items, in JSON format, as an array '
            'of objects, with each checklist item having a short title, which '
            'goes in the "title" field. '
            'Come up with up to 10 checklist items. ',
      ),
    );

    final prompt = PromptValue.string(promptText);

    await llm.stream(prompt).forEach((res) {
      state += res.outputAsString;
    });

    final exp = RegExp(
      r'(\[[^[]*\])',
      multiLine: true,
    );
    final match = exp.firstMatch(state);
    final map = json.decode(match?.group(0) ?? '[]');

    debugPrint(map.toString() ?? 'No match');
  }
}
