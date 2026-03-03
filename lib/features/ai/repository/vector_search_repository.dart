import 'dart:typed_data';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/database/embeddings_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/services/dev_logger.dart';

/// Result of a vector search, including timing information.
class VectorSearchResult {
  VectorSearchResult({
    required this.tasks,
    required this.elapsed,
  });

  final List<JournalEntity> tasks;
  final Duration elapsed;
}

/// Orchestrates vector-based semantic search for tasks.
///
/// Flow:
/// 1. Resolve Ollama base URL from AI config
/// 2. Embed the query text via [OllamaEmbeddingRepository]
/// 3. Search the vector database via [EmbeddingsDb.search]
/// 4. Resolve results to parent tasks (deduplicating by ID)
class VectorSearchRepository {
  VectorSearchRepository({
    required EmbeddingsDb embeddingsDb,
    required OllamaEmbeddingRepository embeddingRepository,
    required JournalDb journalDb,
    required AiConfigRepository aiConfigRepository,
  })  : _embeddingsDb = embeddingsDb,
        _embeddingRepository = embeddingRepository,
        _journalDb = journalDb,
        _aiConfigRepository = aiConfigRepository;

  final EmbeddingsDb _embeddingsDb;
  final OllamaEmbeddingRepository _embeddingRepository;
  final JournalDb _journalDb;
  final AiConfigRepository _aiConfigRepository;

  /// Searches for tasks semantically related to [query].
  ///
  /// Returns up to [k] unique tasks ordered by embedding distance.
  /// Non-task results are resolved to their parent task via linked entries.
  Future<VectorSearchResult> searchRelatedTasks({
    required String query,
    int k = 20,
    Set<String>? categoryIds,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (k <= 0) {
      stopwatch.stop();
      return VectorSearchResult(tasks: [], elapsed: stopwatch.elapsed);
    }

    final baseUrl = await _aiConfigRepository.resolveOllamaBaseUrl();
    if (baseUrl == null) {
      stopwatch.stop();
      return VectorSearchResult(tasks: [], elapsed: stopwatch.elapsed);
    }

    final Float32List queryVector;
    try {
      queryVector = await _embeddingRepository.embed(
        input: query,
        baseUrl: baseUrl,
      );
    } on Exception catch (e) {
      DevLogger.warning(
        name: 'VectorSearchRepository',
        message: 'Failed to embed query: $e',
      );
      stopwatch.stop();
      return VectorSearchResult(tasks: [], elapsed: stopwatch.elapsed);
    }

    final searchResults = _embeddingsDb.search(
      queryVector: queryVector,
      k: k,
      categoryIds: categoryIds,
    );

    final tasks = await _resolveToTasks(searchResults);

    stopwatch.stop();
    return VectorSearchResult(tasks: tasks, elapsed: stopwatch.elapsed);
  }

  /// Resolves search results to unique tasks, preserving distance ordering.
  ///
  /// If a result is already a Task, it is fetched directly. Otherwise, the
  /// parent task is resolved via linked entries. Both direct and linked
  /// entities are bulk-fetched to avoid N+1 queries.
  Future<List<JournalEntity>> _resolveToTasks(
    List<EmbeddingSearchResult> results,
  ) async {
    final seenIds = <String>{};
    final tasks = <JournalEntity>[];

    // 1. Bulk-fetch all direct task entities in one query.
    final directTaskIds = results
        .where((r) => r.entityType == kEntityTypeTask)
        .map((r) => r.entityId)
        .toSet();
    final directEntities = <String, JournalEntity>{
      for (final e in await _journalDb.getJournalEntitiesForIds(directTaskIds))
        e.meta.id: e,
    };

    // 2. Batch-fetch linked entries for all non-task results.
    final nonTaskIds =
        results.where((r) => r.entityType != kEntityTypeTask).toList();
    final childToParentIds = <String, List<String>>{};
    if (nonTaskIds.isNotEmpty) {
      final links = await _journalDb
          .linksForIds(nonTaskIds.map((r) => r.entityId).toList())
          .get();
      for (final link in links) {
        (childToParentIds[link.toId] ??= []).add(link.fromId);
      }
    }

    // 3. Bulk-fetch all parent entities referenced by links.
    final allParentIds = childToParentIds.values.expand((ids) => ids).toSet();
    final parentEntities = allParentIds.isNotEmpty
        ? <String, JournalEntity>{
            for (final e
                in await _journalDb.getJournalEntitiesForIds(allParentIds))
              e.meta.id: e,
          }
        : <String, JournalEntity>{};

    // 4. Iterate original ranked results to preserve global ordering.
    for (final result in results) {
      if (result.entityType == kEntityTypeTask) {
        final entity = directEntities[result.entityId];
        if (entity is Task && seenIds.add(entity.meta.id)) {
          tasks.add(entity);
        }
        continue;
      }

      final parentIds = childToParentIds[result.entityId] ?? [];
      for (final parentId in parentIds) {
        final entity = parentEntities[parentId];
        if (entity is Task && seenIds.add(entity.meta.id)) {
          tasks.add(entity);
        }
      }
    }

    return tasks;
  }
}
