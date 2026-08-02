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

/// Revalidates whether generated embeddings still belong to current work.
typedef EmbeddingWriteGuard = FutureOr<bool> Function();

/// Shared embedding processing logic used by both the embedding service
/// (real-time) and the backfill controller (batch backfill).
///
/// Extracts text from a journal entity, checks for content changes via
/// SHA-256 hashing, generates an embedding via Ollama, and stores it.
class EmbeddingProcessor {
  EmbeddingProcessor._();

  static final _agentReportWriteGate = _AgentReportWriteGate();

  /// Prevents new report-vector writes for [agentId] and waits until every
  /// write that already entered the processor has finished.
  static Future<void> quiesceAgentReportWrites(String agentId) =>
      _agentReportWriteGate.quiesce(agentId);

  /// Reopens report-vector writes after a hard-delete attempt has finished.
  static void resumeAgentReportWrites(String agentId) =>
      _agentReportWriteGate.resume(agentId);

  /// Processes a single entity for embedding generation.
  ///
  /// Returns `true` if an embedding was generated and stored, `false` if
  /// the entity was skipped (not found, ineligible, unchanged, etc.).
  ///
  /// When [labelNameResolver] is provided, task entities are embedded using
  /// the enriched "tiny template" (title + labels + body) instead of plain
  /// title + body. This produces higher-quality embeddings for tasks.
  /// When [writeGuard] is provided, it is checked immediately before a shard
  /// move or generated-vector replacement so stale asynchronous work cannot
  /// write after its caller disabled or superseded it.
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
    EmbeddingWriteGuard? writeGuard,
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
        if (writeGuard != null && !await writeGuard()) return false;
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

    final didEmbed = await _embedChunks(
      text: text,
      entityId: entityId,
      entityType: type,
      contentHash: hash,
      categoryId: categoryId,
      embeddingStore: embeddingStore,
      embeddingRepository: embeddingRepository,
      baseUrl: baseUrl,
      writeGuard: writeGuard,
    );
    if (!didEmbed) return false;

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
  /// Returns `true` if an embedding was generated and stored or an unchanged
  /// report was moved to its current category shard. Returns `false` when the
  /// report is skipped (too short, unchanged and already in place, etc.).
  ///
  /// When provided, [writeGuard] is re-evaluated after generation and directly
  /// before storage so superseded asynchronous work cannot recreate a stale
  /// report vector.
  static Future<bool> processAgentReport({
    required String reportId,
    required String reportContent,
    required String taskId,
    required String categoryId,
    required String subtype,
    required EmbeddingStore embeddingStore,
    required OllamaEmbeddingRepository embeddingRepository,
    required String baseUrl,
    String? agentId,
    EmbeddingWriteGuard? writeGuard,
  }) async {
    final writeLease = agentId == null
        ? null
        : _agentReportWriteGate.tryAcquire(agentId);
    if (agentId != null && writeLease == null) return false;
    try {
      final text = reportContent.trim();
      if (text.length < kMinEmbeddingTextLength) return false;

      final hash = EmbeddingContentExtractor.contentHash(text);
      final existingHash = await embeddingStore.getContentHash(reportId);
      if (existingHash == hash) {
        final existingCategoryId = await embeddingStore.getCategoryId(
          reportId,
        );
        final existingTaskId = await embeddingStore.getTaskId(reportId);
        final categoryChanged =
            existingCategoryId != null && existingCategoryId != categoryId;
        final taskChanged = existingTaskId != null && existingTaskId != taskId;
        if (categoryChanged || taskChanged) {
          if (writeGuard != null && !await writeGuard()) return false;
          await embeddingStore.moveEntityToShard(
            reportId,
            categoryId,
            taskId: taskId,
          );
          return true;
        }
        return false;
      }

      return await _embedChunks(
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
        writeGuard: writeGuard,
      );
    } finally {
      writeLease?.release();
    }
  }

