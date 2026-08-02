import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_processor.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';

/// Background embedding generation service.
///
/// Listens to [UpdateNotifications.localUpdateStream] for entity changes
/// and generates embeddings for text-rich entries using Ollama's `/api/embed`.
/// When [agentRepository] is available, startup also reconciles durable current
/// task-agent reports so an interrupted in-memory retry is recovered.
///
/// Respects the [enableEmbeddingsFlag] config flag — when disabled, the
/// service silently drops all notifications.
///
/// Uses content hashing (SHA-256) to skip re-embedding unchanged content.
/// Processing is single-flight: only one embedding request runs at a time,
/// with a set for pending entity IDs.
class EmbeddingService {
  EmbeddingService({
    required this.embeddingStore,
    required this.embeddingRepository,
    required this.journalDb,
    required this.updateNotifications,
    required this.aiConfigRepository,
    this.agentRepository,
  });

  final EmbeddingStore embeddingStore;
  final OllamaEmbeddingRepository embeddingRepository;
  final JournalDb journalDb;
  final UpdateNotifications updateNotifications;
  final AiConfigRepository aiConfigRepository;

  /// Optional agent store used to recover current report embeddings at
  /// startup. Reports are durable while their normal availability retry is
  /// deliberately in-memory, so a startup scan closes interrupted retries.
  final AgentRepository? agentRepository;

  StreamSubscription<Set<String>>? _subscription;
  final _pendingEntityIds = <String>{};
  bool _isProcessing = false;
  bool _stopped = false;
  Future<void>? _inFlightProcessing;
  Future<void>? _inFlightAgentReportRecovery;
  bool _agentReportRecoveryPending = false;
  bool _agentReportRecoveryRunning = false;
  Timer? _availabilityRetryTimer;

  /// The notification tokens that indicate an embeddable entity was changed.
  static const Set<String> _relevantTokens = {
    textEntryNotification,
    taskNotification,
    audioNotification,
    aiResponseNotification,
  };

  /// Starts listening to local update notifications.
  ///
  /// Idempotent — calling while already started is a no-op.
  void start() {
    if (_subscription != null) return;
    _stopped = false;
    _subscription = updateNotifications.localUpdateStream.listen(_onBatch);
    if (agentRepository != null) {
      _agentReportRecoveryPending = true;
      _startAgentReportRecovery();
    }
  }

  /// Stops listening, clears pending work, and awaits any in-flight processing.
  ///
  /// Sets the [_stopped] flag so the processing loop exits after the current
  /// entity completes. In-flight work is awaited to ensure clean shutdown.
  Future<void> stop() async {
    _stopped = true;
    _availabilityRetryTimer?.cancel();
    _availabilityRetryTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _pendingEntityIds.clear();
    _agentReportRecoveryPending = false;
    final inFlight = _inFlightProcessing;
    _inFlightProcessing = null;
    final reportRecovery = _inFlightAgentReportRecovery;
    _inFlightAgentReportRecovery = null;
    if (inFlight != null) {
      // Ignore errors — _processEntity already handles them internally.
      await inFlight.catchError((_) {});
    }
    if (reportRecovery != null) {
      await reportRecovery.catchError((_) {});
    }
  }

  void _onBatch(Set<String> tokens) {
    // Only process if the batch contains at least one relevant type token.
    final hasRelevantType = tokens.any(_relevantTokens.contains);
    if (!hasRelevantType) return;

    // Extract entity UUIDs from the batch (filter out type tokens).
    final entityIds = tokens.where(_isEntityId).toSet();
    if (entityIds.isEmpty) return;

    _pendingEntityIds.addAll(entityIds);
    if (_availabilityRetryTimer?.isActive ?? false) {
      // A fresh notification may reflect endpoint recovery or a changed
      // Ollama configuration. Re-probe immediately; the repository still
      // fast-fails without network I/O if the same endpoint is cooling down.
      _availabilityRetryTimer?.cancel();
      _availabilityRetryTimer = null;
    }
    // Only start a new processing future if one isn't already running.
    // Overwriting _inFlightProcessing while _isProcessing is true would
    // cause stop() to await a completed no-op instead of the real work.
    if (!_isProcessing) {
      _inFlightProcessing = _processNext();
      unawaited(_inFlightProcessing);
    }
    _startAgentReportRecovery();
  }

