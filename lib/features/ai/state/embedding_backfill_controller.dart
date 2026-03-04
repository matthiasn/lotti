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
    this.failedCount = 0,
  });

  final double progress;
  final bool isRunning;
  final String? error;
  final int processedCount;
  final int totalCount;
  final int embeddedCount;

  /// Number of entities that failed to embed during the current run.
  final int failedCount;

  EmbeddingBackfillState copyWith({
    double? progress,
    bool? isRunning,
    String? error,
    bool clearError = false,
    int? processedCount,
    int? totalCount,
    int? embeddedCount,
    int? failedCount,
  }) {
    return EmbeddingBackfillState(
      progress: progress ?? this.progress,
      isRunning: isRunning ?? this.isRunning,
      error: clearError ? null : error ?? this.error,
      processedCount: processedCount ?? this.processedCount,
      totalCount: totalCount ?? this.totalCount,
      embeddedCount: embeddedCount ?? this.embeddedCount,
      failedCount: failedCount ?? this.failedCount,
    );
  }
}

/// Services resolved during the guard phase and passed into the body.
class _BackfillServices {
  _BackfillServices({
    required this.journalDb,
    required this.embeddingsDb,
    required this.embeddingRepository,
    required this.baseUrl,
  });

  final JournalDb journalDb;
  final EmbeddingsDb embeddingsDb;
  final OllamaEmbeddingRepository embeddingRepository;
  final String baseUrl;
}

class EmbeddingBackfillController extends Notifier<EmbeddingBackfillState> {
  bool _cancelled = false;

  @override
  EmbeddingBackfillState build() => const EmbeddingBackfillState();

  /// Cancels a running backfill operation.
  void cancel() {
    _cancelled = true;
  }

