import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os/util/time_range_utils.dart';
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
  /// logged work, then calculates the union of their time ranges to prevent
  /// double-counting overlapping entries.
  ///
  /// This is the canonical implementation of time-spent calculation logic.
  /// Both [getTaskProgressData] and `AiInputRepository._calculateTimeSpentFromEntities`
  /// use this same filtering logic.
  static Duration sumTimeSpentFromEntities(List<JournalEntity> entities) {
    return calculateUnionDuration(
      entities
          .where(_shouldCountDuration)
          .map(
            (entity) => TimeRange(
              start: entity.meta.dateFrom,
              end: entity.meta.dateTo,
            ),
          )
          .toList(),
    );
  }

  Future<(Duration?, Map<String, TimeRange>)?> getTaskProgressData({
    required String id,
  }) async {
    final timeRanges = <String, TimeRange>{};
    final task = await getIt<JournalDb>().journalEntityById(id);

    if (task is! Task) {
      return null;
    }

    final estimate = task.data.estimate;
    final items = await getIt<JournalDb>().getLinkedEntities(id);

    for (final journalEntity in items) {
      if (_shouldCountDuration(journalEntity)) {
        timeRanges[journalEntity.id] = TimeRange(
          start: journalEntity.meta.dateFrom,
          end: journalEntity.meta.dateTo,
        );
      }
    }

    return (estimate, timeRanges);
  }

  TaskProgressState getTaskProgress({
    required Map<String, TimeRange> timeRanges,
    Duration? estimate,
  }) {
    final progress = calculateUnionDuration(timeRanges.values.toList());

    return TaskProgressState(
      progress: progress,
      estimate: estimate ?? Duration.zero,
    );
  }
}
