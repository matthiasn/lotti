import 'package:flutter/foundation.dart';
import 'package:langchain/langchain.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/platform.dart';
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

    if (isMobile || markdown == null || journalEntity == null) {
      return;
    }

    final text = headline.isNotEmpty ? '#$headline\n\n$markdown' : markdown;
    debugPrint('${DateTime.now()} Embedding started');
    final data = await _client.generateEmbedding(
      request: GenerateEmbeddingRequest(
        model: 'llama3:8b',
        prompt: Document(pageContent: text).pageContent,
        options: const RequestOptions(
          useMmap: true,
        ),
      ),
    );

    debugPrint('${DateTime.now()} Embedding length ${data.embedding?.length}');
    debugPrint(journalEntity.meta.id);
  }
}
