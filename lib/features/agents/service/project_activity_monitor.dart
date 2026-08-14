import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_automation_policy.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/agent_time_utils.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/util/agent_error_logging.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';

/// Serializes project-activity writes with explicit wake cancellation.
///
/// Activity batches capture a causal sequence before asynchronous project and
/// link resolution. A later cancellation installs a cutoff immediately,
/// then both paths rendezvous here before writing. Older batches are rejected;
/// batches observed after the cancellation remain eligible. A failed
/// cancellation removes only its own cutoff so it cannot silently consume
/// activity when persistence rolled back.
class ProjectActivityCancellationCoordinator {
  final Map<String, int> _committedCancellationSequences = {};
  final Map<String, Set<int>> _pendingCancellationSequences = {};
  final Map<String, Future<void>> _tails = {};
  var _sequence = 0;

  /// Captures the causal position of a notification before async resolution.
  int captureActivity() => ++_sequence;

  Future<T> runCancellation<T>({
    required String agentId,
    required Future<T> Function() action,
  }) {
    final cancellationSequence = ++_sequence;
    (_pendingCancellationSequences[agentId] ??= {}).add(
      cancellationSequence,
    );
    return _serialize(agentId, () async {
      try {
        final result = await action();
        final committed = _committedCancellationSequences[agentId];
        if (committed == null || cancellationSequence > committed) {
          _committedCancellationSequences[agentId] = cancellationSequence;
        }
        return result;
      } finally {
        final pending = _pendingCancellationSequences[agentId];
        pending?.remove(cancellationSequence);
        if (pending?.isEmpty ?? false) {
          _pendingCancellationSequences.remove(agentId);
        }
      }
    });
  }

  Future<bool> runActivityWrite({
    required String agentId,
    required int observedSequence,
    required Future<void> Function() action,
  }) => _serialize(agentId, () async {
    final cancellationCutoff = _cancellationCutoff(agentId);
    if (cancellationCutoff != null && observedSequence <= cancellationCutoff) {
      return false;
    }
    await action();
    return true;
  });

  int? _cancellationCutoff(String agentId) {
    var cutoff = _committedCancellationSequences[agentId];
    for (final sequence
        in _pendingCancellationSequences[agentId] ?? const <int>{}) {
      if (cutoff == null || sequence > cutoff) cutoff = sequence;
    }
    return cutoff;
  }

  Future<T> _serialize<T>(
    String agentId,
    Future<T> Function() action,
  ) async {
    final previous = _tails[agentId] ?? Future<void>.value();
    final completed = Completer<void>();
    final tail = completed.future;
    _tails[agentId] = tail;
    await previous;
    try {
      return await action();
    } finally {
      completed.complete();
      if (identical(_tails[agentId], tail)) {
        final _ = _tails.remove(agentId);
      }
    }
  }
}

/// Tracks local project-linked activity and marks project summaries stale.
///
/// Linked-task activity does not wake project agents immediately. This monitor
/// listens to the local update stream, resolves whether an affected project has
/// a provisioned agent, and persists both a pending activity marker and a
/// one-shot morning fallback. Project subscriptions may still queue a sooner
/// short-delay wake for direct edits. A successful wake clears both paths when
/// it consumed the newest activity; activity arriving mid-run retains the
/// fallback, so it remains one-shot per pending batch rather than recurring.
class ProjectActivityMonitor with AgentErrorLogging {
  ProjectActivityMonitor({
    required this._notifications,
    required this._agentRepository,
    required this._projectRepository,
    required this._syncService,
    this.domainLogger,
    this._clock = const Clock(),
    ProjectActivityCancellationCoordinator? cancellationCoordinator,
  }) : _cancellationCoordinator =
           cancellationCoordinator ?? ProjectActivityCancellationCoordinator();

  final UpdateNotifications _notifications;
  final AgentRepository _agentRepository;
  final ProjectRepository _projectRepository;
  final AgentSyncService _syncService;
  final ProjectActivityCancellationCoordinator _cancellationCoordinator;
  @override
  final DomainLogger? domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentRuntime;
  final Clock _clock;

