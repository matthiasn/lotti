import 'package:clock/clock.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:uuid/uuid.dart';

/// Creates a follow-up task linked to the source task, with optional audio
/// linking.
///
/// Used by the task agent's split workflow: the agent identifies a new task
/// from user audio/notes, calls `create_follow_up_task`, and the handler
/// creates the task entity plus `BasicLink`s.
///
/// The new task inherits the source task's category. Priority defaults to P2
/// if not specified.
class FollowUpTaskHandler {
  FollowUpTaskHandler({
    required PersistenceLogic persistenceLogic,
    required JournalDb journalDb,
  }) : _persistenceLogic = persistenceLogic,
       _journalDb = journalDb;

  final PersistenceLogic _persistenceLogic;
  final JournalDb _journalDb;

  static const _uuid = Uuid();

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
    final priority = _parsePriority(args['priority']);
    final dueDate = _parseDueDate(args['dueDate']);
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
      priority: priority,
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

    // Link source task → new task.
    await _persistenceLogic.createLink(
      fromId: sourceTaskId,
      toId: newTaskId,
    );

    // Optionally link audio entry → new task.
    final sourceAudioId = args['sourceAudioId'];
    if (sourceAudioId is String && sourceAudioId.isNotEmpty) {
      await _persistenceLogic.createLink(
        fromId: sourceAudioId,
        toId: newTaskId,
      );
    }

    return ToolExecutionResult(
      success: true,
      output: 'Created follow-up task "$title" ($newTaskId)',
      mutatedEntityId: newTaskId,
    );
  }

  static TaskPriority _parsePriority(Object? value) {
    if (value is String) {
      return taskPriorityFromString(value);
    }
    return TaskPriority.p2Medium;
  }

  static DateTime? _parseDueDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
