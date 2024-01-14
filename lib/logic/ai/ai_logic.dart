import 'package:flutter/foundation.dart';
import 'package:langchain/langchain.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:ollama_dart/ollama_dart.dart';

class AiLogic {
  AiLogic() : _client = OllamaClient();

  final OllamaClient _client;

  Future<void> embed(
    JournalEntity? journalEntity, {
    String? linkedFromId,
  }) async {
    final markdown = journalEntity?.entryText?.markdown;
    final headline = switch (journalEntity) {
      Task() => journalEntity.data.title,
      _ => '',
    };

    if (markdown == null || journalEntity == null) {
      return;
    }

    final text = headline.isNotEmpty ? '#$headline\n\n$markdown' : markdown;
    debugPrint('${DateTime.now()} create Embedding document');

    final doc = Document(pageContent: text);
    debugPrint('${DateTime.now()} Embedding starting');

    final data = await _client.generateEmbedding(
      request: GenerateEmbeddingRequest(
        model: 'llama2:13b',
        prompt: doc.pageContent,
        options: const RequestOptions(
          numGpu: 24,
          embeddingOnly: true,
          useMmap: true,
        ),
      ),
    );

    debugPrint('${DateTime.now()} Embedding length ${data.embedding?.length}');
    debugPrint(journalEntity.meta.id);
  }
}
