import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_processor.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';

enum _ReportRecoveryTargetStatus {
  current,
  reportHeadChanged,
  primaryAgentChanged,
  taskCategoryChanged,
  taskDeleted,
}

/// Background embedding generation service.
///
/// Listens to [UpdateNotifications.localUpdateStream] for entity changes and
/// [UpdateNotifications.syncUpdateStream] for durable current-report-head and
/// task-agent-link changes, then generates embeddings for text-rich entries
/// using Ollama's `/api/embed`.
/// When [agentRepository] is available, startup also reconciles durable current
/// task-agent reports so an interrupted in-memory retry is recovered.
///
/// Respects the [enableEmbeddingsFlag] config flag — when disabled, the
/// service drops queued entity work, rejects in-flight writes, and retains
/// durable report reconciliation for the next enablement.
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
  StreamSubscription<Set<String>>? _syncSubscription;
  StreamSubscription<List<AiConfig>>? _providerConfigSubscription;
  StreamSubscription<bool>? _embeddingFlagSubscription;
  final _pendingEntityIds = <String>{};
  final _pendingUnlinkedTaskIds = <String>{};
  final _pendingChangedTaskIds = <String>{};
  bool _isProcessing = false;
  bool _entityBatchRerunRequested = false;
  bool _embeddingsEnabled = true;
  int _embeddingFlagRevision = 0;
  bool _stopped = false;
  Future<void>? _inFlightProcessing;
  Future<void>? _inFlightAgentReportRecovery;
  bool _agentReportRecoveryPending = false;
  bool _fullAgentReportRecoveryPending = false;
  bool _agentReportRecoveryRunning = false;
  bool _agentReportRecoveryRerunRequested = false;
  int _providerConfigRevision = 0;
  Timer? _availabilityRetryTimer;

  /// The notification tokens that indicate an embeddable entity was changed.
  static const Set<String> _relevantTokens = {
    textEntryNotification,
    taskNotification,
    audioNotification,
    aiResponseNotification,
  };

  /// Starts listening to local entity and synced agent-head notifications.
  ///
  /// Idempotent — calling while already started is a no-op.
  void start() {
    if (_subscription != null) return;
    _stopped = false;
    _subscription = updateNotifications.localUpdateStream.listen(_onBatch);
    _syncSubscription = updateNotifications.syncUpdateStream.listen(
      _onSyncBatch,
    );
    var shouldSkipInitialProviderSnapshot = true;
    _providerConfigSubscription = aiConfigRepository
        .watchConfigsByType(AiConfigType.inferenceProvider)
        .listen(
          (_) {
            if (shouldSkipInitialProviderSnapshot) {
              shouldSkipInitialProviderSnapshot = false;
              return;
            }
            _onProviderConfigsChanged();
          },
          onError: (Object error, StackTrace stackTrace) {
            // An error is not an initial provider snapshot. The first data
            // event after recovery must wake pending work instead of being
            // discarded by the initial-value suppression.
            shouldSkipInitialProviderSnapshot = false;
            _onProviderConfigWatchError(error, stackTrace);
          },
        );
    _embeddingFlagSubscription = journalDb
        .watchConfigFlag(enableEmbeddingsFlag)
        .skip(1)
        .listen(
          _onEmbeddingFlagChanged,
          onError: _onEmbeddingFlagWatchError,
        );
    if (agentRepository != null) {
      _requestAgentReportRecovery();
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
    await _syncSubscription?.cancel();
    _syncSubscription = null;
    if (_providerConfigSubscription != null) {
      // Provider streams can be backed by a fake-async bootstrap future. The
      // stopped guard already makes late emissions inert, so do not let that
      // cancellation delay shutdown or a second idempotent stop call.
      unawaited(_providerConfigSubscription!.cancel());
    }
    _providerConfigSubscription = null;
    if (_embeddingFlagSubscription != null) {
      unawaited(_embeddingFlagSubscription!.cancel());
    }
    _embeddingFlagSubscription = null;
    _pendingEntityIds.clear();
    _pendingUnlinkedTaskIds.clear();
    _pendingChangedTaskIds.clear();
    _entityBatchRerunRequested = false;
    _agentReportRecoveryPending = false;
    _fullAgentReportRecoveryPending = false;
    _agentReportRecoveryRerunRequested = false;
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
    final hasAgentChange = tokens.contains(agentNotification);
    final hasRelevantEntityType = tokens.any(_relevantTokens.contains);
    final unlinkedTaskIds = _idsWithPrefix(
      tokens,
      agentTaskLinkNotificationPrefix,
    );
    if (!hasAgentChange && !hasRelevantEntityType && unlinkedTaskIds.isEmpty) {
      return;
    }

    if (_availabilityRetryTimer?.isActive ?? false) {
      // A fresh notification may reflect endpoint recovery, changed Ollama
      // configuration, or a newer durable report head.
      _availabilityRetryTimer?.cancel();
      _availabilityRetryTimer = null;
    }
    if (unlinkedTaskIds.isNotEmpty) {
      _pendingUnlinkedTaskIds.addAll(unlinkedTaskIds);
    }
    if (hasAgentChange || unlinkedTaskIds.isNotEmpty) {
      _requestAgentReportRecovery(fullScan: hasAgentChange);
    }
    if (!hasRelevantEntityType) {
      _resumePendingEntityBatch();
      return;
    }

    // Extract entity UUIDs from the batch (filter out type tokens).
    final entityIds = tokens.where(_isEntityId).toSet();
    if (entityIds.isEmpty) return;

    _pendingEntityIds.addAll(entityIds);
    // Only start a new processing future if one isn't already running.
    // Overwriting _inFlightProcessing while _isProcessing is true would
    // cause stop() to await a completed no-op instead of the real work.
    if (!_isProcessing) {
      _inFlightProcessing = _processNext();
      unawaited(_inFlightProcessing);
    }
    _startAgentReportRecovery();
  }

  /// Reconciles derived vectors when sync advances a current report head.
  void _onSyncBatch(Set<String> tokens) {
    final unlinkedTaskIds = _idsWithPrefix(
      tokens,
      agentTaskLinkNotificationPrefix,
    );
    final changedTaskIds = _idsWithPrefix(tokens, taskNotificationPrefix);
    final requiresFullScan =
        tokens.contains(agentIdentityNotification) ||
        tokens.contains(agentReportHeadNotification) ||
        tokens.contains(agentReportNotification) ||
        tokens.contains(agentTaskLinkNotification);
    if (!requiresFullScan &&
        unlinkedTaskIds.isEmpty &&
        changedTaskIds.isEmpty) {
      return;
    }
    _pendingUnlinkedTaskIds.addAll(unlinkedTaskIds);
    _pendingChangedTaskIds.addAll(changedTaskIds);
    if (_availabilityRetryTimer?.isActive ?? false) {
      _availabilityRetryTimer?.cancel();
      _availabilityRetryTimer = null;
      if (_isProcessing) _entityBatchRerunRequested = true;
    }
    _requestAgentReportRecovery(fullScan: requiresFullScan);
    _resumePendingEntityBatch();
  }

  /// Rechecks pending report recovery when provider configuration changes.
  void _onProviderConfigsChanged() {
    _providerConfigRevision++;
    _availabilityRetryTimer?.cancel();
    _availabilityRetryTimer = null;
    if (_isProcessing) _entityBatchRerunRequested = true;
    _requestAgentReportRecovery();
    _resumePendingEntityBatch();
  }

  /// Keeps optional embedding configuration failures inside this service.
  void _onProviderConfigWatchError(Object error, StackTrace stackTrace) {
    if (_stopped) return;
    developer.log(
      'Ollama provider configuration watch failed',
      error: error,
      stackTrace: stackTrace,
      name: 'EmbeddingService',
    );
  }

  void _onEmbeddingFlagChanged(bool enabled) {
    _embeddingFlagRevision++;
    _embeddingsEnabled = enabled;
    _availabilityRetryTimer?.cancel();
    _availabilityRetryTimer = null;
    if (!enabled) {
      _pendingEntityIds.clear();
      _entityBatchRerunRequested = false;
      if (agentRepository != null) {
        _agentReportRecoveryPending = true;
        _fullAgentReportRecoveryPending = true;
      }
      return;
    }
    if (_isProcessing) _entityBatchRerunRequested = true;
    _requestAgentReportRecovery();
    _resumePendingEntityBatch();
  }

  /// Keeps optional embedding-flag failures inside this service.
  void _onEmbeddingFlagWatchError(Object error, StackTrace stackTrace) {
    if (_stopped) return;
    developer.log(
      'Embedding flag watch failed',
      error: error,
      stackTrace: stackTrace,
      name: 'EmbeddingService',
    );
  }

  void _resumePendingEntityBatch() {
    if (_stopped || _pendingEntityIds.isEmpty || _isProcessing) return;
    _inFlightProcessing = _processNext();
    unawaited(_inFlightProcessing);
  }

  /// Requests one recovery pass, coalescing a request that arrives mid-pass.
  void _requestAgentReportRecovery({bool fullScan = true}) {
    if (_stopped || agentRepository == null) return;
    _agentReportRecoveryPending = true;
    if (fullScan) _fullAgentReportRecoveryPending = true;
    if (_agentReportRecoveryRunning) {
      _agentReportRecoveryRerunRequested = true;
      return;
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
    _agentReportRecoveryPending = false;
    _agentReportRecoveryRerunRequested = false;

    try {
      final flagRevision = _embeddingFlagRevision;
      final enabled = await journalDb.getConfigFlag(enableEmbeddingsFlag);
      if (flagRevision == _embeddingFlagRevision) {
        _embeddingsEnabled = enabled;
      }
      if (!enabled || !_embeddingsEnabled || _stopped) {
        if (!_stopped) _agentReportRecoveryPending = true;
        return;
      }

      final providerConfigRevision = _providerConfigRevision;
      final baseUrl = await aiConfigRepository.resolveOllamaBaseUrl();
      if (baseUrl == null ||
          !_embeddingsEnabled ||
          _stopped ||
          providerConfigRevision != _providerConfigRevision) {
        if (!_stopped) _agentReportRecoveryPending = true;
        return;
      }

      final fullScanRequested = _fullAgentReportRecoveryPending;
      _fullAgentReportRecoveryPending = false;
      final changedTaskIds = Set<String>.of(_pendingChangedTaskIds);
      _pendingChangedTaskIds.removeAll(changedTaskIds);

      var failureCount = 0;
      Object? firstError;
      StackTrace? firstStackTrace;

      void recordFailure(Object error, StackTrace stackTrace) {
        failureCount++;
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }

      final unlinkedTaskIds = List<String>.of(_pendingUnlinkedTaskIds);
      _pendingUnlinkedTaskIds.removeAll(unlinkedTaskIds);
      for (var index = 0; index < unlinkedTaskIds.length; index++) {
        if (_stopped || !_embeddingsEnabled) {
          if (!_stopped) {
            _pendingUnlinkedTaskIds.addAll(unlinkedTaskIds.skip(index));
            _agentReportRecoveryPending = true;
          }
          return;
        }
        final taskId = unlinkedTaskIds[index];
        try {
          final currentLinks = await repository.getLinksTo(
            taskId,
            type: AgentLinkTypes.agentTask,
          );
          if (currentLinks.isNotEmpty) {
            changedTaskIds.add(taskId);
            continue;
          }
          await _deleteReportEmbeddingsForTask(taskId);
        } catch (error, stackTrace) {
          _pendingUnlinkedTaskIds.add(taskId);
          _agentReportRecoveryPending = true;
          recordFailure(error, stackTrace);
        }
      }

      if (!fullScanRequested) {
        final targetedTaskIds = changedTaskIds.toList(growable: false);
        for (var index = 0; index < targetedTaskIds.length; index++) {
          if (_shouldStopAgentReportRecoveryPass(providerConfigRevision)) {
            return;
          }
          final taskId = targetedTaskIds[index];
          try {
            final currentLinks = await repository.getLinksTo(
              taskId,
              type: AgentLinkTypes.agentTask,
            );
            if (currentLinks.isEmpty) continue;
            final primaryLink = currentLinks.selectPrimary();
            final agentEntity = await repository.getEntity(primaryLink.fromId);
            if (agentEntity is! AgentIdentityEntity) continue;
            await _recoverAgentReportsForTask(
              repository: repository,
              agent: agentEntity,
              taskId: taskId,
              baseUrl: baseUrl,
            );
          } on OllamaEmbeddingAvailabilityException catch (error) {
            if (!_stopped) {
              _pendingChangedTaskIds.addAll(targetedTaskIds.skip(index));
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
            _pendingChangedTaskIds.add(taskId);
            _agentReportRecoveryPending = true;
            recordFailure(error, stackTrace);
          }
        }

        if (failureCount > 0) {
          developer.log(
            'Agent report embedding recovery skipped $failureCount '
            'operation(s)',
            error: firstError,
            stackTrace: firstStackTrace,
            name: 'EmbeddingService',
          );
        }
        return;
      }

      // This service owns a dedicated long-lived repository wrapper. Agent
      // writes happen through Riverpod and sync repository instances, whose
      // cache invalidations cannot reach this wrapper.
      repository.invalidateAgentIdentitiesCache();
      final agents = await repository.getAllAgentIdentities();

      final agentsById = {for (final agent in agents) agent.id: agent};
      final taskLinksByTaskId = <String, List<AgentLink>>{};
      var topologyIncomplete = false;
      for (final agent in agents) {
        if (_shouldStopAgentReportRecoveryPass(providerConfigRevision)) {
          return;
        }

        try {
          final taskLinks = await repository.getLinksFrom(
            agent.id,
            type: AgentLinkTypes.agentTask,
          );
          for (final link in taskLinks) {
            taskLinksByTaskId.putIfAbsent(link.toId, () => []).add(link);
          }
        } catch (error, stackTrace) {
          topologyIncomplete = true;
          recordFailure(error, stackTrace);
        }
      }

      if (topologyIncomplete) {
        _agentReportRecoveryPending = true;
        _fullAgentReportRecoveryPending = true;
        developer.log(
          'Agent report embedding recovery skipped $failureCount operation(s) '
          'because the task topology snapshot was incomplete',
          error: firstError,
          stackTrace: firstStackTrace,
          name: 'EmbeddingService',
        );
        return;
      }

      for (final entry in taskLinksByTaskId.entries) {
        if (_shouldStopAgentReportRecoveryPass(providerConfigRevision)) {
          return;
        }
        final primaryLink = entry.value.selectPrimary();
        final agent = agentsById[primaryLink.fromId];
        if (agent == null) continue;

        try {
          await _recoverAgentReportsForTask(
            repository: repository,
            agent: agent,
            taskId: entry.key,
            baseUrl: baseUrl,
          );
        } on OllamaEmbeddingAvailabilityException catch (error) {
          if (!_stopped) {
            _agentReportRecoveryPending = true;
            _fullAgentReportRecoveryPending = true;
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
          recordFailure(error, stackTrace);
        }
      }

      if (failureCount > 0) {
        _agentReportRecoveryPending = true;
        _fullAgentReportRecoveryPending = true;
        developer.log(
          'Agent report embedding recovery skipped $failureCount operation(s)',
          error: firstError,
          stackTrace: firstStackTrace,
          name: 'EmbeddingService',
        );
      }
    } on Object catch (error, stackTrace) {
      if (!_stopped) {
        _agentReportRecoveryPending = true;
        _fullAgentReportRecoveryPending = true;
      }
      developer.log(
        'Agent report embedding recovery failed: $error',
        error: error,
        stackTrace: stackTrace,
        name: 'EmbeddingService',
      );
    } finally {
      final rerunRequested = _agentReportRecoveryRerunRequested;
      _agentReportRecoveryRerunRequested = false;
      _agentReportRecoveryRunning = false;
      if (rerunRequested && _agentReportRecoveryPending) {
        // The signal requesting this rerun arrived while the previous request
        // was in flight. Any cooldown installed by that old request is stale:
        // provider, flag, or durable report state may already have changed.
        _availabilityRetryTimer?.cancel();
        _availabilityRetryTimer = null;
        _startAgentReportRecovery();
      }
    }
  }

  bool _shouldStopAgentReportRecoveryPass(int providerConfigRevision) =>
      _stopped ||
      !_embeddingsEnabled ||
      providerConfigRevision != _providerConfigRevision;

  /// Deletes every vector indexed to [taskId], plus a just-written report that
  /// may not yet be visible through the reverse index.
  Future<void> _deleteReportEmbeddingsForTask(
    String taskId, {
    String? additionalReportId,
  }) async {
    final reportIds = {
      ...await embeddingStore.getEntityIdsForTask(taskId),
      ?additionalReportId,
    };
    for (final reportId in reportIds) {
      await embeddingStore.deleteEntityEmbeddings(reportId);
    }
  }

  Future<bool> _taskIsDeleted(String taskId) async {
    final entity = (await journalDb.journalEntityMapForIdsIncludingDeleted([
      taskId,
    ]))[taskId];
    return entity?.meta.deletedAt != null;
  }

  /// Reconciles one agent until its durable current-report head is stable.
  ///
  /// A normal wake can publish a successor while startup recovery awaits
  /// network or storage work. Following the new head here ensures cleanup is
  /// based on the eventual searchable successor instead of stopping after the
  /// superseded attempt.
  Future<void> _recoverAgentReportsForTask({
    required AgentRepository repository,
    required AgentIdentityEntity agent,
    required String taskId,
    required String baseUrl,
  }) async {
    final task = await journalDb.journalEntityById(taskId);
    if (task == null && await _taskIsDeleted(taskId)) {
      await _deleteReportEmbeddingsForTask(taskId);
      return;
    }
    final categoryId = task?.meta.categoryId ?? '';
    final attemptedReportIds = <String>{};
    final removedReportIds = <String>{};

    while (!_stopped && _embeddingsEnabled) {
      final report = await repository.getLatestReport(
        agent.id,
        AgentReportScopes.current,
      );
      if (report == null ||
          report.content.isEmpty ||
          !attemptedReportIds.add(report.id)) {
        return;
      }

      final didEmbed = await EmbeddingProcessor.processAgentReport(
        reportId: report.id,
        reportContent: report.content,
        taskId: taskId,
        categoryId: categoryId,
        subtype: AgentReportScopes.current,
        embeddingStore: embeddingStore,
        embeddingRepository: embeddingRepository,
        baseUrl: baseUrl,
        writeGuard: () async {
          if (!_embeddingsEnabled || _stopped) return false;
          final status = await _reportRecoveryTargetStatus(
            repository: repository,
            agentId: agent.id,
            taskId: taskId,
            reportId: report.id,
            categoryId: categoryId,
          );
          return status == _ReportRecoveryTargetStatus.current;
        },
      );
      if (!_embeddingsEnabled || _stopped) return;
      final postStoreStatus = await _reportRecoveryTargetStatus(
        repository: repository,
        agentId: agent.id,
        taskId: taskId,
        reportId: report.id,
        categoryId: categoryId,
      );
      if (postStoreStatus != _ReportRecoveryTargetStatus.current) {
        if (postStoreStatus == _ReportRecoveryTargetStatus.taskDeleted) {
          await _deleteReportEmbeddingsForTask(
            taskId,
            additionalReportId: didEmbed ? report.id : null,
          );
          return;
        }
        if (didEmbed && removedReportIds.add(report.id)) {
          await embeddingStore.deleteEntityEmbeddings(report.id);
        }
        if (postStoreStatus == _ReportRecoveryTargetStatus.reportHeadChanged) {
          // Follow a successor for the same agent without rebuilding the
          // task topology snapshot.
          continue;
        }
        // Topology and category changes require a fresh outer pass so agent
        // selection and the target shard are rebuilt from durable state.
        _requestAgentReportRecovery();
        return;
      }

      final currentReportIsSearchable =
          didEmbed || await embeddingStore.hasEmbedding(report.id);
      if (!currentReportIsSearchable) return;

      final cleanupCandidateIds = await embeddingStore.getEntityIdsForTask(
        taskId,
      );
      final statusAfterCandidateRead = await _reportRecoveryTargetStatus(
        repository: repository,
        agentId: agent.id,
        taskId: taskId,
        reportId: report.id,
        categoryId: categoryId,
      );
      if (statusAfterCandidateRead != _ReportRecoveryTargetStatus.current) {
        if (statusAfterCandidateRead ==
            _ReportRecoveryTargetStatus.taskDeleted) {
          await _deleteReportEmbeddingsForTask(
            taskId,
            additionalReportId: didEmbed ? report.id : null,
          );
          return;
        }
        if (didEmbed && removedReportIds.add(report.id)) {
          await embeddingStore.deleteEntityEmbeddings(report.id);
        }
        if (statusAfterCandidateRead ==
            _ReportRecoveryTargetStatus.reportHeadChanged) {
          // The candidate snapshot cannot contain a successor published after
          // it was read. Reconcile that successor before deleting anything.
          continue;
        }
        _requestAgentReportRecovery();
        return;
      }
      for (final candidateId in cleanupCandidateIds) {
        if (candidateId != report.id && removedReportIds.add(candidateId)) {
          await embeddingStore.deleteEntityEmbeddings(candidateId);
        }
      }
      return;
    }
  }

  /// Confirms every durable selector that determines a report vector's owner.
  ///
  /// The checks run immediately before storage and cleanup. A changed report
  /// head can be followed inside the current task pass; a changed primary link
  /// or category needs a fresh outer pass to rebuild topology and shard state.
  Future<_ReportRecoveryTargetStatus> _reportRecoveryTargetStatus({
    required AgentRepository repository,
    required String agentId,
    required String taskId,
    required String reportId,
    required String categoryId,
  }) async {
    final latestReport = await repository.getLatestReport(
      agentId,
      AgentReportScopes.current,
    );
    if (latestReport?.id != reportId) {
      return _ReportRecoveryTargetStatus.reportHeadChanged;
    }

    final taskLinks = await repository.getLinksTo(
      taskId,
      type: AgentLinkTypes.agentTask,
    );
    if (taskLinks.isEmpty || taskLinks.selectPrimary().fromId != agentId) {
      return _ReportRecoveryTargetStatus.primaryAgentChanged;
    }

    final task = await journalDb.journalEntityById(taskId);
    if (task == null && await _taskIsDeleted(taskId)) {
      return _ReportRecoveryTargetStatus.taskDeleted;
    }
    if ((task?.meta.categoryId ?? '') != categoryId) {
      return _ReportRecoveryTargetStatus.taskCategoryChanged;
    }
    return _ReportRecoveryTargetStatus.current;
  }

  Future<void> _processNext() async {
    if (_isProcessing) return;
    _isProcessing = true;
    final providerConfigRevision = _providerConfigRevision;

    try {
      // Resolve config flag and base URL once per batch to avoid
      // redundant DB queries for each entity.
      final flagRevision = _embeddingFlagRevision;
      final enabled = await journalDb.getConfigFlag(enableEmbeddingsFlag);
      if (flagRevision == _embeddingFlagRevision) {
        _embeddingsEnabled = enabled;
      }
      if (!enabled || !_embeddingsEnabled) {
        if (!_entityBatchRerunRequested) _pendingEntityIds.clear();
        return;
      }

      final baseUrl = await aiConfigRepository.resolveOllamaBaseUrl();
      if (baseUrl == null) {
        if (!_entityBatchRerunRequested) _pendingEntityIds.clear();
        return;
      }
      if (providerConfigRevision != _providerConfigRevision) return;

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

      while (_pendingEntityIds.isNotEmpty && !_stopped && _embeddingsEnabled) {
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
            writeGuard: () =>
                _embeddingsEnabled &&
                !_stopped &&
                providerConfigRevision == _providerConfigRevision,
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
        if (providerConfigRevision != _providerConfigRevision) {
          if (!_stopped && _embeddingsEnabled) {
            _pendingEntityIds.add(entityId);
          }
          break;
        }
        if (_entityBatchRerunRequested) break;
      }
    } on Object catch (e, stackTrace) {
      developer.log(
        'Embedding batch preflight failed: $e',
        error: e,
        stackTrace: stackTrace,
        name: 'EmbeddingService',
      );
      if (!_entityBatchRerunRequested) _pendingEntityIds.clear();
    } finally {
      _isProcessing = false;
      if (_entityBatchRerunRequested) {
        _entityBatchRerunRequested = false;
        _availabilityRetryTimer?.cancel();
        _availabilityRetryTimer = null;
        _resumePendingEntityBatch();
      }
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

  static Set<String> _idsWithPrefix(Set<String> tokens, String prefix) => tokens
      .where((token) => token.startsWith(prefix))
      .map((token) => token.substring(prefix.length))
      .where((id) => id.isNotEmpty)
      .toSet();

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
