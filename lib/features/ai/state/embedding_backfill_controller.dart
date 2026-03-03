import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/database/embeddings_db.dart';
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

class EmbeddingBackfillController extends Notifier<EmbeddingBackfillState> {
  bool _cancelled = false;

  @override
  EmbeddingBackfillState build() => const EmbeddingBackfillState();

  /// Cancels a running backfill operation.
  void cancel() {
    _cancelled = true;
  }

  Future<void> backfillCategory(String categoryId) async {
    if (state.isRunning) {
      return;
    }

    if (!getIt.isRegistered<EmbeddingsDb>()) {
      state = state.copyWith(
        error: 'Embedding pipeline not available',
        isRunning: false,
      );
      return;
    }

    _cancelled = false;
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
      final embeddingsDb = getIt<EmbeddingsDb>();
      final embeddingRepository = getIt<OllamaEmbeddingRepository>();
      final aiConfigRepository = getIt<AiConfigRepository>();

      // Check that embeddings are enabled before starting backfill.
      final enabled = await db.getConfigFlag(enableEmbeddingsFlag);
      if (!enabled) {
        state = state.copyWith(
          error: 'Embeddings are disabled',
          isRunning: false,
        );
        return;
      }

      // Resolve Ollama base URL once upfront.
      final baseUrl = await aiConfigRepository.resolveOllamaBaseUrl();
      if (baseUrl == null) {
        state = state.copyWith(
          error: 'No Ollama provider configured',
          isRunning: false,
        );
        return;
      }

      // Fetch all entity IDs in this category.
      final entityIds = await db.journalEntityIdsByCategory(categoryId).get();
      final total = entityIds.length;
      state = state.copyWith(totalCount: total);

      if (total == 0) {
        state = state.copyWith(isRunning: false, progress: 1);
        return;
      }

      var processed = 0;
      var embedded = 0;

      for (final entityId in entityIds) {
        if (_cancelled) break;

        try {
          final didEmbed = await EmbeddingProcessor.processEntity(
            entityId: entityId,
            journalDb: db,
            embeddingsDb: embeddingsDb,
            embeddingRepository: embeddingRepository,
            baseUrl: baseUrl,
          );
          if (didEmbed) embedded++;
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
      }
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
}
