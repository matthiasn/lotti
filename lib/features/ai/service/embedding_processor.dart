import 'dart:typed_data';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:lotti/features/ai/state/consts.dart';

/// Callback that resolves a list of label IDs to their display names.
///
/// Used by [EmbeddingProcessor] to build the enriched "tiny template" for
/// task embeddings. The callback should filter out deleted labels and return
/// only active label names.
typedef LabelNameResolver =
    Future<List<String>> Function(
      List<String> labelIds,
    );

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
  /// When [labelNameResolver] is provided, task entities are embedded using
  /// the enriched "tiny template" (title + labels + body) instead of plain
  /// title + body. This produces higher-quality embeddings for tasks.
  ///
  /// Does NOT catch exceptions from the embedding repository — callers
  /// are responsible for error handling.
  static Future<bool> processEntity({
    required String entityId,
    required JournalDb journalDb,
    required EmbeddingStore embeddingStore,
    required OllamaEmbeddingRepository embeddingRepository,
    required String baseUrl,
    LabelNameResolver? labelNameResolver,
  }) async {
    final entity = await journalDb.journalEntityById(entityId);
    if (entity == null) return false;

    final type = EmbeddingContentExtractor.entityType(entity);
    if (type == null) return false;

    // For tasks, try the enriched template with labels first.
    final text = await _extractText(entity, labelNameResolver);
    if (text == null) return false;

    final categoryId = entity.meta.categoryId ?? '';
    final storedCategoryId = await embeddingStore.getCategoryId(entityId);
    final categoryChanged =
        storedCategoryId != null && storedCategoryId != categoryId;

    // Skip if content hash unchanged — but check for category changes.
    final hash = EmbeddingContentExtractor.contentHash(text);
    final existingHash = await embeddingStore.getContentHash(entityId);
    if (existingHash == hash) {
      if (categoryChanged) {
        await embeddingStore.moveEntityToShard(entityId, categoryId);
        if (entity is Task) {
          await embeddingStore.moveRelatedReportEmbeddings(
            entityId,
            categoryId,
          );
        }
        return true;
      }
      return false;
    }

    await _embedChunks(
      text: text,
      entityId: entityId,
      entityType: type,
      contentHash: hash,
      categoryId: categoryId,
      embeddingStore: embeddingStore,
      embeddingRepository: embeddingRepository,
      baseUrl: baseUrl,
    );

    // When both content and category changed, the task embedding is already
    // written to the correct shard by _embedChunks. But related report
    // embeddings still live in the old shard and must be moved.
    if (categoryChanged && entity is Task) {
      await embeddingStore.moveRelatedReportEmbeddings(entityId, categoryId);
    }

    return true;
  }

  /// Builds a [LabelNameResolver] backed by a cached snapshot of all label
  /// definitions from [journalDb].
  ///
  /// Filters out deleted labels. The snapshot is taken once and reused for
  /// all subsequent lookups, making this efficient for batch processing.
  static Future<LabelNameResolver> buildLabelResolver(
    JournalDb journalDb,
  ) async {
    final allLabels = await journalDb.getAllLabelDefinitions();
    final labelMap = <String, String>{};
    for (final label in allLabels) {
      if (label.deletedAt == null) {
        labelMap[label.id] = label.name;
      }
    }
    return (List<String> labelIds) async {
      return labelIds.map((id) => labelMap[id]).whereType<String>().toList();
    };
  }

  /// Extracts text for embedding, using the enriched task template when a
  /// label resolver is available for task entities.
  static Future<String?> _extractText(
    JournalEntity entity,
    LabelNameResolver? labelNameResolver,
  ) async {
    if (entity is Task && labelNameResolver != null) {
      final labelIds = entity.meta.labelIds ?? const <String>[];
      final labelNames = labelIds.isEmpty
          ? <String>[]
          : await labelNameResolver(labelIds);
      return EmbeddingContentExtractor.extractTaskText(
        title: entity.data.title,
        labelNames: labelNames,
        bodyText: entity.entryText?.plainText,
      );
    }
    return EmbeddingContentExtractor.extractText(entity);
  }

  /// Processes an agent report for embedding generation.
  ///
  /// Agent reports live in the agent database (not the journal), so this
  /// method accepts the report content directly rather than looking it up.
  ///
  /// Returns `true` if an embedding was generated and stored, `false` if
  /// skipped (too short, unchanged content hash, etc.).
  static Future<bool> processAgentReport({
    required String reportId,
    required String reportContent,
    required String taskId,
    required String categoryId,
    required String subtype,
    required EmbeddingStore embeddingStore,
    required OllamaEmbeddingRepository embeddingRepository,
    required String baseUrl,
  }) async {
    final text = reportContent.trim();
    if (text.length < kMinEmbeddingTextLength) return false;

    final hash = EmbeddingContentExtractor.contentHash(text);
    final existingHash = await embeddingStore.getContentHash(reportId);
    if (existingHash == hash) return false;

    await _embedChunks(
      text: text,
      entityId: reportId,
      entityType: kEntityTypeAgentReport,
      contentHash: hash,
      categoryId: categoryId,
      taskId: taskId,
      subtype: subtype,
      embeddingStore: embeddingStore,
      embeddingRepository: embeddingRepository,
      baseUrl: baseUrl,
    );

    return true;
  }

  /// Chunks [text] and generates embeddings for each chunk.
  ///
  /// All embeddings are generated first, then old data is deleted and new
  /// data inserted. This avoids leaving an entity with no embeddings if a
  /// transient embedding failure occurs mid-way.
  static Future<void> _embedChunks({
    required String text,
    required String entityId,
    required String entityType,
    required String contentHash,
    required EmbeddingStore embeddingStore,
    required OllamaEmbeddingRepository embeddingRepository,
    required String baseUrl,
    String categoryId = '',
    String taskId = '',
    String subtype = '',
  }) async {
    final chunks = TextChunker.chunk(text);

    // Phase 1: Generate all embeddings (network calls that can fail).
    final generated = <Float32List>[];
    for (final chunk in chunks) {
      generated.add(
        await embeddingRepository.embed(input: chunk, baseUrl: baseUrl),
      );
    }

    await embeddingStore.replaceEntityEmbeddings(
      entityId: entityId,
      entityType: entityType,
      modelId: ollamaEmbedDefaultModel,
      contentHash: contentHash,
      embeddings: generated,
      categoryId: categoryId,
      taskId: taskId,
      subtype: subtype,
    );
  }
}
