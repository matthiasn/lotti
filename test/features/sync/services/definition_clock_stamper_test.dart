import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/services/definition_clock_stamper.dart';
import 'package:mocktail/mocktail.dart';

import '../../../database/test_utils.dart';
import '../../../helpers/commit_evaluating_vector_clock_service.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  setUpAll(() {
    registerJournalDbTestFallbacks();
    registerAllFallbackValues();
  });

  final legacy = categoryMindfulness.copyWith(
    name: 'Legacy',
    updatedAt: DateTime.utc(2026, 9, 5, 10),
    vectorClock: null,
  );

  late Directory directory;
  late JournalDb db;
  late CommitEvaluatingVectorClockService vectorClockService;
  late MockOutboxService outboxService;
  late DefinitionClockStamper stamper;

  setUp(() {
    directory = setupTestDirectory();
    registerJournalDbTestServices(
      updateNotifications: MockUpdateNotifications(),
      loggingService: MockDomainLogger(),
      documentsDirectory: directory,
    );
    db = JournalDb(inMemoryDatabase: true);
    vectorClockService = CommitEvaluatingVectorClockService();
    when(
      () => vectorClockService.getNextVectorClock(
        previous: any(named: 'previous'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer(
      (invocation) async => VectorClock({
        ...?(invocation.namedArguments[#previous] as VectorClock?)?.vclock,
        'host': 3,
      }),
    );
    outboxService = MockOutboxService();
    when(
      () => outboxService.enqueueMessageOrThrow(any()),
    ).thenAnswer((_) async {});
    stamper = DefinitionClockStamper(
      journalDb: db,
      vectorClockService: vectorClockService,
      outboxService: outboxService,
    );
  });

  tearDown(() async {
    await db.close();
    unregisterJournalDbTestServices();
    directory.deleteSync(recursive: true);
  });

  SyncEntityDefinition sent() =>
      verify(
            () => outboxService.enqueueMessageOrThrow(captureAny()),
          ).captured.single
          as SyncEntityDefinition;

  test(
    'a clockless definition gets its own counter, content and updatedAt '
    'unchanged, and is stored and sent that way',
    () async {
      await db.upsertEntityDefinition(legacy);

      final stamped = await stamper.stamp(legacy.id);

      final expected = legacy.copyWith(
        vectorClock: const VectorClock({'host': 3}),
      );
      expect(stamped, expected);
      expect(await db.definitionById(legacy.id), expected);
      expect(sent().entityDefinition, expected);
      verify(
        () => vectorClockService.getNextVectorClock(
          payload: (
            id: legacy.id,
            type: SyncSequencePayloadType.entityDefinition,
          ),
        ),
      ).called(1);
      expect(vectorClockService.commits, [true]);
    },
  );

  // DefinitionClocks.tla, StampsBeaten: stamped on top of the clocked copy
  // it beat, the row supersedes that copy on every device.
  test('a stamp goes on top of the clock it is given', () async {
    await db.upsertEntityDefinition(legacy);

    final stamped = await stamper.stamp(
      legacy.id,
      over: const VectorClock({'peer': 4}),
    );

    expect(stamped?.vectorClock, const VectorClock({'peer': 4, 'host': 3}));
    expect(
      (await db.definitionStamp(legacy))?.vectorClock,
      const VectorClock({'peer': 4, 'host': 3}),
    );
  });

  test('a definition that already has a clock is left alone', () async {
    await db.upsertEntityDefinition(
      legacy.copyWith(vectorClock: const VectorClock({'peer': 1})),
    );

    expect(await stamper.stamp(legacy.id), isNull);

    verifyNever(
      () => vectorClockService.getNextVectorClock(
        previous: any(named: 'previous'),
        payload: any(named: 'payload'),
      ),
    );
    verifyNever(() => outboxService.enqueueMessageOrThrow(any()));
    expect(vectorClockService.commits, [false]);
  });

  test('an unknown id stamps nothing', () async {
    expect(await stamper.stamp('unknown'), isNull);

    verifyNever(() => outboxService.enqueueMessageOrThrow(any()));
  });

  test(
    'a failed enqueue rolls the stamp back and releases the counter, so the '
    'next run retries the row',
    () async {
      await db.upsertEntityDefinition(legacy);
      when(
        () => outboxService.enqueueMessageOrThrow(any()),
      ).thenThrow(StateError('outbox closed'));

      await expectLater(stamper.stamp(legacy.id), throwsStateError);

      expect((await db.definitionStamp(legacy))?.vectorClock, isNull);
      expect(await db.clocklessDefinitions(), [legacy]);
    },
  );
}
