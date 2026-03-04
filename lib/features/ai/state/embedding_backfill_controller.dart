import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
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

      // Build label resolver for enriched task templates.
      final labelResolver = await EmbeddingProcessor.buildLabelResolver(db);

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
            labelNameResolver: labelResolver,
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

  /// Backfills embeddings for all agent reports.
  ///
  /// Iterates every agent instance, resolves its task link and latest report
  /// via the report head pointer, and embeds the report content. Reports that
  /// are already embedded with a matching content hash are skipped.
  Future<void> backfillAgentReports() async {
    if (state.isRunning) return;

    if (!getIt.isRegistered<EmbeddingsDb>() ||
        !getIt.isRegistered<AgentRepository>()) {
      state = state.copyWith(
        error: 'Embedding or agent pipeline not available',
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
      final journalDb = getIt<JournalDb>();
      final embeddingsDb = getIt<EmbeddingsDb>();
      final embeddingRepository = getIt<OllamaEmbeddingRepository>();
      final aiConfigRepository = getIt<AiConfigRepository>();
      final agentRepository = getIt<AgentRepository>();

      final enabled = await journalDb.getConfigFlag(enableEmbeddingsFlag);
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

      // Get all agent instances and resolve their task links + report heads.
      final agents = await agentRepository.getAllAgentIdentities();
      final total = agents.length;
      state = state.copyWith(totalCount: total);

      if (total == 0) {
        state = state.copyWith(isRunning: false, progress: 1);
        return;
      }

      var processed = 0;
      var embedded = 0;

      for (final agent in agents) {
        if (_cancelled) break;

        try {
          // Resolve the task this agent is linked to.
          final taskLinks = await agentRepository.getLinksFrom(
            agent.id,
            type: AgentLinkTypes.agentTask,
          );
          if (taskLinks.isEmpty) {
            processed++;
            state = state.copyWith(
              processedCount: processed,
              progress: processed / total,
            );
            continue;
          }
          final taskId = taskLinks.first.toId;

          // Get the latest report via the head pointer.
          final report = await agentRepository.getLatestReport(
            agent.id,
            AgentReportScopes.current,
          );
          if (report == null || report.content.isEmpty) {
            processed++;
            state = state.copyWith(
              processedCount: processed,
              progress: processed / total,
            );
            continue;
          }

          // Resolve the task's category.
          final taskEntity = await journalDb.journalEntityById(taskId);
          final categoryId = taskEntity?.meta.categoryId ?? '';

          final didEmbed = await EmbeddingProcessor.processAgentReport(
            reportId: report.id,
            reportContent: report.content,
            taskId: taskId,
            categoryId: categoryId,
            subtype: AgentReportScopes.current,
            embeddingsDb: embeddingsDb,
            embeddingRepository: embeddingRepository,
            baseUrl: baseUrl,
          );
          if (didEmbed) embedded++;
        } catch (e, stackTrace) {
          developer.log(
            'Agent report backfill failed for ${agent.id}: $e',
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
        'Agent report backfill error: $e',
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
