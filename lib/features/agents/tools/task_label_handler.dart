import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/labels/utils/label_tool_parsing.dart';

/// Result of processing a task label assignment.
class TaskLabelResult {
  const TaskLabelResult({
    required this.success,
    required this.message,
    this.assigned = const [],
    this.error,
    this.didWrite = false,
  });

  final bool success;
  final String message;
  final List<String> assigned;
  final String? error;
  final bool didWrite;
  bool get wasNoOp => success && !didWrite;
}

/// Handler for assigning labels to a task via the agent tool system.
///
/// Parses the structured label arguments (with confidence ranking), then
/// delegates to [LabelAssignmentProcessor] for validation, suppression
/// filtering, and persistence.
///
/// The handler does NOT use `getIt` — all dependencies are injected via
/// constructor parameters for testability.
class TaskLabelHandler {
  TaskLabelHandler({
    required this.task,
    required this.processor,
  });

  final Task task;
  final LabelAssignmentProcessor processor;

  /// Assigns labels from structured [args] containing a `labels` array.
  ///
  /// Each label entry must have an `id` and `confidence` field. Labels are
  /// ranked by confidence, low-confidence entries are dropped, and at most
  /// 3 are selected.
  ///
  /// Returns a no-op success if:
  /// - The task already has >= 3 labels
  /// - No valid labels remain after parsing
  /// - All proposed labels are already assigned
  Future<TaskLabelResult> handle(Map<String, dynamic> args) async {
    developer.log(
      'Processing assign_task_labels',
      name: 'TaskLabelHandler',
    );

    // Check max labels upfront.
    final existingIds = task.meta.labelIds ?? const <String>[];
    if (existingIds.length >= 3) {
      const message = 'Task already has 3 or more labels. Skipping assignment.';
      developer.log(message, name: 'TaskLabelHandler');
      return const TaskLabelResult(
        success: true,
        message: message,
      );
    }

    // Parse and rank by confidence.
    final parseResult = parseLabelCallArgs(jsonEncode(args));
    if (parseResult.selectedIds.isEmpty) {
      const message = 'No valid labels after parsing '
          '(all dropped due to low confidence or empty input).';
      developer.log(message, name: 'TaskLabelHandler');
      return const TaskLabelResult(
        success: true,
        message: message,
      );
    }

    try {
      final result = await processor.processAssignment(
        taskId: task.meta.id,
        proposedIds: parseResult.selectedIds,
        existingIds: existingIds,
        categoryId: task.meta.categoryId,
        droppedLow: parseResult.droppedLow,
        legacyUsed: parseResult.legacyUsed,
        confidenceBreakdown: parseResult.confidenceBreakdown,
        totalCandidates: parseResult.totalCandidates,
      );

      if (result.rateLimited) {
        const message = 'Label assignment rate limited. Try again later.';
        developer.log(message, name: 'TaskLabelHandler');
        return const TaskLabelResult(
          success: false,
          message: message,
          error: message,
        );
      }

      final message = result.toStructuredJson(parseResult.selectedIds);
      final didAssign = result.assigned.isNotEmpty;

      developer.log(
        didAssign
            ? 'Assigned ${result.assigned.length} label(s)'
            : 'No labels assigned (all skipped/invalid)',
        name: 'TaskLabelHandler',
      );

      return TaskLabelResult(
        success: true,
        message: message,
        assigned: result.assigned,
        didWrite: didAssign,
      );
    } catch (e, s) {
      const message = 'Failed to assign labels. Continuing without changes.';
      developer.log(
        'Failed to assign labels',
        name: 'TaskLabelHandler',
        error: e,
        stackTrace: s,
      );

      return TaskLabelResult(
        success: false,
        message: message,
        error: e.toString(),
      );
    }
  }

  /// Converts a [TaskLabelResult] to a [ToolExecutionResult].
  static ToolExecutionResult toToolExecutionResult(
    TaskLabelResult result, {
    String? entityId,
  }) {
    return ToolExecutionResult(
      success: result.success,
      output: result.message,
      mutatedEntityId: result.didWrite ? entityId : null,
      errorMessage: result.error,
    );
  }

  /// Builds the label context sections for injection into the user message.
  ///
  /// Returns a string containing:
  /// - Assigned labels (id + name)
  /// - Suppressed labels (do NOT propose these)
  /// - Available labels (id + name)
  ///
  /// Returns an empty string if no labels are available.
  static Future<String> buildLabelContext({
    required Task task,
    required JournalDb journalDb,
  }) async {
    final allDefs = await journalDb.getAllLabelDefinitions();
    if (allDefs.isEmpty) return '';

    // Filter to non-deleted labels.
    final activeDefs = allDefs.where((d) => d.deletedAt == null).toList();
    if (activeDefs.isEmpty) return '';

    final categoryId = task.meta.categoryId;
    final existingIds = (task.meta.labelIds ?? const <String>[]).toSet();
    final suppressedIds = task.data.aiSuppressedLabelIds ?? const <String>{};

    // Build suppressed labels list.
    final suppressedLabels = <Map<String, String>>[];
    for (final def in activeDefs) {
      if (suppressedIds.contains(def.id)) {
        suppressedLabels.add({'id': def.id, 'name': def.name});
      }
    }

    // Build available labels list (in scope, not assigned, not suppressed).
    final availableLabels = <Map<String, String>>[];
    for (final def in activeDefs) {
      if (existingIds.contains(def.id)) continue;
      if (suppressedIds.contains(def.id)) continue;

      // Check category scope.
      final cats = def.applicableCategoryIds;
      final isGlobal = cats == null || cats.isEmpty;
      final inCategory =
          categoryId != null && (cats?.contains(categoryId) ?? false);
      if (!isGlobal && !inCategory) continue;

      availableLabels.add({'id': def.id, 'name': def.name});
    }

    if (availableLabels.isEmpty && suppressedLabels.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();

    // Assigned labels are already included in the Current Task Context JSON,
    // so we only emit suppressed and available labels here.

    if (suppressedLabels.isNotEmpty) {
      buffer
        ..writeln('## Suppressed Labels (do NOT propose these)')
        ..writeln('```json')
        ..writeln(jsonEncode(suppressedLabels))
        ..writeln('```')
        ..writeln();
    }

    if (availableLabels.isNotEmpty) {
      buffer
        ..writeln('## Available Labels (id and name)')
        ..writeln('```json')
        ..writeln(jsonEncode(availableLabels))
        ..writeln('```')
        ..writeln();
    }

    return buffer.toString();
  }
}
