import 'dart:async';

import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'linked_entries_controller.g.dart';

@riverpod
class LinkedEntriesController extends _$LinkedEntriesController {
  LinkedEntriesController() {
    listen();
  }

  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();
  final watchedIds = <String>{};

  void listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((affectedIds) async {
      if (affectedIds.intersection(watchedIds).isNotEmpty) {
        final includeHidden = ref.read(includeHiddenControllerProvider(id: id));
        final latest = await _fetch(includeHidden: includeHidden);
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      }
    });
  }

  @override
  Future<List<EntryLink>> build({
    required String id,
  }) async {
    ref.onDispose(() => _updateSubscription?.cancel());
    final includeHidden = ref.watch(includeHiddenControllerProvider(id: id));
    final res = await _fetch(includeHidden: includeHidden);
    watchedIds.add(id);
    return res;
  }

  Future<List<EntryLink>> _fetch({required bool includeHidden}) async {
    final res = await ref.read(journalRepositoryProvider).getLinksFromId(
          id,
          includeHidden: includeHidden,
        );
    watchedIds.addAll(res.map((link) => link.toId));
    return res;
  }

  Future<void> removeLink({required String toId}) async {
    await ref.read(journalRepositoryProvider).removeLink(
          fromId: id,
          toId: toId,
        );
  }
}

@riverpod
class IncludeHiddenController extends _$IncludeHiddenController {
  @override
  bool build({required String id}) {
    return false;
  }

  void toggleIncludeHidden() {
    state = !state;
  }

  set includeHidden(bool value) {
    state = value;
  }

  bool get includeHidden => state;
}