  void _startAgentReportRecovery() {
    if (_stopped ||
        !_agentReportRecoveryPending ||
        _agentReportRecoveryRunning) {
      return;
    }
    _inFlightAgentReportRecovery = _recoverAgentReportEmbeddings();
    unawaited(_inFlightAgentReportRecovery);
  }

  Future<void> _recoverAgentReportEmbeddings() async {
    final repository = agentRepository;
    if (repository == null || _agentReportRecoveryRunning) return;
    _agentReportRecoveryRunning = true;

    try {
      final enabled = await journalDb.getConfigFlag(enableEmbeddingsFlag);
      if (!enabled || _stopped) {
        _agentReportRecoveryPending = false;
        return;
      }

      final baseUrl = await aiConfigRepository.resolveOllamaBaseUrl();
      if (baseUrl == null || _stopped) {
        _agentReportRecoveryPending = false;
        return;
      }

      final agents = await repository.getAllAgentIdentities();
      var failureCount = 0;
      Object? firstError;
      StackTrace? firstStackTrace;

      for (final agent in agents) {
        if (_stopped) return;

        try {
          final taskLinks = await repository.getLinksFrom(
            agent.id,
            type: AgentLinkTypes.agentTask,
          );
          if (taskLinks.isEmpty) continue;

          final report = await repository.getLatestReport(
            agent.id,
            AgentReportScopes.current,
          );
          if (report == null || report.content.isEmpty) continue;

          final taskId = taskLinks.first.toId;
          final task = await journalDb.journalEntityById(taskId);
          final didEmbed = await EmbeddingProcessor.processAgentReport(
            reportId: report.id,
            reportContent: report.content,
            taskId: taskId,
            categoryId: task?.meta.categoryId ?? '',
            subtype: AgentReportScopes.current,
            embeddingStore: embeddingStore,
            embeddingRepository: embeddingRepository,
            baseUrl: baseUrl,
            writeGuard: () async {
              final latestReport = await repository.getLatestReport(
                agent.id,
                AgentReportScopes.current,
              );
              return latestReport?.id == report.id;
            },
          );
          final latestReport = await repository.getLatestReport(
            agent.id,
            AgentReportScopes.current,
          );
          if (latestReport?.id != report.id) {
            // The head advanced while the store swap was in flight. Remove
            // only the vector this recovery attempt can have introduced;
            // the new head's normal workflow owns predecessor cleanup.
            if (didEmbed) {
              await embeddingStore.deleteEntityEmbeddings(report.id);
            }
            continue;
          }
          final currentReportIsSearchable =
              didEmbed || await embeddingStore.hasEmbedding(report.id);
          if (!currentReportIsSearchable) continue;

          final currentReports = await repository
              .getEntitiesByAgentIdAndSubtype(
                agent.id,
                type: AgentEntityTypes.agentReport,
                subtype: AgentReportScopes.current,
              );
          for (final historicalReport
              in currentReports.whereType<AgentReportEntity>()) {
            // A newer report may be persisted after the head recheck but
            // before this query completes. Never let startup recovery delete
            // a report at or beyond the still-current snapshot.
            if (historicalReport.createdAt.isBefore(report.createdAt)) {
              await embeddingStore.deleteEntityEmbeddings(
                historicalReport.id,
              );
            }
          }
        } on OllamaEmbeddingAvailabilityException catch (error) {
          if (!_stopped) {
            _agentReportRecoveryPending = true;
            _scheduleAvailabilityRetry(error.retryAt);
          }
          if (error is! OllamaEmbeddingCooldownException ||
              error.shouldLogSummary) {
            developer.log(
              'Agent report embedding recovery paused because Ollama is '
              'unavailable: $error',
              name: 'EmbeddingService',
            );
          }
          return;
        } catch (error, stackTrace) {
          failureCount++;
          firstError ??= error;
          firstStackTrace ??= stackTrace;
        }
      }

      _agentReportRecoveryPending = false;
      if (failureCount > 0) {
        developer.log(
          'Agent report embedding recovery skipped $failureCount report(s)',
          error: firstError,
          stackTrace: firstStackTrace,
          name: 'EmbeddingService',
        );
      }
    } on Object catch (error, stackTrace) {
      _agentReportRecoveryPending = false;
      developer.log(
        'Agent report embedding recovery failed: $error',
        error: error,
        stackTrace: stackTrace,
        name: 'EmbeddingService',
      );
    } finally {
      _agentReportRecoveryRunning = false;
    }
  }