  /// Common preamble: validates preconditions, resolves services, resets
  /// state, and runs [body]. Handles errors and the `finally` block.
  Future<void> _guardedRun(
    Future<void> Function(_BackfillServices services) body, {
    bool requireAgentRepository = false,
  }) async {
    if (state.isRunning) return;

    if (!getIt.isRegistered<EmbeddingsDb>()) {
      state = state.copyWith(
        error: 'Embedding pipeline not available',
        isRunning: false,
      );
      return;
    }

    if (requireAgentRepository && !getIt.isRegistered<AgentRepository>()) {
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
      failedCount: 0,
      clearError: true,
    );

    try {
      final db = getIt<JournalDb>();
      final embeddingsDb = getIt<EmbeddingsDb>();
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
          embeddingsDb: embeddingsDb,
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
  Future<_EmbedResult> _processEntities({
    required List<String> entityIds,
    required _BackfillServices services,
    required LabelNameResolver labelResolver,
    int processedOffset = 0,
    int embeddedOffset = 0,
    int failedOffset = 0,
    int totalOverride = 0,
  }) async {
    final total = totalOverride > 0 ? totalOverride : entityIds.length;
    var processed = processedOffset;
    var embedded = embeddedOffset;
    var failed = failedOffset;

    for (final entityId in entityIds) {
      if (_cancelled) break;

      try {
        final didEmbed = await EmbeddingProcessor.processEntity(
          entityId: entityId,
          journalDb: services.journalDb,
          embeddingsDb: services.embeddingsDb,
          embeddingRepository: services.embeddingRepository,
          baseUrl: services.baseUrl,
          labelNameResolver: labelResolver,
        );
        if (didEmbed) embedded++;
      } catch (e, stackTrace) {
        failed++;
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
        failedCount: failed,
        progress: processed / total,
      );
    }

    return _EmbedResult(
      processed: processed,
      embedded: embedded,
      failed: failed,
    );
  }

  Future<void> backfillCategory(String categoryId) async {
    await _guardedRun((services) async {
      final labelResolver =
          await EmbeddingProcessor.buildLabelResolver(services.journalDb);

      final entityIds =
          await services.journalDb.journalEntityIdsByCategory(categoryId).get();
      state = state.copyWith(totalCount: entityIds.length);

      if (entityIds.isEmpty) {
        state = state.copyWith(progress: 1);
        return;
      }

      await _processEntities(
        entityIds: entityIds,
        services: services,
        labelResolver: labelResolver,
      );
    });
  }

  /// Re-indexes all embeddings by clearing the database and running
  /// backfill for every category plus all agent reports.
  ///
  /// This is needed when the chunking strategy changes (e.g. switching
  /// from single-embedding to overlapping chunks) so existing data is
  /// re-embedded with the new logic.
  Future<void> reindexAll() async {
    await _guardedRun((services) async {
      // Clear all existing embeddings.
      services.embeddingsDb.deleteAll();

      final labelResolver =
          await EmbeddingProcessor.buildLabelResolver(services.journalDb);

      // Collect all entity IDs across all categories.
      final categories =
          await services.journalDb.allCategoryDefinitions().get();
      final allEntityIds = <String>[];
      for (final cat in categories) {
        final ids =
            await services.journalDb.journalEntityIdsByCategory(cat.id).get();
        allEntityIds.addAll(ids);
      }

      // Count agent reports so the total reflects both phases.
      final agentCount = getIt.isRegistered<AgentRepository>()
          ? (await getIt<AgentRepository>().getAllAgentIdentities()).length
          : 0;
      final total = allEntityIds.length + agentCount;
      state = state.copyWith(totalCount: total);

      if (total == 0) {
        state = state.copyWith(progress: 1);
        return;
      }

      final result = await _processEntities(
        entityIds: allEntityIds,
        services: services,
        labelResolver: labelResolver,
        totalOverride: total,
      );

      // Also reindex agent reports (if the agent repository is available).
      if (!_cancelled && getIt.isRegistered<AgentRepository>()) {
        await _reindexAgentReports(
          services: services,
          processedOffset: result.processed,
          embeddedOffset: result.embedded,
          failedOffset: result.failed,
          total: total,
        );
      }
    });
  }

  Future<void> _reindexAgentReports({
    required _BackfillServices services,
    int processedOffset = 0,
    int embeddedOffset = 0,
    int failedOffset = 0,
    int total = 0,
  }) async {
    final agentRepository = getIt<AgentRepository>();
    var processed = processedOffset;
    var embedded = embeddedOffset;
    var failed = failedOffset;

    final agents = await agentRepository.getAllAgentIdentities();
    for (final agent in agents) {
      if (_cancelled) break;
      try {
        final taskLinks = await agentRepository.getLinksFrom(
          agent.id,
          type: AgentLinkTypes.agentTask,
        );
        if (taskLinks.isEmpty) {
          processed++;
          state = state.copyWith(
            processedCount: processed,
            progress: total > 0 ? processed / total : 1,
          );
          continue;
        }
        final taskId = taskLinks.first.toId;

        final report = await agentRepository.getLatestReport(
          agent.id,
          AgentReportScopes.current,
        );
        if (report == null || report.content.isEmpty) {
          processed++;
          state = state.copyWith(
            processedCount: processed,
            progress: total > 0 ? processed / total : 1,
          );
          continue;
        }

        final taskEntity = await services.journalDb.journalEntityById(taskId);
        final categoryId = taskEntity?.meta.categoryId ?? '';

        final didEmbed = await EmbeddingProcessor.processAgentReport(
          reportId: report.id,
          reportContent: report.content,
          taskId: taskId,
          categoryId: categoryId,
          subtype: AgentReportScopes.current,
          embeddingsDb: services.embeddingsDb,
          embeddingRepository: services.embeddingRepository,
          baseUrl: services.baseUrl,
        );
        if (didEmbed) embedded++;
      } catch (e, stackTrace) {
        failed++;
        developer.log(
          'Reindex agent report failed for ${agent.id}: $e',
          error: e,
          stackTrace: stackTrace,
          name: 'EmbeddingBackfillController',
        );
      }

      processed++;
      state = state.copyWith(
        processedCount: processed,
        embeddedCount: embedded,
        failedCount: failed,
        progress: total > 0 ? processed / total : 1,
      );
    }
  }

  /// Backfills embeddings for all agent reports.
  ///
  /// Iterates every agent instance, resolves its task link and latest report
  /// via the report head pointer, and embeds the report content. Reports that
  /// are already embedded with a matching content hash are skipped.
  Future<void> backfillAgentReports() async {
    await _guardedRun(
      (services) async {
        final agentRepository = getIt<AgentRepository>();

        // Get all agent instances and resolve their task links + report heads.
        final agents = await agentRepository.getAllAgentIdentities();
        final total = agents.length;
        state = state.copyWith(totalCount: total);

        if (total == 0) {
          state = state.copyWith(progress: 1);
          return;
        }

        var processed = 0;
        var embedded = 0;
        var failed = 0;

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
            final taskEntity =
                await services.journalDb.journalEntityById(taskId);
            final categoryId = taskEntity?.meta.categoryId ?? '';

            final didEmbed = await EmbeddingProcessor.processAgentReport(
              reportId: report.id,
              reportContent: report.content,
              taskId: taskId,
              categoryId: categoryId,
              subtype: AgentReportScopes.current,
              embeddingsDb: services.embeddingsDb,
              embeddingRepository: services.embeddingRepository,
              baseUrl: services.baseUrl,
            );
            if (didEmbed) embedded++;
          } catch (e, stackTrace) {
            failed++;
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
            failedCount: failed,
            progress: processed / total,
          );
        }
      },
      requireAgentRepository: true,
    );
  }
}

class _EmbedResult {
  _EmbedResult({
    required this.processed,
    required this.embedded,
    required this.failed,
  });
  final int processed;
  final int embedded;
  final int failed;
}
