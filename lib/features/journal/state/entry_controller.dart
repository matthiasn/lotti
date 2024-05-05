import 'dart:async';

import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'entry_controller.g.dart';

@riverpod
class EntryController extends _$EntryController {
  EntryController() {
    listen();
  }
  late final String entryId;
  final int _epoch = 0;

  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();
  StreamSubscription<({DatabaseType type, String id})>? _updateSubscription;

  final JournalDb _journalDb = getIt<JournalDb>();
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();

  void listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((event) async {
      if (event.id == entryId) {
        final latest = await _fetch();
        if (latest != state.value?.entry) {
          state = AsyncData(state.value?.copyWith(entry: latest));
        }
      }
    });
  }

  @override
  Future<EntryState?> build({required String id}) async {
    entryId = id;
    ref.onDispose(() => _updateSubscription?.cancel());
    final entry = await _fetch();
    return EntryState.saved(
      entryId: id,
      entry: entry,
      showMap: false,
      isFocused: false,
      epoch: _epoch,
    );
  }

  Future<JournalEntity?> _fetch() async {
    return _journalDb.journalEntityById(entryId);
  }

  Future<bool> delete({
    required bool beamBack,
  }) async {
    final res = await _persistenceLogic.deleteJournalEntity(entryId);
    if (beamBack) {
      getIt<NavService>().beamBack();
    }
    return res;
  }

  void toggleMapVisible() {
    final current = state.value;
    if (current?.entry?.geolocation != null) {
      state = AsyncData(
        current?.copyWith(
          showMap: current.showMap,
        ),
      );
    }
  }

  Future<void> toggleStarred() async {
    final item = await _journalDb.journalEntityById(entryId);
    if (item != null) {
      final prev = item.meta.starred ?? false;
      await _persistenceLogic.updateJournalEntity(
        item,
        item.meta.copyWith(
          starred: !prev,
        ),
      );
    }
  }

  Future<void> togglePrivate() async {
    final item = await _journalDb.journalEntityById(entryId);
    if (item != null) {
      final prev = item.meta.private ?? false;
      await _persistenceLogic.updateJournalEntity(
        item,
        item.meta.copyWith(
          private: !prev,
        ),
      );
    }
  }

  Future<void> toggleFlagged() async {
    final item = await _journalDb.journalEntityById(entryId);
    if (item != null) {
      await _persistenceLogic.updateJournalEntity(
        item,
        item.meta.copyWith(
          flag: item.meta.flag == EntryFlag.import
              ? EntryFlag.none
              : EntryFlag.import,
        ),
      );
    }
  }
}
