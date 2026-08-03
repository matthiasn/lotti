import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// Whether any task other than the one being viewed exists to be linked to.
///
/// The Linked Tasks card offers two things: link an existing task, and create
/// a new one already linked. On a brand-new install neither the card nor its
/// explanation has anything to describe — the app's very first task cannot be
/// linked to anything, and a bordered card teaching a relationship feature
/// before a relationship is possible is what made the first task screen read
/// as unfinished. Nothing to link to, no card.
///
/// Deliberately mirrors the candidate query `TaskSearchPickerBody` runs, so
/// "the card is here" and "the picker has rows" can never disagree: every
/// status (a finished task is a valid target for "duplicates" / "follows up
/// on"), every category plus `''` for uncategorized — an empty category list
/// short-circuits the query builder to `WHERE 1 = 0`.
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

  @override
  Future<bool> build() async {
    ref.onDispose(() => _updateSubscription?.cancel());
    // Any journal write can be the app's second task — including one this
    // page itself creates through "Create new linked task" — so the card has
    // to appear without a reload once one exists.
    _updateSubscription = getIt<UpdateNotifications>().updateStream.listen((_) {
      unawaited(
        _fetch().then((latest) {
          if (ref.mounted && latest != state.value) state = AsyncData(latest);
        }),
      );
    });
    return _fetch();
  }

  Future<bool> _fetch() async {
    final categoryIds = [
      ...getIt<EntitiesCacheService>().sortedCategories.map((c) => c.id),
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
