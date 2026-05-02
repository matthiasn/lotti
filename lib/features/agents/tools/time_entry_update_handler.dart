import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/time_entry_datetime.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/time_service.dart';

/// Updates an existing completed time-entry journal entry linked to a task.
///
/// This handler is intentionally separate from the running-timer update path:
/// completed-entry edits do not synchronize [TimeService] state, and live timers
/// must keep using the running-timer-specific path.
class TimeEntryUpdateHandler {
  TimeEntryUpdateHandler({
    required PersistenceLogic persistenceLogic,
    required JournalDb journalDb,
    required TimeService timeService,
    DomainLogger? domainLogger,
  }) : _persistenceLogic = persistenceLogic,
       _journalDb = journalDb,
       _timeService = timeService,
       _domainLogger = domainLogger;

  final PersistenceLogic _persistenceLogic;
  final JournalDb _journalDb;
  final TimeService _timeService;
  final DomainLogger? _domainLogger;

  static const _sub = 'TimeEntryUpdateHandler';

  Future<ToolExecutionResult> handle(
    String sourceTaskId,
    Map<String, dynamic> args,
  ) async {
    final rawEntryId = args['entryId'];
    final entryId = rawEntryId is String ? rawEntryId.trim() : '';
    if (entryId.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "entryId" must be a non-empty string',
        errorMessage: 'Missing or invalid entryId',
      );
    }

    final hasSummary = args.containsKey('summary');
    final hasStartTime = args.containsKey('startTime');
    final hasEndTime = args.containsKey('endTime');

    if (!hasSummary && !hasStartTime && !hasEndTime) {
      return const ToolExecutionResult(
        success: false,
        output:
            'Error: at least one of summary, startTime, endTime must be '
            'provided',
        errorMessage: 'No changes specified',
      );
    }

    String? summary;
    if (hasSummary) {
      final rawSummary = args['summary'];
      summary = rawSummary is String ? rawSummary.trim() : null;
      if (summary == null || summary.isEmpty || summary.length > 500) {
        return const ToolExecutionResult(
          success: false,
          output:
              'Error: "summary" must be a non-empty string with at most '
              '500 characters',
          errorMessage: 'Missing, empty, or too-long summary',
        );
      }
    }

    final startTime = _parseOptionalTime(args, 'startTime');
    if (startTime.error != null) return startTime.error!;

    final endTime = _parseOptionalTime(args, 'endTime');
    if (endTime.error != null) return endTime.error!;

    final entry = await _journalDb.journalEntityById(entryId);
    if (entry == null) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: entry $entryId not found',
        errorMessage: 'Entry not found',
      );
    }

    if (entry is! JournalEntry) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: entry $entryId is not a time-tracking journal entry',
        errorMessage: 'Unsupported entry type',
      );
    }

    final linkedEntries = await _journalDb.getLinkedEntities(sourceTaskId);
    final isLinkedFromTask = linkedEntries.any(
      (linked) => linked.meta.id == entryId,
    );
    if (!isLinkedFromTask) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: entry $entryId is not linked from this task',
        errorMessage: 'Entry is not linked from source task',
      );
    }

    if (_timeService.getCurrent()?.meta.id == entryId) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: use update_running_timer to edit the active timer',
        errorMessage: 'Entry is the active timer',
      );
    }

    final resolvedDateFrom = startTime.value ?? entry.meta.dateFrom;
    final resolvedDateTo = endTime.value ?? entry.meta.dateTo;

    if (!resolvedDateTo.isAfter(resolvedDateFrom)) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: endTime must be after startTime',
        errorMessage: 'endTime is not after startTime',
      );
    }

    final entryText = summary != null
        ? EntryText(plainText: '$summary [generated]')
        : null;

    final ok = await _persistenceLogic.updateJournalEntry(
      journalEntityId: entryId,
      entryText: entryText,
      dateFrom: startTime.value,
      dateTo: endTime.value,
    );

    if (!ok) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: failed to persist time entry update',
        errorMessage: 'updateJournalEntry returned false',
      );
    }

    _domainLogger?.log(
      LogDomains.agentWorkflow,
      'Updated time entry $entryId linked to $sourceTaskId',
      subDomain: _sub,
    );

    return ToolExecutionResult(
      success: true,
      output:
          'Updated time entry ${_formatUpdatedRange(resolvedDateFrom, resolvedDateTo)}',
      mutatedEntityId: entryId,
    );
  }

  ({DateTime? value, ToolExecutionResult? error}) _parseOptionalTime(
    Map<String, dynamic> args,
    String key,
  ) {
    if (!args.containsKey(key)) return (value: null, error: null);

    final raw = args[key];
    if (raw is! String || raw.isEmpty) {
      return (
        value: null,
        error: ToolExecutionResult(
          success: false,
          output:
              'Error: "$key" must be a valid ISO 8601 datetime '
              'with explicit local time',
          errorMessage: 'Missing or invalid $key',
        ),
      );
    }

    final parsed = parseTimeEntryLocalDateTime(raw);
    if (parsed == null) {
      return (
        value: null,
        error: ToolExecutionResult(
          success: false,
          output:
              'Error: "$key" must be a valid ISO 8601 datetime '
              'with explicit local time',
          errorMessage: 'Unparseable $key',
        ),
      );
    }

    return (value: parsed, error: null);
  }

  String _formatUpdatedRange(DateTime dateFrom, DateTime dateTo) =>
      '(${formatTimeEntryHhMm(dateFrom)}–${formatTimeEntryHhMm(dateTo)})';
}
