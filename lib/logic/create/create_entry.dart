import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/screenshots.dart';

Future<JournalEntity?> createTextEntry({
  String? linkedId,
  String? categoryId,
}) async {
  final entry = await JournalRepository.createTextEntry(
    const EntryText(plainText: ''),
    id: uuid.v1(),
    linkedId: linkedId,
    categoryId: categoryId,
    started: DateTime.now(),
  );

  if (linkedId == null) {
    beamToNamed('/journal/${entry?.meta.id}');
  }
  return entry;
}

Future<JournalEntity?> createChecklist({
  required Task task,
  required WidgetRef ref,
}) async {
  final result = await ref
      .read(checklistRepositoryProvider)
      .createChecklist(
        taskId: task.id,
      );

  return result.checklist;
}

Future<Task?> createTask({
  String? linkedId,
  String? categoryId,
  DateTime? due,
}) async {
  final now = DateTime.now();

  // Look up category defaults for profile inheritance.
  final category = categoryId != null
      ? getIt<EntitiesCacheService>().getCategoryById(categoryId)
      : null;

  final task = await getIt<PersistenceLogic>().createTaskEntry(
    data: TaskData(
      status: taskStatusFromString(''),
      title: '',
      statusHistory: [],
      dateTo: now,
      dateFrom: now,
      estimate: Duration.zero,
      due: due,
      profileId: category?.defaultProfileId,
    ),
    entryText: const EntryText(plainText: ''),
    linkedId: linkedId,
    categoryId: categoryId,
  );

  return task;
}

/// Auto-creates an agent for [task] if the task's category has a
/// `defaultTemplateId` set. The agent is created in content-awaiting mode
/// so it won't run until the task has meaningful content.
///
/// Call this after [createTask] from contexts that have Riverpod [WidgetRef].
Future<void> autoAssignCategoryAgent(WidgetRef ref, Task task) async {
  final categoryId = task.meta.categoryId;
  if (categoryId == null) return;

  final category = getIt<EntitiesCacheService>().getCategoryById(categoryId);
  final templateId = category?.defaultTemplateId;
  if (templateId == null) return;

  final service = ref.read(taskAgentServiceProvider);
  await service.createTaskAgent(
    taskId: task.meta.id,
    templateId: templateId,
    profileId: category?.defaultProfileId,
    allowedCategoryIds: {categoryId},
    awaitContent: true,
  );
}

Future<JournalEvent?> createEvent({String? linkedId, String? categoryId}) =>
    getIt<PersistenceLogic>().createEventEntry(
      data: const EventData(
        status: EventStatus.tentative,
        title: '',
        stars: 0,
      ),
      entryText: const EntryText(plainText: ''),
      linkedId: linkedId,
      categoryId: categoryId,
    );

Future<JournalEntity?> createScreenshot({
  String? linkedId,
  String? categoryId,
  AutomaticImageAnalysisTrigger? analysisTrigger,
}) async {
  final persistenceLogic = getIt<PersistenceLogic>();
  final imageData = await takeScreenshot();
  final entry = await JournalRepository.createImageEntry(
    imageData,
    linkedId: linkedId,
    categoryId: categoryId,
    onCreated: createAnalysisCallback(analysisTrigger, linkedId),
  );

  if (entry != null) {
    persistenceLogic.addGeolocation(entry.meta.id);
  }

  return entry;
}
