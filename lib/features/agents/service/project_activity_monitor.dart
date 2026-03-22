import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';

/// Tracks local project-linked activity and marks project summaries stale.
///
/// Project agents do not wake immediately on task/project notifications
/// anymore. Instead, this monitor listens to the local update stream, resolves
/// whether an affected project has a provisioned project agent, and persists a
/// pending activity marker on the agent state. The scheduled 06:00 wake later
/// decides whether to spend tokens on a fresh report.
class ProjectActivityMonitor {
  ProjectActivityMonitor({
    required UpdateNotifications notifications,
    required AgentRepository agentRepository,
    required AgentSyncService syncService,
    this.domainLogger,
    Clock clock = const Clock(),
  }) : _notifications = notifications,
       _agentRepository = agentRepository,
       _syncService = syncService,
       _clock = clock;

  final UpdateNotifications _notifications;
  final AgentRepository _agentRepository;
  final AgentSyncService _syncService;
  final DomainLogger? domainLogger;
  final Clock _clock;

  StreamSubscription<Set<String>>? _subscription;

  void _log(String message, {String? subDomain}) {
    domainLogger?.log(
      LogDomains.agentRuntime,
      message,
      subDomain: subDomain,
    );
  }

  void _logError(String message, {Object? error, StackTrace? stackTrace}) {
    if (domainLogger != null) {
      domainLogger!.error(
        LogDomains.agentRuntime,
        message,
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      developer.log(
        '$message${error != null ? ': $error' : ''}',
        name: 'ProjectActivityMonitor',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Start tracking local project activity.
  void start() {
    _subscription?.cancel();
    _subscription = _notifications.localUpdateStream.listen((affectedIds) {
      unawaited(_handleBatch(affectedIds));
    });
  }

  /// Stop tracking project activity.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _handleBatch(Set<String> affectedIds) async {
    if (affectedIds.isEmpty) return;

    // Only IDs with an `agent_project` link matter here. Generic
    // notification tokens such as `PROJECT` simply return no links.
    await Future.wait(
      affectedIds.map(_markProjectActivityIfNeeded),
    );
  }

  Future<void> _markProjectActivityIfNeeded(String projectId) async {
    try {
      final links = await _agentRepository.getLinksTo(
        projectId,
        type: AgentLinkTypes.agentProject,
      );
      if (links.isEmpty) return;

      final agentId = _selectPrimaryProjectLink(links).fromId;
      final state = await _agentRepository.getAgentState(agentId);
      if (state == null || state.deletedAt != null) return;

      final now = _clock.now();
      final pendingActivityAt = state.slots.pendingProjectActivityAt;
      if (pendingActivityAt != null && !pendingActivityAt.isBefore(now)) {
        return;
      }

      await _syncService.upsertEntity(
        state.copyWith(
          revision: state.revision + 1,
          slots: state.slots.copyWith(
            pendingProjectActivityAt: now,
          ),
          updatedAt: now,
        ),
      );

      // UI/state providers listen on the general update stream, but this state
      // mutation should not feed back into local wake triggering.
      _notifications.notify({agentId, agentNotification}, fromSync: true);

      _log(
        'marked pending project activity for '
        '${DomainLogger.sanitizeId(agentId)}',
        subDomain: 'activity',
      );
    } catch (error, stackTrace) {
      _logError(
        'failed to mark project activity for '
        '${DomainLogger.sanitizeId(projectId)}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  AgentLink _selectPrimaryProjectLink(List<AgentLink> links) {
    final sorted = links.toList()
      ..sort((a, b) {
        final createdAtComparison = b.createdAt.compareTo(a.createdAt);
        if (createdAtComparison != 0) {
          return createdAtComparison;
        }
        return b.id.compareTo(a.id);
      });
    return sorted.first;
  }
}