  Future<void> _processNext() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // Resolve config flag and base URL once per batch to avoid
      // redundant DB queries for each entity.
      final enabled = await journalDb.getConfigFlag(enableEmbeddingsFlag);
      if (!enabled) {
        _pendingEntityIds.clear();
        return;
      }

      final baseUrl = await aiConfigRepository.resolveOllamaBaseUrl();
      if (baseUrl == null) {
        _pendingEntityIds.clear();
        return;
      }

      // Cache label definitions for the batch to avoid one DB query per entity.
      // Best-effort: label resolution failures should not block core embeddings.
      LabelNameResolver? labelResolver;
      try {
        labelResolver = await EmbeddingProcessor.buildLabelResolver(journalDb);
      } on Object catch (e, stackTrace) {
        developer.log(
          'Failed to build label resolver; continuing without labels: $e',
          error: e,
          stackTrace: stackTrace,
          name: 'EmbeddingService',
        );
      }

      while (_pendingEntityIds.isNotEmpty && !_stopped) {
        final entityId = _pendingEntityIds.first;
        _pendingEntityIds.remove(entityId);

        try {
          await EmbeddingProcessor.processEntity(
            entityId: entityId,
            journalDb: journalDb,
            embeddingStore: embeddingStore,
            embeddingRepository: embeddingRepository,
            baseUrl: baseUrl,
            labelNameResolver: labelResolver,
          );
        } on OllamaEmbeddingAvailabilityException catch (e) {
          developer.log(
            'Embedding batch paused because Ollama is unavailable: $e',
            name: 'EmbeddingService',
          );
          if (!_stopped) {
            _pendingEntityIds.add(entityId);
            _scheduleAvailabilityRetry(e.retryAt);
          }
          break;
        } catch (e, stackTrace) {
          developer.log(
            'Failed to generate embedding for $entityId: $e',
            error: e,
            stackTrace: stackTrace,
            name: 'EmbeddingService',
          );
          // Swallow error — don't block other entities.
        }
      }
    } on Object catch (e, stackTrace) {
      developer.log(
        'Embedding batch preflight failed: $e',
        error: e,
        stackTrace: stackTrace,
        name: 'EmbeddingService',
      );
      _pendingEntityIds.clear();
    } finally {
      _isProcessing = false;
    }
  }

  void _scheduleAvailabilityRetry(DateTime retryAt) {
    _availabilityRetryTimer?.cancel();
    final remaining = retryAt.difference(clock.now());
    final delay = remaining.isNegative ? Duration.zero : remaining;
    _availabilityRetryTimer = Timer(delay, () {
      _availabilityRetryTimer = null;
      if (_stopped) return;
      _startAgentReportRecovery();
      if (_pendingEntityIds.isNotEmpty && !_isProcessing) {
        _inFlightProcessing = _processNext();
        unawaited(_inFlightProcessing);
      }
    });
  }

  /// Matches UUID format (8-4-4-4-12 hex digits) used for entity IDs.
  ///
  /// Notification type tokens are UPPER_SNAKE_CASE and never match this
  /// pattern, so this cleanly separates entity IDs from type markers.
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool _isEntityId(String token) => _uuidPattern.hasMatch(token);
}
