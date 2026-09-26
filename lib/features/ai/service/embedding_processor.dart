import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/get_it.dart';

/// Callback that resolves a list of label IDs to their display names.
///
/// Used by [EmbeddingProcessor] to build the enriched "tiny template" for
/// task embeddings. The callback should filter out deleted labels and return
/// only active label names.
typedef LabelNameResolver =
    Future<List<String>> Function(
      List<String> labelIds,
    );

/// Shared embedding processing logic used by the embedding service
/// (real-time), the backfill controller (batch backfill) and the task
/// agent's report writer.
///
/// Extracts text from a journal entity, checks for content changes via
/// SHA-256 hashing, generates an embedding via Ollama, and stores it.
///
/// **One run per entity at a time.** These callers run concurrently and do
/// not know about each other, and a run spans a network call. Each run for
/// an entity therefore holds that entity's lock from its journal read to its
/// store write, so a run that read an older version can never write after a
/// run that read a newer one; the model is `specs/tla/EmbeddingFreshness.tla`.
abstract final class EmbeddingProcessor {
  /// The tail of each entity's queue of runs, removed when it drains.
  static final Map<String, Future<void>> _tails = {};

  /// Runs [action] once every earlier run for [key] has finished.
  static Future<T> _serialized<T>(
    String key,
    Future<T> Function() action,
  ) async {
    final previous = _tails[key] ?? Future<void>.value();
    final done = Completer<void>();
    final tail = done.future;
    _tails[key] = tail;
    await previous;
    try {
      return await action();
    } finally {
      done.complete();
      if (identical(_tails[key], tail)) {
        final _ = _tails.remove(key);
      }
    }
  }

