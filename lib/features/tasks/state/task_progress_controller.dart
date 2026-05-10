import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/util/time_range_utils.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/repository/task_progress_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_progress_controller.g.dart';

@riverpod
class TaskProgressController extends _$TaskProgressController {
  final _timeRanges = <String, TimeRange>{};
  final _subscribedIds = <String>{};
  Duration? _estimate;
  StreamSubscription<Set<String>>? _updateSubscription;
  StreamSubscription<JournalEntity?>? _timeServiceSubscription;
  final TimeService _timeService = getIt<TimeService>();

  void listen() {
    _updateSubscription = getIt<UpdateNotifications>().updateStream.listen((
      affectedIds,
    ) async {
      if (affectedIds.intersection(_subscribedIds).isNotEmpty) {
        final latest = await _fetch();
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      }
    });

    _timeServiceSubscription = _timeService.getStream().listen((journalEntity) {
      if (journalEntity != null) {
        if (_timeService.linkedFrom?.id != id) {
          return;
        }

        _timeRanges[journalEntity.meta.id] = TimeRange(
          start: journalEntity.meta.dateFrom,
          end: journalEntity.meta.dateTo,
        );
        state = AsyncData(_getProgress());
      }
    });
  }

  @override
  Future<TaskProgressState?> build({required String id}) async {
    _subscribedIds.add(id);
    ref
      ..onDispose(() => _updateSubscription?.cancel())
      ..onDispose(() => _timeServiceSubscription?.cancel())
      ..cacheFor(entryCacheDuration);

    final progress = await _fetch();
    listen();
    return progress;
  }

  Future<TaskProgressState?> _fetch() async {
    final res = await ref
        .read(taskProgressRepositoryProvider)
        .getTaskProgressData(id: id);

    _estimate = res?.$1;
    final timeRanges = res?.$2;

    if (timeRanges == null) {
      return null;
    }

    // The DB snapshot's `dateTo` for the currently-running timer is stale
    // (it equals `dateFrom` until a stop or save flushes a fresh `dateTo`
    // back to the row), so re-fetching unconditionally would clobber the
    // in-memory range that the 1Hz `TimeService` ticker owns. That made the
    // cumulative recorded time blip back to 0 every time an unrelated
    // notification (checklist item toggle, sub-entry edit, …) arrived for
    // this task — until the next tick caught the display back up. Preserve
    // the live range across the re-fetch so the running timer never
    // "resets" on incidental task-scoped notifications.
    final live = _timeService.getCurrent();
    final isLiveForThisTask = live != null && _timeService.linkedFrom?.id == id;
    final liveRange = isLiveForThisTask ? _timeRanges[live.meta.id] : null;

    _timeRanges
      ..clear()
      ..addAll(timeRanges);
    if (isLiveForThisTask && liveRange != null) {
      _timeRanges[live.meta.id] = liveRange;
    }

    _subscribedIds.addAll(timeRanges.keys);

    return _getProgress();
  }

  TaskProgressState _getProgress() {
    return ref
        .read(taskProgressRepositoryProvider)
        .getTaskProgress(timeRanges: _timeRanges, estimate: _estimate);
  }
}
