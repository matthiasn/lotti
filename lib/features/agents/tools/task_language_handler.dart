import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';

/// Result of processing a task language update.
class TaskLanguageResult {
  const TaskLanguageResult({
    required this.success,
    required this.message,
    this.updatedTask,
    this.error,
    this.didWrite = false,
  });

  final bool success;
  final String message;
  final Task? updatedTask;
  final String? error;
  final bool didWrite;
  bool get wasNoOp => success && !didWrite;
}

/// Handler for setting the language of a task.
///
/// Validates the language code against [SupportedLanguage] values, detects
/// no-op cases (language already set to requested value), and persists the
/// update via [JournalRepository].
class TaskLanguageHandler {
  TaskLanguageHandler({
    required this.task,
    required this.journalRepository,
  });

  Task task;
  final JournalRepository journalRepository;

  /// Sets the task language to [languageCode].
  ///
  /// Returns a no-op success if the task already has the requested language.
  /// Returns an error if the language code is not in [SupportedLanguage].
  Future<TaskLanguageResult> handle(String languageCode) async {
    final trimmed = languageCode.trim().toLowerCase();

    developer.log(
      'Processing set_task_language: "$trimmed"',
      name: 'TaskLanguageHandler',
    );

    if (trimmed.isEmpty) {
      const message = 'Invalid language code: must not be empty.';
      return const TaskLanguageResult(
        success: false,
        message: message,
        error: message,
      );
    }

    // Validate against supported languages.
    final supported = SupportedLanguage.fromCode(trimmed);
    if (supported == null) {
      final message = 'Unsupported language code: "$trimmed". '
          'Must be one of: ${SupportedLanguage.values.map((l) => l.code).join(", ")}';
      developer.log(message, name: 'TaskLanguageHandler');
      return TaskLanguageResult(
        success: false,
        message: message,
        error: message,
      );
    }

    // No-op if language already matches.
    if (task.data.languageCode == trimmed) {
      final message = 'Language is already "$trimmed". No change needed.';
      developer.log(
        'Language unchanged — skipping write',
        name: 'TaskLanguageHandler',
      );
      return TaskLanguageResult(
        success: true,
        message: message,
        updatedTask: task,
      );
    }

    final updatedTask = task.copyWith(
      data: task.data.copyWith(languageCode: trimmed),
    );

    try {
      final success = await journalRepository.updateJournalEntity(updatedTask);

      if (!success) {
        const message = 'Failed to update language: repository returned false.';
        developer.log(message, name: 'TaskLanguageHandler');
        return const TaskLanguageResult(
          success: false,
          message: message,
          error: message,
        );
      }

      task = updatedTask;

      final message = 'Task language set to "$trimmed" (${supported.name}).';
      developer.log(
        'Successfully set task language to "$trimmed"',
        name: 'TaskLanguageHandler',
      );

      return TaskLanguageResult(
        success: true,
        message: message,
        updatedTask: updatedTask,
        didWrite: true,
      );
    } catch (e, s) {
      const message =
          'Failed to update language. Continuing without language change.';
      developer.log(
        'Failed to update task language',
        name: 'TaskLanguageHandler',
        error: e,
        stackTrace: s,
      );

      return TaskLanguageResult(
        success: false,
        message: message,
        error: e.toString(),
      );
    }
  }

  /// Converts a [TaskLanguageResult] to a [ToolExecutionResult].
  static ToolExecutionResult toToolExecutionResult(
    TaskLanguageResult result, {
    String? entityId,
  }) {
    return ToolExecutionResult(
      success: result.success,
      output: result.message,
      mutatedEntityId: result.didWrite ? entityId : null,
      errorMessage: result.error,
    );
  }
}
