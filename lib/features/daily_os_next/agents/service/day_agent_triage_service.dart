import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_helpers.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_reads.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
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

    final now = clock.now();
    final updated = switch (action.trim()) {
      'today' => _withDueToday(entity, now),
      'doNow' || 'do_now' => _withStatus(
        entity,
        TaskStatus.inProgress(
          id: _uuid.v4(),
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
      ),
      'defer' => entity.copyWith(
        data: entity.data.copyWith(
          due: endOfDay(
            deferTo ??
                (throw const DayAgentCaptureException(
                  'deferTo is required for defer',
                )),
          ),
        ),
      ),
      'done' => _withStatus(
        entity,
        TaskStatus.done(
          id: _uuid.v4(),
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
      ),
      'drop' => _withStatus(
        entity,
        TaskStatus.rejected(
          id: _uuid.v4(),
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
      ),
      _ => throw DayAgentCaptureException('unknown triage action "$action"'),
    };

    final applied = await journalRepository.updateJournalEntity(updated);
    if (!applied) {
      throw DayAgentCaptureException('failed to update task $taskId');
    }
    onPersistedStateChanged?.call(taskId);
    return updated;
  }

  Task _withStatus(Task task, TaskStatus status) {
    return task.copyWith(
      data: task.data.copyWith(
        status: status,
        statusHistory: [...task.data.statusHistory, status],
      ),
    );
  }

  Task _withDueToday(Task task, DateTime now) {
    final updated = task.copyWith(
      data: task.data.copyWith(due: endOfDay(now)),
    );
    final status = task.data.status.toDbString;
    if (status == 'BLOCKED' || status == 'ON HOLD') {
      return _withStatus(
        updated,
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
