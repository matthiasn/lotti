import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/state/health_data.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'health_chart_controller.g.dart';

@riverpod
class HealthChartDataController extends _$HealthChartDataController {
  final JournalDb _journalDb = getIt<JournalDb>();

  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();

  void listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((affectedIds) async {
      if (affectedIds.contains(healthDataType)) {
        final latest = await _fetch();
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      }
    });
  }

  @override
  Future<List<JournalEntity>> build({
    required String healthDataType,
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
    return _journalDb.getQuantitativeByType(
      type: healthDataType,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }
}

@riverpod
class HealthObservationsController extends _$HealthObservationsController {
  HealthObservationsController() {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      Future.delayed(Duration(milliseconds: 500 + Random().nextInt(500)), () {
        getIt<HealthImport>().fetchHealthDataDelta(healthDataType);
      });
    }
  }

  @override
  Future<List<Observation>> build({
    required String healthDataType,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    ref.cacheFor(dashboardCacheDuration);

    final items = ref
            .watch(
              healthChartDataControllerProvider(
                healthDataType: healthDataType,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ),
            )
            .valueOrNull ??
        [];

    return aggregateByType(items, healthDataType);
  }
}
