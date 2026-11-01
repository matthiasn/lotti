import 'dart:async';
import 'dart:typed_data';

import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/database/embedding_register.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/embedding_sync/embedding_share.dart';
import 'package:lotti/features/ai/on_device_embedding/on_device_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
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
/// SHA-256 hashing, generates an embedding with the on-device model, and
/// stores it.
///
/// **One run per entity at a time.** These callers run concurrently and do
/// not know about each other, and a run spans a model call. Each run for
/// an entity therefore holds that entity's lock from its journal read to its
/// store write, so a run that read an older version can never write after a
/// run that read a newer one; the model is `specs/tla/EmbeddingFreshness.tla`.
///
/// **Every store and every removal is a version** of the entry's register
/// (`<entityId>|<modelId>`), written with its chunks in one transaction.
/// While an [EmbeddingShare] is registered and grants a reservation, the
/// version gets the next clock of this host and is sent to the user's other
/// devices; otherwise it is stored without a clock and stays here. A
/// removal is a tombstone: no chunks, a bumped clock.
abstract final class EmbeddingProcessor {
  /// The tail of each entity's queue of runs, removed when it drains.
  static final Map<String, Future<void>> _tails = {};

  /// Runs [action] under [key]'s lock, the one every run of this processor
  /// for that entity (an agent report: its task) holds. The sync receiver
  /// stores arriving vectors under it, so they never interleave with a
  /// local embed of the same entry.
  static Future<T> runExclusive<T>(String key, Future<T> Function() action) =>
      _serialized(key, action);

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
    required OnDeviceEmbeddingRepository embeddingRepository,
    LabelNameResolver? labelNameResolver,
  }) => _serialized(entityId, () async {
    final entity = await journalDb.journalEntityById(entityId);
    if (entity == null) {
      // Deleted (the read hides soft-deleted rows) or never stored. A
      // deleted entry that could have had vectors announces its removal
      // even when this device holds none: another device may have shared
      // some, and a receiver never processes the deletion itself.
      final deleted = await journalDb.journalEntityByIdIncludingDeleted(
        entityId,
      );
      final deletedType = deleted == null
          ? null
          : EmbeddingContentExtractor.entityType(deleted);
      await _removeVectors(
        entityId: entityId,
        modelId: embeddingRepository.modelId,
        embeddingStore: embeddingStore,
        entityType: deletedType,
        sourceVectorClock: deleted?.meta.vectorClock,
        announce: deletedType != null,
      );
      return false;
    }

    final type = EmbeddingContentExtractor.entityType(entity);
    if (type == null) return false;

    final categoryId = entity.meta.categoryId ?? '';

    // For tasks, try the enriched template with labels first.
    final text = await embeddingText(entity, labelNameResolver);
    if (text == null) {
      await _removeVectors(
        entityId: entityId,
        modelId: embeddingRepository.modelId,
        embeddingStore: embeddingStore,
        entityType: type,
        sourceVectorClock: entity.meta.vectorClock,
      );
      await _moveReports(entity, categoryId, embeddingStore);
      return false;
    }

    // A tombstone made from this version of the entry, or a later one, says
    // it has no vectors: its deletion (or shortening) is on its way, and an
    // embed now would bring back what another device removed.
    if (_tombstoneCovers(
      await embeddingStore.getRegister(entityId),
      entity.meta.vectorClock,
    )) {
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
      sourceVectorClock: entity.meta.vectorClock,
      embeddingStore: embeddingStore,
      embeddingRepository: embeddingRepository,
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
  /// Filters out deleted labels, and keeps private ones whatever this
  /// device's privacy toggle says: the names are part of a task's text, and
  /// that text must hash the same on every device, or a peer holds the
  /// vectors it receives for good. The snapshot is taken once and reused for
  /// all subsequent lookups, making this efficient for batch processing.
  static Future<LabelNameResolver> buildLabelResolver(
    JournalDb journalDb,
  ) async {
    final allLabels = await journalDb.getAllLabelDefinitionsIncludingPrivate();
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
  ///
  /// The one extraction both sides of vector sync use: the writer hashes
  /// what it embeds with it, the receiver hashes its own copy with it.
  static Future<String?> embeddingText(
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
  /// method accepts the report's fields directly rather than looking them
  /// up. It embeds the one-liner, the TLDR and the body together
  /// ([EmbeddingContentExtractor.extractAgentReportText]), so a task is found
  /// by its whole report.
  /// The report is stored in the category of its task [taskId], read from
  /// [journalDb] (the default shard when the task is gone).
  ///
  /// Once stored, the report is the task's only one in the index: every
  /// other report embedded for [taskId] is deleted, not just the one it
  /// replaced. A report whose own embedding was skipped (endpoint down, text
  /// too short) would otherwise leave the one before it searchable for good.
  /// A skipped or failed run deletes nothing, so the task stays findable by
  /// its last embedded report.
  ///
  /// Runs under the task's lock, the one [processEntity] holds while it
  /// moves the task's reports: a recategorisation of the task either lands
  /// before this run reads the category, or is processed after the report
  /// is stored and moves it along. The cleanup runs under the same lock, so
  /// an earlier report's run can never delete a newer report's vector.
  ///
  /// Each report removed that way gets a tombstone version of its own
  /// register, so the user's other devices drop it too.
  ///
  /// A report is immutable and only the device that wrote it embeds it, so
  /// its version carries no source clock.
  ///
  /// Returns `true` if an embedding was generated and stored, `false` if
  /// skipped (too short, unchanged content hash, etc.).
  static Future<bool> processAgentReport({
    required String reportId,
    required String content,
    required String taskId,
    required String subtype,
    required JournalDb journalDb,
    required EmbeddingStore embeddingStore,
    required OnDeviceEmbeddingRepository embeddingRepository,
    String? tldr,
    String? oneLiner,
  }) => _serialized(taskId, () async {
    final text = EmbeddingContentExtractor.extractAgentReportText(
      content: content,
      tldr: tldr,
      oneLiner: oneLiner,
    );
    if (text == null) return false;

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
    );

    for (final staleId in await embeddingStore.agentReportIdsForTask(taskId)) {
      if (staleId != reportId) {
        await _removeVectors(
          entityId: staleId,
          modelId: embeddingRepository.modelId,
          embeddingStore: embeddingStore,
        );
      }
    }

    return true;
  });

  /// Where versions are shared, set by the composition root once sync and
  /// the embedding pipeline are both up; `null` without sync (a guest
  /// world, a test), and then every version stays on this device.
  static EmbeddingShare? share;

  /// Reserves the next version of [entityId]'s register after [previous],
  /// or returns `null` while versions are not shared.
  static Future<EmbeddingVersionTicket?> _reserve(
    String entityId,
    String modelId,
    EmbeddingRegister? previous,
  ) async => share?.reserve(
    registerId: embeddingRegisterId(entityId, modelId),
    previous: previous?.vectorClock,
  );

  /// Whether [register] is a tombstone made from the entry version
  /// [entityClock], or one after it.
  static bool _tombstoneCovers(
    EmbeddingRegister? register,
    VectorClock? entityClock,
  ) {
    final source = register?.sourceVectorClock;
    if (register == null || !register.deleted) return false;
    if (source == null || entityClock == null) return false;
    final status = VectorClock.compare(source, entityClock);
    return status == VclockStatus.equal || status == VclockStatus.a_gt_b;
  }

  /// Removes [entityId]'s vectors, as a tombstone version when it is shared.
  /// [sourceVectorClock] is the entry version the removal is made from — the
  /// deleted or shortened one — so a concurrent embed of an older text
  /// loses to it.
  ///
  /// A no-op for an entity with neither chunks nor a live register, so an
  /// entry that stays too short sends nothing however often it is processed;
  /// with [announce] — a deleted entry — the tombstone goes out anyway,
  /// unless one is stored already.
  static Future<void> _removeVectors({
    required String entityId,
    required String modelId,
    required EmbeddingStore embeddingStore,
    String? entityType,
    VectorClock? sourceVectorClock,
    bool announce = false,
  }) async {
    final previous = await embeddingStore.getRegister(entityId);
    if (previous != null && previous.deleted) return;
    final hasChunks = await embeddingStore.hasEmbedding(entityId);
    if (!hasChunks && previous == null && !announce) return;

    final ticket = await _reserve(entityId, modelId, previous);
    if (ticket == null) {
      await embeddingStore.deleteEntityEmbeddings(entityId);
      return;
    }
    final tombstone = EmbeddingRegister(
      entityId: entityId,
      modelId: modelId,
      entityType: previous?.entityType ?? entityType ?? '',
      contentHash: '',
      vectorClock: ticket.vectorClock,
      sourceVectorClock: sourceVectorClock,
      deleted: true,
      taskId: previous?.taskId ?? '',
      subtype: previous?.subtype ?? '',
      originatingHostId: ticket.hostId,
    );
    try {
      await embeddingStore.writeTombstone(tombstone);
    } on Object {
      await ticket.release();
      rethrow;
    }
    await ticket.send(tombstone, const []);
  }

  /// Chunks [text] and generates embeddings for each chunk.
  ///
  /// All embeddings are generated first, then old data is deleted and new
  /// data inserted. This avoids leaving an entity with no embeddings if a
  /// transient embedding failure occurs mid-way.
  ///
  /// The chunk set is stored as the register's next version, which is
  /// shared when an [EmbeddingShare] grants it a clock.
  static Future<void> _embedChunks({
    required String text,
    required String entityId,
    required String entityType,
    required String contentHash,
    required EmbeddingStore embeddingStore,
    required OnDeviceEmbeddingRepository embeddingRepository,
    String categoryId = '',
    String taskId = '',
    String subtype = '',
    VectorClock? sourceVectorClock,
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
      // Phase 1: Generate all embeddings (model calls that can fail). No
      // provider is called and nothing is consumed, so the session records
      // the work and its vector, without an interaction per chunk.
      final generated = <Float32List>[
        for (final chunk in chunks)
          await embeddingRepository.embedDocument(chunk),
      ];

      final modelId = embeddingRepository.modelId;
      final ticket = await _reserve(
        entityId,
        modelId,
        await embeddingStore.getRegister(entityId),
      );
      final version = EmbeddingRegister(
        entityId: entityId,
        modelId: modelId,
        entityType: entityType,
        contentHash: contentHash,
        vectorClock: ticket?.vectorClock,
        sourceVectorClock: sourceVectorClock,
        taskId: taskId,
        subtype: subtype,
        originatingHostId: ticket?.hostId ?? '',
      );
      try {
        await embeddingStore.replaceEntityEmbeddings(
          entityId: entityId,
          entityType: entityType,
          modelId: modelId,
          contentHash: contentHash,
          embeddings: generated,
          categoryId: categoryId,
          taskId: taskId,
          subtype: subtype,
          register: version,
        );
      } on Object {
        await ticket?.release();
        rethrow;
      }
      await ticket?.send(version, generated);
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
