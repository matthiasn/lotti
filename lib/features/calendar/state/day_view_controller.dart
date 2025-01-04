import 'dart:async';

import 'package:calendar_view/calendar_view.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/calendar/state/calendar_event.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tinycolor2/tinycolor2.dart';
import 'package:visibility_detector/visibility_detector.dart';

part 'day_view_controller.g.dart';

@riverpod
class DayViewController extends _$DayViewController {
  StreamSubscription<Set<String>>? _updateSubscription;
  bool _isVisible = false;

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
        final latest = await _fetch();
        state = AsyncData(latest);
      }
    });
  }

  void onVisibilityChanged(VisibilityInfo info) {
    _isVisible = info.visibleFraction > 0.5;
    if (_isVisible) {
      _fetch().then((latest) {
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      });
    }
  }

  @override
  Future<List<CalendarEventData<CalendarEvent>>> build() async {
    ref
      ..onDispose(() => _updateSubscription?.cancel())
      ..cacheFor(entryCacheDuration);
    final data = await _fetch();
    listen();
    return data;
  }

  Future<List<CalendarEventData<CalendarEvent>>> _fetch({
    int timeSpanDays = 90,
  }) async {
    final now = DateTime.now();
    final db = getIt<JournalDb>();
    final data = <CalendarEventData<CalendarEvent>>[];
    final start = now.dayAtMidnight.subtract(Duration(days: timeSpanDays));

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
      entryIdFromLinkedIds[toId] = {
        fromId,
        ...?entryIdFromLinkedIds[toId],
      };
    }

    entryIdFromLinkedIds.forEach((toId, fromIds) {
      linkedIds.addAll(fromIds);
    });

    final entriesForIds = await db.getJournalEntitiesForIds(linkedIds);
    final linkedEntries = <String, JournalEntity>{};

    for (final item in entriesForIds) {
      linkedEntries[item.meta.id] = item;
    }

    for (final journalEntity in items) {
      final duration = entryDuration(journalEntity);

      if (duration.inSeconds > 60 &&
          (journalEntity is JournalEntry ||
              journalEntity is JournalAudio ||
              journalEntity is WorkoutEntry)) {
        final linkedTo = entryIdFromLinkedIds[journalEntity.meta.id]
            ?.map((id) => linkedEntries[id])
            .nonNulls;

        final linkedEntry = linkedTo?.firstOrNull;
        final categoryId = linkedEntry?.meta.categoryId;

        final category =
            getIt<EntitiesCacheService>().getCategoryById(categoryId);

        final color = colorFromCssHex(
          journalEntity is WorkoutEntry ? '#A8CD66' : category?.color,
          substitute: Colors.grey,
        );

        final startTime = journalEntity.meta.dateFrom;
        final dateTo = journalEntity.meta.dateTo;
        final endTime =
            dateTo.day != startTime.day ? startTime.endOfDay : dateTo;

        final title = journalEntity is WorkoutEntry
            ? journalEntity.data.workoutType
            : switch (linkedEntry) {
                Task() => linkedEntry.data.title,
                JournalEvent() => linkedEntry.data.title,
                _ => '',
              };

        final categoryName = category?.name;
        final categoryPrefix = categoryName != null ? '$categoryName - ' : '';
        final titleWithCategory = '$categoryPrefix$title';

        final description = journalEntity is WorkoutEntry
            ? entryTextForWorkout(
                journalEntity.data,
                includeTitle: false,
              )
            : journalEntity.entryText?.plainText.truncate(100);

        final event = CalendarEvent(
          entity: journalEntity,
          linkedFrom: linkedEntry,
        );

        data.add(
          CalendarEventData<CalendarEvent>(
            event: event,
            date: journalEntity.meta.dateFrom,
            startTime: startTime,
            endTime: endTime,
            color: color,
            title: titleWithCategory,
            titleStyle: TextStyle(
              fontSize: fontSizeMedium,
              color: color.isDark ? Colors.white : Colors.black,
            ),
            descriptionStyle: TextStyle(
              fontSize: fontSizeSmall,
              color: color.isDark ? Colors.white : Colors.black,
            ),
            description: description,
          ),
        );
      }
    }
    return data;
  }
}

@Riverpod(keepAlive: true)
class DaySelectionController extends _$DaySelectionController {
  DaySelectionController();

  @override
  DateTime build() {
    return DateTime.now();
  }

  // ignore: use_setters_to_change_properties
  void selectDay(DateTime day) {
    state = day;
  }
}

@Riverpod(keepAlive: true)
class TimeChartSelectedData extends _$TimeChartSelectedData {
  TimeChartSelectedData();

  Map<int, Map<String, dynamic>> selectedData = {};

  @override
  Map<int, Map<String, dynamic>> build() {
    return {};
  }

  // ignore: use_setters_to_change_properties
  void updateSelection(Map<int, Map<String, dynamic>> data) {
    state = data;
  }
}

@Riverpod(keepAlive: true)
class CalendarGlobalKeyController extends _$CalendarGlobalKeyController {
  CalendarGlobalKeyController();

  final GlobalKey<DayViewState> globalKey = GlobalKey<DayViewState>();

  @override
  GlobalKey<DayViewState> build() {
    final selectedDay = ref.watch(daySelectionControllerProvider);

    if (globalKey.currentState?.currentDate != selectedDay) {
      globalKey.currentState?.jumpToDate(selectedDay);
    }

    return globalKey;
  }
}
