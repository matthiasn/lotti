// ignore_for_file: avoid_redundant_argument_values
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
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
  setUpAll(() {
    // Provide fallbacks for enums used in mocked method signatures
    registerFallbackValue(InsightLevel.info);
    registerFallbackValue(InsightType.log);
  });

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

    when(() => mockLimiter.isRateLimited(any())).thenReturn(false);
    when(() => mockRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        )).thenAnswer((_) async => true);

    // Define all labels as valid global labels
    Future<LabelDefinition> def(String id) async => LabelDefinition(
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
    for (final id in const ['a', 'b', 'c', 'd']) {
      when(() => mockDb.getLabelDefinitionById(id)).thenAnswer((_) => def(id));
    }

    // Register mocks that LabelAssignmentProcessor may access indirectly
    getIt
      ..registerSingleton<LabelAssignmentRateLimiter>(mockLimiter)
      ..registerSingleton<LoggingService>(mockLogging)
      ..registerSingleton<JournalDb>(mockDb);

    processor = LabelAssignmentProcessor(
      db: mockDb,
      repository: mockRepo,
      rateLimiter: mockLimiter,
      logging: mockLogging,
    );
  });

  tearDown(getIt.reset);

  test(
      'processor telemetry includes dropped_low, legacy_capped and confidenceBreakdown',
      () async {
    // Act
    await processor.processAssignment(
      taskId: 't1',
      proposedIds: const ['a', 'b', 'c'],
      existingIds: const [],
      // Phase 2 parser metrics
      droppedLow: 1,
      legacyUsed: true,
      totalCandidates: 5,
      confidenceBreakdown: const {
        'very_high': 0,
        'high': 2,
        'medium': 1,
        'low': 1,
      },
    );

    // Assert captureEvent was called with JSON containing the fields
    final captured = verify(() => mockLogging.captureEvent(
          captureAny<dynamic>(),
          domain: captureAny(named: 'domain'),
          subDomain: captureAny(named: 'subDomain'),
          level: any(named: 'level'),
          type: any(named: 'type'),
        )).captured;
    expect(captured, isNotEmpty);
    final message = captured.first as String;
    final telemetry = jsonDecode(message) as Map<String, dynamic>;
    expect(telemetry['dropped_low'], 1);
    expect(telemetry['legacy_capped'], isTrue);
    final breakdown =
        Map<String, dynamic>.from(telemetry['confidenceBreakdown'] as Map);
    expect(breakdown['high'], 2);
    expect(breakdown['medium'], 1);
    expect(breakdown['low'], 1);
  });
}
