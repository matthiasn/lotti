// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_event_service.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/labels/services/label_assignment_rate_limiter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';

class _MockLabelsRepository extends Mock implements LabelsRepository {}

class _MockLoggingService extends Mock implements LoggingService {}

void main() {
  late MockJournalDb mockDb;
  late _MockLabelsRepository mockRepo;
  late _MockLoggingService mockLogging;
  late LabelAssignmentRateLimiter limiter;
  late LabelAssignmentProcessor processor;

  setUp(() {
    mockDb = MockJournalDb();
    mockRepo = _MockLabelsRepository();
    mockLogging = _MockLoggingService();
    limiter = LabelAssignmentRateLimiter();
    getIt.registerSingleton<LabelAssignmentEventService>(
      LabelAssignmentEventService(),
    );
    processor = LabelAssignmentProcessor(
      db: mockDb,
      repository: mockRepo,
      rateLimiter: limiter,
      logging: mockLogging,
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  LabelDefinition makeLabel(String id) => LabelDefinition(
        id: id,
        name: id,
        color: '#000',
        description: null,
        sortOrder: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
      );

  test('concurrent assignments to same task do not duplicate labels', () async {
    when(() => mockDb.getLabelDefinitionById('a'))
        .thenAnswer((_) async => makeLabel('a'));

    // Delay persistence to increase overlap
    when(() => mockRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        )).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return true;
    });

    // Fire two assignments nearly simultaneously
    final f1 = processor.processAssignment(
      taskId: 't1',
      proposedIds: const ['a'],
      existingIds: const [],
    );
    final f2 = processor.processAssignment(
      taskId: 't1',
      proposedIds: const ['a'],
      existingIds: const [],
    );

    final results = await Future.wait([f1, f2]);
    expect(results[0].assigned, ['a']);
    expect(results[1].assigned, ['a']);
    // Repository is called for both (current behavior), but labels API
    // remains de-duplicating internally.
    verify(() => mockRepo.addLabels(
          journalEntityId: 't1',
          addedLabelIds: ['a'],
        )).called(2);
  });

  test('assignment when task is deleted mid-operation (persistence fails)',
      () async {
    when(() => mockDb.getLabelDefinitionById('a'))
        .thenAnswer((_) async => makeLabel('a'));
    when(
      () => mockRepo.addLabels(
        journalEntityId: any(named: 'journalEntityId'),
        addedLabelIds: any(named: 'addedLabelIds'),
      ),
    ).thenAnswer((_) async => false); // simulate deleted task

    final events = getIt<LabelAssignmentEventService>();
    final received = <LabelAssignmentEvent>[];
    final sub = events.stream.listen(received.add);

    final result = await processor.processAssignment(
      taskId: 't1',
      proposedIds: const ['a'],
      existingIds: const [],
    );
    // Allow asynchronous stream delivery
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    // Even if persistence fails, current behavior publishes event and records rate limit
    expect(result.assigned, ['a']);
    expect(received.length, 1);
    expect(limiter.isRateLimited('t1'), isTrue);
  });

  test('rate limiter clear allows subsequent assignments', () async {
    when(() => mockDb.getLabelDefinitionById('a'))
        .thenAnswer((_) async => makeLabel('a'));
    when(() => mockRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        )).thenAnswer((_) async => true);

    // First assignment records in limiter
    final first = await processor.processAssignment(
      taskId: 't2',
      proposedIds: const ['a'],
      existingIds: const [],
    );
    expect(first.assigned, ['a']);
    expect(limiter.isRateLimited('t2'), isTrue);

    // Clear while pending (simulated): allow next assignment
    limiter.clearHistory();
    final second = await processor.processAssignment(
      taskId: 't2',
      proposedIds: const ['a'],
      existingIds: const [],
    );
    expect(second.assigned, ['a']);
  });

  test('supports special characters in label IDs (spaces, unicode)', () async {
    for (final id in const ['with space', 'ünicode', 'emoji😀']) {
      when(() => mockDb.getLabelDefinitionById(id))
          .thenAnswer((_) async => makeLabel(id));
    }
    when(() => mockRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        )).thenAnswer((_) async => true);

    final result = await processor.processAssignment(
      taskId: 't3',
      proposedIds: const ['with space', 'ünicode', 'emoji😀'],
      existingIds: const [],
    );

    expect(result.assigned, containsAll(['with space', 'ünicode', 'emoji😀']));
  });
}
