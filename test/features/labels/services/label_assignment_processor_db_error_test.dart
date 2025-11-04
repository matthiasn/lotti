import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/labels/services/label_assignment_rate_limiter.dart';
import 'package:lotti/features/labels/services/label_validator.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockLabelsRepository extends Mock implements LabelsRepository {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  test('processAssignment handles DB error when fetching suppression',
      () async {
    final db = MockJournalDb();
    final repo = MockLabelsRepository();
    final log = MockLoggingService();

    // Valid global label 'S'
    when(() => db.getLabelDefinitionById('S'))
        .thenAnswer((_) async => LabelDefinition(
              id: 'S',
              name: 'S',
              color: '#000',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
              private: false,
            ));
    // Suppression lookup fails
    when(() => db.journalEntityById(any())).thenThrow(Exception('db'));

    when(() => repo.addLabels(
          journalEntityId: any<String>(named: 'journalEntityId'),
          addedLabelIds: any<List<String>>(named: 'addedLabelIds'),
        )).thenAnswer((_) async => true);

    final processor = LabelAssignmentProcessor(
      db: db,
      repository: repo,
      rateLimiter: LabelAssignmentRateLimiter(),
      logging: log,
      validator: LabelValidator(db: db),
    );

    final res = await processor.processAssignment(
      taskId: 't',
      proposedIds: const ['S'],
      existingIds: const [],
      // omit categoryId (defaults to null)
    );

    // With suppression lookup failed, treat as not suppressed and assign
    expect(res.assigned, equals(['S']));
  });
}
