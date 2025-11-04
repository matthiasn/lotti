// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_event_service.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/labels/services/label_assignment_rate_limiter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:mocktail/mocktail.dart';

class MockLabelsRepository extends Mock implements LabelsRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class MockLimiter extends Mock implements LabelAssignmentRateLimiter {}

class MockJournalDb extends Mock implements JournalDb {}

void main() {
  setUpAll(() {
    registerFallbackValue(InsightLevel.info);
    registerFallbackValue(InsightType.log);
  });
  late MockLabelsRepository mockRepo;
  late MockLoggingService mockLogging;
  late MockLimiter mockLimiter;
  late MockJournalDb mockDb;
  late LabelAssignmentProcessor processor;

  setUp(() {
    mockRepo = MockLabelsRepository();
    mockLogging = MockLoggingService();
    mockLimiter = MockLimiter();
    mockDb = MockJournalDb();
    when(() => mockLimiter.isRateLimited(any())).thenReturn(false);
    getIt.registerSingleton<LabelAssignmentEventService>(
      LabelAssignmentEventService(),
    );
    processor = LabelAssignmentProcessor(
      db: mockDb,
      repository: mockRepo,
      rateLimiter: mockLimiter,
      logging: mockLogging,
    );
  });

  tearDown(getIt.reset);

  test('short-circuits when task already has >=3 labels', () async {
    final result = await processor.processAssignment(
      taskId: 't1',
      proposedIds: const ['a', 'b'],
      existingIds: const ['e1', 'e2', 'e3'],
      shadowMode: false,
    );

    expect(result.assigned, isEmpty);
    expect(result.invalid, isEmpty);
    expect(result.skipped, isEmpty);
    verifyNever(() => mockRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        ));

    // Verify a max_total_reached event was logged
    verify(() => mockLogging.captureEvent(
          any<dynamic>(),
          domain: 'labels_ai_assignment',
          subDomain: 'processor',
          level: any<InsightLevel>(named: 'level'),
          type: any<InsightType>(named: 'type'),
        )).called(1);
  });
}
