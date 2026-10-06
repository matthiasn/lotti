import 'package:lotti/classes/change_source.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/logic/repositories/task_field_write.dart';
import 'package:lotti/services/domain_logging.dart';

/// Result of processing a task language update.
class TaskLanguageResult {
  const TaskLanguageResult({
    required this.success,
    required this.message,
    this.error,
    this.didWrite = false,
  });

  final bool success;
  final String message;
  final String? error;
  final bool didWrite;
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
    required this._domainLogger,
  });

  /// Receives the handler's traces and failures.
  final DomainLogger _domainLogger;

  Task task;
  final JournalRepository journalRepository;

  /// Sets the task language to [languageCode].
  ///
  /// Returns a no-op success if the task already has the requested language.
  /// Returns a success with no change if the task has a user-set language
  /// (agent cannot override user-set languages).
  /// Returns an error if the language code is not in [SupportedLanguage].
  Future<TaskLanguageResult> handle(String languageCode) async {
    final trimmed = languageCode.trim().toLowerCase();

    _domainLogger.log(
      LogDomain.agentWorkflow,
      'Processing set_task_language: chars=${trimmed.length}',
      subDomain: 'TaskLanguageHandler',
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
      final message =
          'Unsupported language code: "$trimmed". '
          'Must be one of: ${SupportedLanguage.values.map((l) => l.code).join(", ")}';
      _domainLogger.log(
        LogDomain.agentWorkflow,
        'Rejected unsupported language code',
        subDomain: 'TaskLanguageHandler',
        level: InsightLevel.warn,
      );
      return TaskLanguageResult(
        success: false,
        message: message,
        error: message,
      );
    }

    // No-op if language already matches (regardless of source).
    if (task.data.languageCode == trimmed) {
      final message = 'Language is already "$trimmed". No change needed.';
      _domainLogger.log(
        LogDomain.agentWorkflow,
        'Language unchanged — skipping write',
        subDomain: 'TaskLanguageHandler',
      );
      return TaskLanguageResult(
        success: true,
        message: message,
      );
    }

    // Guard: never overwrite a user-set language with a different value.
    if (task.data.languageCode != null &&
        task.data.languageSource == ChangeSource.user) {
      final message =
          'Language was manually set by user to "${task.data.languageCode}". '
          'Agent cannot override user-set language.';
      _domainLogger.log(
        LogDomain.agentWorkflow,
        'Skipped user-set language',
        subDomain: 'TaskLanguageHandler',
      );
      return TaskLanguageResult(
        success: true,
        message: message,
      );
    }

    try {
      final write = await writeTaskField(
        journalRepository: journalRepository,
        task: task,
        field: (data) => (data.languageCode, data.languageSource),
        set: (stored) => stored.copyWith(
          languageCode: trimmed,
          languageSource: ChangeSource.agent,
        ),
      );

      switch (write) {
        case TaskFieldWriteFailed():
          const message =
              'Failed to update language: repository returned false.';
          _domainLogger.log(
            LogDomain.agentWorkflow,
            message,
            subDomain: 'TaskLanguageHandler',
            level: InsightLevel.warn,
          );
          return const TaskLanguageResult(
            success: false,
            message: message,
            error: message,
          );
        case TaskFieldMoved(task: final stored):
          task = stored;
          const message =
              "Nothing applied: the task's language changed since this "
              'call read it, so it stays as it is.';
          _domainLogger.log(
            LogDomain.agentWorkflow,
            message,
            subDomain: 'TaskLanguageHandler',
          );
          return const TaskLanguageResult(success: true, message: message);
        case TaskFieldWritten(task: final stored):
          task = stored;
      }

      final message = 'Task language set to "$trimmed" (${supported.name}).';
      _domainLogger.log(
        LogDomain.agentWorkflow,
        'Successfully set task language',
        subDomain: 'TaskLanguageHandler',
      );

      return TaskLanguageResult(
        success: true,
        message: message,
        didWrite: true,
      );
    } catch (e, s) {
      const message =
          'Failed to update language. Continuing without language change.';
      _domainLogger.error(
        LogDomain.agentWorkflow,
        e,
        stackTrace: s,
        subDomain: 'TaskLanguageHandler',
        message: 'Failed to update task language',
      );

      return TaskLanguageResult(
        success: false,
        message: message,
        error: e.toString(),
      );
    }
  }
}
