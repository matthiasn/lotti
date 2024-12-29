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

  void listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((affectedIds) async {
      if (affectedIds.contains(id)) {
        final includeHidden = ref.read(includeHiddenControllerProvider);
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
    final includeHidden = ref.watch(includeHiddenControllerProvider);
    final res = await _fetch(includeHidden: includeHidden);
    return res;
  }

  Future<List<EntryLink>> _fetch({required bool includeHidden}) async {
    return ref.read(journalRepositoryProvider).getLinksFromId(
          id,
          includeHidden: includeHidden,
        );
  }
}

@riverpod
class IncludeHiddenController extends _$IncludeHiddenController {
  @override
  bool build() {
    return false;
  }

  void toggleIncludeHidden() {
    state = !state;
  }
}
