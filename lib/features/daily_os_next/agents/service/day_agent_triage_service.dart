part of 'day_agent_capture_service.dart';

/// Reconcile-triage pipeline of [DayAgentCaptureService]; same
/// delegator pattern as the corpus part.
extension DayAgentTriageService on DayAgentCaptureService {
  /// Applies one reconcile triage action to a task.
  Future<Task> applyTriageImpl({
    required String taskId,
    required String action,
    DateTime? deferTo,
  }) async {
    final entity = await journalDb.journalEntityById(taskId);
    if (entity is! Task) {
      throw DayAgentCaptureException('task $taskId not found');
    }

    final now = clock.now();
    final updated = switch (action.trim()) {
      'today' => DayAgentCaptureService._withDueToday(entity, now),
      'doNow' || 'do_now' => DayAgentCaptureService._withStatus(
        entity,
        TaskStatus.inProgress(
          id: DayAgentCaptureService._uuid.v4(),
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
      ),
      'defer' => entity.copyWith(
        data: entity.data.copyWith(
          due: DayAgentCaptureService._endOfDay(
            deferTo ??
                (throw const DayAgentCaptureException(
                  'deferTo is required for defer',
                )),
          ),
        ),
      ),
      'done' => DayAgentCaptureService._withStatus(
        entity,
        TaskStatus.done(
          id: DayAgentCaptureService._uuid.v4(),
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
      ),
      'drop' => DayAgentCaptureService._withStatus(
        entity,
        TaskStatus.rejected(
          id: DayAgentCaptureService._uuid.v4(),
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
      ),
      _ => throw DayAgentCaptureException('unknown triage action "$action"'),
    };

    final applied = await this.journalRepository.updateJournalEntity(updated);
    if (!applied) {
      throw DayAgentCaptureException('failed to update task $taskId');
    }
    onPersistedStateChanged?.call(taskId);
    return updated;
  }
}
