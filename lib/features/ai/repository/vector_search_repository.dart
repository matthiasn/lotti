import 'dart:typed_data';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
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
  }) async {
    final stopwatch = Stopwatch()..start();

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
    );

    final tasks = await _resolveToTasks(searchResults);

    stopwatch.stop();
    return VectorSearchResult(tasks: tasks, elapsed: stopwatch.elapsed);
  }

  /// Resolves search results to unique tasks, preserving distance ordering.
  ///
  /// If a result is already a Task, it is fetched directly. Otherwise, the
  /// parent task is resolved via linked entries.
  ///
  /// Direct task IDs are bulk-fetched in a single query to avoid N+1.
  Future<List<JournalEntity>> _resolveToTasks(
    List<EmbeddingSearchResult> results,
  ) async {
    final seenIds = <String>{};
    final tasks = <JournalEntity>[];

    // Separate direct task results from non-task results.
    final directTaskIds = <String>[];
    final nonTaskResults = <EmbeddingSearchResult>[];

    for (final result in results) {
      if (result.entityType == kEntityTypeTask) {
        if (seenIds.add(result.entityId)) {
          directTaskIds.add(result.entityId);
        }
      } else {
        nonTaskResults.add(result);
      }
    }

    // Bulk-fetch all direct task entities in one query.
    if (directTaskIds.isNotEmpty) {
      final entities =
          await _journalDb.getJournalEntitiesForIds(directTaskIds.toSet());
      final entityMap = {for (final e in entities) e.meta.id: e};
      // Preserve distance ordering from results.
      for (final id in directTaskIds) {
        final entity = entityMap[id];
        if (entity != null) {
          tasks.add(entity);
        }
      }
    }

    // Resolve non-task results to parent tasks via linked entries.
    for (final result in nonTaskResults) {
      final linkedEntities =
          await _journalDb.linkedToJournalEntities(result.entityId).get();
      for (final dbEntity in linkedEntities) {
        final entity = fromDbEntity(dbEntity);
        if (entity is Task && seenIds.add(entity.meta.id)) {
          tasks.add(entity);
        }
      }
    }

    return tasks;
  }
}
