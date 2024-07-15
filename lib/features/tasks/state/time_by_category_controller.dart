import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'time_by_category_controller.g.dart';

@riverpod
class TimeByCategoryController extends _$TimeByCategoryController {
  TimeByCategoryController() {
    listen();
  }

  StreamSubscription<Set<String>>? _updateSubscription;

  void listen() {
    _updateSubscription = getIt<UpdateNotifications>()
        .updateStream
        .listen((affectedIds) async {});
  }

  @override
  Future<Map<String, Duration>> build() async {
    ref.onDispose(() => _updateSubscription?.cancel());
    final data = await _fetch();
    return data;
  }

  Future<Map<String, Duration>> _fetch() async {
    final db = getIt<JournalDb>();
    final data = <String, Duration>{};
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final dbEntities = await db.sortedInRange(start, now).get();
    final items = entityStreamMapper(dbEntities);
    debugPrint('TimeByCategoryController length: ${items.length}');

    for (final journalEntity in items) {
      final duration = entryDuration(journalEntity);

      if (journalEntity is JournalEntry || journalEntity is JournalAudio) {
        final linkedTo =
            await db.linkedToJournalEntities(journalEntity.meta.id).get();
        final categoryId = entityStreamMapper(linkedTo)
            .map((item) {
              return item.meta.categoryId;
            })
            .whereNotNull()
            .firstOrNull;

        final category =
            getIt<EntitiesCacheService>().getCategoryById(categoryId);

        final key = category?.name ?? 'unassigned';
        final timeByCategory = data[key] ?? Duration.zero;
        data[key] = timeByCategory + duration;
      }
    }

    debugPrint('TimeByCategoryController: $data');

    return data;
  }
}
