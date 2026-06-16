import 'package:clock/clock.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/time_service.dart';

/// `errorMessage` constants for the running-timer update tool, used so the
/// orchestrator and tests can match failures by a stable string rather than
/// the human-readable `output` shown to the model.
abstract final class RunningTimerUpdateFailure {
  static const invalidSummary = 'Missing, empty, or too-long summary';
  static const invalidTimerId = 'Missing or invalid timerId';
  static const noActiveTimer = 'No active timer';
  static const sourceTaskMismatch = 'Timer source task mismatch';
  static const timerIdMismatch = 'Timer id mismatch';
  static const unsupportedEntityType = 'Unsupported timer entity type';
}

/// Updates the entry text of the currently running timer.
///
/// Used by the task agent when an "Active Running Timer" is in scope: instead
/// of proposing a brand-new time entry that would collide with the running
/// timer (or report effort the timer already covers), the agent proposes
/// rich descriptive text to replace the active timer's entry text.
///
/// The handler refuses to act if no timer is running, or if the running
/// timer's source task does not match `taskId`, or if the running timer's
/// id does not match the `timerId` argument the agent supplied. Together
/// these checks guarantee the proposal still applies at execution time and
/// never crosses task boundaries.
class RunningTimerUpdateHandler {
  RunningTimerUpdateHandler({
    required this._persistenceLogic,
    required this._timeService,
    this._domainLogger,
  });

  final PersistenceLogic _persistenceLogic;
  final TimeService _timeService;
  final DomainLogger? _domainLogger;

  static const _sub = 'RunningTimerUpdateHandler';

  /// Replaces the running timer's entry text with the agent's `summary`,
  /// guarding [sourceTaskId] / `timerId` consistency so a stale proposal can
  /// never edit a timer that has stopped or now belongs to a different task.
  /// Returns a failed [ToolExecutionResult] (carrying a
  /// [RunningTimerUpdateFailure] code) when any guard fails.
  Future<ToolExecutionResult> handle(
    String sourceTaskId,
    Map<String, dynamic> args,
  ) async {
    final rawSummary = args['summary'];
    final summary = rawSummary is String ? rawSummary.trim() : null;
    if (summary == null || summary.isEmpty || summary.length > 500) {
      return const ToolExecutionResult(
        success: false,
        output:
            'Error: "summary" must be a non-empty string with at most '
            '500 characters',
        errorMessage: RunningTimerUpdateFailure.invalidSummary,
      );
    }

    final rawTimerId = args['timerId'];
    final timerId = rawTimerId is String ? rawTimerId.trim() : '';
    if (timerId.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "timerId" must be a non-empty string',
        errorMessage: RunningTimerUpdateFailure.invalidTimerId,
      );
    }

    final current = _timeService.getCurrent();
    if (current == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: no timer is currently running',
        errorMessage: RunningTimerUpdateFailure.noActiveTimer,
      );
    }

    // Order matters: validate task ownership BEFORE comparing IDs. If the
    // active timer belongs to a different task, return a generic mismatch
    // error that never names the real timer id — otherwise an agent waking
    // for task A could probe with arbitrary `timerId` values and read the
    // currently running id for task B out of the error message.
    if (_timeService.linkedFrom?.id != sourceTaskId) {
      return const ToolExecutionResult(
        success: false,
        output:
            'Error: the running timer belongs to a different task and '
            'cannot be updated from this wake',
        errorMessage: RunningTimerUpdateFailure.sourceTaskMismatch,
      );
    }

    if (current.meta.id != timerId) {
      return ToolExecutionResult(
        success: false,
        output:
            'Error: timerId "$timerId" does not match the currently running '
            'timer (${current.meta.id})',
        errorMessage: RunningTimerUpdateFailure.timerIdMismatch,
      );
    }

    if (current is! JournalEntry) {
      return ToolExecutionResult(
        success: false,
        output:
            'Error: running timer entity is not a JournalEntry '
            '(${current.runtimeType})',
        errorMessage: RunningTimerUpdateFailure.unsupportedEntityType,
      );
    }

    final newEntryText = EntryText(plainText: '$summary [generated]');
    final dateTo = clock.now();

    final ok = await _persistenceLogic.updateJournalEntityText(
      timerId,
      newEntryText,
      dateTo,
    );

    if (!ok) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: failed to persist running timer text update',
        errorMessage: 'updateJournalEntityText returned false',
      );
    }

    // Keep the in-memory TimeService snapshot in sync with what was just
    // persisted — text, dateTo, and updatedAt — so the UI's running-timer
    // indicator and the next wake's context see the same values that
    // landed in the DB without waiting for a reload.
    _timeService.updateCurrent(
      current.copyWith(
        entryText: newEntryText,
        meta: current.meta.copyWith(
          dateTo: dateTo,
          updatedAt: dateTo,
        ),
      ),
    );

    _domainLogger?.log(
      LogDomain.agentWorkflow,
      'Updated running timer ${DomainLogger.sanitizeId(timerId)} text '
      'linked to ${DomainLogger.sanitizeId(sourceTaskId)}',
      subDomain: _sub,
    );

    return ToolExecutionResult(
      success: true,
      output: 'Updated running timer text: "$summary"',
      mutatedEntityId: timerId,
    );
  }
}
