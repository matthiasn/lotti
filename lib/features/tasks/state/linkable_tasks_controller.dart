import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';

/// Whether any task other than the one being viewed exists to be linked to.
///
/// The Linked Tasks card offers two things: link an existing task, and create
/// a new one already linked. On a brand-new install neither the card nor its
/// explanation has anything to describe — the app's very first task cannot be
/// linked to anything, and a bordered card teaching a relationship feature
/// before a relationship is possible is what made the first task screen read
/// as unfinished. Nothing to link to, no card.
///
/// Deliberately at least as wide as the candidate set `TaskSearchPickerBody`
/// can reach, so "the card is here" and "the picker has rows" can never
/// disagree: every status (a finished task is a valid target for "duplicates"
/// / "follows up on"), every category plus `''` for uncategorized — an empty
/// category list short-circuits the query builder to `WHERE 1 = 0`.
///
/// Every category means `categoriesById`, not `sortedCategories`: the latter
/// drops inactive ones, and the picker's FTS path resolves matches through
/// `getJournalEntitiesForIds`, which applies no category filter at all. Gating
/// on the narrower set would hide the whole card from someone whose only other
/// task sits in a category they have since archived — a task the picker would
/// happily find.
final AsyncNotifierProviderFamily<LinkableTasksController, bool, String>
linkableTasksExistProvider = AsyncNotifierProvider.autoDispose
    .family<LinkableTasksController, bool, String>(
      LinkableTasksController.new,
      name: 'linkableTasksExistProvider',
    );

class LinkableTasksController extends AsyncNotifier<bool> {
  LinkableTasksController([this.taskId = '']);

  final String taskId;

  StreamSubscription<Set<String>>? _updateSubscription;

  /// Increments per refresh. A burst of writes (a sync batch, an import) starts
  /// several overlapping queries, and without this an older one completing last
  /// would restore its stale answer over a newer one's.
  int _generation = 0;

  @override
  Future<bool> build() async {
    ref.onDispose(() => _updateSubscription?.cancel());
    // Any journal write can be the app's second task — including one this
    // page itself creates through "Create new linked task" — so the card has
    // to appear without a reload once one exists.
    _updateSubscription = getIt<UpdateNotifications>().updateStream.listen(
      (_) => unawaited(_refresh()),
    );
    return _fetch();
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    try {
      final latest = await _fetch();
      if (!ref.mounted || generation != _generation) return;
      if (latest != state.value) state = AsyncData(latest);
    } catch (error, stackTrace) {
      // Keep the last good answer rather than blanking a card the user is
      // looking at over a transient query failure — the next write refreshes
      // it anyway. Reported so the failure is not silent.
      if (!ref.mounted || generation != _generation) return;
      getIt<LoggingService>().captureException(
        error,
        domain: 'LinkableTasksController',
        subDomain: 'refresh',
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> _fetch() async {
    final categoryIds = [
      ...getIt<EntitiesCacheService>().categoriesById.keys,
      '',
    ];
    // Two rows, not a count: the current task is itself a candidate row, so a
    // limit of one cannot distinguish "only this task" from "this task and
    // others".
    final tasks = await getIt<JournalDb>().getTasks(
      starredStatuses: const [false, true],
      taskStatuses: allTaskStatuses,
      categoryIds: categoryIds,
      limit: 2,
    );
    return tasks.any((task) => task is Task && task.meta.id != taskId);
  }
}
