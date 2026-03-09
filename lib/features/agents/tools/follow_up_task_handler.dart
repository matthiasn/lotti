import 'package:clock/clock.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// Creates a follow-up task linked to the source task.
///
/// Used by the task agent's split workflow: the agent identifies a new task
/// from user audio/notes, calls `create_follow_up_task`, and the handler
/// creates the task entity plus a `BasicLink` from source to new task.
///
/// The new task inherits the source task's category. Priority defaults to P2
/// if not specified.
class FollowUpTaskHandler {
  FollowUpTaskHandler({
    required PersistenceLogic persistenceLogic,
    required JournalDb journalDb,
    DomainLogger? domainLogger,
  }) : _persistenceLogic = persistenceLogic,
       _journalDb = journalDb,
       _domainLogger = domainLogger;

  final PersistenceLogic _persistenceLogic;
  final JournalDb _journalDb;
  final DomainLogger? _domainLogger;

  static const _uuid = Uuid();
  static const _sub = 'FollowUpTaskHandler';

  /// Creates a follow-up task and links it to the source task.
  ///
  /// Returns a [ToolExecutionResult] with `mutatedEntityId` set to the new
  /// task's ID on success.
  Future<ToolExecutionResult> handle(
    String sourceTaskId,
    Map<String, dynamic> args,
  ) async {
    final title = args['title'];
    if (title is! String || title.trim().isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "title" must be a non-empty string',
        errorMessage: 'Missing or empty title',
      );
    }

    // Read source task to inherit category.
    final sourceEntity = await _journalDb.journalEntityById(sourceTaskId);
    if (sourceEntity is! Task) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: source task $sourceTaskId not found or not a Task',
        errorMessage: 'Source task lookup failed',
      );
    }

    final categoryId = sourceEntity.meta.categoryId;
    final now = clock.now();

    // Parse optional fields.
    final rawPriority = args['priority'];
    final priority = _parsePriority(rawPriority);
    if (rawPriority != null && priority == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "priority" must be one of P0, P1, P2, P3',
        errorMessage: 'Invalid priority',
      );
    }
    final rawDueDate = args['dueDate'];
    final dueDate = _parseDueDate(rawDueDate);
    if (rawDueDate != null && dueDate == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "dueDate" must be a valid YYYY-MM-DD date',
        errorMessage: 'Invalid dueDate',
      );
    }
    final description = args['description'];

    // Build task data.
    final taskData = TaskData(
      status: TaskStatus.open(
        id: _uuid.v1(),
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      dateFrom: now,
      dateTo: now,
      statusHistory: [],
      title: title.trim(),
      priority: priority!,
      due: dueDate,
    );

    final entryText = EntryText(
      plainText: description is String ? description : '',
    );

    // Create the task entry.
    final newTask = await _persistenceLogic.createTaskEntry(
      data: taskData,
      entryText: entryText,
      categoryId: categoryId,
    );

    if (newTask == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: failed to create follow-up task',
        errorMessage: 'Task creation failed',
      );
    }

    final newTaskId = newTask.meta.id;

    // Verify the task is actually persisted and readable.
    final verifyTask = await _journalDb.journalEntityById(newTaskId);
    _domainLogger?.log(
      LogDomains.agentWorkflow,
      'Created task $newTaskId — verify lookup: '
      '${verifyTask?.runtimeType} (found: ${verifyTask != null})',
      subDomain: _sub,
    );

    final warnings = <String>[];

    // Link source task → new task. Wrapped in try-catch so a link failure
    // does not lose the already-created task ID. Also checks the bool return
    // value since PersistenceLogic.createLink reports some failures that way.
    try {
      final linked = await _persistenceLogic.createLink(
        fromId: sourceTaskId,
        toId: newTaskId,
      );
      if (!linked) {
        warnings.add('Warning: failed to link source task');
      }
    } catch (e) {
      _domainLogger?.error(
        LogDomains.agentWorkflow,
        'Failed to link source $sourceTaskId → $newTaskId',
        error: e,
        subDomain: _sub,
      );
      warnings.add('Warning: failed to link source task');
    }

    final output = StringBuffer('Created follow-up task "$title" ($newTaskId)');
    for (final w in warnings) {
      output.write('. $w');
    }

    return ToolExecutionResult(
      success: true,
      output: output.toString(),
      mutatedEntityId: newTaskId,
    );
  }

  /// Parses a priority string. Returns `null` if the value is present but
  /// not a recognized priority string (caller should reject).
  /// Absent/null values return `p2Medium` as default.
  static TaskPriority? _parsePriority(Object? value) {
    if (value == null) return TaskPriority.p2Medium;
    if (value is! String) return null;
    final parsed = taskPriorityFromString(value);
    // taskPriorityFromString returns fallback for unknown values — detect that
    // by checking if the input (case-insensitive) matches a known priority.
    final upper = value.trim().toUpperCase();
    if (!const {'P0', 'P1', 'P2', 'P3'}.contains(upper)) return null;
    return parsed;
  }

  static DateTime? _parseDueDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
