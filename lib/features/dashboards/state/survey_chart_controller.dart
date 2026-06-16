import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'survey_chart_controller.g.dart';

/// Loads the survey-completion entities of one `surveyType` within a date range
/// and keeps them live for its chart.
///
/// Caches for `dashboardCacheDuration` and re-fetches whenever a survey-related
/// [UpdateNotifications] event fires (pushing new state only when the rows
/// changed). The entities are returned unaggregated; the chart turns each
/// survey's `calculatedScores` into lines via `surveyLines`.
@riverpod
class SurveyChartDataController extends _$SurveyChartDataController {
  final JournalDb _journalDb = getIt<JournalDb>();

  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();

  /// Subscribes to survey update notifications and re-fetches on change.
  /// Called once from `build`; cancelled on dispose.
  void listen() {
    _updateSubscription = _updateNotifications.updateStream.listen((
      affectedIds,
    ) async {
      if (affectedIds.contains(surveyNotification)) {
        final latest = await _fetch();
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      }
    });
  }

  @override
  Future<List<JournalEntity>> build({
    required String surveyType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    ref
      ..onDispose(() {
        _updateSubscription?.cancel();
      })
      ..cacheFor(dashboardCacheDuration);

    final data = await _fetch();
    listen();
    return data;
  }

  Future<List<JournalEntity>> _fetch() async {
    return _journalDb.getSurveyCompletionsByType(
      type: surveyType,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }
}
