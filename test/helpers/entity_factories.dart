import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';

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
    List<String>? tagIds,
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
      tagIds: tagIds,
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
    final taskStatus = status ??
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
    List<String>? tagIds,
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
        tagIds: tagIds,
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
