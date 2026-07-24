import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_helpers.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';

/// Derived, read-time-only readiness for one task (ADR 0042 §4): the open
/// (neither tombstoned nor closed) tasks currently blocking it, plus a count
/// of blocker links whose target couldn't be resolved at all.
///
/// An unresolvable blocker still counts toward [isBlocked] — "an unresolvable
/// blocker keeps blocking" is the conservative default the ADR requires, since
/// a missing task more often means a sync gap than a deliberate removal.
@immutable
class TaskBlockersResult {
  const TaskBlockersResult({
    required this.openBlockers,
    required this.unresolvedCount,
  });

  static const empty = TaskBlockersResult(openBlockers: [], unresolvedCount: 0);

  final List<Task> openBlockers;
  final int unresolvedCount;

  bool get isBlocked => openBlockers.isNotEmpty || unresolvedCount > 0;

  @override
  bool operator ==(Object other) =>
      other is TaskBlockersResult &&
      const ListEquality<Task>().equals(other.openBlockers, openBlockers) &&
      other.unresolvedCount == unresolvedCount;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(openBlockers), unresolvedCount);
}

/// Resolves which open tasks currently block `taskId`, independent of the
/// task's own `TaskStatus` — a task can have a live `blocks` link pointing at
/// it while its stored status is still `open` (nobody flipped the status
/// picker), and that's exactly the state this provider must surface.
///
/// Deliberately separate from `TaskLinkGroupsController` (a sibling provider):
/// that provider's resolution path (`getJournalEntitiesByIds`) silently drops
/// both a tombstoned blocker and an unresolvable one identically, which is
/// fine for display but loses the distinction ADR 0042 §4 requires here
/// (tombstoned releases the dependent; unresolvable keeps it blocked).
final AsyncNotifierProviderFamily<
  TaskBlockersController,
  TaskBlockersResult,
  String
>
taskBlockersControllerProvider = AsyncNotifierProvider.autoDispose
    .family<TaskBlockersController, TaskBlockersResult, String>(
      TaskBlockersController.new,
      name: 'taskBlockersControllerProvider',
    );

class TaskBlockersController extends AsyncNotifier<TaskBlockersResult> {
  TaskBlockersController([this.taskId = '']);

  final String taskId;

  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();
  final _watchedIds = <String>{};

  void _listen() {
    _updateSubscription = _updateNotifications.updateStream.listen((
      affectedIds,
    ) {
      if (affectedIds.intersection(_watchedIds).isNotEmpty) {
        _fetch().then((latest) {
          if (ref.mounted && latest != state.value) {
            state = AsyncData(latest);
          }
        });
      }
    });
  }

  @override
  Future<TaskBlockersResult> build() async {
    ref
      ..onDispose(() => _updateSubscription?.cancel())
      ..cacheFor(entryCacheDuration);

    final result = await _fetch();
    _watchedIds.add(taskId);
    _listen();
    return result;
  }

  Future<TaskBlockersResult> _fetch() async {
    final journalRepository = ref.read(journalRepositoryProvider);

    final links = await journalRepository.getTypedLinksForTaskIds(
      {taskId},
      linkTypes: const {'BlocksLink'},
    );
    final blockerIds = {
      for (final link in links)
        if (link.toId == taskId && link.deletedAt == null) link.fromId,
    };

    if (blockerIds.isEmpty) {
      _watchedIds.add(taskId);
      return TaskBlockersResult.empty;
    }

    final resolved = await journalRepository
        .getJournalEntitiesByIdsIncludingDeleted(blockerIds);
    final resolvedById = {for (final entity in resolved) entity.id: entity};

    final openBlockers = <Task>[];
    var unresolvedCount = 0;

    for (final blockerId in blockerIds) {
      final entity = resolvedById[blockerId];
      if (entity == null || entity is! Task) {
        // Not found at all (sync gap) or resolved to something other than a
        // task — both treated conservatively: keep blocking (ADR 0042 §4).
        unresolvedCount++;
        continue;
      }
      if (entity.meta.deletedAt != null) {
        continue; // tombstoned — releases the dependent
      }
      if (isClosedTask(entity)) {
        continue; // DONE/REJECTED — releases the dependent
      }
      openBlockers.add(entity);
    }

    _watchedIds
      ..add(taskId)
      ..addAll(blockerIds);

    return TaskBlockersResult(
      openBlockers: openBlockers,
      unresolvedCount: unresolvedCount,
    );
  }
}
