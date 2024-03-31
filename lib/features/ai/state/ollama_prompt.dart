import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_ollama/langchain_ollama.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
        model: 'llama2:13b',
        temperature: 1,
      ),
    );

    final prompt = PromptValue.string(promptText);

    await llm.stream(prompt).forEach((res) {
      state += res.firstOutputAsString;
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
}

final llmResponseProvider =
    NotifierProvider<LlmResponse, String>(LlmResponse.new);

class LlmResponse extends Notifier<String> {
  @override
  String build() {
    return '';
  }

  static const platform = MethodChannel('lotti/llm');

  Future<void> prompt(
    JournalEntity? journalEntity, {
    String? linkedFromId,
  }) async {
    state = '';
    final promptText = journalEntity?.entryText?.plainText;
    final docDir = await getApplicationDocumentsDirectory();
    const modelFile = 'llama-2-7b-chat.Q5_K_S.gguf';
    final modelPath = p.join(docDir.path, 'llm', modelFile);

    final result = await platform.invokeMethod(
      'prompt',
      {
        'inputText': promptText,
        'modelPath': modelPath,
      },
    );

    state = result.toString();

    await getIt<PersistenceLogic>().createTextEntry(
      EntryText(
        plainText: state,
        markdown: state,
        quill: markdownToDelta(state),
      ),
      id: uuid.v1(),
      linkedId: linkedFromId ?? journalEntity?.meta.id,
      started: DateTime.now(),
    );
  }
}
