import 'dart:async';

import 'package:delta_markdown/delta_markdown.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_ollama/langchain_ollama.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/file_utils.dart';

class AiService {
  AiService();

  Future<void> prompt(JournalEntity? journalEntity) async {
    final promptText = journalEntity?.entryText?.plainText;

    if (promptText == null || journalEntity == null) {
      return;
    }
    final llm = Ollama(
      defaultOptions: const OllamaOptions(
        model: 'llama2:13b',
        temperature: 1,
      ),
    );

    final prompt = PromptValue.string(promptText);
    final result = await llm.invoke(prompt);
    final plainText = result.firstOutputAsString;

    await getIt<PersistenceLogic>().createTextEntry(
      EntryText(
        plainText: plainText,
        markdown: plainText,
        quill: markdownToDelta(plainText),
      ),
      id: uuid.v1(),
      linkedId: journalEntity.meta.id,
      started: DateTime.now(),
    );
  }
}
