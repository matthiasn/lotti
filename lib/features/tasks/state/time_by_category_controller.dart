import 'dart:async';

import 'package:collection/collection.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
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
  Future<Map<DateTime, Map<CategoryDefinition?, Duration>>> build() async {
    ref.onDispose(() => _updateSubscription?.cancel());
    final data = await _fetch();
    return data;
  }

  Future<Map<DateTime, Map<CategoryDefinition?, Duration>>> _fetch() async {
    final now = DateTime.now();
    final db = getIt<JournalDb>();
    final data = <DateTime, Map<CategoryDefinition?, Duration>>{};
    final start = now.subtract(const Duration(days: 30));
    final items = await db.sortedJournalEntities(
      rangeStart: start,
      rangeEnd: now,
    );
    final itemIds = items.map((item) => item.meta.id).toSet();
    final links = await db.linksForEntryIds(itemIds);
    final entryIdFromLinkedIds = <String, Set<String>>{};
    final linkedIds = <String>{};

    for (final link in links) {
      final fromId = link.fromId;
      final toId = link.toId;
      final prev = entryIdFromLinkedIds[toId] ?? <String>{}
        ..add(fromId);
      entryIdFromLinkedIds[toId] = prev;
    }

    entryIdFromLinkedIds.forEach((fromId, toIds) {
      linkedIds.addAll(toIds);
    });

    final entriesForIds = await db.getJournalEntitiesForIds(linkedIds);
    final linkedEntries = <String, JournalEntity>{};

    for (final item in entriesForIds) {
      linkedEntries[item.meta.id] = item;
    }

    for (final journalEntity in items) {
      final duration = entryDuration(journalEntity);

      if (journalEntity is JournalEntry || journalEntity is JournalAudio) {
        final linkedTo =
            (entryIdFromLinkedIds[journalEntity.meta.id] ?? <String>{})
                .map((id) {
          return linkedEntries[id];
        }).whereNotNull();

        final categoryId = linkedTo
            .map((item) {
              return item.meta.categoryId;
            })
            .whereNotNull()
            .firstOrNull;

        final category =
            getIt<EntitiesCacheService>().getCategoryById(categoryId);

        final noon = journalEntity.meta.dateFrom.noon;
        final dataByDay = data[noon] ?? <CategoryDefinition?, Duration>{};
        final timeByCategory = dataByDay[category] ?? Duration.zero;
        dataByDay[category] = timeByCategory + duration;
        data[noon] = dataByDay;
      }
    }
    return data;
  }
}

@riverpod
Future<List<TimeByDayAndCategory>> timeByDayChart(TimeByDayChartRef ref) async {
  final timeByCategoryAndDay = ref.watch(timeByCategoryControllerProvider);
  return _convertTimeByCategory(timeByCategoryAndDay.value);
}

class TimeByDayAndCategory {
  TimeByDayAndCategory({
    required this.date,
    required this.categoryId,
    required this.categoryDefinition,
    required this.duration,
  });

  final DateTime date;
  final String categoryId;
  final CategoryDefinition? categoryDefinition;
  final Duration duration;
}

List<TimeByDayAndCategory> _convertTimeByCategory(
  Map<DateTime, Map<CategoryDefinition?, Duration>>? timeByCategoryAndDay,
) {
  final data = <TimeByDayAndCategory>[];
  timeByCategoryAndDay?.forEach((date, timeByCategory) {
    final sortedCategories = getIt<EntitiesCacheService>().sortedCategories;
    for (final categoryDefinition in sortedCategories) {
      data.add(
        TimeByDayAndCategory(
          date: date,
          categoryId: categoryDefinition.id,
          categoryDefinition: categoryDefinition,
          duration: timeByCategory[categoryDefinition] ?? Duration.zero,
        ),
      );
    }

    data.add(
      TimeByDayAndCategory(
        date: date,
        categoryId: 'unassigned',
        categoryDefinition: null,
        duration: timeByCategory[null] ?? Duration.zero,
      ),
    );
  });

  return data.reversed.toList();
}
