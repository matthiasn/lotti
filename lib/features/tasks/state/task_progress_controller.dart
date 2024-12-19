import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/time_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_progress_controller.g.dart';

@riverpod
class TaskProgressController extends _$TaskProgressController {
  TaskProgressController() {
    listen();
  }
  late final String entryId;
  final _durations = <String, Duration>{};
  final _subscribedIds = <String>{};
  Duration? _estimate;
  StreamSubscription<Set<String>>? _updateSubscription;
  StreamSubscription<JournalEntity?>? _timeServiceSubscription;
  final TimeService _timeService = getIt<TimeService>();

  void listen() {
    _updateSubscription =
        getIt<UpdateNotifications>().updateStream.listen((affectedIds) async {
      if (affectedIds.intersection(_subscribedIds).isNotEmpty) {
        final latest = await _fetch();
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      }
    });

    _timeServiceSubscription = _timeService.getStream().listen((journalEntity) {
      if (journalEntity != null) {
        if (_timeService.linkedFrom?.id != entryId) {
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
    entryId = id;
    _subscribedIds.add(id);
    ref
      ..onDispose(() => _updateSubscription?.cancel())
      ..onDispose(() => _timeServiceSubscription?.cancel());
    final progress = await _fetch();
    return progress;
  }

  Future<TaskProgressState?> _fetch() async {
    final task = await getIt<JournalDb>().journalEntityById(entryId);

    if (task is! Task) {
      return null;
    }

    _estimate = task.data.estimate;
    final items = await getIt<JournalDb>().getLinkedEntities(entryId);
    final linkedIds = items.map((item) => item.id).toList();
    _subscribedIds.addAll(linkedIds);

    _durations.clear();
    for (final journalEntity in items) {
      if (journalEntity is! Task) {
        final duration = entryDuration(journalEntity);
        _durations[journalEntity.meta.id] = duration;
      }
    }

    return _getProgress();
  }

  TaskProgressState _getProgress() {
    var progress = Duration.zero;
    for (final duration in _durations.values) {
      progress = progress + duration;
    }

    return TaskProgressState(
      progress: progress,
      estimate: _estimate ?? Duration.zero,
    );
  }
}
