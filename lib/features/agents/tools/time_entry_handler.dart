import 'package:clock/clock.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/time_entry_datetime.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/time_service.dart';

/// Creates a time tracking journal entry linked to the source task.
///
/// Used by the task agent when a user dictates a work session description.
/// Supports two modes:
/// - **Completed session**: both `startTime` and `endTime` provided.
/// - **Running timer**: only `startTime` provided; hooks into [TimeService].
///
/// Completed sessions are validated against the originating wake timestamp when
/// that deferred-execution context is available, so delayed approvals do not
/// incorrectly fail after midnight.
class TimeEntryHandler {
  TimeEntryHandler({
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

  static const _sub = 'TimeEntryHandler';

  /// Creates a time entry and optionally starts a running timer.
  ///
  /// Returns a [ToolExecutionResult] with `mutatedEntityId` set to the new
  /// entry's ID on success.
  Future<ToolExecutionResult> handle(
    String sourceTaskId,
    Map<String, dynamic> args,
  ) async {
    // --- Validate summary ---
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

    // --- Parse and validate startTime ---
    final startTimeRaw = args['startTime'];
    if (startTimeRaw is! String || startTimeRaw.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output:
            'Error: "startTime" must be a valid ISO 8601 datetime '
            'with explicit local time',
        errorMessage: 'Missing or invalid startTime',
      );
    }
    final startTime = parseTimeEntryLocalDateTime(startTimeRaw);
    if (startTime == null) {
      return const ToolExecutionResult(
        success: false,
        output:
            'Error: "startTime" must be a valid ISO 8601 datetime '
            'with explicit local time',
        errorMessage: 'Unparseable startTime',
      );
    }

    final now = clock.now();

    // --- Parse and validate optional endTime ---
    // Use containsKey to distinguish "key absent" (running timer) from
    // "key present with null value" (which is also an error, not running timer).
    final hasEndTime = args.containsKey('endTime');
    DateTime? endTime;
    if (hasEndTime) {
      final endTimeRaw = args['endTime'];
      if (endTimeRaw is! String || endTimeRaw.isEmpty) {
        return const ToolExecutionResult(
          success: false,
          output:
              'Error: "endTime" must be a valid ISO 8601 datetime '
              'with explicit local time',
          errorMessage: 'Missing or invalid endTime',
        );
      }

      endTime = parseTimeEntryLocalDateTime(endTimeRaw);
      if (endTime == null) {
        return const ToolExecutionResult(
          success: false,
          output:
              'Error: "endTime" must be a valid ISO 8601 datetime '
              'with explicit local time',
          errorMessage: 'Unparseable endTime',
        );
      }
    }

    final isRunningTimer = !hasEndTime;
    final completedReference = _resolveCompletedSessionReference(args, now);

    if (isRunningTimer) {
      if (!_isSameDay(startTime, now)) {
        return const ToolExecutionResult(
          success: false,
          output: "Error: startTime must be today's date",
          errorMessage: 'startTime is not today',
        );
      }
      if (startTime.isAfter(now)) {
        return const ToolExecutionResult(
          success: false,
          output: 'Error: startTime must not be in the future',
          errorMessage: 'startTime is in the future',
        );
      }
    } else {
      if (!_isSameDay(startTime, completedReference.timestamp)) {
        return ToolExecutionResult(
          success: false,
          output:
              'Error: completed-session startTime must be on the same day '
              'as the ${completedReference.label} '
              '(${_formatDate(completedReference.timestamp)})',
          errorMessage: 'startTime is not on ${completedReference.label} day',
        );
      }
      // At approval time (deferred execution), the user is the authority and
      // may intentionally confirm an entry whose start/end drifted past the
      // wake timestamp (e.g. a meeting the agent estimated would end at
      // 13:00). Only enforce the "not in the future" cutoff at wake time.
      if (completedReference.enforceFutureCutoff &&
          startTime.isAfter(completedReference.timestamp)) {
        return ToolExecutionResult(
          success: false,
          output:
              'Error: startTime must not be after the '
              '${completedReference.label}',
          errorMessage: 'startTime is after ${completedReference.label}',
        );
      }
    }

    if (endTime != null) {
      if (!endTime.isAfter(startTime)) {
        return const ToolExecutionResult(
          success: false,
          output: 'Error: endTime must be after startTime',
          errorMessage: 'endTime is not after startTime',
        );
      }
      if (!_isSameDay(endTime, startTime)) {
        return const ToolExecutionResult(
          success: false,
          output: 'Error: endTime must be on the same day as startTime',
          errorMessage: 'endTime is on a different day',
        );
      }
      if (completedReference.enforceFutureCutoff &&
          endTime.isAfter(completedReference.timestamp)) {
        return ToolExecutionResult(
          success: false,
          output:
              'Error: endTime must not be after the '
              '${completedReference.label}',
          errorMessage: 'endTime is after ${completedReference.label}',
        );
      }
    }

    // --- Check for active timer when starting a running timer ---
    if (isRunningTimer && _timeService.getCurrent() != null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: a timer is already running — stop it first',
        errorMessage: 'Timer already running',
      );
    }

    // --- Look up source task for category inheritance ---
    final sourceEntity = await _journalDb.journalEntityById(sourceTaskId);
    if (sourceEntity is! Task) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: source task $sourceTaskId not found or not a Task',
        errorMessage: 'Source task lookup failed',
      );
    }

    final categoryId = sourceEntity.meta.categoryId;

    // --- Create journal entry ---
    // For completed sessions, pass endTime directly to createMetadata so the
    // correct dateTo is written in a single DB write instead of
    // create-then-update.
    final entryText = EntryText(plainText: '$summary [generated]');

    final journalEntity = JournalEntity.journalEntry(
      entryText: entryText,
      meta: await _persistenceLogic.createMetadata(
        dateFrom: startTime,
        dateTo: endTime,
        categoryId: categoryId,
      ),
    );

    final saved = await _persistenceLogic.createDbEntity(
      journalEntity,
      linkedId: sourceTaskId,
    );

    if (saved != true) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: failed to persist time entry',
        errorMessage: 'createDbEntity returned false',
      );
    }

    final createdId = journalEntity.meta.id;

    // --- Start running timer if no endTime ---
    // The pre-check above (getCurrent != null) and this start() call are not
    // atomic, but Dart's single-threaded event loop means no concurrent call
    // can race between them during synchronous execution.
    if (isRunningTimer) {
      // Use the already-created entity directly — TimeService only stores it
      // in memory and does not need a freshly-fetched DB copy.
      try {
        await _timeService.start(journalEntity, sourceEntity);
      } catch (e, _) {
        _domainLogger?.log(
          LogDomains.agentWorkflow,
          'Time entry $createdId persisted but timer start failed: $e',
          subDomain: _sub,
        );
        return ToolExecutionResult(
          success: false,
          output:
              'Time entry was saved ($createdId) but the running timer '
              'could not be started: $e',
          errorMessage: 'Timer start failed after persistence',
          mutatedEntityId: createdId,
        );
      }
    }

    _domainLogger?.log(
      LogDomains.agentWorkflow,
      'Created time entry $createdId '
      '(${isRunningTimer ? "running timer" : "completed session"}) '
      'linked to $sourceTaskId',
      subDomain: _sub,
    );

    final timeRange = isRunningTimer
        ? 'running timer from ${formatTimeEntryHhMm(startTime)}'
        : '${formatTimeEntryHhMm(startTime)}–${formatTimeEntryHhMm(endTime!)}';

    return ToolExecutionResult(
      success: true,
      output:
          'Created time entry ($timeRange): "$summary" '
          '($createdId)',
      mutatedEntityId: createdId,
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Resolves the reference timestamp used for same-day and future-cutoff
  /// validation.
  ///
  /// When called directly by the agent at wake time, no
  /// `_referenceTimestamp` arg is injected so `fallback` (clock.now()) is
  /// used and `enforceFutureCutoff` is `true` — the agent cannot fabricate
  /// times after the current instant.
  ///
  /// At approval time, `ChangeSetConfirmationService` injects the originating
  /// wake timestamp. The same-day check still runs against that timestamp so
  /// after-midnight approvals of same-day-as-wake entries still work, but the
  /// future cutoff is disabled so the user can confirm entries the agent
  /// estimated to extend past the wake instant (e.g. an ongoing meeting).
  static ({DateTime timestamp, String label, bool enforceFutureCutoff})
  _resolveCompletedSessionReference(
    Map<String, dynamic> args,
    DateTime fallback,
  ) {
    final raw = args[timeEntryReferenceTimestampArg];
    final parsed = raw is String ? DateTime.tryParse(raw) : null;

    if (parsed == null) {
      return (
        timestamp: fallback,
        label: 'current time',
        enforceFutureCutoff: true,
      );
    }

    return (
      timestamp: parsed.isUtc ? parsed.toLocal() : parsed,
      label: 'wake timestamp',
      enforceFutureCutoff: false,
    );
  }

  static String _formatDate(DateTime dt) =>
      dt.toIso8601String().split('T').first;
}
