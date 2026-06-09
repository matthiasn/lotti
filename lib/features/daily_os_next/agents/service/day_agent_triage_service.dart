part of 'day_agent_capture_service.dart';

/// Reconcile-triage pipeline of [DayAgentCaptureService]; same
/// delegator pattern as the corpus part.
extension DayAgentTriageService on DayAgentCaptureService {
  /// Applies one reconcile triage action to a task.
  ///
  /// The target task must be inside the planner's category allow-list:
  /// triage mutates task status/due dates, so the planner must not be able
  /// to close or re-date tasks outside its configured scope.
  Future<Task> applyTriageImpl({
    required String agentId,
    required String taskId,
    required String action,
    DateTime? deferTo,
  }) async {
    final identity = await _requireIdentity(agentId);
    final entity = await journalDb.journalEntityById(taskId);
    if (entity is! Task) {
      throw DayAgentCaptureException('task $taskId not found');
    }
    if (!DayAgentCaptureService._categoryAllowed(
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
          due: _endOfDay(
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

    final applied = await this.journalRepository.updateJournalEntity(updated);
    if (!applied) {
      throw DayAgentCaptureException('failed to update task $taskId');
    }
    onPersistedStateChanged?.call(taskId);
    return updated;
  }
}
