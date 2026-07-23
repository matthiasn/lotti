import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/state/consts.dart';

/// Default fixed date for test entities. Never use DateTime.now() in tests.
final testFixedDate = DateTime(2024, 3, 15, 10);

/// Factory for creating [Metadata] instances in tests.
///
/// All parameters have sensible defaults. Override only what matters for your
/// test to keep assertions focused:
/// ```dart
/// final meta = TestMetadataFactory.create(id: 'my-task');
/// ```
class TestMetadataFactory {
  static Metadata create({
    String id = 'test-entity-1',
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool starred = false,
    bool private = false,
    String? categoryId,
  }) {
    final date = createdAt ?? testFixedDate;
    return Metadata(
      id: id,
      createdAt: date,
      updatedAt: updatedAt ?? date,
      dateFrom: dateFrom ?? date,
      dateTo: dateTo ?? date,
      starred: starred,
      private: private,
      categoryId: categoryId,
    );
  }
}

/// Factory for creating [TaskData] instances in tests.
///
/// ```dart
/// final data = TestTaskDataFactory.create(title: 'Fix bug');
/// ```
class TestTaskDataFactory {
  static TaskData create({
    String title = 'Test Task',
    DateTime? dateFrom,
    DateTime? dateTo,
    TaskStatus? status,
    List<TaskStatus>? statusHistory,
    List<String>? checklistIds,
    Duration? estimate,
    String? languageCode,
  }) {
    final date = dateFrom ?? testFixedDate;
    final taskStatus =
        status ??
        TaskStatus.open(
          id: 'status-1',
          createdAt: date,
          utcOffset: 0,
        );
    return TaskData(
      title: title,
      dateFrom: date,
      dateTo: dateTo ?? date,
      status: taskStatus,
      statusHistory: statusHistory ?? [taskStatus],
      checklistIds: checklistIds,
      estimate: estimate,
      languageCode: languageCode,
    );
  }
}

/// Factory for creating [Task] instances in tests.
///
/// Combines [TestMetadataFactory] and [TestTaskDataFactory] for convenience:
/// ```dart
/// final task = TestTaskFactory.create(id: 'task-1', title: 'Fix bug');
/// ```
class TestTaskFactory {
  static Task create({
    String id = 'test-task-1',
    String title = 'Test Task',
    String plainText = '',
    DateTime? createdAt,
    DateTime? dateFrom,
    DateTime? dateTo,
    TaskStatus? status,
    List<TaskStatus>? statusHistory,
    String? categoryId,
    List<String>? checklistIds,
    Duration? estimate,
    String? languageCode,
    bool starred = false,
    bool private = false,
  }) {
    return Task(
      meta: TestMetadataFactory.create(
        id: id,
        createdAt: createdAt,
        dateFrom: dateFrom,
        dateTo: dateTo,
        starred: starred,
        private: private,
        categoryId: categoryId,
      ),
      data: TestTaskDataFactory.create(
        title: title,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
        statusHistory: statusHistory,
        checklistIds: checklistIds,
        estimate: estimate,
        languageCode: languageCode,
      ),
      entryText: EntryText(plainText: plainText),
    );
  }
}

/// Factory for creating [ProjectEntry] instances in tests.
///
/// ```dart
/// final project = TestProjectFactory.create(id: 'proj-1', title: 'Alpha');
/// ```
class TestProjectFactory {
  static ProjectEntry create({
    String id = 'test-project-1',
    String title = 'Test Project',
    String? categoryId,
    DateTime? createdAt,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    final date = createdAt ?? testFixedDate;
    return ProjectEntry(
      meta: TestMetadataFactory.create(
        id: id,
        createdAt: date,
        dateFrom: dateFrom ?? date,
        dateTo: dateTo ?? date,
        categoryId: categoryId,
      ),
      data: ProjectData(
        title: title,
        status: ProjectStatus.active(
          id: 'status-1',
          createdAt: date,
          utcOffset: 0,
        ),
        dateFrom: dateFrom ?? date,
        dateTo: dateTo ?? date,
      ),
    );
  }
}

/// Factory for creating [JournalImage] instances in tests.
///
/// ```dart
/// final image = TestImageFactory.create(id: 'img-1');
/// ```
class TestImageFactory {
  static JournalImage create({
    String id = 'test-image-1',
    String? plainText,
    DateTime? createdAt,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    final date = createdAt ?? testFixedDate;
    final from = dateFrom ?? date;
    return JournalImage(
      meta: TestMetadataFactory.create(
        id: id,
        createdAt: date,
        dateFrom: from,
        dateTo: dateTo ?? from,
      ),
      data: ImageData(
        capturedAt: from,
        imageId: 'image-id-$id',
        imageFile: '$id.jpg',
        imageDirectory: '/images/',
      ),
      entryText: plainText == null ? null : EntryText(plainText: plainText),
    );
  }
}

/// Factory for creating [AiResponseEntry] instances in tests — e.g. the image
/// analyses (summary/OCR) linked from an image entry.
///
/// ```dart
/// final ocr = TestAiResponseFactory.create(
///   id: 'ocr-1',
///   model: 'mistral-ocr-latest',
///   response: 'Datum: 05.10.2026',
/// );
/// ```
class TestAiResponseFactory {
  static AiResponseEntry create({
    String id = 'test-ai-response-1',
    String model = 'test-model',
    String response = 'Test analysis',
    AiResponseType? type = AiResponseType.imageAnalysis,
    DateTime? dateFrom,
    DateTime? deletedAt,
  }) {
    final date = dateFrom ?? testFixedDate;
    return AiResponseEntry(
      meta: TestMetadataFactory.create(
        id: id,
        createdAt: date,
        dateFrom: date,
        dateTo: date,
      ).copyWith(deletedAt: deletedAt),
      data: AiResponseData(
        model: model,
        systemMessage: 'system',
        prompt: 'prompt',
        thoughts: '',
        response: response,
        type: type,
      ),
    );
  }
}

/// Factory for creating [ChecklistItemData] instances in tests.
///
/// ```dart
/// final item = TestChecklistItemFactory.create(title: 'Buy milk');
/// ```
class TestChecklistItemFactory {
  static ChecklistItemData create({
    String title = 'Test Item',
    bool isChecked = false,
    List<String> linkedChecklists = const [],
    bool isArchived = false,
    String? id,
  }) {
    return ChecklistItemData(
      title: title,
      isChecked: isChecked,
      linkedChecklists: linkedChecklists,
      isArchived: isArchived,
      id: id,
    );
  }
}
