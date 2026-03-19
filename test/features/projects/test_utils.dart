import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/utils/file_utils.dart';

/// Shared test factory for creating [ProjectEntry] instances.
///
/// All parameters have sensible defaults to keep call sites concise.
ProjectEntry makeTestProject({
  String? id,
  String title = 'Test Project',
  ProjectStatus? status,
  String? categoryId,
  DateTime? targetDate,
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime(2024, 3, 15);
  return JournalEntity.project(
        meta: Metadata(
          id: id ?? uuid.v1(),
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
          // ignore: avoid_redundant_argument_values
          vectorClock: null,
          categoryId: categoryId,
        ),
        data: ProjectData(
          title: title,
          status:
              status ??
              ProjectStatus.open(
                id: uuid.v1(),
                createdAt: now,
                utcOffset: 0,
              ),
          dateFrom: now,
          dateTo: now,
          targetDate: targetDate,
        ),
      )
      as ProjectEntry;
}

/// Shared test factory for creating [Task] instances.
///
/// All parameters have sensible defaults to keep call sites concise.
Task makeTestTask({
  String? id,
  String title = 'Test Task',
  String? projectId,
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime(2024, 3, 15);
  return JournalEntity.task(
        meta: Metadata(
          id: id ?? uuid.v1(),
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
          // ignore: avoid_redundant_argument_values
          vectorClock: null,
        ),
        data: TaskData(
          title: title,
          status: TaskStatus.open(
            id: uuid.v1(),
            createdAt: now,
            utcOffset: 0,
          ),
          statusHistory: const [],
          dateFrom: now,
          dateTo: now,
        ),
        entryText: const EntryText(plainText: ''),
      )
      as Task;
}
