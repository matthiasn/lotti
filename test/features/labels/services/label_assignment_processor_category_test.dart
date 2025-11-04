// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/labels/services/label_assignment_rate_limiter.dart';
import 'package:lotti/features/labels/services/label_validator.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class FakeLabelsRepository extends Fake implements LabelsRepository {
  List<String> lastAdded = const [];
  @override
  Future<bool?> addLabels({
    required String journalEntityId,
    required List<String> addedLabelIds,
  }) async {
    lastAdded = List<String>.from(addedLabelIds);
    return true;
  }
}

class TestLoggingService extends LoggingService {
  @override
  void captureEvent(
    dynamic event, {
    required String domain,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
    InsightType type = InsightType.log,
  }) {
    // no-op for tests
  }

  @override
  void captureException(
    dynamic exception, {
    required String domain,
    String? subDomain,
    dynamic stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) {
    // no-op for tests
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('processor skips out-of-scope labels and assigns in-scope', () async {
    final db = MockJournalDb();
    final repo = FakeLabelsRepository();
    final logging = TestLoggingService();
    final validator = LabelValidator(db: db);

    // Task with category cat1
    final task = JournalEntity.task(
      meta: Metadata(
        id: 't1',
        createdAt: DateTime(2025, 11, 4),
        updatedAt: DateTime(2025, 11, 4),
        dateFrom: DateTime(2025, 11, 4),
        dateTo: DateTime(2025, 11, 4),
        categoryId: 'cat1',
        tags: null,
        tagIds: null,
        labelIds: const [],
        utcOffset: 0,
        timezone: null,
        vectorClock: null,
        deletedAt: null,
        flag: null,
        starred: null,
        private: null,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 's1',
          createdAt: DateTime(2025, 11, 4),
          utcOffset: 0,
        ),
        dateFrom: DateTime(2025, 11, 4),
        dateTo: DateTime(2025, 11, 4),
        statusHistory: const [],
        title: 'Task',
      ),
    );

    when(() => db.journalEntityById('t1')).thenAnswer((_) async => task);

    final now = DateTime(2025, 11, 4);
    final inScope = LabelDefinition(
      id: 'in',
      name: 'In',
      color: '#0f0',
      createdAt: now,
      updatedAt: now,
      vectorClock: null,
      applicableCategoryIds: const ['cat1'],
    );
    final outScope =
        inScope.copyWith(id: 'out', applicableCategoryIds: const ['other']);

    when(() => db.getLabelDefinitionById('in'))
        .thenAnswer((_) async => inScope);
    when(() => db.getLabelDefinitionById('out'))
        .thenAnswer((_) async => outScope);

    final processor = LabelAssignmentProcessor(
      db: db,
      repository: repo,
      logging: logging,
      rateLimiter: LabelAssignmentRateLimiter(),
      validator: validator,
    );

    final res = await processor.processAssignment(
      taskId: 't1',
      proposedIds: const ['in', 'out'],
      existingIds: const [],
    );

    // Assign only in-scope; out-of-scope is skipped with reason
    expect(res.assigned, ['in']);
    expect(res.invalid, isEmpty);
    expect(
        res.skipped
            .any((m) => m['id'] == 'out' && m['reason'] == 'out_of_scope'),
        isTrue);
  });
}
