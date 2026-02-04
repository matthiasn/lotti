import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/voice/day_plan_functions.dart';
import 'package:lotti/features/tasks/ui/utils.dart' show openTaskStatuses;
import 'package:lotti/services/entities_cache_service.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// Result of parsing tool call arguments.
class _ParseResult {
  const _ParseResult({this.args, this.error});

  final Map<String, dynamic>? args;
  final String? error;
}

/// Result of a single day plan action.
class DayPlanActionResult {
  const DayPlanActionResult({
    required this.functionName,
    required this.success,
    this.message,
    this.error,
  });

  final String functionName;
  final bool success;
  final String? message;
  final String? error;

  String toJsonString() {
    return jsonEncode({
      'success': success,
      if (message != null) 'message': message,
      if (error != null) 'error': error,
    });
  }
}

/// Strategy for processing voice-based day planning tool calls.
///
/// Implements [ConversationStrategy] to handle tool calls from the LLM
/// and execute day plan mutations.
class DayPlanVoiceStrategy extends ConversationStrategy {
  DayPlanVoiceStrategy({
    required this.date,
    required this.dayPlanController,
    required this.categoryResolver,
    required this.taskSearcher,
    required DayPlanData? currentPlanData,
  }) : _planSnapshot = currentPlanData;

  final DateTime date;
  final UnifiedDailyOsDataController dayPlanController;
  final CategoryResolver categoryResolver;
  final TaskSearcher taskSearcher;

  /// Mutable snapshot of plan data, updated after each mutation to prevent
  /// stale lookups when processing multiple tool calls in sequence.
  DayPlanData? _planSnapshot;

