import 'dart:async';

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
  final Map<String, Future<(Duration?, Map<String, TimeRange>)?>>
  _inFlightProgressData = {};
  final Set<String> _pendingTaskIds = <String>{};
  final Map<String, List<Completer<(Duration?, Map<String, TimeRange>)?>>>
  _pendingCompleters = {};
  bool _batchScheduled = false;

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
    final inFlight = _inFlightProgressData[id];
    if (inFlight != null) {
      return inFlight;
    }

    final completer = Completer<(Duration?, Map<String, TimeRange>)?>();
    _pendingTaskIds.add(id);
    _pendingCompleters
        .putIfAbsent(
          id,
          () => <Completer<(Duration?, Map<String, TimeRange>)?>>[],
        )
        .add(completer);

    if (!_batchScheduled) {
      _batchScheduled = true;
      scheduleMicrotask(_flushPendingTaskProgressBatch);
    }

    late final Future<(Duration?, Map<String, TimeRange>)?> future;
    future = completer.future.whenComplete(() {
      if (identical(_inFlightProgressData[id], future)) {
        _inFlightProgressData.remove(id);
      }
    });
    _inFlightProgressData[id] = future;
    return future;
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

  Future<void> _flushPendingTaskProgressBatch() async {
    final taskIds = _pendingTaskIds.toSet();
    if (taskIds.isEmpty) {
      _batchScheduled = false;
      return;
    }

    final completersById =
        <String, List<Completer<(Duration?, Map<String, TimeRange>)?>>>{};
    for (final taskId in taskIds) {
      completersById[taskId] = _pendingCompleters.remove(taskId) ?? [];
    }
    _pendingTaskIds.removeAll(taskIds);
    _batchScheduled = false;

    try {
      final db = getIt<JournalDb>();
      final estimatesByTaskId = await db.getTaskEstimatesByIds(taskIds);
      final linkedTimeSpansByTaskId = await db.getBulkLinkedTimeSpans(taskIds);

      for (final taskId in taskIds) {
        final result = !estimatesByTaskId.containsKey(taskId)
            ? null
            : (
                estimatesByTaskId[taskId],
                _buildTimeRanges(linkedTimeSpansByTaskId[taskId] ?? const []),
              );

        for (final completer
            in completersById[taskId] ??
                const <Completer<(Duration?, Map<String, TimeRange>)?>>[]) {
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        }
      }
    } catch (error, stackTrace) {
      for (final completers in completersById.values) {
        for (final completer in completers) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        }
      }
    } finally {
      if (_pendingTaskIds.isNotEmpty && !_batchScheduled) {
        _batchScheduled = true;
        scheduleMicrotask(_flushPendingTaskProgressBatch);
      }
    }
  }

  static Map<String, TimeRange> _buildTimeRanges(
    List<LinkedEntityTimeSpan> timeSpans,
  ) {
    final timeRanges = <String, TimeRange>{};

    for (final timeSpan in timeSpans) {
      timeRanges[timeSpan.id] = TimeRange(
        start: timeSpan.dateFrom,
        end: timeSpan.dateTo,
      );
    }

    return timeRanges;
  }
}
