import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_reads.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/utils/day_agent_capture_helpers.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Reconcile-triage pipeline for the day-agent capture flow. The capture
/// service keeps a thin delegator so mocks of the service still intercept
/// the public method.
class DayAgentTriageService {
  /// Creates the triage collaborator.
  DayAgentTriageService({
    required this.journalDb,
    required this.journalRepository,
    required this.reads,
    this.onPersistedStateChanged,
  });

  /// Journal DB used for task reads.
  final JournalDb journalDb;

  /// Journal repository used for task mutations.
  final JournalRepository journalRepository;

  /// Shared agent-identity resolution.
  final DayAgentCaptureReads reads;

  /// Callback fired when persisted state changes.
  final void Function(String id)? onPersistedStateChanged;

  /// Applies one reconcile triage action to a task.
  ///
  /// The target task must be inside the planner's category allow-list:
  /// triage mutates task status/due dates, so the planner must not be able
  /// to close or re-date tasks outside its configured scope.
  Future<Task> applyTriage({
    required String agentId,
    required String taskId,
    required String action,
    DateTime? deferTo,
  }) async {
    final identity = await reads.requireIdentity(agentId);
    final entity = await journalDb.journalEntityById(taskId);
    if (entity is! Task) {
      throw DayAgentCaptureException('task $taskId not found');
    }
    if (!categoryAllowed(
      entity.meta.categoryId,
      identity.allowedCategoryIds,
    )) {
      throw DayAgentCaptureException(
        'task $taskId is outside the allowed categories for this planner',
      );
    }

    final change = _triage(action.trim(), clock.now(), deferTo);
    // The scope is checked again on the task the change is written on: a
    // move to a category outside it — by sync or the user — after the read
    // above leaves the task alone.
    bool inScope(Task task) =>
        categoryAllowed(task.meta.categoryId, identity.allowedCategoryIds);
    final updated = await journalRepository.updateTask(
      taskId,
      change,
      onlyIf: inScope,
    );
    if (updated == null) {
      throw DayAgentCaptureException('failed to update task $taskId');
    }
    if (!inScope(updated)) {
      throw DayAgentCaptureException(
        'task $taskId is outside the allowed categories for this planner',
      );
    }
    onPersistedStateChanged?.call(taskId);
    return updated;
  }

  /// The change triage [action] makes to the task as stored, so a field set
  /// since the task was read — by sync, the user or the task agent — is
  /// kept, and a status it sets is recorded in the status history
  /// (`specs/tla/TaskFieldWrites.tla`).
  TaskData Function(TaskData stored) _triage(
    String action,
    DateTime now,
    DateTime? deferTo,
  ) {
    TaskStatus status(
      TaskStatus Function({
        required String id,
        required DateTime createdAt,
        required int utcOffset,
      })
      make,
    ) => make(
      id: _uuid.v4(),
      createdAt: now,
      utcOffset: now.timeZoneOffset.inMinutes,
    );
    return switch (action) {
      'today' => (stored) => _withDueToday(stored, now),
      'doNow' ||
      'do_now' => (stored) => stored.withStatus(status(TaskStatus.inProgress)),
      'defer' => _deferTo(
        deferTo ??
            (throw const DayAgentCaptureException(
              'deferTo is required for defer',
            )),
      ),
      'done' => (stored) => stored.withStatus(status(TaskStatus.done)),
      'drop' => (stored) => stored.withStatus(status(TaskStatus.rejected)),
      _ => throw DayAgentCaptureException('unknown triage action "$action"'),
    };
  }

  TaskData Function(TaskData stored) _deferTo(DateTime day) =>
      (stored) => stored.copyWith(due: endOfDay(day));

  TaskData _withDueToday(TaskData stored, DateTime now) {
    final updated = stored.copyWith(due: endOfDay(now));
    final status = stored.status.toDbString;
    if (status == 'BLOCKED' || status == 'ON HOLD') {
      return updated.withStatus(
        TaskStatus.open(
          id: _uuid.v4(),
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
      );
    }
    return updated;
  }
}
