import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'entry_controller.g.dart';

@riverpod
class EntryController extends _$EntryController {
  EntryController() {
    listen();
  }
  String? _entryId;
  StreamSubscription<({DatabaseType type, String id})>? _updateSubscription;

  final JournalDb _journalDb = getIt<JournalDb>();
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();

  void listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((event) async {
      if (event.id == _entryId) {
        final latest = await fetch();
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      }
    });
  }

  @override
  Future<JournalEntity?> build({required String id}) async {
    _entryId = id;
    ref.onDispose(() => _updateSubscription?.cancel());
    return fetch();
  }

  Future<JournalEntity?> fetch() async {
    if (_entryId == null) {
      return null;
    }
    return _journalDb.journalEntityById(_entryId!);
  }
}
