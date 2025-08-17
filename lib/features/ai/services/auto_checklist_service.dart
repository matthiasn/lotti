import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

class AutoChecklistService {
  AutoChecklistService({
    required ChecklistRepository checklistRepository,
    JournalDb? journalDb,
    LoggingService? loggingService,
  })  : _journalDb = journalDb ?? getIt<JournalDb>(),
        _loggingService = loggingService ?? getIt<LoggingService>(),
        _checklistRepository = checklistRepository;

  final JournalDb _journalDb;
  final LoggingService _loggingService;
  final ChecklistRepository _checklistRepository;

  Future<bool> shouldAutoCreate({required String taskId}) async {
    try {
      final task = await _journalDb.journalEntityById(taskId);

      if (task is! Task) {
        return false;
      }

      final checklistIds = task.data.checklistIds ?? [];
      return checklistIds.isEmpty;
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'auto_checklist_service',
        subDomain: 'shouldAutoCreate',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<({bool success, String? checklistId, String? error})>
      autoCreateChecklist({
    required String taskId,
    required List<ChecklistItemData> suggestions,
    String? title,
    bool? shouldAutoCreate,
  }) async {
    try {
      if (suggestions.isEmpty) {
        return (
          success: false,
          checklistId: null,
          error: 'No suggestions provided'
        );
      }

      // Use provided shouldAutoCreate value or fall back to checking
      final shouldCreate =
          shouldAutoCreate ?? await this.shouldAutoCreate(taskId: taskId);
      if (!shouldCreate) {
        return (
          success: false,
          checklistId: null,
          error: 'Checklists already exist'
        );
      }

      final createdChecklist = await _checklistRepository.createChecklist(
        taskId: taskId,
        items: suggestions,
        title: title ?? 'TODOs',
      );

      if (createdChecklist == null) {
        return (
          success: false,
          checklistId: null,
          error: 'Failed to create checklist'
        );
      }

      _loggingService.captureEvent(
        'auto_checklist_created: taskId=$taskId, checklistId=${createdChecklist.id}, itemCount=${suggestions.length}',
        domain: 'auto_checklist_service',
        subDomain: 'autoCreateChecklist',
      );

      return (success: true, checklistId: createdChecklist.id, error: null);
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'auto_checklist_service',
        subDomain: 'autoCreateChecklist',
        stackTrace: stackTrace,
      );
      return (success: false, checklistId: null, error: exception.toString());
    }
  }
}
