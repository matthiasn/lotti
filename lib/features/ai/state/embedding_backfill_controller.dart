import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_processor.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';

final embeddingBackfillControllerProvider =
    NotifierProvider<EmbeddingBackfillController, EmbeddingBackfillState>(
      EmbeddingBackfillController.new,
    );

class EmbeddingBackfillState {
  const EmbeddingBackfillState({
    this.progress = 0,
    this.isRunning = false,
    this.error,
    this.processedCount = 0,
    this.totalCount = 0,
    this.embeddedCount = 0,
  });

  final double progress;
  final bool isRunning;
  final String? error;
  final int processedCount;
  final int totalCount;
  final int embeddedCount;

  EmbeddingBackfillState copyWith({
    double? progress,
    bool? isRunning,
    String? error,
    bool clearError = false,
    int? processedCount,
    int? totalCount,
    int? embeddedCount,
  }) {
    return EmbeddingBackfillState(
      progress: progress ?? this.progress,
      isRunning: isRunning ?? this.isRunning,
      error: clearError ? null : error ?? this.error,
      processedCount: processedCount ?? this.processedCount,
      totalCount: totalCount ?? this.totalCount,
      embeddedCount: embeddedCount ?? this.embeddedCount,
    );
  }
}

/// Services resolved during the guard phase and passed into the body.
class _BackfillServices {
  _BackfillServices({
    required this.journalDb,
    required this.embeddingStore,
    required this.embeddingRepository,
    required this.baseUrl,
  });

  final JournalDb journalDb;
  final EmbeddingStore embeddingStore;
  final OllamaEmbeddingRepository embeddingRepository;
  final String baseUrl;
}

class EmbeddingBackfillController extends Notifier<EmbeddingBackfillState> {
  @override
  EmbeddingBackfillState build() => const EmbeddingBackfillState();

  /// Common preamble: validates preconditions, resolves services, resets
  /// state, and runs [body]. Handles errors and the `finally` block.
  Future<void> _guardedRun(
    Future<void> Function(_BackfillServices services) body,
  ) async {
    if (state.isRunning) return;

    if (!getIt.isRegistered<EmbeddingStore>()) {
      state = state.copyWith(
        error: 'Embedding pipeline not available',
        isRunning: false,
      );
      return;
    }

    state = state.copyWith(
      isRunning: true,
      progress: 0,
      processedCount: 0,
      totalCount: 0,
      embeddedCount: 0,
      clearError: true,
    );

    try {
      final db = getIt<JournalDb>();
      final embeddingStore = getIt<EmbeddingStore>();
      final embeddingRepository = getIt<OllamaEmbeddingRepository>();
      final aiConfigRepository = getIt<AiConfigRepository>();

      final enabled = await db.getConfigFlag(enableEmbeddingsFlag);
      if (!enabled) {
        state = state.copyWith(
          error: 'Embeddings are disabled',
          isRunning: false,
        );
        return;
      }

      final baseUrl = await aiConfigRepository.resolveOllamaBaseUrl();
      if (baseUrl == null) {
        state = state.copyWith(
          error: 'No Ollama provider configured',
          isRunning: false,
        );
        return;
      }

      await body(
        _BackfillServices(
          journalDb: db,
          embeddingStore: embeddingStore,
          embeddingRepository: embeddingRepository,
          baseUrl: baseUrl,
        ),
      );
    } catch (e, stackTrace) {
      developer.log(
        'Backfill error: $e',
        error: e,
        stackTrace: stackTrace,
        name: 'EmbeddingBackfillController',
      );
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isRunning: false);
    }
  }

  /// Iterates [entityIds], calling [EmbeddingProcessor.processEntity] for
  /// each, and updating progress state. Shared by backfill and reindex.
  /// A known Ollama cooldown stops the run so remaining items do not emit
  /// duplicate fast-failure diagnostics.
  Future<void> _processEntities({
    required List<String> entityIds,
    required _BackfillServices services,
    required LabelNameResolver labelResolver,
  }) async {
    final total = entityIds.length;
    var processed = 0;
    var embedded = 0;

    for (final entityId in entityIds) {
      var stopForCooldown = false;
      try {
        final didEmbed = await EmbeddingProcessor.processEntity(
          entityId: entityId,
          journalDb: services.journalDb,
          embeddingStore: services.embeddingStore,
          embeddingRepository: services.embeddingRepository,
          baseUrl: services.baseUrl,
          labelNameResolver: labelResolver,
        );
        if (didEmbed) embedded++;
      } on OllamaEmbeddingCooldownException catch (e) {
        stopForCooldown = true;
        _recordAvailabilityCooldown(
          e,
          operation: 'Category backfill',
        );
      } catch (e, stackTrace) {
        developer.log(
          'Backfill failed for $entityId: $e',
          error: e,
          stackTrace: stackTrace,
          name: 'EmbeddingBackfillController',
        );
      }

      processed++;
      state = state.copyWith(
        processedCount: processed,
        embeddedCount: embedded,
        progress: processed / total,
      );
      if (stopForCooldown) break;
    }
  }

  void _recordAvailabilityCooldown(
    OllamaEmbeddingCooldownException exception, {
    required String operation,
  }) {
    developer.log(
      '$operation paused during Ollama availability cooldown: $exception',
      name: 'EmbeddingBackfillController',
    );
    state = state.copyWith(error: exception.toString());
  }

  /// Generates embeddings for all entries in the given [categoryIds].
  Future<void> backfillCategories(Set<String> categoryIds) async {
    await _guardedRun((services) async {
      final labelResolver = await EmbeddingProcessor.buildLabelResolver(
        services.journalDb,
      );

      // Collect entity IDs across all selected categories, deduplicating
      // in case an entity belongs to multiple categories.
      final allEntityIds = <String>{};
      for (final categoryId in categoryIds) {
        final ids = await services.journalDb
            .journalEntityIdsByCategory(categoryId)
            .get();
        allEntityIds.addAll(ids);
      }

      state = state.copyWith(totalCount: allEntityIds.length);

      if (allEntityIds.isEmpty) {
        state = state.copyWith(progress: 1);
        return;
      }

      await _processEntities(
        entityIds: allEntityIds.toList(),
        services: services,
        labelResolver: labelResolver,
      );
    });
  }
}
