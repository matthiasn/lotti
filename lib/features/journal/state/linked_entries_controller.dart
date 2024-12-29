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
      if (affectedIds.contains(entryId)) {
        final latest = await _fetch();
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      }
    });
  }

  @override
  Future<List<EntryLink>> build({
    required String entryId,
    bool includedHidden = false,
  }) async {
    ref.onDispose(() => _updateSubscription?.cancel());
    final res = await _fetch();
    return res;
  }

  Future<List<EntryLink>> _fetch() async {
    return ref.read(journalRepositoryProvider).getLinksFromId(
          entryId,
          includedHidden: includedHidden,
        );
  }
}