  final List<DayPlanActionResult> results = [];

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    for (final toolCall in toolCalls) {
      final result = await _handleToolCall(toolCall);
      results.add(result);
      manager.addToolResponse(
        toolCallId: toolCall.id,
        response: result.toJsonString(),
      );
    }
    return ConversationAction.complete; // Single-turn for MVP
  }

  @override
  bool shouldContinue(ConversationManager manager) => false; // Single-turn

  @override
  String? getContinuationPrompt(ConversationManager manager) => null;

  Future<DayPlanActionResult> _handleToolCall(
    ChatCompletionMessageToolCall toolCall,
  ) async {
    final functionName = toolCall.function.name;
    final rawArgs = toolCall.function.arguments;
    final parseResult = _parseArgs(rawArgs);

    if (parseResult.error != null) {
      return DayPlanActionResult(
        functionName: functionName,
        success: false,
        error: 'Invalid tool arguments: ${parseResult.error}. Raw: $rawArgs',
      );
    }

    final args = parseResult.args!;

    try {
      switch (functionName) {
        case DayPlanFunctions.addTimeBlock:
          return _handleAddTimeBlock(args);
        case DayPlanFunctions.resizeTimeBlock:
          return _handleResizeTimeBlock(args);
        case DayPlanFunctions.moveTimeBlock:
          return _handleMoveTimeBlock(args);
        case DayPlanFunctions.deleteTimeBlock:
          return _handleDeleteTimeBlock(args);
        case DayPlanFunctions.linkTaskToDay:
          return _handleLinkTaskToDay(args);
        default:
          return DayPlanActionResult(
            functionName: functionName,
            success: false,
            error: 'Unknown function: $functionName',
          );
      }
    } catch (e) {
      return DayPlanActionResult(
        functionName: functionName,
        success: false,
        error: 'Error executing $functionName: $e',
      );
    }
  }

  /// Result of parsing tool call arguments.
  _ParseResult _parseArgs(String arguments) {
    try {
      final decoded = jsonDecode(arguments);
      if (decoded is! Map<String, dynamic>) {
        return _ParseResult(
            error: 'Expected JSON object, got ${decoded.runtimeType}');
      }
      return _ParseResult(args: decoded);
    } on FormatException catch (e) {
      return _ParseResult(error: 'JSON parse error: ${e.message}');
    }
  }

  Future<DayPlanActionResult> _handleAddTimeBlock(
    Map<String, dynamic> args,
  ) async {
    final categoryName = args['categoryName'] as String?;
    final startTimeStr = args['startTime'] as String?;
    final endTimeStr = args['endTime'] as String?;
    final note = args['note'] as String?;

    if (categoryName == null || startTimeStr == null || endTimeStr == null) {
      return const DayPlanActionResult(
        functionName: DayPlanFunctions.addTimeBlock,
        success: false,
        error: 'Missing required parameters: categoryName, startTime, endTime',
      );
    }

    final category = categoryResolver.resolve(categoryName);
    if (category == null) {
      return DayPlanActionResult(
        functionName: DayPlanFunctions.addTimeBlock,
        success: false,
        error: 'Category not found: $categoryName',
      );
    }

    final startTime = parseTimeForDate(startTimeStr, date);
    final endTime = parseTimeForDate(endTimeStr, date);

    if (startTime == null || endTime == null) {
      return DayPlanActionResult(
        functionName: DayPlanFunctions.addTimeBlock,
        success: false,
        error:
            'Invalid time format. Expected HH:mm, got: $startTimeStr, $endTimeStr',
      );
    }

    if (!endTime.isAfter(startTime)) {
      return const DayPlanActionResult(
        functionName: DayPlanFunctions.addTimeBlock,
        success: false,
        error: 'End time must be after start time',
      );
    }

    final block = PlannedBlock(
      id: const Uuid().v4(),
      categoryId: category.id,
      startTime: startTime,
      endTime: endTime,
      note: note,
    );

    await dayPlanController.addPlannedBlock(block);
    _updateSnapshotWithAddedBlock(block);

    return DayPlanActionResult(
      functionName: DayPlanFunctions.addTimeBlock,
      success: true,
      message: 'Added ${category.name} block from $startTimeStr to $endTimeStr',
    );
  }

  Future<DayPlanActionResult> _handleResizeTimeBlock(
    Map<String, dynamic> args,
  ) async {
    final blockId = args['blockId'] as String?;
    final newStartTimeStr = args['newStartTime'] as String?;
    final newEndTimeStr = args['newEndTime'] as String?;

    if (blockId == null) {
      return const DayPlanActionResult(
        functionName: DayPlanFunctions.resizeTimeBlock,
        success: false,
        error: 'Missing required parameter: blockId',
      );
    }

    if (newStartTimeStr == null && newEndTimeStr == null) {
      return const DayPlanActionResult(
        functionName: DayPlanFunctions.resizeTimeBlock,
        success: false,
        error: 'At least one of newStartTime or newEndTime must be provided',
      );
    }

    final existingBlock = _planSnapshot?.blockById(blockId);
    if (existingBlock == null) {
      return DayPlanActionResult(
        functionName: DayPlanFunctions.resizeTimeBlock,
        success: false,
        error: 'Block not found: $blockId',
      );
    }

    final newStartTime = newStartTimeStr != null
        ? parseTimeForDate(newStartTimeStr, date)
        : existingBlock.startTime;
    final newEndTime = newEndTimeStr != null
        ? parseTimeForDate(newEndTimeStr, date)
        : existingBlock.endTime;

    if (newStartTime == null || newEndTime == null) {
      return const DayPlanActionResult(
        functionName: DayPlanFunctions.resizeTimeBlock,
        success: false,
        error: 'Invalid time format',
      );
    }

    if (!newEndTime.isAfter(newStartTime)) {
      return const DayPlanActionResult(
        functionName: DayPlanFunctions.resizeTimeBlock,
        success: false,
        error: 'End time must be after start time',
      );
    }

    final updatedBlock = existingBlock.copyWith(
      startTime: newStartTime,
      endTime: newEndTime,
    );

    await dayPlanController.updatePlannedBlock(updatedBlock);
    _updateSnapshotWithUpdatedBlock(updatedBlock);

    return DayPlanActionResult(
      functionName: DayPlanFunctions.resizeTimeBlock,
      success: true,
      message:
          'Resized block to ${_formatTime(newStartTime)}-${_formatTime(newEndTime)}',
    );
  }

  Future<DayPlanActionResult> _handleMoveTimeBlock(
    Map<String, dynamic> args,
  ) async {
    final blockId = args['blockId'] as String?;
    final newStartTimeStr = args['newStartTime'] as String?;

    if (blockId == null || newStartTimeStr == null) {
      return const DayPlanActionResult(
        functionName: DayPlanFunctions.moveTimeBlock,
        success: false,
        error: 'Missing required parameters: blockId, newStartTime',
      );
    }

    final existingBlock = _planSnapshot?.blockById(blockId);
    if (existingBlock == null) {
      return DayPlanActionResult(
        functionName: DayPlanFunctions.moveTimeBlock,
        success: false,
        error: 'Block not found: $blockId',
      );
    }

    final newStartTime = parseTimeForDate(newStartTimeStr, date);
    if (newStartTime == null) {
      return DayPlanActionResult(
        functionName: DayPlanFunctions.moveTimeBlock,
        success: false,
        error: 'Invalid time format: $newStartTimeStr',
      );
    }

    // Preserve duration by shifting end time by the same delta
    final duration = existingBlock.endTime.difference(existingBlock.startTime);
    final newEndTime = newStartTime.add(duration);

    final updatedBlock = existingBlock.copyWith(
      startTime: newStartTime,
      endTime: newEndTime,
    );

    await dayPlanController.updatePlannedBlock(updatedBlock);
    _updateSnapshotWithUpdatedBlock(updatedBlock);

    return DayPlanActionResult(
      functionName: DayPlanFunctions.moveTimeBlock,
      success: true,
      message:
          'Moved block to ${_formatTime(newStartTime)}-${_formatTime(newEndTime)}',
    );
  }

  Future<DayPlanActionResult> _handleDeleteTimeBlock(
    Map<String, dynamic> args,
  ) async {
    final blockId = args['blockId'] as String?;

    if (blockId == null) {
      return const DayPlanActionResult(
        functionName: DayPlanFunctions.deleteTimeBlock,
        success: false,
        error: 'Missing required parameter: blockId',
      );
    }

    final existingBlock = _planSnapshot?.blockById(blockId);
    if (existingBlock == null) {
      return DayPlanActionResult(
        functionName: DayPlanFunctions.deleteTimeBlock,
        success: false,
        error: 'Block not found: $blockId',
      );
    }

    await dayPlanController.removePlannedBlock(blockId);
    _updateSnapshotWithRemovedBlock(blockId);

    return DayPlanActionResult(
      functionName: DayPlanFunctions.deleteTimeBlock,
      success: true,
      message: 'Deleted block $blockId',
    );
  }

  Future<DayPlanActionResult> _handleLinkTaskToDay(
    Map<String, dynamic> args,
  ) async {
    final taskTitle = args['taskTitle'] as String?;
    final categoryName = args['categoryName'] as String?;

    if (taskTitle == null) {
      return const DayPlanActionResult(
        functionName: DayPlanFunctions.linkTaskToDay,
        success: false,
        error: 'Missing required parameter: taskTitle',
      );
    }

    final task = await taskSearcher.findByTitle(taskTitle);
    if (task == null) {
      return DayPlanActionResult(
        functionName: DayPlanFunctions.linkTaskToDay,
        success: false,
        error: 'Task not found: $taskTitle',
      );
    }

    // Determine category: explicit > task's category > default
    String? categoryId;
    if (categoryName != null) {
      final category = categoryResolver.resolve(categoryName);
      categoryId = category?.id;
    }
    categoryId ??= task.meta.categoryId;

    if (categoryId == null) {
      return const DayPlanActionResult(
        functionName: DayPlanFunctions.linkTaskToDay,
        success: false,
        error: 'No category specified and task has no category',
      );
    }

    final taskRef = PinnedTaskRef(
      taskId: task.id,
      categoryId: categoryId,
    );

    await dayPlanController.pinTask(taskRef);

    return DayPlanActionResult(
      functionName: DayPlanFunctions.linkTaskToDay,
      success: true,
      message: 'Pinned task "${task.data.title}" to today',
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Updates the local snapshot after adding a block.
  void _updateSnapshotWithAddedBlock(PlannedBlock block) {
    if (_planSnapshot == null) {
      _planSnapshot = DayPlanData(
        planDate: date,
        status: const DayPlanStatus.draft(),
        plannedBlocks: [block],
      );
    } else {
      _planSnapshot = _planSnapshot!.copyWith(
        plannedBlocks: [..._planSnapshot!.plannedBlocks, block],
      );
    }
  }

  /// Updates the local snapshot after updating a block.
  void _updateSnapshotWithUpdatedBlock(PlannedBlock updatedBlock) {
    if (_planSnapshot == null) return;
    _planSnapshot = _planSnapshot!.copyWith(
      plannedBlocks: _planSnapshot!.plannedBlocks
          .map((b) => b.id == updatedBlock.id ? updatedBlock : b)
          .toList(),
    );
  }

  /// Updates the local snapshot after removing a block.
  void _updateSnapshotWithRemovedBlock(String blockId) {
    if (_planSnapshot == null) return;
    _planSnapshot = _planSnapshot!.copyWith(
      plannedBlocks:
          _planSnapshot!.plannedBlocks.where((b) => b.id != blockId).toList(),
    );
  }
}

/// Resolves spoken category names to CategoryDefinition objects.
///
/// Uses fuzzy matching with priority: exact > prefix > contains.
class CategoryResolver {
  CategoryResolver(this.cacheService);

  final EntitiesCacheService cacheService;

  CategoryDefinition? resolve(String spokenName) {
    final normalized = spokenName.toLowerCase().trim();
    if (normalized.isEmpty) return null;

    final categories = cacheService.sortedCategories;

    // Exact match
    for (final cat in categories) {
      if (cat.name.toLowerCase() == normalized) return cat;
    }
    // Prefix match
    for (final cat in categories) {
      if (cat.name.toLowerCase().startsWith(normalized)) return cat;
    }
    // Contains match
    for (final cat in categories) {
      if (cat.name.toLowerCase().contains(normalized)) return cat;
    }
    return null;
  }
}

/// Searches for tasks by title using FTS5 full-text search.
class TaskSearcher {
  TaskSearcher(this.db, this.fts5Db);

  final JournalDb db;
  final Fts5Db fts5Db;

  Future<Task?> findByTitle(String titleQuery) async {
    // 1. Escape FTS5 special characters and build query
    final escapedQuery = _escapeFts5Query(titleQuery);
    if (escapedQuery.isEmpty) return null;

    // 2. FTS5 search returns matching UUIDs
    //    Use title: prefix to search title column specifically
    final matchingIds = await fts5Db.findMatching('title:$escapedQuery*').get();
    if (matchingIds.isEmpty) return null;

    // 3. Load tasks by IDs and filter to open tasks only
    //    JournalDb.getTasks() returns List<JournalEntity>, filter to Task
    final entities = await db.getTasks(
      starredStatuses: [false, true], // Include both starred and unstarred
      taskStatuses:
          openTaskStatuses, // ['OPEN', 'GROOMED', 'IN PROGRESS', 'BLOCKED', 'ON HOLD']
      categoryIds: [], // No category filter
      ids: matchingIds,
    );
    final tasks = entities.whereType<Task>().toList();

    // 4. Return best match (exact title match preferred, then first result)
    final normalizedQuery = titleQuery.toLowerCase().trim();
    return tasks.firstWhereOrNull(
          (t) => t.data.title.toLowerCase() == normalizedQuery,
        ) ??
        tasks.firstOrNull;
  }

  /// Escapes special FTS5 characters to prevent query syntax errors.
  ///
  /// FTS5 special characters: * " ( ) - : ^
  /// We quote the entire query to treat it as a literal phrase.
  String _escapeFts5Query(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return '';

    // Escape double quotes by doubling them, then wrap in quotes
    // for phrase matching with spaces and special chars
    final escaped = trimmed.replaceAll('"', '""');
    return '"$escaped"';
  }
}
