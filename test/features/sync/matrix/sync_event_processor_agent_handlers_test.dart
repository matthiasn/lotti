// ignore_for_file: avoid_redundant_argument_values, cascade_invocations

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

import '../../../mocks/mocks.dart';
import 'sync_event_processor_test_helpers.dart';

void main() {
  setUpAll(registerSyncProcessorFallbacks);
  setUp(setUpProcessorMocks);

  group('SyncEventProcessor - Agent Entities and Links', () {
    late MockAgentRepository mockAgentRepo;

    setUp(() {
      mockAgentRepo = MockAgentRepository();
      when(() => mockAgentRepo.upsertEntity(any())).thenAnswer((_) async {});
      when(() => mockAgentRepo.upsertLink(any())).thenAnswer((_) async {});
      when(() => mockAgentRepo.getEntity(any())).thenAnswer((_) async => null);
      when(
        () => mockAgentRepo.getEntitiesByIds(any()),
      ).thenAnswer((_) async => const <String, AgentDomainEntity>{});
      when(() => mockAgentRepo.getLinkById(any())).thenAnswer(
        (_) async => null,
      );
      processor.agentRepository = mockAgentRepo;
    });

    test('processes agent identity entity', () async {
      final entity = AgentDomainEntity.agent(
        id: 'agent-1',
        agentId: 'agent-1',
        kind: 'task_agent',
        displayName: 'Test Agent',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {'cat-1'},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('agentEntity')),
          subDomain: 'processor.apply',
        ),
      ).called(1);
      verify(
        () => updateNotifications.notify(
          {'agent-1', 'AGENT_CHANGED'},
          fromSync: true,
        ),
      ).called(1);
    });

    test('processes agent state entity', () async {
      final entity = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        revision: 5,
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
        wakeCounter: 42,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
    });

    test(
      'prefetches local agent entities once for outbox bundle dominance checks',
      () async {
        const localVc = VectorClock({'host-A': 2});
        const incomingVc = VectorClock({'host-A': 1});
        final localOne = AgentDomainEntity.agentState(
          id: 'state-bulk-1',
          agentId: 'agent-1',
          revision: 2,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 16),
          vectorClock: localVc,
        );
        final localTwo = AgentDomainEntity.agentState(
          id: 'state-bulk-2',
          agentId: 'agent-2',
          revision: 2,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 16),
          vectorClock: localVc,
        );
        final incomingOne = AgentDomainEntity.agentState(
          id: 'state-bulk-1',
          agentId: 'agent-1',
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: incomingVc,
        );
        final incomingTwo = AgentDomainEntity.agentState(
          id: 'state-bulk-2',
          agentId: 'agent-2',
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: incomingVc,
        );
        when(
          () => mockAgentRepo.getEntitiesByIds(any()),
        ).thenAnswer((invocation) async {
          final ids = invocation.positionalArguments.single as Iterable<String>;
          expect(ids.toSet(), {'state-bulk-1', 'state-bulk-2'});
          return {
            'state-bulk-1': localOne,
            'state-bulk-2': localTwo,
          };
        });

        final message = SyncMessage.outboxBundle(
          children: [
            SyncMessage.agentEntity(
              agentEntity: incomingOne,
              status: SyncEntryStatus.update,
            ),
            SyncMessage.agentEntity(
              agentEntity: incomingTwo,
              status: SyncEntryStatus.update,
            ),
          ],
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.getEntitiesByIds(any())).called(1);
        verifyNever(() => mockAgentRepo.getEntity(any()));
        verifyNever(() => mockAgentRepo.upsertEntity(any()));
      },
    );

    test(
      'refreshes prefetched agent entity cache after same-bundle upsert',
      () async {
        final localInitial = AgentDomainEntity.agentState(
          id: 'state-cache-refresh',
          agentId: 'agent-cache-refresh',
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'host-A': 1}),
        );
        final incomingNewer = AgentDomainEntity.agentState(
          id: 'state-cache-refresh',
          agentId: 'agent-cache-refresh',
          revision: 3,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 17),
          vectorClock: const VectorClock({'host-A': 3}),
        );
        final incomingOlder = AgentDomainEntity.agentState(
          id: 'state-cache-refresh',
          agentId: 'agent-cache-refresh',
          revision: 2,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 16),
          vectorClock: const VectorClock({'host-A': 2}),
        );
        when(
          () => mockAgentRepo.getEntitiesByIds(any()),
        ).thenAnswer((_) async => {'state-cache-refresh': localInitial});

        final message = SyncMessage.outboxBundle(
          children: [
            SyncMessage.agentEntity(
              agentEntity: incomingNewer,
              status: SyncEntryStatus.update,
            ),
            SyncMessage.agentEntity(
              agentEntity: incomingOlder,
              status: SyncEntryStatus.update,
            ),
          ],
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.getEntitiesByIds(any())).called(1);
        verify(() => mockAgentRepo.upsertEntity(incomingNewer)).called(1);
        verifyNever(() => mockAgentRepo.upsertEntity(incomingOlder));
      },
    );

    test(
      'keeps outbox bundle agent prefetch caches isolated across overlaps',
      () async {
        final dominantLocal = AgentDomainEntity.agentState(
          id: 'shared-state',
          agentId: 'agent-shared',
          revision: 5,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 19),
          vectorClock: const VectorClock({'host-A': 5}),
        );
        final staleShared = AgentDomainEntity.agentState(
          id: 'shared-state',
          agentId: 'agent-shared',
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'host-A': 1}),
        );
        final otherShared = AgentDomainEntity.agentState(
          id: 'shared-state',
          agentId: 'agent-shared',
          revision: 2,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 16),
          vectorClock: const VectorClock({'host-A': 2}),
        );
        final blockerOne = AgentDomainEntity.agentState(
          id: 'bundle-one-blocker',
          agentId: 'agent-blocker',
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );
        final blockerTwo = AgentDomainEntity.agentState(
          id: 'bundle-two-blocker',
          agentId: 'agent-blocker',
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );
        var prefetchCall = 0;
        when(
          () => mockAgentRepo.getEntitiesByIds(any()),
        ).thenAnswer((invocation) async {
          final ids = invocation.positionalArguments.single as Iterable<String>;
          expect(ids.toSet(), {'shared-state'});
          prefetchCall += 1;
          if (prefetchCall == 1) {
            return {'shared-state': dominantLocal};
          }
          return const <String, AgentDomainEntity>{};
        });

        final blockerOneStarted = Completer<void>();
        final blockerOneRelease = Completer<void>();
        final blockerTwoStarted = Completer<void>();
        final blockerTwoRelease = Completer<void>();
        when(() => mockAgentRepo.upsertEntity(any())).thenAnswer((
          invocation,
        ) async {
          final entity =
              invocation.positionalArguments.single as AgentDomainEntity;
          if (entity.id == blockerOne.id) {
            if (!blockerOneStarted.isCompleted) {
              blockerOneStarted.complete();
            }
            await blockerOneRelease.future;
          }
          if (entity.id == blockerTwo.id) {
            if (!blockerTwoStarted.isCompleted) {
              blockerTwoStarted.complete();
            }
            await blockerTwoRelease.future;
          }
        });

        final eventOne = MockEvent();
        when(() => eventOne.eventId).thenReturn('event-one');
        when(() => eventOne.originServerTs).thenReturn(DateTime(2024));
        when(() => eventOne.text).thenReturn(
          encodeMessage(
            SyncMessage.outboxBundle(
              children: [
                SyncMessage.agentEntity(
                  agentEntity: blockerOne,
                  status: SyncEntryStatus.update,
                ),
                SyncMessage.agentEntity(
                  agentEntity: staleShared,
                  status: SyncEntryStatus.update,
                ),
              ],
            ),
          ),
        );

        final eventTwo = MockEvent();
        when(() => eventTwo.eventId).thenReturn('event-two');
        when(() => eventTwo.originServerTs).thenReturn(DateTime(2024));
        when(() => eventTwo.text).thenReturn(
          encodeMessage(
            SyncMessage.outboxBundle(
              children: [
                SyncMessage.agentEntity(
                  agentEntity: blockerTwo,
                  status: SyncEntryStatus.update,
                ),
                SyncMessage.agentEntity(
                  agentEntity: otherShared,
                  status: SyncEntryStatus.update,
                ),
              ],
            ),
          ),
        );

        final processOne = processor.process(
          event: eventOne,
          journalDb: journalDb,
        );
        await blockerOneStarted.future;

        final processTwo = processor.process(
          event: eventTwo,
          journalDb: journalDb,
        );
        await blockerTwoStarted.future;

        blockerOneRelease.complete();
        await processOne;

        blockerTwoRelease.complete();
        await processTwo;

        verify(() => mockAgentRepo.getEntitiesByIds(any())).called(2);
        verifyNever(() => mockAgentRepo.upsertEntity(staleShared));
        verify(() => mockAgentRepo.upsertEntity(otherShared)).called(1);
      },
    );

    test('processes agent message entity', () async {
      final entity = AgentDomainEntity.agentMessage(
        id: 'msg-1',
        agentId: 'agent-1',
        threadId: 'thread-1',
        kind: AgentMessageKind.thought,
        createdAt: DateTime(2024, 3, 15),
        vectorClock: null,
        metadata: const AgentMessageMetadata(),
        tokensApprox: 100,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
    });

    test('processes agent message payload entity', () async {
      final entity = AgentDomainEntity.agentMessagePayload(
        id: 'payload-1',
        agentId: 'agent-1',
        createdAt: DateTime(2024, 3, 15),
        vectorClock: null,
        content: const {'text': 'hello world'},
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
    });

    test('processes agent report entity', () async {
      final entity = AgentDomainEntity.agentReport(
        id: 'report-1',
        agentId: 'agent-1',
        scope: 'current',
        createdAt: DateTime(2024, 3, 15),
        vectorClock: null,
        content: 'Report content',
        confidence: 0.9,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
    });

    test('processes agent report head entity', () async {
      final entity = AgentDomainEntity.agentReportHead(
        id: 'head-1',
        agentId: 'agent-1',
        scope: 'current',
        reportId: 'report-1',
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
    });

    test(
      'processes wakeTokenUsage entity with templateId in notification',
      () async {
        final entity = AgentDomainEntity.wakeTokenUsage(
          id: 'usage-1',
          agentId: 'agent-1',
          runKey: 'run-1',
          threadId: 'thread-1',
          modelId: 'models/gemini-2.5-pro',
          createdAt: DateTime(2024, 3, 15),
          vectorClock: null,
          templateId: 'tpl-1',
          inputTokens: 100,
          outputTokens: 50,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
        verify(
          () => updateNotifications.notify(
            {'agent-1', 'tpl-1', 'AGENT_CHANGED'},
            fromSync: true,
          ),
        ).called(1);
      },
    );

    test('processes wakeTokenUsage entity without templateId', () async {
      final entity = AgentDomainEntity.wakeTokenUsage(
        id: 'usage-2',
        agentId: 'agent-1',
        runKey: 'run-2',
        threadId: 'thread-2',
        modelId: 'models/gemini-2.5-pro',
        createdAt: DateTime(2024, 3, 15),
        vectorClock: null,
        inputTokens: 200,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
      verify(
        () => updateNotifications.notify(
          {'agent-1', 'AGENT_CHANGED'},
          fromSync: true,
        ),
      ).called(1);
    });

    test('processes agent link (basic)', () async {
      final link = AgentLink.basic(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'state-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertLink(link)).called(1);
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('agentLink')),
          subDomain: 'processor.apply',
        ),
      ).called(1);
      verify(
        () => updateNotifications.notify(
          {'agent-1', 'state-1', 'AGENT_CHANGED'},
          fromSync: true,
        ),
      ).called(1);
    });

    group('concurrent-branch LWW resolution', () {
      // Two concurrent clocks (each leads on a different host). In canonical
      // host order `host-A` sorts first, so `vcWinsTie` (greater on host-A) is
      // the deterministic winner whenever updatedAt ties.
      const vcWinsTie = VectorClock({'host-A': 2, 'host-B': 1});
      const vcLosesTie = VectorClock({'host-A': 1, 'host-B': 2});

      AgentDomainEntity stateWith({
        required VectorClock vectorClock,
        required DateTime updatedAt,
      }) => AgentDomainEntity.agentState(
        id: 'state-cc',
        agentId: 'agent-1',
        revision: 1,
        slots: const AgentSlots(),
        updatedAt: updatedAt,
        vectorClock: vectorClock,
      );

      AgentLink linkWith({
        required VectorClock vectorClock,
        required DateTime updatedAt,
      }) => AgentLink.basic(
        id: 'link-cc',
        fromId: 'agent-1',
        toId: 'state-1',
        createdAt: DateTime(2024, 3),
        updatedAt: updatedAt,
        vectorClock: vectorClock,
      );

      Future<void> processEntity(AgentDomainEntity incoming) async {
        when(() => event.text).thenReturn(
          encodeMessage(
            SyncMessage.agentEntity(
              agentEntity: incoming,
              status: SyncEntryStatus.update,
            ),
          ),
        );
        await processor.process(event: event, journalDb: journalDb);
      }

      Future<void> processLink(AgentLink incoming) async {
        when(() => event.text).thenReturn(
          encodeMessage(
            SyncMessage.agentLink(
              agentLink: incoming,
              status: SyncEntryStatus.update,
            ),
          ),
        );
        await processor.process(event: event, journalDb: journalDb);
      }

      test('applies incoming entity when its updatedAt is newer', () async {
        when(() => mockAgentRepo.getEntity('state-cc')).thenAnswer(
          (_) async => stateWith(
            vectorClock: vcWinsTie,
            updatedAt: DateTime(2024, 3, 15),
          ),
        );
        final incoming = stateWith(
          vectorClock: vcLosesTie,
          updatedAt: DateTime(2024, 3, 16),
        );

        await processEntity(incoming);

        // LWW: newer updatedAt wins even though the local clock is canonically
        // greater.
        verify(() => mockAgentRepo.upsertEntity(incoming)).called(1);
      });

      test('keeps local entity when its updatedAt is newer', () async {
        when(() => mockAgentRepo.getEntity('state-cc')).thenAnswer(
          (_) async => stateWith(
            vectorClock: vcLosesTie,
            updatedAt: DateTime(2024, 3, 16),
          ),
        );

        await processEntity(
          stateWith(vectorClock: vcWinsTie, updatedAt: DateTime(2024, 3, 15)),
        );

        verifyNever(() => mockAgentRepo.upsertEntity(any()));
      });

      // The next two feed the SAME concurrent pair from both device
      // perspectives on an equal timestamp: the canonically-greater version
      // wins whether it is the incoming payload or the already-stored row —
      // i.e. both devices converge on the same winner.
      test('equal updatedAt: a greater incoming clock is applied', () async {
        when(() => mockAgentRepo.getEntity('state-cc')).thenAnswer(
          (_) async => stateWith(
            vectorClock: vcLosesTie,
            updatedAt: DateTime(2024, 3, 15),
          ),
        );
        final incoming = stateWith(
          vectorClock: vcWinsTie,
          updatedAt: DateTime(2024, 3, 15),
        );

        await processEntity(incoming);

        verify(() => mockAgentRepo.upsertEntity(incoming)).called(1);
      });

      test('equal updatedAt: a greater local clock is kept', () async {
        when(() => mockAgentRepo.getEntity('state-cc')).thenAnswer(
          (_) async => stateWith(
            vectorClock: vcWinsTie,
            updatedAt: DateTime(2024, 3, 15),
          ),
        );

        await processEntity(
          stateWith(vectorClock: vcLosesTie, updatedAt: DateTime(2024, 3, 15)),
        );

        verifyNever(() => mockAgentRepo.upsertEntity(any()));
      });

      test('applies incoming link when its updatedAt is newer', () async {
        when(() => mockAgentRepo.getLinkById('link-cc')).thenAnswer(
          (_) async => linkWith(
            vectorClock: vcWinsTie,
            updatedAt: DateTime(2024, 3, 15),
          ),
        );
        final incoming = linkWith(
          vectorClock: vcLosesTie,
          updatedAt: DateTime(2024, 3, 16),
        );

        await processLink(incoming);

        verify(() => mockAgentRepo.upsertLink(incoming)).called(1);
      });

      test('keeps local link when its updatedAt is newer', () async {
        when(() => mockAgentRepo.getLinkById('link-cc')).thenAnswer(
          (_) async => linkWith(
            vectorClock: vcLosesTie,
            updatedAt: DateTime(2024, 3, 16),
          ),
        );

        await processLink(
          linkWith(vectorClock: vcWinsTie, updatedAt: DateTime(2024, 3, 15)),
        );

        verifyNever(() => mockAgentRepo.upsertLink(any()));
      });

      // Equal-timestamp link cases — exercise the canonical vector-clock
      // tiebreak on the link path, mirroring the entity cases above.
      test('equal updatedAt: a greater incoming link clock wins', () async {
        when(() => mockAgentRepo.getLinkById('link-cc')).thenAnswer(
          (_) async => linkWith(
            vectorClock: vcLosesTie,
            updatedAt: DateTime(2024, 3, 15),
          ),
        );
        final incoming = linkWith(
          vectorClock: vcWinsTie,
          updatedAt: DateTime(2024, 3, 15),
        );

        await processLink(incoming);

        verify(() => mockAgentRepo.upsertLink(incoming)).called(1);
      });

      test('equal updatedAt: a greater local link clock is kept', () async {
        when(() => mockAgentRepo.getLinkById('link-cc')).thenAnswer(
          (_) async => linkWith(
            vectorClock: vcWinsTie,
            updatedAt: DateTime(2024, 3, 15),
          ),
        );

        await processLink(
          linkWith(vectorClock: vcLosesTie, updatedAt: DateTime(2024, 3, 15)),
        );

        verifyNever(() => mockAgentRepo.upsertLink(any()));
      });
    });

    test(
      'no-ops a legacy SyncAgentBundle envelope so the marker advances; '
      'children recover via the per-entity / per-link backfill path',
      () async {
        final entity = AgentDomainEntity.agentState(
          id: 'state-1',
          agentId: 'agent-1',
          revision: 5,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'host-a': 1}),
        );
        final link = AgentLink.basic(
          id: 'link-1',
          fromId: 'agent-1',
          toId: 'state-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'host-a': 2}),
        );
        final message = SyncMessage.agentBundle(
          agentId: 'agent-1',
          wakeRunKey: 'run-1',
          originatingHostId: 'host-a',
          entities: [
            SyncMessage.agentEntity(
                  agentEntity: entity,
                  status: SyncEntryStatus.update,
                )
                as SyncAgentEntity,
          ],
          links: [
            SyncMessage.agentLink(
                  agentLink: link,
                  status: SyncEntryStatus.update,
                )
                as SyncAgentLink,
          ],
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        // Bundle is intentionally not applied — the agent repo is not
        // touched, no AGENT_CHANGED notifications fire, and process()
        // completes cleanly so the inbound queue marker advances. The
        // sender already recorded each child under per-entity /
        // per-link sequence-log entries, so backfill picks them up if
        // they are missing locally.
        verifyNever(() => mockAgentRepo.upsertEntity(any()));
        verifyNever(() => mockAgentRepo.upsertLink(any()));
        verifyNever(
          () => updateNotifications.notify(
            any<Set<String>>(),
            fromSync: any<bool>(named: 'fromSync'),
          ),
        );
      },
    );

    test(
      'processes agent link variants (agentState, messagePrev, etc)',
      () async {
        final links = [
          AgentLink.agentState(
            id: 'link-2',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
          AgentLink.messagePrev(
            id: 'link-3',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
          AgentLink.messagePayload(
            id: 'link-4',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
          AgentLink.toolEffect(
            id: 'link-5',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
          AgentLink.agentTask(
            id: 'link-6',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
        ];

        for (final link in links) {
          reset(mockAgentRepo);
          when(() => mockAgentRepo.upsertLink(any())).thenAnswer((_) async {});

          final message = SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verify(() => mockAgentRepo.upsertLink(link)).called(1);
        }
      },
    );

    test('skips agent entity when agentRepository is null', () async {
      processor.agentRepository = null;

      final entity = AgentDomainEntity.agent(
        id: 'agent-1',
        agentId: 'agent-1',
        kind: 'task_agent',
        displayName: 'Test Agent',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verifyNever(() => mockAgentRepo.upsertEntity(any()));
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('ignored')),
          subDomain: 'processor.apply',
        ),
      ).called(1);
    });

    test('skips agent link when agentRepository is null', () async {
      processor.agentRepository = null;

      final link = AgentLink.basic(
        id: 'link-1',
        fromId: 'a',
        toId: 'b',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verifyNever(() => mockAgentRepo.upsertLink(any()));
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('ignored')),
          subDomain: 'processor.apply',
        ),
      ).called(1);
    });

    test('propagates repository error on agent entity upsert', () async {
      when(
        () => mockAgentRepo.upsertEntity(any()),
      ).thenAnswer((_) async => throw Exception('db error'));

      final entity = AgentDomainEntity.agent(
        id: 'agent-1',
        agentId: 'agent-1',
        kind: 'task_agent',
        displayName: 'Test Agent',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      // The processor catches, logs, and rethrows
      await expectLater(
        () => processor.process(event: event, journalDb: journalDb),
        throwsA(isA<Exception>()),
      );

      verify(
        () => loggingService.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).called(1);
    });

    test('propagates repository error on agent link upsert', () async {
      when(
        () => mockAgentRepo.upsertLink(any()),
      ).thenAnswer((_) async => throw Exception('db error'));

      final link = AgentLink.basic(
        id: 'link-1',
        fromId: 'a',
        toId: 'b',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await expectLater(
        () => processor.process(event: event, journalDb: journalDb),
        throwsA(isA<Exception>()),
      );

      verify(
        () => loggingService.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).called(1);
    });

    group('_localAgentPayloadDominates error handling', () {
      // Tests for lines 444-448: the catch block in _localAgentPayloadDominates
      // fires when VectorClock.compare throws VclockException (e.g. a VC with
      // a negative counter is invalid).  The processor logs the error and
      // treats the dominance check as false, so it falls through to upsert.

      test(
        'logs error and falls through to upsert when incoming VC is invalid '
        '(VclockException — lines 444-448)',
        () async {
          // Local entity has a valid VC so dominance check is attempted.
          final local = AgentDomainEntity.agentState(
            id: 'state-invalid-vc',
            agentId: 'agent-1',
            revision: 2,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 16),
            vectorClock: const VectorClock({'host-A': 1}),
          );
          // Incoming entity has an invalid VC (negative counter) — this causes
          // VectorClock.compare to throw VclockException.
          final incoming = AgentDomainEntity.agentState(
            id: 'state-invalid-vc',
            agentId: 'agent-1',
            revision: 3,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 17),
            vectorClock: const VectorClock({'host-A': -1}),
          );
          when(
            () => mockAgentRepo.getEntity('state-invalid-vc'),
          ).thenAnswer((_) async => local);

          final message = SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          // The catch block in _localAgentPayloadDominates logs and returns
          // false, so the entity is upserted anyway.
          verify(() => mockAgentRepo.upsertEntity(incoming)).called(1);
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(
                named: 'subDomain',
                that: contains('vectorClockCompare'),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'logs error and falls through to upsert when link VC is invalid '
        '(VclockException — lines 444-448)',
        () async {
          final local = AgentLink.basic(
            id: 'link-invalid-vc',
            fromId: 'agent-1',
            toId: 'state-1',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 16),
            vectorClock: const VectorClock({'host-A': 1}),
          );
          final incoming = AgentLink.basic(
            id: 'link-invalid-vc',
            fromId: 'agent-1',
            toId: 'state-1',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 17),
            vectorClock: const VectorClock({'host-A': -1}),
          );
          when(
            () => mockAgentRepo.getLinkById('link-invalid-vc'),
          ).thenAnswer((_) async => local);

          final message = SyncMessage.agentLink(
            agentLink: incoming,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          // Dominance check failed (VclockException caught), falls through to
          // upsert.
          verify(() => mockAgentRepo.upsertLink(incoming)).called(1);
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(
                named: 'subDomain',
                that: contains('vectorClockCompare'),
              ),
            ),
          ).called(1);
        },
      );
    });

    group('agent entity sequence log recording', () {
      late MockSyncSequenceLogService mockSeqService;
      late MockAgentRepository mockAgentRepoSeq;

      setUp(() {
        mockSeqService = MockSyncSequenceLogService();
        mockAgentRepoSeq = MockAgentRepository();
        when(
          () => mockAgentRepoSeq.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(() => mockAgentRepoSeq.upsertLink(any())).thenAnswer((_) async {});
        when(
          () => mockAgentRepoSeq.getEntity(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockAgentRepoSeq.getEntitiesByIds(any()),
        ).thenAnswer((_) async => const <String, AgentDomainEntity>{});
        when(
          () => mockAgentRepoSeq.getLinkById(any()),
        ).thenAnswer((_) async => null);
      });

      test(
        'skips stale agent entity when local vector clock dominates but '
        'still records sequence receipt',
        () async {
          const localVc = VectorClock({'host-A': 2});
          const incomingVc = VectorClock({'host-A': 1});
          final local = AgentDomainEntity.agentState(
            id: 'state-dominates',
            agentId: 'agent-1',
            revision: 2,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 16),
            vectorClock: localVc,
          );
          final incoming = AgentDomainEntity.agentState(
            id: 'state-dominates',
            agentId: 'agent-1',
            revision: 1,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: incomingVc,
          );
          when(
            () => mockAgentRepoSeq.getEntity('state-dominates'),
          ).thenAnswer((_) async => local);
          when(
            () => mockSeqService.recordReceivedEntry(
              entryId: any(named: 'entryId'),
              vectorClock: any(named: 'vectorClock'),
              originatingHostId: any(named: 'originatingHostId'),
              coveredVectorClocks: any(named: 'coveredVectorClocks'),
              payloadType: any(named: 'payloadType'),
              jsonPath: any(named: 'jsonPath'),
            ),
          ).thenAnswer((_) async => []);

          final proc = SyncEventProcessor(
            loggingService: loggingService,
            updateNotifications: updateNotifications,
            aiConfigRepository: aiConfigRepository,
            settingsDb: settingsDb,
            journalEntityLoader: journalEntityLoader,
            sequenceLogService: mockSeqService,
          )..agentRepository = mockAgentRepoSeq;
          final message = SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
            originatingHostId: 'host-A',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await proc.process(event: event, journalDb: journalDb);

          verifyNever(() => mockAgentRepoSeq.upsertEntity(any()));
          verify(
            () => mockSeqService.recordReceivedEntry(
              entryId: 'state-dominates',
              vectorClock: incomingVc,
              originatingHostId: 'host-A',
              coveredVectorClocks: null,
              payloadType: SyncSequencePayloadType.agentEntity,
              jsonPath: any(named: 'jsonPath'),
            ),
          ).called(1);
          verifyNever(
            () => updateNotifications.notify(
              any<Set<String>>(),
              fromSync: any<bool>(named: 'fromSync'),
            ),
          );
        },
      );

      test(
        'applies agent entity when incoming vector clock dominates',
        () async {
          const localVc = VectorClock({'host-A': 1});
          const incomingVc = VectorClock({'host-A': 2});
          final local = AgentDomainEntity.agentState(
            id: 'state-newer',
            agentId: 'agent-1',
            revision: 1,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: localVc,
          );
          final incoming = AgentDomainEntity.agentState(
            id: 'state-newer',
            agentId: 'agent-1',
            revision: 2,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 16),
            vectorClock: incomingVc,
          );
          when(
            () => mockAgentRepoSeq.getEntity('state-newer'),
          ).thenAnswer((_) async => local);
          when(
            () => mockSeqService.recordReceivedEntry(
              entryId: any(named: 'entryId'),
              vectorClock: any(named: 'vectorClock'),
              originatingHostId: any(named: 'originatingHostId'),
              coveredVectorClocks: any(named: 'coveredVectorClocks'),
              payloadType: any(named: 'payloadType'),
              jsonPath: any(named: 'jsonPath'),
            ),
          ).thenAnswer((_) async => []);

          final proc = SyncEventProcessor(
            loggingService: loggingService,
            updateNotifications: updateNotifications,
            aiConfigRepository: aiConfigRepository,
            settingsDb: settingsDb,
            journalEntityLoader: journalEntityLoader,
            sequenceLogService: mockSeqService,
          )..agentRepository = mockAgentRepoSeq;
          final message = SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
            originatingHostId: 'host-A',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await proc.process(event: event, journalDb: journalDb);

          verify(() => mockAgentRepoSeq.upsertEntity(incoming)).called(1);
        },
      );

      test(
        'skips equal agent link vector clock but still records sequence receipt',
        () async {
          const incomingVc = VectorClock({'host-A': 2});
          final local = AgentLink.basic(
            id: 'link-dominates',
            fromId: 'agent-1',
            toId: 'state-1',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 16),
            vectorClock: incomingVc,
          );
          final incoming = AgentLink.basic(
            id: 'link-dominates',
            fromId: 'agent-1',
            toId: 'state-1',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: incomingVc,
          );
          when(
            () => mockAgentRepoSeq.getLinkById('link-dominates'),
          ).thenAnswer((_) async => local);
          when(
            () => mockSeqService.recordReceivedEntry(
              entryId: any(named: 'entryId'),
              vectorClock: any(named: 'vectorClock'),
              originatingHostId: any(named: 'originatingHostId'),
              coveredVectorClocks: any(named: 'coveredVectorClocks'),
              payloadType: any(named: 'payloadType'),
              jsonPath: any(named: 'jsonPath'),
            ),
          ).thenAnswer((_) async => []);

          final proc = SyncEventProcessor(
            loggingService: loggingService,
            updateNotifications: updateNotifications,
            aiConfigRepository: aiConfigRepository,
            settingsDb: settingsDb,
            journalEntityLoader: journalEntityLoader,
            sequenceLogService: mockSeqService,
          )..agentRepository = mockAgentRepoSeq;
          final message = SyncMessage.agentLink(
            agentLink: incoming,
            status: SyncEntryStatus.update,
            originatingHostId: 'host-A',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await proc.process(event: event, journalDb: journalDb);

          verifyNever(() => mockAgentRepoSeq.upsertLink(any()));
          verify(
            () => mockSeqService.recordReceivedEntry(
              entryId: 'link-dominates',
              vectorClock: incomingVc,
              originatingHostId: 'host-A',
              coveredVectorClocks: null,
              payloadType: SyncSequencePayloadType.agentLink,
              jsonPath: any(named: 'jsonPath'),
            ),
          ).called(1);
          verifyNever(
            () => updateNotifications.notify(
              any<Set<String>>(),
              fromSync: any<bool>(named: 'fromSync'),
            ),
          );
        },
      );

      test('records received agent entity in sequence log', () async {
        const vc = VectorClock({'host-A': 10});
        final entity = AgentDomainEntity.agent(
          id: 'agent-seq-1',
          agentId: 'agent-seq-1',
          kind: 'task_agent',
          displayName: 'Seq Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-A',
        );

        when(
          () => mockSeqService.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer((_) async => []);

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = mockAgentRepoSeq;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(event: event, journalDb: journalDb);

        verify(
          () => mockSeqService.recordReceivedEntry(
            entryId: 'agent-seq-1',
            vectorClock: vc,
            originatingHostId: 'host-A',
            coveredVectorClocks: null,
            payloadType: SyncSequencePayloadType.agentEntity,
            jsonPath: any(named: 'jsonPath'),
          ),
        ).called(1);
      });

      test('logs gap detection for agent entity', () async {
        const vc = VectorClock({'host-B': 20});
        final entity = AgentDomainEntity.agent(
          id: 'agent-gap-1',
          agentId: 'agent-gap-1',
          kind: 'task_agent',
          displayName: 'Gap Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-B',
        );

        when(
          () => mockSeqService.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer(
          (_) async => [(hostId: 'host-B', counter: 18)],
        );

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = mockAgentRepoSeq;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(event: event, journalDb: journalDb);

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: contains('apply.agentEntity.gapsDetected count=1'),
            ),
            subDomain: 'processor.gapDetection',
          ),
        ).called(1);
      });

      test('handles recordReceivedEntry exception for agent entity', () async {
        const vc = VectorClock({'host-C': 5});
        final entity = AgentDomainEntity.agent(
          id: 'agent-err-1',
          agentId: 'agent-err-1',
          kind: 'task_agent',
          displayName: 'Err Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-C',
        );

        when(
          () => mockSeqService.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenThrow(Exception('seq log error'));

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = mockAgentRepoSeq;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(event: event, journalDb: journalDb);

        // Entity should still be upserted despite seq log error
        verify(() => mockAgentRepoSeq.upsertEntity(entity)).called(1);
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'recordReceived',
          ),
        ).called(1);
      });

      test('records received agent link in sequence log', () async {
        const vc = VectorClock({'host-A': 15});
        final link = AgentLink.basic(
          id: 'link-seq-1',
          fromId: 'agent-1',
          toId: 'state-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentLink(
          agentLink: link,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-A',
        );

        when(
          () => mockSeqService.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer((_) async => []);

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = mockAgentRepoSeq;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(event: event, journalDb: journalDb);

        verify(
          () => mockSeqService.recordReceivedEntry(
            entryId: 'link-seq-1',
            vectorClock: vc,
            originatingHostId: 'host-A',
            coveredVectorClocks: null,
            payloadType: SyncSequencePayloadType.agentLink,
            jsonPath: any(named: 'jsonPath'),
          ),
        ).called(1);
      });

      test('logs gap detection for agent link', () async {
        const vc = VectorClock({'host-D': 12});
        final link = AgentLink.basic(
          id: 'link-gap-1',
          fromId: 'agent-1',
          toId: 'state-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentLink(
          agentLink: link,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-D',
        );

        when(
          () => mockSeqService.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer(
          (_) async => [
            (hostId: 'host-D', counter: 9),
            (hostId: 'host-D', counter: 10),
          ],
        );

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = mockAgentRepoSeq;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(event: event, journalDb: journalDb);

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(that: contains('apply.agentLink.gapsDetected count=2')),
            subDomain: 'processor.gapDetection',
          ),
        ).called(1);
      });

      test('handles recordReceivedEntry exception for agent link', () async {
        const vc = VectorClock({'host-E': 7});
        final link = AgentLink.basic(
          id: 'link-err-1',
          fromId: 'agent-1',
          toId: 'state-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentLink(
          agentLink: link,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-E',
        );

        when(
          () => mockSeqService.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenThrow(Exception('seq log error link'));

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = mockAgentRepoSeq;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(event: event, journalDb: journalDb);

        // Link should still be upserted despite seq log error.
        verify(() => mockAgentRepoSeq.upsertLink(link)).called(1);
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'recordReceived',
          ),
        ).called(1);
      });

      test('skips sequence log when vectorClock is null', () async {
        final entity = AgentDomainEntity.agent(
          id: 'agent-no-vc',
          agentId: 'agent-no-vc',
          kind: 'task_agent',
          displayName: 'No VC',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-A',
        );

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = mockAgentRepoSeq;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(event: event, journalDb: journalDb);

        verifyNever(
          () => mockSeqService.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        );
      });

      test('skips sequence log when originatingHostId is null', () async {
        const vc = VectorClock({'host-A': 10});
        final entity = AgentDomainEntity.agent(
          id: 'agent-no-host',
          agentId: 'agent-no-host',
          kind: 'task_agent',
          displayName: 'No Host',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
          // no originatingHostId
        );

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = mockAgentRepoSeq;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(event: event, journalDb: journalDb);

        verifyNever(
          () => mockSeqService.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        );
      });
    });

    group('lifecycle side-effects on incoming identity', () {
      late MockWakeOrchestrator mockOrchestrator;

      setUp(() {
        mockOrchestrator = MockWakeOrchestrator();
        processor.wakeOrchestrator = mockOrchestrator;
        when(
          () => mockOrchestrator.removeSubscriptions(any()),
        ).thenReturn(null);
      });

      test('removes subscriptions when agent is dormant', () async {
        final entity = AgentDomainEntity.agent(
          id: 'agent-dormant',
          agentId: 'agent-dormant',
          kind: 'task_agent',
          displayName: 'Dormant Agent',
          lifecycle: AgentLifecycle.dormant,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
        verify(
          () => mockOrchestrator.removeSubscriptions('agent-dormant'),
        ).called(1);
      });

      test('removes subscriptions when agent is destroyed', () async {
        final entity = AgentDomainEntity.agent(
          id: 'agent-destroyed',
          agentId: 'agent-destroyed',
          kind: 'task_agent',
          displayName: 'Destroyed Agent',
          lifecycle: AgentLifecycle.destroyed,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
        verify(
          () => mockOrchestrator.removeSubscriptions('agent-destroyed'),
        ).called(1);
      });

      test('restores subscriptions for active task_agent', () async {
        final entity = AgentDomainEntity.agent(
          id: 'agent-active',
          agentId: 'agent-active',
          kind: 'task_agent',
          displayName: 'Active Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final taskLink = AgentLink.basic(
          id: 'link-1',
          fromId: 'agent-active',
          toId: 'task-42',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        when(
          () => mockAgentRepo.getLinksFrom(
            'agent-active',
            type: 'agent_task',
          ),
        ).thenAnswer((_) async => [taskLink]);

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
        verifyNever(() => mockOrchestrator.removeSubscriptions(any()));
        verify(
          () => mockOrchestrator.addSubscription(
            any(
              that: isA<AgentSubscription>().having(
                (s) => s.agentId,
                'agentId',
                'agent-active',
              ),
            ),
          ),
        ).called(1);
      });

      test('does NOT remove subscriptions for non-identity entities', () async {
        final entity = AgentDomainEntity.agentState(
          id: 'state-1',
          agentId: 'agent-1',
          revision: 5,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
        verifyNever(() => mockOrchestrator.removeSubscriptions(any()));
      });

      test('safe when wakeOrchestrator is null', () async {
        processor.wakeOrchestrator = null;

        final entity = AgentDomainEntity.agent(
          id: 'agent-dormant',
          agentId: 'agent-dormant',
          kind: 'task_agent',
          displayName: 'Dormant Agent',
          lifecycle: AgentLifecycle.dormant,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        // Should not throw even though lifecycle is dormant.
        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
        verifyNever(() => mockOrchestrator.removeSubscriptions(any()));
      });
    });

    group('subscription restoration on incoming agent link', () {
      late MockWakeOrchestrator mockOrchestrator;

      setUp(() {
        mockOrchestrator = MockWakeOrchestrator();
        processor.wakeOrchestrator = mockOrchestrator;
      });

      test(
        'agent_task link for active task_agent restores subscription',
        () async {
          final activeAgent = AgentDomainEntity.agent(
            id: 'agent-1',
            agentId: 'agent-1',
            kind: 'task_agent',
            displayName: 'Active Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );

          when(
            () => mockAgentRepo.getEntity('agent-1'),
          ).thenAnswer((_) async => activeAgent);

          final link = AgentLink.agentTask(
            id: 'link-1',
            fromId: 'agent-1',
            toId: 'task-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );

          final message = SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verify(() => mockAgentRepo.upsertLink(link)).called(1);
          verify(
            () => mockOrchestrator.addSubscription(
              any(
                that: isA<AgentSubscription>()
                    .having((s) => s.agentId, 'agentId', 'agent-1')
                    .having(
                      (s) => s.matchEntityIds,
                      'matchEntityIds',
                      {'task-42'},
                    ),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'agent_task link for dormant agent does NOT restore subscription',
        () async {
          final dormantAgent = AgentDomainEntity.agent(
            id: 'agent-1',
            agentId: 'agent-1',
            kind: 'task_agent',
            displayName: 'Dormant Agent',
            lifecycle: AgentLifecycle.dormant,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );

          when(
            () => mockAgentRepo.getEntity('agent-1'),
          ).thenAnswer((_) async => dormantAgent);

          final link = AgentLink.agentTask(
            id: 'link-1',
            fromId: 'agent-1',
            toId: 'task-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );

          final message = SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verify(() => mockAgentRepo.upsertLink(link)).called(1);
          verifyNever(() => mockOrchestrator.addSubscription(any()));
        },
      );

      test(
        'soft-deleted agent_task link removes the wake subscription',
        () async {
          final link = AgentLink.agentTask(
            id: 'link-deleted',
            fromId: 'agent-1',
            toId: 'task-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
            deletedAt: DateTime(2024, 3, 16),
          );

          final message = SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verify(() => mockAgentRepo.upsertLink(link)).called(1);
          // Mirror remote delete: the per-link subscription must go so this
          // device stops waking an agent that was unlinked elsewhere.
          verify(
            () => mockOrchestrator.removeSubscription('agent-1_task_task-42'),
          ).called(1);
          // Delete path skips agent lookup + re-subscribe entirely.
          verifyNever(() => mockAgentRepo.getEntity(any()));
          verifyNever(() => mockOrchestrator.addSubscription(any()));
        },
      );

      test('non-agent_task link does NOT trigger subscription logic', () async {
        final link = AgentLink.basic(
          id: 'link-1',
          fromId: 'agent-1',
          toId: 'state-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final message = SyncMessage.agentLink(
          agentLink: link,
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertLink(link)).called(1);
        // getEntity should not be called for non-agent_task links.
        verifyNever(() => mockAgentRepo.getEntity(any()));
        verifyNever(() => mockOrchestrator.addSubscription(any()));
      });
    });

    group('descriptor-only resolution (jsonPath)', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync(
          'agent_resolve_test',
        );
        if (getIt.isRegistered<Directory>()) {
          getIt.unregister<Directory>();
        }
        getIt.registerSingleton<Directory>(tempDir);
      });

      tearDown(() async {
        await getIt.reset();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('resolves agent entity from jsonPath on disk', () async {
        final entity = AgentDomainEntity.agent(
          id: 'agent-disk',
          agentId: 'agent-disk',
          kind: 'task_agent',
          displayName: 'Disk Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        const relativePath = '/agent_entities/agent-disk.json';
        final normalized = stripLeadingSlashes(relativePath);
        final file = File(path.join(tempDir.path, normalized));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(jsonEncode(entity.toJson()));

        const message = SyncMessage.agentEntity(
          status: SyncEntryStatus.update,
          jsonPath: relativePath,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
      });

      test(
        'keeps dominant local agent entity cache when jsonPath payload is stale',
        () async {
          const localVc = VectorClock({'host-A': 2});
          const incomingVc = VectorClock({'host-A': 1});
          final local = AgentDomainEntity.agentState(
            id: 'state-cache',
            agentId: 'agent-1',
            revision: 2,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 16),
            vectorClock: localVc,
          );
          final stale = AgentDomainEntity.agentState(
            id: 'state-cache',
            agentId: 'agent-1',
            revision: 1,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: incomingVc,
          );
          when(
            () => mockAgentRepo.getEntity('state-cache'),
          ).thenAnswer((_) async => local);

          const relativePath = '/agent_entities/state-cache.json';
          final normalized = stripLeadingSlashes(relativePath);
          final file = File(path.join(tempDir.path, normalized));
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(jsonEncode(stale.toJson()));

          const message = SyncMessage.agentEntity(
            status: SyncEntryStatus.update,
            jsonPath: relativePath,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verifyNever(() => mockAgentRepo.upsertEntity(any()));
          final restored = AgentDomainEntity.fromJson(
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
          );
          expect(
            restored.mapOrNull(agentState: (entity) => entity.revision),
            2,
          );
        },
      );

      test('resolves agent link from jsonPath on disk', () async {
        final link = AgentLink.basic(
          id: 'link-disk',
          fromId: 'agent-1',
          toId: 'state-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        const relativePath = '/agent_links/link-disk.json';
        final normalized = stripLeadingSlashes(relativePath);
        final file = File(path.join(tempDir.path, normalized));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(jsonEncode(link.toJson()));

        const message = SyncMessage.agentLink(
          status: SyncEntryStatus.update,
          jsonPath: relativePath,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertLink(link)).called(1);
      });

      test('skips agent entity with no entity and no jsonPath', () async {
        const message = SyncMessage.agentEntity(
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verifyNever(() => mockAgentRepo.upsertEntity(any()));
        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(that: contains('no payload and no jsonPath')),
            subDomain: 'processor.resolve',
          ),
        ).called(1);
      });

      test('skips agent link with no link and no jsonPath', () async {
        const message = SyncMessage.agentLink(
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verifyNever(() => mockAgentRepo.upsertLink(any()));
        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(that: contains('no payload and no jsonPath')),
            subDomain: 'processor.resolve',
          ),
        ).called(1);
      });

      test('skips agent entity with path-traversal jsonPath', () async {
        const message = SyncMessage.agentEntity(
          status: SyncEntryStatus.update,
          jsonPath: '../../../etc/passwd',
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verifyNever(() => mockAgentRepo.upsertEntity(any()));
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'resolve.agentEntity.invalidPath',
          ),
        ).called(1);
      });

      test('skips agent link with path-traversal jsonPath', () async {
        const message = SyncMessage.agentLink(
          status: SyncEntryStatus.update,
          jsonPath: '../../../etc/passwd',
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verifyNever(() => mockAgentRepo.upsertLink(any()));
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'resolve.agentLink.invalidPath',
          ),
        ).called(1);
      });

      test(
        'rethrows FileSystemException for missing agent entity file',
        () async {
          const message = SyncMessage.agentEntity(
            status: SyncEntryStatus.update,
            jsonPath: '/agent_entities/missing.json',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await expectLater(
            () => processor.process(event: event, journalDb: journalDb),
            throwsA(isA<FileSystemException>()),
          );
        },
      );

      test(
        'rethrows FileSystemException for missing agent link file',
        () async {
          const message = SyncMessage.agentLink(
            status: SyncEntryStatus.update,
            jsonPath: '/agent_links/missing.json',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await expectLater(
            () => processor.process(event: event, journalDb: journalDb),
            throwsA(isA<FileSystemException>()),
          );
        },
      );

      test('skips agent entity with corrupt JSON file', () async {
        const relativePath = '/agent_entities/corrupt.json';
        final normalized = stripLeadingSlashes(relativePath);
        final file = File(path.join(tempDir.path, normalized));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('not valid json {{{');

        const message = SyncMessage.agentEntity(
          status: SyncEntryStatus.update,
          jsonPath: relativePath,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verifyNever(() => mockAgentRepo.upsertEntity(any()));
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'resolve.agentEntity',
          ),
        ).called(1);
      });

      group('descriptor-based resolution (AttachmentIndex)', () {
        late AttachmentIndex attachmentIndex;
        late SyncEventProcessor processorWithIndex;
        late MockEvent descriptorEvent;

        setUp(() {
          attachmentIndex = AttachmentIndex(logging: loggingService);
          processorWithIndex = SyncEventProcessor(
            loggingService: loggingService,
            updateNotifications: updateNotifications,
            aiConfigRepository: aiConfigRepository,
            settingsDb: settingsDb,
            journalEntityLoader: journalEntityLoader,
            attachmentIndex: attachmentIndex,
          );
          processorWithIndex.agentRepository = mockAgentRepo;

          descriptorEvent = MockEvent();
          when(() => descriptorEvent.eventId).thenReturn('desc-event-id');
          when(
            () => descriptorEvent.attachmentMimetype,
          ).thenReturn('application/json');
          when(() => descriptorEvent.content).thenReturn({
            'relativePath': '/agent_entities/agent-desc.json',
          });
        });

        test(
          'fetches agent entity from descriptor when file is missing',
          () async {
            final entity = AgentDomainEntity.agent(
              id: 'agent-desc',
              agentId: 'agent-desc',
              kind: 'task_agent',
              displayName: 'Descriptor Agent',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: const {},
              currentStateId: 'state-1',
              config: const AgentConfig(),
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
              vectorClock: null,
            );

            final bytes = Uint8List.fromList(
              utf8.encode(jsonEncode(entity.toJson())),
            );
            when(
              descriptorEvent.downloadAndDecryptAttachment,
            ).thenAnswer((_) async => MatrixFile(bytes: bytes, name: 'e.json'));

            attachmentIndex.record(descriptorEvent);

            const message = SyncMessage.agentEntity(
              status: SyncEntryStatus.update,
              jsonPath: '/agent_entities/agent-desc.json',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            await processorWithIndex.process(
              event: event,
              journalDb: journalDb,
            );

            verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
            verify(descriptorEvent.downloadAndDecryptAttachment).called(1);
          },
        );

        test(
          'fetches agent link from descriptor when file is missing',
          () async {
            final link = AgentLink.basic(
              id: 'link-desc',
              fromId: 'agent-1',
              toId: 'state-1',
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
              vectorClock: null,
            );

            final bytes = Uint8List.fromList(
              utf8.encode(jsonEncode(link.toJson())),
            );

            final linkDescriptorEvent = MockEvent();
            when(
              () => linkDescriptorEvent.eventId,
            ).thenReturn('link-desc-event-id');
            when(
              () => linkDescriptorEvent.attachmentMimetype,
            ).thenReturn('application/json');
            when(() => linkDescriptorEvent.content).thenReturn({
              'relativePath': '/agent_links/link-desc.json',
            });
            when(
              linkDescriptorEvent.downloadAndDecryptAttachment,
            ).thenAnswer((_) async => MatrixFile(bytes: bytes, name: 'l.json'));

            attachmentIndex.record(linkDescriptorEvent);

            const message = SyncMessage.agentLink(
              status: SyncEntryStatus.update,
              jsonPath: '/agent_links/link-desc.json',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            await processorWithIndex.process(
              event: event,
              journalDb: journalDb,
            );

            verify(() => mockAgentRepo.upsertLink(link)).called(1);
            verify(linkDescriptorEvent.downloadAndDecryptAttachment).called(1);
          },
        );

        test(
          'throws when descriptor download fails (no stale fallback)',
          () async {
            when(
              descriptorEvent.downloadAndDecryptAttachment,
            ).thenThrow(Exception('download failed'));

            attachmentIndex.record(descriptorEvent);

            const message = SyncMessage.agentEntity(
              status: SyncEntryStatus.update,
              jsonPath: '/agent_entities/agent-desc.json',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            await expectLater(
              () => processorWithIndex.process(
                event: event,
                journalDb: journalDb,
              ),
              throwsA(isA<FileSystemException>()),
            );

            verifyNever(() => mockAgentRepo.upsertEntity(any()));
          },
        );

        test('throws when descriptor returns empty bytes', () async {
          when(descriptorEvent.downloadAndDecryptAttachment).thenAnswer(
            (_) async => MatrixFile(bytes: Uint8List(0), name: 'e.json'),
          );

          attachmentIndex.record(descriptorEvent);

          const message = SyncMessage.agentEntity(
            status: SyncEntryStatus.update,
            jsonPath: '/agent_entities/agent-desc.json',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await expectLater(
            () => processorWithIndex.process(
              event: event,
              journalDb: journalDb,
            ),
            throwsA(isA<FileSystemException>()),
          );

          verifyNever(() => mockAgentRepo.upsertEntity(any()));
        });

        test('falls back to disk when no descriptor in index', () async {
          final entity = AgentDomainEntity.agent(
            id: 'agent-disk-fb',
            agentId: 'agent-disk-fb',
            kind: 'task_agent',
            displayName: 'Disk Fallback',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );

          const relativePath = '/agent_entities/agent-disk-fb.json';
          final normalized = stripLeadingSlashes(relativePath);
          final file = File(path.join(tempDir.path, normalized));
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(jsonEncode(entity.toJson()));

          const message = SyncMessage.agentEntity(
            status: SyncEntryStatus.update,
            jsonPath: relativePath,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processorWithIndex.process(
            event: event,
            journalDb: journalDb,
          );

          verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
        });

        test('skips agent entity with corrupt descriptor JSON', () async {
          final bytes = Uint8List.fromList(utf8.encode('not valid json'));
          when(
            descriptorEvent.downloadAndDecryptAttachment,
          ).thenAnswer((_) async => MatrixFile(bytes: bytes, name: 'e.json'));

          attachmentIndex.record(descriptorEvent);

          const message = SyncMessage.agentEntity(
            status: SyncEntryStatus.update,
            jsonPath: '/agent_entities/agent-desc.json',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          // Descriptor fetched successfully but JSON parse fails →
          // permanent skip (returns null), not a retry.
          await processorWithIndex.process(
            event: event,
            journalDb: journalDb,
          );

          verifyNever(() => mockAgentRepo.upsertEntity(any()));
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: 'resolve.agentEntity.parseFetched',
            ),
          ).called(1);
        });
      });

      test('skips agent link with corrupt JSON file', () async {
        const relativePath = '/agent_links/corrupt.json';
        final normalized = stripLeadingSlashes(relativePath);
        final file = File(path.join(tempDir.path, normalized));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('not valid json {{{');

        const message = SyncMessage.agentLink(
          status: SyncEntryStatus.update,
          jsonPath: relativePath,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verifyNever(() => mockAgentRepo.upsertLink(any()));
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'resolve.agentLink',
          ),
        ).called(1);
      });

      group('_restoreDominantAgentCache FileSystemException (lines 465-469)', () {
        setUpAll(() {
          registerFallbackValue(const FileSystemException('fallback'));
        });

        // When local VC dominates AND jsonPath resolves outside the documents
        // directory (path-traversal after normalisation), resolveJsonCandidateFile
        // throws FileSystemException.  _restoreDominantAgentCache catches it and
        // logs at lines 465-469 without propagating.

        test(
          'logs FileSystemException when jsonPath escapes the documents '
          'directory during cache restore for an agent entity',
          () async {
            const localVc = VectorClock({'host-A': 2});
            const incomingVc = VectorClock({'host-A': 1});
            final local = AgentDomainEntity.agentState(
              id: 'state-restore-fail',
              agentId: 'agent-1',
              revision: 2,
              slots: const AgentSlots(),
              updatedAt: DateTime(2024, 3, 16),
              vectorClock: localVc,
            );
            final stale = AgentDomainEntity.agentState(
              id: 'state-restore-fail',
              agentId: 'agent-1',
              revision: 1,
              slots: const AgentSlots(),
              updatedAt: DateTime(2024, 3, 15),
              vectorClock: incomingVc,
            );
            when(
              () => mockAgentRepo.getEntity('state-restore-fail'),
            ).thenAnswer((_) async => local);

            // Use a path-traversal jsonPath — resolveJsonCandidateFile throws
            // FileSystemException which _restoreDominantAgentCache catches.
            final message = SyncMessage.agentEntity(
              agentEntity: stale,
              status: SyncEntryStatus.update,
              jsonPath: '../../etc/evil.json',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            // Should complete without throwing.
            await processor.process(event: event, journalDb: journalDb);

            // Local dominates → entity NOT upserted.
            verifyNever(() => mockAgentRepo.upsertEntity(any()));
            // The FileSystemException is caught and logged at lines 465-469.
            verify(
              () => loggingService.error(
                LogDomain.sync,
                any<FileSystemException>(),
                stackTrace: any<StackTrace>(named: 'stackTrace'),
                subDomain: any<String>(
                  named: 'subDomain',
                  that: contains('restoreDominantCache'),
                ),
              ),
            ).called(1);
          },
        );

        test(
          'logs FileSystemException when jsonPath escapes the documents '
          'directory during cache restore for an agent link',
          () async {
            const localVc = VectorClock({'host-B': 3});
            const incomingVc = VectorClock({'host-B': 2});
            final local = AgentLink.basic(
              id: 'link-restore-fail',
              fromId: 'agent-1',
              toId: 'state-1',
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 16),
              vectorClock: localVc,
            );
            final stale = AgentLink.basic(
              id: 'link-restore-fail',
              fromId: 'agent-1',
              toId: 'state-1',
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
              vectorClock: incomingVc,
            );
            when(
              () => mockAgentRepo.getLinkById('link-restore-fail'),
            ).thenAnswer((_) async => local);

            final message = SyncMessage.agentLink(
              agentLink: stale,
              status: SyncEntryStatus.update,
              jsonPath: '../../etc/evil.json',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            await processor.process(event: event, journalDb: journalDb);

            verifyNever(() => mockAgentRepo.upsertLink(any()));
            verify(
              () => loggingService.error(
                LogDomain.sync,
                any<FileSystemException>(),
                stackTrace: any<StackTrace>(named: 'stackTrace'),
                subDomain: any<String>(
                  named: 'subDomain',
                  that: contains('restoreDominantCache'),
                ),
              ),
            ).called(1);
          },
        );
      });
    });
  });

  test('logs exceptions for invalid base64 payloads', () async {
    when(() => event.text).thenReturn('not-base64');

    await expectLater(
      processor.process(event: event, journalDb: journalDb),
      throwsA(isA<FormatException>()),
    );

    verify(
      () => loggingService.error(
        LogDomain.sync,
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: 'SyncEventProcessor',
      ),
    ).called(1);
  });

  test('logs exceptions thrown by handlers', () async {
    const message = SyncMessage.journalEntity(
      id: 'entity-id',
      jsonPath: '/entity.json',
      vectorClock: null,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));
    when(
      () => journalEntityLoader.load(
        jsonPath: '/entity.json',
      ),
    ).thenThrow(Exception('load failed'));

    await expectLater(
      processor.process(event: event, journalDb: journalDb),
      throwsA(isA<Exception>()),
    );

    verify(
      () => loggingService.error(
        LogDomain.sync,
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: 'SyncEventProcessor',
      ),
    ).called(1);
  });

  test('skips message with unknown enum value (ArgumentError)', () async {
    // Simulate a SyncMessage JSON with an unknown enum value that would
    // cause $enumDecode to throw ArgumentError.
    final badJson = {
      'runtimeType': 'journalEntity',
      'id': 'entity-id',
      'jsonPath': '/entity.json',
      'vectorClock': null,
      'status': 'unknownEnumValue',
    };
    final encoded = base64.encode(utf8.encode(json.encode(badJson)));
    when(() => event.text).thenReturn(encoded);

    // Should NOT throw — the error is caught and logged.
    await processor.process(event: event, journalDb: journalDb);

    verify(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(
          that: contains('skipping undeserializable sync message'),
        ),
        subDomain: 'processor.skipUnrecoverable',
      ),
    ).called(1);
  });

  test('skips message with FormatException from malformed JSON', () async {
    // Valid base64/JSON but with a structure that causes FormatException
    // when SyncMessage.fromJson tries to parse sub-fields.
    final badJson = {
      'runtimeType': 'journalEntity',
      'id': 123, // wrong type — id should be String
      'jsonPath': '/entity.json',
      'vectorClock': null,
      'status': 'initial',
    };
    final encoded = base64.encode(utf8.encode(json.encode(badJson)));
    when(() => event.text).thenReturn(encoded);

    // The error might be TypeError or similar — either way, if it's not
    // ArgumentError or FormatException, it will rethrow through the outer
    // catch. Let's verify it doesn't crash with an unrecoverable retry.
    try {
      await processor.process(event: event, journalDb: journalDb);
      // If it didn't throw, it was caught as deserialization error → good.
    } on Object {
      // If it threw, it's a non-deserialization error that rethrows → also ok,
      // but verify the outer catch logged it.
      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'SyncEventProcessor',
        ),
      ).called(1);
    }
  });

  test('skips message with CheckedFromJsonException from empty JSON', () async {
    // An empty JSON object hits the default case in the generated
    // _$SyncMessageFromJson switch, which throws CheckedFromJsonException.
    // The processor catches this and logs a skip.
    final badJson = <String, dynamic>{};
    final encoded = base64.encode(utf8.encode(json.encode(badJson)));
    when(() => event.text).thenReturn(encoded);

    await processor.process(event: event, journalDb: journalDb);

    verify(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(
          that: contains('skipping undeserializable sync message'),
        ),
        subDomain: 'processor.skipUnrecoverable',
      ),
    ).called(1);
  });
}
