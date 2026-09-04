import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Serializes project-agent provisioning with destructive project mutations.
///
/// Agent state and projects live in separate databases, so they cannot share a
/// database transaction. Holding this per-project coordinator across both the
/// final project existence checks and the destructive project flow closes the
/// local create/delete race; a post-create check still compensates project
/// tombstones arriving independently through sync.
class ProjectAgentMutationCoordinator {
  static final Object _activeProjectZoneKey = Object();
  final Map<String, Future<void>> _tails = {};

  Future<T> run<T>(String projectId, Future<T> Function() action) async {
    if (Zone.current[_activeProjectZoneKey] == projectId) {
      return action();
    }
    final previous = _tails[projectId] ?? Future<void>.value();
    final completed = Completer<void>();
    final tail = completed.future;
    _tails[projectId] = tail;
    await previous;
    try {
      return await runZoned(
        action,
        zoneValues: {_activeProjectZoneKey: projectId},
      );
    } finally {
      completed.complete();
      if (identical(_tails[projectId], tail)) {
        final _ = _tails.remove(projectId);
      }
    }
  }
}

/// Shared by journal category edits, agent provisioning, and retirement.
final projectAgentMutationCoordinatorProvider =
    Provider<ProjectAgentMutationCoordinator>(
      (_) => ProjectAgentMutationCoordinator(),
      name: 'projectAgentMutationCoordinatorProvider',
    );
