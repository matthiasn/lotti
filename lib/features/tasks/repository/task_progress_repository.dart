import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_progress_repository.g.dart';

@Riverpod(keepAlive: true)
TaskProgressRepository taskProgressRepository(Ref ref) {
  return TaskProgressRepository();
}

class TaskProgressRepository {
  /// Determines if an entity's duration should count toward time spent.
  ///
  /// Excludes the following entity types:
  /// - [Task]: represents task structure, not logged work
  /// - [AiResponseEntry]: represents AI outputs, not logged work
  /// - [JournalAudio]: audio recording duration should not count as time spent,
  ///   as it would cause double-counting (e.g., recording a 1-hour meeting
  ///   while also logging a 1-hour time entry for the same meeting)
  static bool _shouldCountDuration(JournalEntity entity) =>
      entity is! Task && entity is! AiResponseEntry && entity is! JournalAudio;

  /// Calculate total time spent from a list of entities.
  ///
  /// Uses [_shouldCountDuration] to filter out entities that don't represent
  /// logged work, then sums the durations of the remaining entities.
  ///
  /// This is the canonical implementation of time-spent calculation logic.
  /// Both [getTaskProgressData] and `AiInputRepository._calculateTimeSpentFromEntities`
  /// use this same filtering logic.
  static Duration sumTimeSpentFromEntities(List<JournalEntity> entities) {
    var total = Duration.zero;
    for (final entity in entities) {
      if (_shouldCountDuration(entity)) {
        total += entryDuration(entity);
      }
    }
    return total;
  }

  Future<(Duration?, Map<String, Duration>)?> getTaskProgressData({
    required String id,
  }) async {
    final durations = <String, Duration>{};
    final task = await getIt<JournalDb>().journalEntityById(id);

    if (task is! Task) {
      return null;
    }

    final estimate = task.data.estimate;
    final items = await getIt<JournalDb>().getLinkedEntities(id);

    for (final journalEntity in items) {
      if (_shouldCountDuration(journalEntity)) {
        final duration = entryDuration(journalEntity);
        durations[journalEntity.id] = duration;
      }
    }

    return (estimate, durations);
  }

  TaskProgressState getTaskProgress({
    required Map<String, Duration> durations,
    Duration? estimate,
  }) {
    var progress = Duration.zero;
    for (final duration in durations.values) {
      progress = progress + duration;
    }

    return TaskProgressState(
      progress: progress,
      estimate: estimate ?? Duration.zero,
    );
  }
}
