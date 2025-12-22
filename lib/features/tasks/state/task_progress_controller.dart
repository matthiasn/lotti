import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/repository/task_progress_repository.dart';
import 'package:lotti/features/tasks/state/update_stream_listener.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_progress_controller.g.dart';

@riverpod
class TaskProgressController extends _$TaskProgressController {
  final _durations = <String, Duration>{};
  Duration? _estimate;
  late final UpdateStreamListener<TaskProgressState> _listener;
  StreamSubscription<JournalEntity?>? _timeServiceSubscription;
  final TimeService _timeService = getIt<TimeService>();

  void _listenToTimeService() {
    _timeServiceSubscription = _timeService.getStream().listen((journalEntity) {
      if (journalEntity != null) {
        if (_timeService.linkedFrom?.id != id) {
          return;
        }

        final duration = entryDuration(journalEntity);
        _durations[journalEntity.meta.id] = duration;
        state = AsyncData(_getProgress());
      }
    });
  }

  @override
  Future<TaskProgressState?> build({required String id}) async {
    _listener = ref.createUpdateStreamListener<TaskProgressState>(
      fetcher: _fetch,
      getState: () => state.value,
      setState: (value) => state = AsyncData(value),
      initialIds: {id},
    );
    ref
      ..onDispose(() => _timeServiceSubscription?.cancel())
      ..cacheFor(entryCacheDuration);

    final progress = await _fetch();
    _listener.start();
    _listenToTimeService();
    return progress;
  }

  Future<TaskProgressState?> _fetch() async {
    final res = await ref
        .read(taskProgressRepositoryProvider)
        .getTaskProgressData(id: id);

    _estimate = res?.$1;
    final durations = res?.$2;

    if (durations == null) {
      return null;
    }

    _durations
      ..clear()
      ..addAll(durations);

    _listener.addIds(durations.keys);

    return _getProgress();
  }

  TaskProgressState _getProgress() {
    return ref
        .read(taskProgressRepositoryProvider)
        .getTaskProgress(durations: _durations, estimate: _estimate);
  }
}
