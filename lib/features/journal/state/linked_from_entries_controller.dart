import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'linked_from_entries_controller.g.dart';

@riverpod
class LinkedFromEntriesController extends _$LinkedFromEntriesController {
  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();
  final watchedIds = <String>{};

  void listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((affectedIds) {
      if (affectedIds.intersection(watchedIds).isNotEmpty) {
        _fetch().then((latest) {
          if (latest != state.value) {
            state = AsyncData(latest);
          }
        });
      }
    });
  }

  @override
  Future<List<JournalEntity>> build({
    required String id,
  }) async {
    ref
      ..onDispose(() => _updateSubscription?.cancel())
      ..cacheFor(entryCacheDuration);

    final res = await _fetch();
    watchedIds.add(id);
    listen();
    return res;
  }

  Future<List<JournalEntity>> _fetch() async {
    final res = await ref.read(journalRepositoryProvider).getLinkedToEntities(
          linkedTo: id,
        );
    watchedIds.addAll(res.map((item) => item.id));
    return res;
  }
}