  /// Processes a single entity for embedding generation.
  ///
  /// Returns `true` if an embedding was generated and stored, or moved to
  /// the entity's new category, and `false` otherwise (not found, deleted,
  /// ineligible, unchanged, etc.).
  ///
  /// An entity that is gone — deleted, or with text under
  /// [kMinEmbeddingTextLength] — has its stored vectors deleted, so search
  /// can no longer find it by text it no longer has. A task's agent-report
  /// embeddings are moved to the task's category on every run, whether or
  /// not the task has a vector of its own.
  ///
  /// When [labelNameResolver] is provided, task entities are embedded using
  /// the enriched "tiny template" (title + labels + body) instead of plain
  /// title + body. This produces higher-quality embeddings for tasks.
  ///
  /// Serialized per entity with every other run of this processor.
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
  }) => _serialized(entityId, () async {
    final entity = await journalDb.journalEntityById(entityId);
    if (entity == null) {
      // Deleted (the read hides soft-deleted rows) or never stored.
      await embeddingStore.deleteEntityEmbeddings(entityId);
      return false;
    }

    final type = EmbeddingContentExtractor.entityType(entity);
    if (type == null) return false;

    final categoryId = entity.meta.categoryId ?? '';

    // For tasks, try the enriched template with labels first.
    final text = await _extractText(entity, labelNameResolver);
    if (text == null) {
      await embeddingStore.deleteEntityEmbeddings(entityId);
      await _moveReports(entity, categoryId, embeddingStore);
      return false;
    }

    final storedCategoryId = await embeddingStore.getCategoryId(entityId);
    final categoryChanged =
        storedCategoryId != null && storedCategoryId != categoryId;

    // Skip if content hash unchanged — but check for category changes.
    final hash = EmbeddingContentExtractor.contentHash(text);
    final existingHash = await embeddingStore.getContentHash(entityId);
    if (existingHash == hash) {
      if (categoryChanged) {
        await embeddingStore.moveEntityToShard(entityId, categoryId);
      }
      await _moveReports(entity, categoryId, embeddingStore);
      return categoryChanged;
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
    await _moveReports(entity, categoryId, embeddingStore);

    return true;
  });

  /// Moves a task's agent-report embeddings into [categoryId], the
  /// category just read for it; a no-op for reports already there and for
  /// any other entity.
  static Future<void> _moveReports(
    JournalEntity entity,
    String categoryId,
    EmbeddingStore embeddingStore,
  ) async {
    if (entity is! Task) return;
    await embeddingStore.moveRelatedReportEmbeddings(entity.id, categoryId);
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
  /// The report is stored in the category of its task [taskId], read from
  /// [journalDb] (the default shard when the task is gone).
  ///
  /// Runs under the task's lock, the one [processEntity] holds while it
  /// moves the task's reports: a recategorisation of the task either lands
  /// before this run reads the category, or is processed after the report
  /// is stored and moves it along.
  ///
  /// Returns `true` if an embedding was generated and stored, `false` if
  /// skipped (too short, unchanged content hash, etc.).
  static Future<bool> processAgentReport({
    required String reportId,
    required String reportContent,
    required String taskId,
    required String subtype,
    required JournalDb journalDb,
    required EmbeddingStore embeddingStore,
    required OllamaEmbeddingRepository embeddingRepository,
    required String baseUrl,
  }) => _serialized(taskId, () async {
    final text = reportContent.trim();
    if (text.length < kMinEmbeddingTextLength) return false;

    final hash = EmbeddingContentExtractor.contentHash(text);
    final existingHash = await embeddingStore.getContentHash(reportId);
    if (existingHash == hash) return false;

    final task = await journalDb.journalEntityById(taskId);
    final categoryId = task?.meta.categoryId ?? '';

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
  });

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
    final capture = getIt.isRegistered<AiInteractionCapture>()
        ? getIt<AiInteractionCapture>()
        : null;
    final output = AiArtifactReference(
      type: AiArtifactType.embeddingVector,
      id: entityId,
      subId: contentHash,
    );
    final attributionSession = await capture?.beginSession(
      workType: AiWorkType.embeddingIndexing,
      trigger: const AiTriggerSnapshot(type: AiTriggerType.automatic),
      automationId: 'automation:embedding-indexer',
      automationDisplayName: 'Embedding indexer',
      intendedOutputs: [output],
      taskId: taskId.isEmpty ? null : taskId,
      categoryId: categoryId.isEmpty ? null : categoryId,
    );
    var completionStarted = false;

    try {
      // Phase 1: Generate all embeddings (network calls that can fail).
      final generated = <Float32List>[];
      for (final chunk in chunks) {
        Future<Float32List> invoke() => embeddingRepository.embed(
          input: chunk,
          baseUrl: baseUrl,
        );
        final embedding = capture == null
            ? await invoke()
            : await capture.captureUnary(
                workType: AiWorkType.embeddingIndexing,
                interactionKind: AiInteractionKind.embedding,
                responseType: AiConsumptionResponseType.embeddingIndexing,
                providerType: InferenceProviderType.ollama,
                modelId: ollamaEmbedDefaultModel,
                requestText: chunk,
                invoke: invoke,
                responseText: (value) =>
                    sha256.convert(value.buffer.asUint8List()).toString(),
                interactionContext: AiCapturedContext(
                  entryId: entityId,
                ),
                existingSession: attributionSession,
                terminalizeSuccess: false,
                terminalizeFailure: false,
                triggerType: AiTriggerType.automatic,
                automationId: 'automation:embedding-indexer',
                automationDisplayName: 'Embedding indexer',
                taskId: taskId.isEmpty ? null : taskId,
                categoryId: categoryId.isEmpty ? null : categoryId,
              );
        generated.add(embedding);
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
      if (attributionSession != null) {
        completionStarted = true;
        await capture!.completeSession(
          session: attributionSession,
          outputs: [output],
        );
      }
    } on Object catch (error) {
      if (attributionSession != null && !completionStarted) {
        await capture!.completeSession(
          session: attributionSession,
          outputs: const [],
          status: AiWorkStatus.failed,
          errorCode: error.runtimeType.toString(),
        );
      }
      rethrow;
    }
  }
}
