// ignore_for_file: avoid_redundant_argument_values, unnecessary_lambdas
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_event_service.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/labels/services/label_assignment_rate_limiter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockLabelsRepository extends Mock implements LabelsRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class MockLimiter extends Mock implements LabelAssignmentRateLimiter {}

void main() {
  late MockJournalDb mockDb;
  late MockLabelsRepository mockRepo;
  late MockLoggingService mockLogging;
  late MockLimiter mockLimiter;
  late LabelAssignmentProcessor processor;

  setUp(() {
    mockDb = MockJournalDb();
    mockRepo = MockLabelsRepository();
    mockLogging = MockLoggingService();
    mockLimiter = MockLimiter();
    getIt.registerSingleton<LabelAssignmentEventService>(
      LabelAssignmentEventService(),
    );
    when(() => mockLimiter.isRateLimited(any())).thenReturn(false);
    when(() => mockRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        )).thenAnswer((_) async => true);
    processor = LabelAssignmentProcessor(
      db: mockDb,
      repository: mockRepo,
      rateLimiter: mockLimiter,
      logging: mockLogging,
    );
  });

  tearDown(() {
    getIt.reset();
  });

  LabelDefinition makeLabel(String id, {bool deleted = false}) =>
      LabelDefinition(
        id: id,
        name: id,
        color: '#000',
        description: null,
        sortOrder: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        deletedAt: deleted ? DateTime.now() : null,
      );

  test('assigns valid and filters invalid', () async {
    // existing contains p0 (ignored for exclusivity)
    when(() => mockDb.getLabelDefinitionById('p0'))
        .thenAnswer((_) async => makeLabel('p0'));

    // proposed: p1 (same group) -> now allowed, bug (no group) -> assigned, del (deleted) -> invalid
    when(() => mockDb.getLabelDefinitionById('p1'))
        .thenAnswer((_) async => makeLabel('p1'));
    when(() => mockDb.getLabelDefinitionById('bug'))
        .thenAnswer((_) async => makeLabel('bug'));
    when(() => mockDb.getLabelDefinitionById('del'))
        .thenAnswer((_) async => makeLabel('del', deleted: true));

    final result = await processor.processAssignment(
      taskId: 't1',
      proposedIds: const ['p1', 'bug', 'del'],
      existingIds: const ['p0'],
      shadowMode: false,
    );

    expect(result.assigned, containsAll(['bug', 'p1']));
    expect(result.invalid, contains('del'));
    verify(() => mockRepo.addLabels(
          journalEntityId: 't1',
          addedLabelIds: any(named: 'addedLabelIds'),
        )).called(1);
    verify(() => mockLimiter.recordAssignment('t1')).called(1);
  });

  test('rate limiting prevents persistence and returns rateLimited', () async {
    when(() => mockLimiter.isRateLimited('t1')).thenReturn(true);

    // Valid label but should not be persisted due to rate limit
    when(() => mockDb.getLabelDefinitionById('ok'))
        .thenAnswer((_) async => makeLabel('ok'));

    final result = await processor.processAssignment(
      taskId: 't1',
      proposedIds: const ['ok'],
      existingIds: const [],
      shadowMode: false,
    );

    expect(result.rateLimited, isTrue);
    verifyNever(() => mockRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        ));
    verifyNever(() => mockLimiter.recordAssignment(any()));
  });

  test('shadow mode computes but does not persist', () async {
    when(() => mockDb.getLabelDefinitionById('ok'))
        .thenAnswer((_) async => makeLabel('ok'));

    final result = await processor.processAssignment(
      taskId: 't1',
      proposedIds: const ['ok'],
      existingIds: const [],
      shadowMode: true,
    );

    expect(result.assigned, contains('ok'));
    verifyNever(() => mockRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        ));
    verifyNever(() => mockLimiter.recordAssignment(any()));
  });

  test('caps at maximum labels per assignment', () async {
    // Prepare 7 valid labels; only first 5 should be considered
    for (final id in const ['a', 'b', 'c', 'd', 'e', 'f', 'g']) {
      when(() => mockDb.getLabelDefinitionById(id))
          .thenAnswer((_) async => makeLabel(id));
    }

    final result = await processor.processAssignment(
      taskId: 't1',
      proposedIds: const ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
      existingIds: const [],
      shadowMode: false,
    );

    expect(result.assigned.length, lessThanOrEqualTo(5));
    verify(() => mockRepo.addLabels(
          journalEntityId: 't1',
          addedLabelIds: any(named: 'addedLabelIds'),
        )).called(1);
  });

  test('returns early for empty proposed list', () async {
    final result = await processor.processAssignment(
      taskId: 't1',
      proposedIds: const [],
      existingIds: const [],
      shadowMode: false,
    );

    expect(result.assigned, isEmpty);
    verifyNever(() => mockRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        ));
  });
}
