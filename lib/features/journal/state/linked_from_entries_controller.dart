import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';

/// Loads and live-updates the entries that link *to* entry `id` (incoming
/// links, the "linked from" set), resolved to full [JournalEntity]s.
///
/// Mirrors `LinkedEntriesController` but for the reverse direction: subscribes
/// to [UpdateNotifications] and re-fetches when the source or any linking
/// entity changes, caching for `entryCacheDuration`.
final AsyncNotifierProviderFamily<
  LinkedFromEntriesController,
  List<JournalEntity>,
  String
>
linkedFromEntriesControllerProvider = AsyncNotifierProvider.autoDispose
    .family<LinkedFromEntriesController, List<JournalEntity>, String>(
      LinkedFromEntriesController.new,
      name: 'linkedFromEntriesControllerProvider',
    );

class LinkedFromEntriesController extends AsyncNotifier<List<JournalEntity>> {
  LinkedFromEntriesController([this.id = '']);

  final String id;

  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();
  final watchedIds = <String>{};

  void listen() {
    _updateSubscription = _updateNotifications.updateStream.listen((
      affectedIds,
    ) {
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
  Future<List<JournalEntity>> build() async {
    ref
      ..onDispose(() => _updateSubscription?.cancel())
      ..cacheFor(entryCacheDuration);

    final res = await _fetch();
    watchedIds.add(id);
    listen();
    return res;
  }

  Future<List<JournalEntity>> _fetch() async {
    final res = await ref
        .read(journalRepositoryProvider)
        .getLinkedToEntities(
          linkedTo: id,
        );
    watchedIds.addAll(res.map((item) => item.id));
    return res;
  }
}
