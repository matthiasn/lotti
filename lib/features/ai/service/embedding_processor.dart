import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/database/embeddings_db.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/features/ai/state/consts.dart';

/// Shared embedding processing logic used by both the embedding service
/// (real-time) and the backfill controller (batch backfill).
///
/// Extracts text from a journal entity, checks for content changes via
/// SHA-256 hashing, generates an embedding via Ollama, and stores it.
class EmbeddingProcessor {
  EmbeddingProcessor._();

  /// Processes a single entity for embedding generation.
  ///
  /// Returns `true` if an embedding was generated and stored, `false` if
  /// the entity was skipped (not found, ineligible, unchanged, etc.).
  ///
  /// Does NOT catch exceptions from the embedding repository — callers
  /// are responsible for error handling.
  static Future<bool> processEntity({
    required String entityId,
    required JournalDb journalDb,
    required EmbeddingsDb embeddingsDb,
    required OllamaEmbeddingRepository embeddingRepository,
    required String baseUrl,
  }) async {
    final entity = await journalDb.journalEntityById(entityId);
    if (entity == null) return false;

    final text = EmbeddingContentExtractor.extractText(entity);
    if (text == null) return false;

    final type = EmbeddingContentExtractor.entityType(entity);
    if (type == null) return false;

    // Skip if content hash unchanged.
    final hash = EmbeddingContentExtractor.contentHash(text);
    final existingHash = embeddingsDb.getContentHash(entityId);
    if (existingHash == hash) return false;

    final embedding = await embeddingRepository.embed(
      input: text,
      baseUrl: baseUrl,
    );

    embeddingsDb.upsertEmbedding(
      entityId: entityId,
      entityType: type,
      modelId: ollamaEmbedDefaultModel,
      embedding: embedding,
      contentHash: hash,
      categoryId: entity.meta.categoryId ?? '',
    );

    return true;
  }
}
