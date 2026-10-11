import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_link.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/agents/agent_database.dart' hide AgentLink;
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/sync/services/agent_clock_stamper.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/commit_evaluating_vector_clock_service.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late AgentDatabase db;
  late AgentRepository repository;
  late CommitEvaluatingVectorClockService vectorClockService;
  late MockOutboxService outboxService;
  late AgentClockStamper stamper;

  final clockless = makeTestIdentity(id: 'agent-1', agentId: 'agent-1');
  final link = AgentLink.agentTask(
    id: 'link-1',
    fromId: 'agent-1',
    toId: 'task-1',
    createdAt: DateTime(2024, 3, 15),
    updatedAt: DateTime(2024, 3, 15),
    vectorClock: null,
  );

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    repository = AgentRepository(db);
    vectorClockService = CommitEvaluatingVectorClockService();
    when(
      () => vectorClockService.getNextVectorClock(
        previous: any(named: 'previous'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async => const VectorClock({'host': 3}));
    outboxService = MockOutboxService();
    when(
      () => outboxService.enqueueMessageOrThrow(any()),
    ).thenAnswer((_) async {});
    stamper = AgentClockStamper(
      agentRepository: repository,
      vectorClockService: vectorClockService,
      outboxService: outboxService,
    );
  });

  tearDown(() => db.close());

  List<SyncMessage> sent() => verify(
    () => outboxService.enqueueMessageOrThrow(captureAny()),
  ).captured.cast<SyncMessage>();

  test('a clockless entity is stamped from the row stored now, stored and '
      'sent that way', () async {
    await repository.upsertEntity(clockless);
    // An edit lands after a caller listed the row: the stamp must carry it.
    final edited = clockless.copyWith(displayName: 'Edited meanwhile');
    await repository.upsertEntity(edited);

    final stamped = await stamper.stampEntity('agent-1');

    expect(
      stamped,
      edited.copyWith(vectorClock: const VectorClock({'host': 3})),
    );
    expect(await repository.getEntityIncludingDeleted('agent-1'), stamped);
    expect(
      (sent().single as SyncAgentEntity).agentEntity,
      stamped,
    );
  });

  test('an entity that has a clock by now is left as it stands, one that '
      'is gone is null, and nothing is sent', () async {
    final clocked = clockless.copyWith(
      vectorClock: const VectorClock({'peer': 7}),
    );
    await repository.upsertEntity(clocked);

    // Returned as it stands, for a caller that sends it.
    expect(await stamper.stampEntity('agent-1'), clocked);
    expect(await stamper.stampEntity('missing'), isNull);
    expect(await repository.getEntityIncludingDeleted('agent-1'), clocked);
    verifyNever(() => outboxService.enqueueMessageOrThrow(any()));
  });

  test('a failed enqueue rolls the stamp back, so the next run retries the '
      'entity', () async {
    await repository.upsertEntity(clockless);
    when(
      () => outboxService.enqueueMessageOrThrow(any()),
    ).thenThrow(Exception('outbox down'));

    await expectLater(stamper.stampEntity('agent-1'), throwsException);

    expect(
      (await repository.getEntityIncludingDeleted('agent-1'))?.vectorClock,
      isNull,
    );
  });

  test('without send, the stamp is stored and the caller sends it', () async {
    await repository.upsertEntity(clockless);

    final stamped = await stamper.stampEntity('agent-1', send: false);

    expect(stamped?.vectorClock, const VectorClock({'host': 3}));
    expect(await repository.getEntityIncludingDeleted('agent-1'), stamped);
    verifyNever(() => outboxService.enqueueMessageOrThrow(any()));
  });

  test('a clockless link is stamped from the stored row and sent; one with '
      'a clock is left alone', () async {
    await repository.upsertLink(link);

    final stamped = await stamper.stampLink('link-1');

    expect(stamped, link.copyWith(vectorClock: const VectorClock({'host': 3})));
    expect(await repository.getLinkByIdIncludingDeleted('link-1'), stamped);
    expect((sent().single as SyncAgentLink).agentLink, stamped);

    expect(await stamper.stampLink('link-1'), stamped);
    expect(await stamper.stampLink('missing', send: false), isNull);
  });

  test('without send, a stamped link is stored and not sent', () async {
    await repository.upsertLink(link);

    final stamped = await stamper.stampLink('link-1', send: false);

    expect(stamped?.vectorClock, const VectorClock({'host': 3}));
    verifyNever(() => outboxService.enqueueMessageOrThrow(any()));
  });
}