  /// Chunks [text] and generates embeddings for each chunk.
  ///
  /// All embeddings are generated first, then old data is deleted and new
  /// data inserted. This avoids leaving an entity with no embeddings if a
  /// transient embedding failure occurs mid-way. When [writeGuard] is
  /// supplied, it is rechecked between provider calls and immediately before
  /// storage so superseded work stops without replacing the old vectors.
  static Future<bool> _embedChunks({
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
    EmbeddingWriteGuard? writeGuard,
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
    AiAttributionSession? attributionSession;
    var completionStarted = false;

    Future<bool> writeStillAllowed() async {
      if (writeGuard == null || await writeGuard()) return true;
      final supersededSession = attributionSession;
      if (supersededSession != null && !completionStarted) {
        completionStarted = true;
        await capture!.completeSession(
          session: supersededSession,
          outputs: const [],
          status: AiWorkStatus.cancelled,
          errorCode: 'superseded',
        );
      }
      return false;
    }

    try {
      // Phase 1: Generate all embeddings (network calls that can fail).
      final generated = <Float32List>[];
      for (final chunk in chunks) {
        if (generated.isNotEmpty && !await writeStillAllowed()) return false;
        final invocationWrapper = capture == null
            ? null
            : (Future<Float32List> Function() invoke) async {
                attributionSession ??= await capture.beginSession(
                  workType: AiWorkType.embeddingIndexing,
                  trigger: const AiTriggerSnapshot(
                    type: AiTriggerType.automatic,
                  ),
                  automationId: 'automation:embedding-indexer',
                  automationDisplayName: 'Embedding indexer',
                  intendedOutputs: [output],
                  taskId: taskId.isEmpty ? null : taskId,
                  categoryId: categoryId.isEmpty ? null : categoryId,
                );
                return capture.captureUnary(
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
              };
        final embedding = await embeddingRepository.embed(
          input: chunk,
          baseUrl: baseUrl,
          invocationWrapper: invocationWrapper,
        );
        generated.add(embedding);
      }

      if (!await writeStillAllowed()) return false;

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
      final completedSession = attributionSession;
      if (completedSession != null) {
        completionStarted = true;
        await capture!.completeSession(
          session: completedSession,
          outputs: [output],
        );
      }
      return true;
    } on Object catch (error) {
      final failedSession = attributionSession;
      if (failedSession != null && !completionStarted) {
        await capture!.completeSession(
          session: failedSession,
          outputs: const [],
          status: AiWorkStatus.failed,
          errorCode: error.runtimeType.toString(),
        );
      }
      rethrow;
    }
  }
}

class _AgentReportWriteGate {
  final _blockedAgentIds = <String>{};
  final _activeWriteCounts = <String, int>{};
  final _drained = <String, Completer<void>>{};

  Future<void> quiesce(String agentId) {
    _blockedAgentIds.add(agentId);
    if ((_activeWriteCounts[agentId] ?? 0) == 0) {
      return Future.value();
    }
    return _drained.putIfAbsent(agentId, Completer<void>.new).future;
  }

  _AgentReportWriteLease? tryAcquire(String agentId) {
    if (_blockedAgentIds.contains(agentId)) return null;
    _activeWriteCounts.update(agentId, (count) => count + 1, ifAbsent: () => 1);
    return _AgentReportWriteLease(() => _release(agentId));
  }

  void _release(String agentId) {
    final remaining = (_activeWriteCounts[agentId] ?? 1) - 1;
    if (remaining > 0) {
      _activeWriteCounts[agentId] = remaining;
      return;
    }
    _activeWriteCounts.remove(agentId);
    _drained.remove(agentId)?.complete();
  }

  void resume(String agentId) {
    _blockedAgentIds.remove(agentId);
    _drained.remove(agentId);
  }
}

class _AgentReportWriteLease {
  _AgentReportWriteLease(this._onRelease);

  final void Function() _onRelease;

  void release() => _onRelease();
}
