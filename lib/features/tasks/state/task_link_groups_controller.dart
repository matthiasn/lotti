import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';

/// The relationship semantics a [TaskLinkEntry] can represent, mirroring
/// [EntryLinkType]'s task-relevant variants (rating/project links never
/// appear here — they're not requested by [TaskLinkGroupsController]).
enum TaskLinkKind { basic, blocks, followsUp, duplicates, fixes, supersedes }

/// The `linked_entries.type` column string for a [TaskLinkKind], as derived
/// by `linkedDbEntity` — needed by callers unlinking a specific row via
/// `JournalRepository.removeTypedLink`.
String taskLinkKindDbType(TaskLinkKind kind) {
  switch (kind) {
    case TaskLinkKind.basic:
      return 'BasicLink';
    case TaskLinkKind.blocks:
      return 'BlocksLink';
    case TaskLinkKind.followsUp:
      return 'FollowsUpLink';
    case TaskLinkKind.duplicates:
      return 'DuplicatesLink';
    case TaskLinkKind.fixes:
      return 'FixesLink';
    case TaskLinkKind.supersedes:
      return 'SupersedesLink';
  }
}

/// Which side of the link the current task (the one the provider is keyed
/// on) is on. `outgoing` means the current task is the link's `fromId`.
enum TaskLinkDirection { outgoing, incoming }

/// One resolved row: the other task in a link touching the current task,
/// plus enough context to render and to unlink precisely.
@immutable
class TaskLinkEntry {
  const TaskLinkEntry({
    required this.linkId,
    required this.task,
    required this.kind,
    required this.direction,
  });

  final String linkId;
  final Task task;
  final TaskLinkKind kind;
  final TaskLinkDirection direction;

  @override
  bool operator ==(Object other) =>
      other is TaskLinkEntry &&
      other.linkId == linkId &&
      other.task == task &&
      other.kind == kind &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(linkId, task, kind, direction);
}

/// Grouped task-relationship links for one task: plain (`BasicLink`) links —
/// today's "Linked Tasks" flat list, unchanged — and the 5 typed
/// relationships, both directions, bucketed separately so the widget layer
/// can group/label them without re-deriving link semantics.
@immutable
class TaskLinkGroups {
  const TaskLinkGroups({required this.flat, required this.typed});

  static const empty = TaskLinkGroups(flat: [], typed: []);

  final List<TaskLinkEntry> flat;
  final List<TaskLinkEntry> typed;

  int get totalCount => flat.length + typed.length;
}

const _allTaskLinkDbTypes = {
  'BasicLink',
  'BlocksLink',
  'FollowsUpLink',
  'DuplicatesLink',
  'FixesLink',
  'SupersedesLink',
};

/// Resolves every plain and typed task-relationship link touching a task, in
/// both directions, from a single batched
/// `JournalRepository.getTypedLinksForTaskIds` call. Replaces
/// `outgoingLinkedTasksProvider`/`linkedFromEntriesControllerProvider` for
/// `LinkedTasksWidget`'s own reads — those shared providers stay untouched
/// for every other consumer (AI context resolution, reference-image selection,
/// generic journal linking), since scoping them here would risk breaking those.
final AsyncNotifierProviderFamily<
  TaskLinkGroupsController,
  TaskLinkGroups,
  String
>
taskLinkGroupsControllerProvider = AsyncNotifierProvider.autoDispose
    .family<TaskLinkGroupsController, TaskLinkGroups, String>(
      TaskLinkGroupsController.new,
      name: 'taskLinkGroupsControllerProvider',
    );

class TaskLinkGroupsController extends AsyncNotifier<TaskLinkGroups> {
  TaskLinkGroupsController([this.taskId = '']);

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
          if (ref.mounted && !_equals(latest, state.value)) {
            state = AsyncData(latest);
          }
        });
      }
    });
  }

  bool _equals(TaskLinkGroups a, TaskLinkGroups? b) {
    if (b == null) return false;
    const listEquality = ListEquality<TaskLinkEntry>();
    return listEquality.equals(a.flat, b.flat) &&
        listEquality.equals(a.typed, b.typed);
  }

  @override
  Future<TaskLinkGroups> build() async {
    ref
      ..onDispose(() => _updateSubscription?.cancel())
      ..cacheFor(entryCacheDuration);

    final result = await _fetch();
    _watchedIds.add(taskId);
    _listen();
    return result;
  }

  Future<TaskLinkGroups> _fetch() async {
    final journalRepository = ref.read(journalRepositoryProvider);

    final links = await journalRepository.getTypedLinksForTaskIds(
      {taskId},
      linkTypes: _allTaskLinkDbTypes,
    );
    if (links.isEmpty) return TaskLinkGroups.empty;

    final liveLinks = links.where((l) => l.deletedAt == null).toList();
    final otherIds = {
      for (final link in liveLinks)
        link.fromId == taskId ? link.toId : link.fromId,
    };

    final entities = await journalRepository.getJournalEntitiesByIds(
      otherIds,
    );
    final tasksById = {
      for (final entity in entities)
        if (entity is Task) entity.id: entity,
    };

    final flat = <TaskLinkEntry>[];
    final typed = <TaskLinkEntry>[];
    final sortableLinks = [...liveLinks]
      ..sort((a, b) {
        final primary = b.createdAt.compareTo(a.createdAt);
        return primary != 0 ? primary : b.id.compareTo(a.id);
      });

    for (final link in sortableLinks) {
      final direction = link.fromId == taskId
          ? TaskLinkDirection.outgoing
          : TaskLinkDirection.incoming;
      final otherId = direction == TaskLinkDirection.outgoing
          ? link.toId
          : link.fromId;
      final task = tasksById[otherId];
      if (task == null) continue;

      final kind = link.map(
        basic: (_) => TaskLinkKind.basic,
        rating: (_) => throw StateError(
          'unexpected RatingLink from a task-relationship link query',
        ),
        project: (_) => throw StateError(
          'unexpected ProjectLink from a task-relationship link query',
        ),
        blocks: (_) => TaskLinkKind.blocks,
        followsUp: (_) => TaskLinkKind.followsUp,
        duplicates: (_) => TaskLinkKind.duplicates,
        fixes: (_) => TaskLinkKind.fixes,
        supersedes: (_) => TaskLinkKind.supersedes,
      );

      final entry = TaskLinkEntry(
        linkId: link.id,
        task: task,
        kind: kind,
        direction: direction,
      );
      (kind == TaskLinkKind.basic ? flat : typed).add(entry);
    }

    _watchedIds
      ..add(taskId)
      ..addAll(tasksById.keys);

    return TaskLinkGroups(flat: flat, typed: typed);
  }
}
