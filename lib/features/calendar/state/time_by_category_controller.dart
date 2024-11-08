import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:visibility_detector/visibility_detector.dart';

part 'time_by_category_controller.g.dart';

@riverpod
class TimeByCategoryController extends _$TimeByCategoryController {
  TimeByCategoryController() {
    listen();
  }

  StreamSubscription<Set<String>>? _updateSubscription;
  bool _isVisible = true;

  void listen() {
    _updateSubscription = getIt<UpdateNotifications>()
        .updateStream
        .throttleTime(
          const Duration(seconds: 5),
          leading: false,
          trailing: true,
        )
        .listen((_) async {
      if (_isVisible) {
        final timeSpanDays = ref.read(timeFrameControllerProvider);
        final latest = await _fetch(timeSpanDays);
        state = AsyncData(latest);
      }
    });
  }

  void onVisibilityChanged(VisibilityInfo info) {
    _isVisible = info.visibleFraction > 0.5;
    if (_isVisible) {
      final timeSpanDays = ref.read(timeFrameControllerProvider);
      _fetch(timeSpanDays).then((latest) {
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      });
    }
  }

  @override
  Future<Map<DateTime, Map<CategoryDefinition?, Duration>>> build() async {
    ref.onDispose(() => _updateSubscription?.cancel());
    final timeSpanDays = ref.watch(timeFrameControllerProvider);
    final data = await _fetch(timeSpanDays);
    return data;
  }

  Future<Map<DateTime, Map<CategoryDefinition?, Duration>>> _fetch(
    int timeSpanDays,
  ) async {
    final now = DateTime.now();
    final db = getIt<JournalDb>();
    final data = <DateTime, Map<CategoryDefinition?, Duration>>{};
    final start = now.dayAtMidnight.subtract(Duration(days: timeSpanDays));

    getDaysAtNoon(timeSpanDays, now).forEach((day) {
      data[day] = <CategoryDefinition?, Duration>{};
    });

    final items = await db.sortedJournalEntities(
      rangeStart: start,
      rangeEnd: now.add(const Duration(days: 1)).dayAtMidnight,
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

        final noon = journalEntity.meta.dateFrom.dayAtNoon;
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
class TimeFrameController extends _$TimeFrameController {
  int _timeSpanDays = 30;

  @override
  int build() {
    return _timeSpanDays;
  }

  void onValueChanged(int days) {
    _timeSpanDays = days;
    state = days;
  }
}

@riverpod
Future<List<TimeByDayAndCategory>> timeByDayChart(Ref ref) async {
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

List<DateTime> getDaysAtNoon(int rangeDays, DateTime rangeEnd) {
  return List<DateTime>.generate(rangeDays, (days) {
    final day = rangeEnd.subtract(Duration(days: days));
    return day.dayAtNoon;
  });
}

@riverpod
Future<int> maxCategoriesCount(Ref ref) async {
  final events = ref.watch(timeByDayChartProvider).value;
  final categoryIdsByDay = <DateTime, Set<String>>{};
  final nonZeroEvents = events?.where((e) => e.duration > Duration.zero);
  nonZeroEvents?.forEach((e) {
    categoryIdsByDay[e.date] = categoryIdsByDay[e.date] ?? {};
    categoryIdsByDay[e.date]?.add(e.categoryId);
  });
  return categoryIdsByDay.values.map((e) => e.length).toList().maxOrNull ?? 0;
}
