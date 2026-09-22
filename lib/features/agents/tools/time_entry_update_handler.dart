import 'package:clock/clock.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/time_entry_datetime.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/time_service.dart';

/// Updates an existing time-entry journal entry linked to a task: its text,
/// its range, or both.
///
/// Whether a timer is ticking on the entry never decides whether the edit
/// applies. A proposal written while the timer ran on one device must still
/// apply when it is confirmed on another, after the timer stopped, or after a
/// restart — the text of an entry is the same edit in every one of those
/// cases. A running timer only narrows which fields the edit may carry:
///
/// - **Running on this device** ([TimeService.getCurrent]): text only. Its end
///   is live and its start anchors the ticking duration, so `startTime` and
///   `endTime` are refused until it stops. The write stamps the end as now,
///   as the entry editor does when it saves a running timer, and replaces the
///   service's snapshot so the running indicator and the next wake read the
///   new text without a reload.
/// - **Otherwise** — completed, or running on another device: any
///   combination.
///
/// A failure the arguments alone decide is [ToolExecutionResult.nonRetryable],
/// so a confirmed proposal that can never apply is retracted instead of left
/// behind as a dead retry. A failure that depends on state — an entry not
/// synced to this device yet, a timer that will stop, a failed write — stays
/// retryable.
class TimeEntryUpdateHandler {
  TimeEntryUpdateHandler({
    required this._persistenceLogic,
    required this._journalDb,
    required this._timeService,
    this._domainLogger,
  });

  final PersistenceLogic _persistenceLogic;
  final JournalDb _journalDb;
  final TimeService _timeService;
  final DomainLogger? _domainLogger;

  static const _sub = 'TimeEntryUpdateHandler';

  /// Applies the agent's edits (`summary`, `startTime`, `endTime`) to the
  /// time entry identified by `entryId` in [args], scoped to [sourceTaskId].
  /// Returns a failed [ToolExecutionResult] when the arguments are invalid,
  /// the entry is not a time entry of this task, a timer running on this
  /// device would have its range edited, or the new range is invalid.
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
        nonRetryable: true,
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
        nonRetryable: true,
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
          nonRetryable: true,
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
        output:
            'Error: entry $entryId not found (deleted, or not synced to this '
            'device yet)',
        errorMessage: 'Entry not found',
      );
    }

    if (entry is! JournalEntry) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: entry $entryId is not a time-tracking journal entry',
        errorMessage: 'Unsupported entry type',
        nonRetryable: true,
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

    final editsRange = hasStartTime || hasEndTime;
    final isRunningHere = _timeService.getCurrent()?.meta.id == entryId;
    if (isRunningHere && editsRange) {
      return ToolExecutionResult(
        success: false,
        output:
            'Error: entry $entryId is a running timer — its start and end '
            'cannot change until the timer is stopped',
        errorMessage: 'Running timer range is locked',
      );
    }

    final now = clock.now();
    final resolvedDateFrom = startTime.value ?? entry.meta.dateFrom;
    final resolvedDateTo = isRunningHere
        ? now
        : endTime.value ?? entry.meta.dateTo;

    // Only a range edit is checked against the range. A text-only edit must
    // apply whatever is stored — above all to a timer still ticking on
    // another device, whose synced entry has not been given a length yet.
    if (editsRange && !resolvedDateTo.isAfter(resolvedDateFrom)) {
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
      dateTo: isRunningHere ? now : endTime.value,
    );

    if (!ok) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: failed to persist time entry update',
        errorMessage: 'updateJournalEntry returned false',
      );
    }

    if (isRunningHere) {
      // Its range edits were refused above, so the summary is what changed.
      _timeService.updateCurrent(
        entry.copyWith(
          entryText: entryText,
          meta: entry.meta.copyWith(dateTo: now, updatedAt: now),
        ),
      );
    }

    _domainLogger?.log(
      LogDomain.agentWorkflow,
      'Updated ${isRunningHere ? 'running timer' : 'time entry'} '
      '${DomainLogger.sanitizeId(entryId)} linked to '
      '${DomainLogger.sanitizeId(sourceTaskId)}',
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
    if (raw is! String || raw.trim().isEmpty) {
      return (
        value: null,
        error: ToolExecutionResult(
          success: false,
          output:
              'Error: "$key" must be a valid ISO 8601 datetime '
              'with explicit local time',
          errorMessage: 'Missing or invalid $key',
          nonRetryable: true,
        ),
      );
    }

    final parsed = parseTimeEntryLocalDateTime(raw.trim());
    if (parsed == null) {
      return (
        value: null,
        error: ToolExecutionResult(
          success: false,
          output:
              'Error: "$key" must be a valid ISO 8601 datetime '
              'with explicit local time',
          errorMessage: 'Unparseable $key',
          nonRetryable: true,
        ),
      );
    }

    return (value: parsed, error: null);
  }

  String _formatUpdatedRange(DateTime dateFrom, DateTime dateTo) =>
      '(${formatTimeEntryHhMm(dateFrom)}–${formatTimeEntryHhMm(dateTo)})';
}
