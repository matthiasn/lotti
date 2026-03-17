import 'package:clock/clock.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
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
    final summary = args['summary'];
    if (summary is! String || summary.trim().isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "summary" must be a non-empty string',
        errorMessage: 'Missing or empty summary',
      );
    }

    // --- Parse and validate startTime ---
    final startTimeRaw = args['startTime'];
    if (startTimeRaw is! String || startTimeRaw.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "startTime" must be a valid ISO 8601 datetime',
        errorMessage: 'Missing or invalid startTime',
      );
    }
    final startTime = DateTime.tryParse(startTimeRaw);
    if (startTime == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "startTime" must be a valid ISO 8601 datetime',
        errorMessage: 'Unparseable startTime',
      );
    }

    final now = clock.now();

    // startTime must be today and not in the future.
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

    // --- Parse and validate optional endTime ---
    final endTimeRaw = args['endTime'];
    DateTime? endTime;
    if (endTimeRaw != null) {
      if (endTimeRaw is! String || endTimeRaw.isEmpty) {
        return const ToolExecutionResult(
          success: false,
          output: 'Error: "endTime" must be a valid ISO 8601 datetime',
          errorMessage: 'Missing or invalid endTime',
        );
      }

      endTime = DateTime.tryParse(endTimeRaw);
      if (endTime == null) {
        return const ToolExecutionResult(
          success: false,
          output: 'Error: "endTime" must be a valid ISO 8601 datetime',
          errorMessage: 'Unparseable endTime',
        );
      }
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
      if (endTime.isAfter(now)) {
        return const ToolExecutionResult(
          success: false,
          output: 'Error: endTime must not be in the future',
          errorMessage: 'endTime is in the future',
        );
      }
    }

    final isRunningTimer = endTime == null;

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
    final entryText = EntryText(plainText: '${summary.trim()} [generated]');

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
    if (isRunningTimer) {
      // Use the already-created entity directly — TimeService only stores it
      // in memory and does not need a freshly-fetched DB copy.
      await _timeService.start(journalEntity, sourceEntity);
    }

    _domainLogger?.log(
      LogDomains.agentWorkflow,
      'Created time entry $createdId '
      '(${isRunningTimer ? "running timer" : "completed session"}) '
      'linked to $sourceTaskId',
      subDomain: _sub,
    );

    final timeRange = isRunningTimer
        ? 'running timer from ${_formatTime(startTime)}'
        : '${_formatTime(startTime)}–${_formatTime(endTime)}';

    return ToolExecutionResult(
      success: true,
      output:
          'Created time entry ($timeRange): "${summary.trim()}" '
          '($createdId)',
      mutatedEntityId: createdId,
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
