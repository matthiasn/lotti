import 'package:clock/clock.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/time_service.dart';

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
    required PersistenceLogic persistenceLogic,
    required TimeService timeService,
    DomainLogger? domainLogger,
  }) : _persistenceLogic = persistenceLogic,
       _timeService = timeService,
       _domainLogger = domainLogger;

  final PersistenceLogic _persistenceLogic;
  final TimeService _timeService;
  final DomainLogger? _domainLogger;

  static const _sub = 'RunningTimerUpdateHandler';

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
        errorMessage: 'Missing, empty, or too-long summary',
      );
    }

    final rawTimerId = args['timerId'];
    final timerId = rawTimerId is String ? rawTimerId.trim() : '';
    if (timerId.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "timerId" must be a non-empty string',
        errorMessage: 'Missing or invalid timerId',
      );
    }

    final current = _timeService.getCurrent();
    if (current == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: no timer is currently running',
        errorMessage: 'No active timer',
      );
    }

    if (current.meta.id != timerId) {
      return ToolExecutionResult(
        success: false,
        output:
            'Error: timerId "$timerId" does not match the currently running '
            'timer (${current.meta.id})',
        errorMessage: 'Timer id mismatch',
      );
    }

    if (_timeService.linkedFrom?.id != sourceTaskId) {
      return const ToolExecutionResult(
        success: false,
        output:
            'Error: the running timer belongs to a different task and '
            'cannot be updated from this wake',
        errorMessage: 'Timer source task mismatch',
      );
    }

    if (current is! JournalEntry) {
      return ToolExecutionResult(
        success: false,
        output:
            'Error: running timer entity is not a JournalEntry '
            '(${current.runtimeType})',
        errorMessage: 'Unsupported timer entity type',
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

    // Keep the in-memory TimeService snapshot in sync with the new text so
    // the UI's running-timer indicator and the next wake's context both see
    // the updated description without waiting for a reload.
    _timeService.updateCurrent(
      current.copyWith(entryText: newEntryText),
    );

    _domainLogger?.log(
      LogDomains.agentWorkflow,
      'Updated running timer $timerId text linked to $sourceTaskId',
      subDomain: _sub,
    );

    return ToolExecutionResult(
      success: true,
      output: 'Updated running timer text: "$summary"',
      mutatedEntityId: timerId,
    );
  }
}
