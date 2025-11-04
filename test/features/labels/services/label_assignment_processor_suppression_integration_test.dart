// ignore_for_file: unnecessary_lambdas
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
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
  test('processor integrates validator + suppression + repository correctly',
      () async {
    final db = MockJournalDb();
    final repo = MockLabelsRepository();
    final log = MockLoggingService();

    // Task context
    const taskId = 't1';
    final task = Task(
      meta: Metadata(
        id: taskId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
        categoryId: 'engineering',
        labelIds: const ['A'], // already assigned
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 's',
          createdAt: DateTime.now(),
          utcOffset: 0,
        ),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
        statusHistory: const [],
        title: 'Task',
        aiSuppressedLabelIds: const {'S'},
      ),
    );

    // DB lookups used by processor/validator
    when(() => db.journalEntityById(taskId)).thenAnswer((_) async => task);
    // Label defs
    LabelDefinition global(String id) => LabelDefinition(
          id: id,
          name: id,
          color: '#000',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
          private: false,
        );
    LabelDefinition engineeringOnly(String id) => LabelDefinition(
          id: id,
          name: id,
          color: '#000',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
          private: false,
          applicableCategoryIds: const ['engineering'],
        );

    // getLabelDefinitionById
    when(() => db.getLabelDefinitionById('A'))
        .thenAnswer((_) async => global('A'));
    when(() => db.getLabelDefinitionById('S'))
        .thenAnswer((_) async => global('S'));
    when(() => db.getLabelDefinitionById('D')).thenAnswer(
        (_) async => global('D').copyWith(deletedAt: DateTime.now()));
    when(() => db.getLabelDefinitionById('C'))
        .thenAnswer((_) async => LabelDefinition(
              id: 'C',
              name: 'C',
              color: '#000',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
              private: false,
              applicableCategoryIds: const ['design'], // out of scope
            ));
    when(() => db.getLabelDefinitionById('G'))
        .thenAnswer((_) async => engineeringOnly('G'));

    // getAllLabelDefinitions used for out_of_scope classification path
    when(() => db.getAllLabelDefinitions()).thenAnswer((_) async => [
          global('A'),
          global('S'),
          global('D').copyWith(deletedAt: DateTime.now()),
          engineeringOnly('G'),
          LabelDefinition(
            id: 'C',
            name: 'C',
            color: '#000',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            vectorClock: null,
            private: false,
            applicableCategoryIds: const ['design'],
          ),
        ]);

    // Expect addLabels called only with the valid new id 'G'
    when(() => repo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any<List<String>>(named: 'addedLabelIds'),
        )).thenAnswer((_) async => true);

    // Capture telemetry
    final telemetry = <String>[];
    when(() => log.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        )).thenAnswer((inv) {
      telemetry.add(inv.positionalArguments.first as String);
    });

    final processor = LabelAssignmentProcessor(
      db: db,
      repository: repo,
      logging: log,
      rateLimiter: LabelAssignmentRateLimiter(),
      validator: LabelValidator(db: db),
    );

    final result = await processor.processAssignment(
      taskId: taskId,
      // Mix of already assigned, suppressed, deleted, out-of-scope, and valid
      proposedIds: const ['A', 'S', 'D', 'C', 'G'],
      existingIds: const ['A'],
      categoryId: 'engineering',
    );

    // Assert result
    expect(result.assigned, equals(['G']));
    expect(result.invalid.toSet(), contains('D'));
    final skippedReasons = {
      for (final m in result.skipped) m['id']!: m['reason']!
    };
    expect(skippedReasons['A'], 'already_assigned');
    expect(skippedReasons['S'], 'suppressed');
    expect(skippedReasons['C'], 'out_of_scope');

    // Persisted labels
    final captured = verify(() => repo.addLabels(
          journalEntityId: taskId,
          addedLabelIds: captureAny(named: 'addedLabelIds'),
        )).captured;
    final persisted = (captured.first as List).cast<String>();
    expect(persisted, equals(['G']));

    // Telemetry includes suppressed and out_of_scope counts
    expect(telemetry, isNotEmpty);
    final last = jsonDecode(telemetry.last) as Map<String, dynamic>;
    final skipped = last['skipped'] as Map<String, dynamic>;
    expect(skipped['suppressed'], 1);
    expect(skipped['out_of_scope'], 1);
    expect(last['assigned'], 1);
  });
}
