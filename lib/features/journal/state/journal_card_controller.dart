import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'journal_card_controller.g.dart';

@riverpod
class JournalCardController extends _$JournalCardController {
  JournalCardController() {
    listen();
  }

  late final String entryId;
  StreamSubscription<Set<String>>? _updateSubscription;
  final JournalDb _journalDb = getIt<JournalDb>();
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
  Future<JournalEntity?> build({required String id}) async {
    entryId = id;
    ref.onDispose(() => _updateSubscription?.cancel());
    final entry = await _fetch();
    return entry;
  }

  Future<JournalEntity?> _fetch() async {
    return _journalDb.journalEntityById(entryId);
  }
}
