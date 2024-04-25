import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_chroma/langchain_chroma.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/platform.dart';
import 'package:ollama_dart/ollama_dart.dart';

class AiLogic {
  AiLogic() {
    loadDb();
  }

  Future<void> loadDb() async {
    _vectorStore = MemoryVectorStore(
      embeddings: MyLlamaEmbedding(),
      initialMemoryVectors: await loadVectors(),
    );

    _chroma = Chroma(
      collectionName: 'llama3-embeddings2',
      embeddings: MyLlamaEmbedding(),
      collectionMetadata: {
        'hnsw:space': 'cosine',
      },
    );
  }

  late final Chroma _chroma;
  late final MemoryVectorStore _vectorStore;

  Future<void> embed(
    JournalEntity? journalEntity, {
    String? linkedFromId,
  }) async {
    final plainText = journalEntity?.entryText?.plainText;
    final headline = switch (journalEntity) {
      Task() => journalEntity.data.title,
      _ => '',
    };

    if (isMobile ||
        plainText == null ||
        plainText.isEmpty ||
        journalEntity == null) {
      return;
    }

    final text = headline.isNotEmpty ? '#$headline\n\n$plainText' : plainText;
    final id = journalEntity.meta.id;
    final document = Document(
      pageContent: text,
      id: id,
    );
    await _vectorStore.delete(ids: [id]);
    await _vectorStore.addDocuments(documents: [document]);
    await persist();

    // await _chroma.delete(ids: [id]);
    // await _chroma.addDocuments(documents: [document]);
    // await search();
  }

  Future<void> search(String query) async {
    final res = await _vectorStore.similaritySearchWithScores(
      query: query,
      config: const ChromaSimilaritySearch(
        k: 10,
      ),
    );
    debugPrint('\nSearch result');
    for (final (doc, score) in res) {
      debugPrint('$score ${doc.pageContent}');
    }
    debugPrint('\n');
  }

  String getFilePath() => '${getIt<Directory>().path}/langchain/vectors.json';

  Future<void> persist() async {
    final vectors = _vectorStore.memoryVectors;
    final json = jsonEncode(vectors.map((e) => e.toMap()).toList());
    final file = await File(getFilePath()).create(recursive: true);
    await file.writeAsString(json);
  }

  Future<List<MemoryVector>?> loadVectors() async {
    final file = File(getFilePath());
    if (!file.existsSync()) {
      return null;
    }
    final json = await file.readAsString();
    final docs = jsonDecode(json) as List<dynamic>;

    return docs.map((e) {
      final map = e as Map<String, dynamic>;
      final embedding = map['embedding'] as List<dynamic>;
      return MemoryVector.fromMap({
        'document': map['document'],
        'embedding': embedding.map((e) => double.parse(e.toString())).toList(),
      });
    }).toList();
  }
}

class MyLlamaEmbedding implements Embeddings {
  MyLlamaEmbedding();

  final client = OllamaClient();

  @override
  Future<List<List<double>>> embedDocuments(List<Document> documents) async {
    final embeddings = <List<double>>[];

    for (final doc in documents) {
      final pageContent = doc.pageContent;
      if (pageContent.length > 10) {
        final embedding = await createEmbedding(doc.pageContent);
        if (embedding != null) {
          embeddings.add(embedding);
        }
      }
    }
    return embeddings;
  }

  @override
  Future<List<double>> embedQuery(String query) async {
    return await createEmbedding(query) ?? [];
  }

  Future<List<double>?> createEmbedding(String text) async {
    debugPrint('${DateTime.now()} Embedding started');
    final embeddingResponse = await client.generateEmbedding(
      request: GenerateEmbeddingRequest(
        model: 'llama3:8b',
        prompt: text,
        options: const RequestOptions(
          useMmap: true,
        ),
      ),
    );
    final embedding = embeddingResponse.embedding;
    debugPrint('${DateTime.now()} Embedding length ${embedding?.length}');
    return embedding;
  }
}