  StreamSubscription<Set<String>>? _subscription;

  void _log(String message, {String? subDomain}) {
    domainLogger?.log(
      LogDomain.agentRuntime,
      message,
      subDomain: subDomain,
    );
  }

  /// Start tracking local project activity.
  void start() {
    _subscription?.cancel();
    _subscription = _notifications.localUpdateStream.listen((affectedIds) {
      final observedAt = _clock.now();
      final observedSequence = _cancellationCoordinator.captureActivity();
      unawaited(_handleBatch(affectedIds, observedAt, observedSequence));
    });
  }

  /// Stop tracking project activity.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _handleBatch(
    Set<String> affectedIds,
    DateTime observedAt,
    int observedSequence,
  ) async {
    if (affectedIds.isEmpty) return;

    final projectIds = await _projectRepository.resolveAffectedProjectIds(
      affectedIds,
    );
    if (projectIds.isEmpty) return;

    // Only project IDs with an `agent_project` link matter here. Generic
    // notification tokens are filtered out by the project repository.
    await Future.wait(
      projectIds.map(
        (projectId) => _markProjectActivityIfNeeded(
          projectId,
          observedAt,
          observedSequence,
        ),
      ),
    );
  }

  Future<void> _markProjectActivityIfNeeded(
    String projectId,
    DateTime observedAt,
    int observedSequence,
  ) async {
    try {
      final links = await _agentRepository.getLinksTo(
        projectId,
        type: AgentLinkTypes.agentProject,
      );
      if (links.isEmpty) return;

      final agentId = links.selectPrimary().fromId;
      final snapshot = await _agentRepository.getAgentState(agentId);
      if (snapshot == null || snapshot.deletedAt != null) return;
      final now = observedAt;
      final pendingActivityAt = snapshot.slots.pendingProjectActivityAt;
      if (pendingActivityAt != null && !pendingActivityAt.isBefore(now)) {
        return;
      }

      final persisted = await _cancellationCoordinator.runActivityWrite(
        agentId: agentId,
        observedSequence: observedSequence,
        action: () => _syncService.runInTransaction(() async {
          // Re-read inside the same transaction as the write. The wake router
          // may have persisted `reportStaleAt` after the snapshot above; using
          // that current row keeps the independent freshness and activity
          // mutations from erasing one another.
          final current = await _agentRepository.getAgentState(agentId);
          if (current == null || current.deletedAt != null) return;
          final currentPendingActivityAt =
              current.slots.pendingProjectActivityAt;
          if (currentPendingActivityAt != null &&
              !currentPendingActivityAt.isBefore(now)) {
            return;
          }

          final identity = await _agentRepository.getEntity(agentId);
          final automaticUpdatesAllowed =
              identity is AgentIdentityEntity &&
              projectAgentAutomaticWakesAllowed(
                config: identity.config,
                lifecycle: identity.lifecycle,
              );
          await _syncService.upsertEntity(
            current.copyWith(
              slots: current.slots.copyWith(
                pendingProjectActivityAt: now,
              ),
              // Project activity owns a single durable morning fallback. A
              // successful wake clears it; another activity update can arm a
              // new one, but no workflow rolls it forward unconditionally.
              scheduledWakeAt:
                  current.scheduledWakeAt ??
                  (automaticUpdatesAllowed
                      ? nextOccurrenceOf(
                          now,
                          hour: AgentSchedules.projectDailyDigestHour,
                        )
                      : null),
              updatedAt: now,
            ),
          );
        }),
      );
      if (!persisted) return;

      _notifications.notifyUiOnly({agentId, agentNotification});

      _log(
        'marked pending project activity for '
        '${DomainLogger.sanitizeId(agentId)}',
        subDomain: 'activity',
      );
    } catch (error, stackTrace) {
      logError(
        'failed to mark project activity for '
        '${DomainLogger.sanitizeId(projectId)}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
