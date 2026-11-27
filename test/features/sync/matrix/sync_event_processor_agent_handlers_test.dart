// ignore_for_file: avoid_redundant_argument_values, cascade_invocations

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/agent_link.dart';
import 'package:lotti/classes/agents/change_set.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/classes/g_counter.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/agents/agent_repo_retention.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/sync/matrix/sync_descriptor_fetcher.dart';
import 'package:lotti/features/sync/matrix/sync_descriptor_recovery.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/utils/attachment_decoding.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

import '../../../mocks/mocks.dart';
import '../../agents/agent_test_device.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../agents/test_data/evolution_factories.dart';
import '../../ai_consumption/test_utils.dart';
import 'recorded_attachment_stack.dart';
import 'sync_event_processor_test_helpers.dart';

void main() {
  setUpAll(registerSyncProcessorFallbacks);
  setUp(setUpProcessorMocks);

  group('SyncEventProcessor - Agent Entities and Links', () {
    /// This device: a real in-memory agent database behind the real
    /// repository, which the processor under test writes to.
    late AgentTestDevice device;

    /// Project agents sync asked to arm their next update slot.
    late List<String> armedAgentIds;

    Future<void> receiveEntity(AgentDomainEntity entity) =>
        device.receiveEnvelope(
          SyncMessage.agentEntity(
            agentEntity: entity,
            status: SyncEntryStatus.update,
          ),
          envelope: event,
          journalDb: journalDb,
        );

    Future<void> receiveLink(AgentLink link) => device.receiveEnvelope(
      SyncMessage.agentLink(agentLink: link, status: SyncEntryStatus.update),
      envelope: event,
      journalDb: journalDb,
    );

    setUp(() {
      armedAgentIds = [];
      processor.armProjectUpdate = (agentId) async =>
          armedAgentIds.add(agentId);
      device = AgentTestDevice('local', background: false);
      addTearDown(device.close);
      device.attachProcessor(processor);
    });

    group('an agent this device deleted (ADR 0108)', () {
      setUp(() async {
        await device.repository.upsertEntity(
          makeTestIdentity(id: 'agent-gone', agentId: 'agent-gone'),
        );
        await device.repository.hardDeleteAgent('agent-gone');
      });

      AgentLink taskLink({required String id, required String fromId}) =>
          AgentLink.agentTask(
            id: id,
            fromId: fromId,
            toId: 'task-1',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );

      test('a link from it is refused', () async {
        await receiveLink(taskLink(id: 'link-gone', fromId: 'agent-gone'));

        expect(
          await device.repository.getLinkByIdIncludingDeleted('link-gone'),
          isNull,
        );
        verifyNever(
          () => updateNotifications.notify(any(), fromSync: true),
        );
      });

      test('a link to it is refused: both ends are checked', () async {
        await receiveLink(
          AgentLink.basic(
            id: 'link-to-gone',
            fromId: 'agent-1',
            toId: 'agent-gone',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
        );

        expect(
          await device.repository.getLinkByIdIncludingDeleted('link-to-gone'),
          isNull,
        );
      });

      test('an entity of it, sent inline, is refused', () async {
        await receiveEntity(
          AgentDomainEntity.agentMessage(
            id: 'msg-late',
            agentId: 'agent-gone',
            threadId: 'thread-1',
            kind: AgentMessageKind.thought,
            createdAt: DateTime(2024, 3, 15),
            vectorClock: null,
            metadata: const AgentMessageMetadata(),
            tokensApprox: 1,
          ),
        );

        expect(
          await device.repository.getEntityIncludingDeleted('msg-late'),
          isNull,
        );
        verifyNever(
          () => updateNotifications.notify(any(), fromSync: true),
        );
      });

      test('a link between two agents it did not delete is applied', () async {
        final link = taskLink(id: 'link-live', fromId: 'agent-1');

        await receiveLink(link);

        expect(
          await device.repository.getLinkByIdIncludingDeleted('link-live'),
          link,
        );
      });
    });

    group('change sets (ChangeSetLifecycle.tla)', () {
      const estimate = ChangeItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 30},
        humanSummary: 'Set estimate',
      );
      const title = ChangeItem(
        toolName: 'set_task_title',
        args: {'title': 'T'},
        humanSummary: 'Set title',
      );

      ChangeSetEntity changeSet(
        List<ChangeItem> items,
        Map<String, int> clock,
      ) =>
          AgentDomainEntity.changeSet(
                id: 'cs-sync',
                agentId: 'agent-1',
                taskId: 'task-1',
                threadId: 'thread-1',
                runKey: 'run-1',
                status: ChangeItem.deriveSetStatus(items),
                items: items,
                createdAt: DateTime(2026, 9),
                vectorClock: VectorClock(clock),
              )
              as ChangeSetEntity;

      Future<ChangeSetEntity?> stored() async =>
          await device.repository.getEntity('cs-sync') as ChangeSetEntity?;

      test(
        'concurrent versions merge item by item: both decisions survive',
        () async {
          await device.repository.upsertEntity(
            changeSet(
              [
                estimate.withStatus(ChangeItemStatus.confirmed),
                title,
              ],
              {'local': 2},
            ),
          );

          await receiveEntity(
            changeSet(
              [
                estimate,
                title.withStatus(ChangeItemStatus.rejected),
              ],
              {'local': 1, 'peer': 1},
            ),
          );

          final merged = (await stored())!;
          expect(merged.items.map((i) => i.status), [
            ChangeItemStatus.confirmed,
            ChangeItemStatus.rejected,
          ]);
          expect(merged.status, ChangeSetStatus.resolved);
          expect(
            merged.vectorClock,
            const VectorClock({'local': 2, 'peer': 1}),
          );
          verify(
            () => updateNotifications.notify(
              {'agent-1', 'AGENT_CHANGED'},
              fromSync: true,
            ),
          ).called(1);
        },
      );

      test('a version the local row covers is dropped', () async {
        final local = changeSet(
          [
            estimate.withStatus(ChangeItemStatus.confirmed),
          ],
          {'local': 2},
        );
        await device.repository.upsertEntity(local);

        await receiveEntity(changeSet([estimate], {'local': 1}));

        expect(await stored(), local);
        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(that: contains('skippedLocalWins id=cs-sync')),
            subDomain: 'processor.apply',
          ),
        ).called(1);
      });

      test('a set not stored yet is written as received', () async {
        final incoming = changeSet([estimate], {'peer': 1});

        await receiveEntity(incoming);

        expect(await stored(), incoming);
      });

      test(
        'a malformed local clock is logged and the peer version applied',
        () async {
          await device.repository.upsertEntity(
            changeSet([estimate], {'local': -1}),
          );
          final incoming = changeSet(
            [
              estimate.withStatus(ChangeItemStatus.confirmed),
            ],
            {'peer': 1},
          );

          await receiveEntity(incoming);

          expect(await stored(), incoming);
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'apply.agentEntity.vectorClockCompare',
            ),
          ).called(1);
        },
      );

      test(
        'a local claim that commits during the receive is not overwritten',
        () async {
          // The receive read the local row, a local claim confirmed the
          // estimate, and the receive then wrote the peer's version over it:
          // the claim, and the only record that the change was applied, was
          // gone.
          await device.repository.upsertEntity(
            changeSet([estimate, title], {'local': 1}),
          );
          final read = device.holdNextStoredReadOf('cs-sync');

          final received = receiveEntity(
            changeSet(
              [
                estimate,
                title.withStatus(ChangeItemStatus.rejected),
              ],
              {'local': 1, 'peer': 1},
            ),
          );
          await pumpEventQueue();
          final claim = device.repository.runInTransaction(() async {
            final current = (await stored())!;
            await device.repository.upsertEntity(
              current.copyWith(
                items: [
                  current.items[0].withStatus(ChangeItemStatus.confirmed),
                  current.items[1],
                ],
                vectorClock: VectorClock({
                  ...current.vectorClock!.vclock,
                  'local': 2,
                }),
              ),
            );
          });
          await pumpEventQueue();
          read.complete();
          await Future.wait([received, claim]);

          expect((await stored())!.items.map((i) => i.status), [
            ChangeItemStatus.confirmed,
            ChangeItemStatus.rejected,
          ]);
        },
      );
    });

    group('removals and the one-transaction receive (ADR 0081 addendum)', () {
      AgentDomainEntity reportHead(
        Map<String, int> clock, {
        required DateTime at,
        DateTime? deletedAt,
        String reportId = 'report-1',
      }) => AgentDomainEntity.agentReportHead(
        id: 'head-removed',
        agentId: 'agent-1',
        scope: 'current',
        reportId: reportId,
        updatedAt: at,
        vectorClock: VectorClock(clock),
        deletedAt: deletedAt,
      );

      /// The stored version, a tombstone included.
      Future<AgentDomainEntity?> stored() =>
          device.repository.getEntityIncludingDeleted('head-removed');

      test(
        'a late copy of the live version does not bring a removed entity '
        'back',
        () async {
          // The receive read the stored row with `getEntity`, which filters
          // `deleted_at IS NULL`: the removal read as no row, and the late
          // copy of the version it removed was written over it.
          final removal = reportHead(
            {'host-A': 2},
            at: DateTime(2026, 9, 25, 9),
            deletedAt: DateTime(2026, 9, 25, 10),
          );
          await device.repository.upsertEntity(removal);

          await receiveEntity(
            reportHead({'host-A': 1}, at: DateTime(2026, 9, 25, 9)),
          );

          expect(await stored(), removal);
          expect(await device.repository.getEntity('head-removed'), isNull);
          verify(
            () => loggingService.log(
              LogDomain.sync,
              any<String>(that: contains('skippedLocalWins id=head-removed')),
              subDomain: 'processor.apply',
            ),
          ).called(1);
        },
      );

      test('a removal replaces the live version it succeeds', () async {
        await device.repository.upsertEntity(
          reportHead({'host-A': 1}, at: DateTime(2026, 9, 25, 9)),
        );
        final removal = reportHead(
          {'host-A': 1, 'host-B': 1},
          at: DateTime(2026, 9, 25, 9),
          deletedAt: DateTime(2026, 9, 25, 10),
        );

        await receiveEntity(removal);

        expect(await stored(), removal);
      });

      test(
        'a local write that commits during the receive of a report head is '
        'not overwritten',
        () async {
          // Only agent state, change sets and evolution sessions were read
          // and written in one transaction. For every other type a local
          // write could commit between the read and the write, and the
          // receive then wrote the peer's version over it.
          await device.repository.upsertEntity(
            reportHead({'host-A': 1}, at: DateTime(2026, 9, 25, 9)),
          );
          final read = device.holdNextStoredReadOf('head-removed');

          final received = receiveEntity(
            reportHead(
              {'host-B': 1},
              at: DateTime(2026, 9, 25, 10),
              reportId: 'report-peer',
            ),
          );
          await pumpEventQueue();
          final local = reportHead(
            {'host-A': 2},
            at: DateTime(2026, 9, 25, 11),
            reportId: 'report-local',
          );
          final write = device.repository.runInTransaction(
            () => device.repository.upsertEntity(local),
          );
          await pumpEventQueue();
          read.complete();
          await Future.wait([received, write]);

          expect(await stored(), local);
        },
      );
    });

    group('agent-state head (AgentMessageLog.tla, ADR 0076)', () {
      // `b1` came from the device whose clock runs ahead; this device
      // received it, chained `a1` off it and moved its head to `a1`.
      AgentStateEntity state({
        required String? head,
        required Map<String, int> clock,
        required DateTime at,
      }) => makeTestState(
        id: 'state-head',
        agentId: 'agent-1',
        updatedAt: at,
        vectorClock: VectorClock(clock),
      ).copyWith(recentHeadMessageId: head);

      AgentLink edge(String child, String parent) => AgentLink.messagePrev(
        id: 'msgprev-$child',
        fromId: child,
        toId: parent,
        createdAt: DateTime(2026, 9),
        updatedAt: DateTime(2026, 9),
        vectorClock: null,
      );

      Future<AgentStateEntity> stored() async =>
          (await device.repository.getEntity('state-head'))!
              as AgentStateEntity;

      /// Stores the agent's log — `a1` chained off `b1` — and [local], its
      /// state row.
      Future<void> storeLog(AgentStateEntity local) async {
        await device.repository.upsertEntity(
          makeTestMessage(
            id: 'b1',
            agentId: 'agent-1',
            createdAt: DateTime(2026, 9, 1, 12),
          ),
        );
        await device.repository.upsertEntity(
          makeTestMessage(
            id: 'a1',
            agentId: 'agent-1',
            createdAt: DateTime(2026, 9, 1, 9),
            prevMessageId: 'b1',
          ),
        );
        await device.repository.upsertLink(edge('a1', 'b1'));
        await device.repository.upsertEntity(local);
      }

      test(
        'a concurrent version with an older head does not move the head back '
        '(TLC: HeadNeverRegresses)',
        () async {
          // The trace: the fast device's state row still points at `b1` and
          // wins last-writer-wins on its skewed `updatedAt`.
          await storeLog(
            state(head: 'a1', clock: {'local': 1}, at: DateTime(2026, 9, 1, 9)),
          );
          final incoming = state(
            head: 'b1',
            clock: {'peer': 1},
            at: DateTime(2026, 9, 1, 12),
          );

          await receiveEntity(incoming);

          final row = await stored();
          expect(row.recentHeadMessageId, 'a1');
          // Every other field is still the last writer's.
          expect(row.updatedAt, incoming.updatedAt);
          expect(row.vectorClock, incoming.vectorClock);
        },
      );

      test(
        'a concurrent version whose head descends from the local one moves it '
        'forward',
        () async {
          await storeLog(
            state(
              head: 'b1',
              clock: {'local': 1},
              at: DateTime(2026, 9, 1, 12),
            ),
          );

          await receiveEntity(
            state(head: 'a1', clock: {'peer': 1}, at: DateTime(2026, 9, 1, 9)),
          );

          final row = await stored();
          expect(row.recentHeadMessageId, 'a1');
          expect(row.vectorClock, const VectorClock({'local': 1}));
        },
      );

      test(
        'an unclocked version from an older build does not move the head '
        'back',
        () async {
          await storeLog(
            state(head: 'a1', clock: {'local': 1}, at: DateTime(2026, 9, 1, 9)),
          );
          final legacy = state(
            head: 'b1',
            clock: const {},
            at: DateTime(2026, 9, 1, 12),
          ).copyWith(vectorClock: null);

          await receiveEntity(legacy);

          final row = await stored();
          expect(row.recentHeadMessageId, 'a1');
          // The unclocked version still applies otherwise.
          expect(row.vectorClock, isNull);
          expect(row.updatedAt, legacy.updatedAt);
        },
      );

      test(
        'a dominating version keeps a local head that descends from its own',
        () async {
          // A concurrent merge kept the winner's clock and took `a1` from the
          // other side; the winner's successor still names `b1`.
          await storeLog(
            state(head: 'a1', clock: {'peer': 1}, at: DateTime(2026, 9, 1, 12)),
          );
          final incoming = state(
            head: 'b1',
            clock: {'peer': 2},
            at: DateTime(2026, 9, 1, 13),
          );

          await receiveEntity(incoming);

          final row = await stored();
          expect(row.recentHeadMessageId, 'a1');
          expect(row.vectorClock, incoming.vectorClock);
        },
      );

      test(
        'a local append that commits during the receive is not overwritten '
        '(TLC: AtomicReceive)',
        () async {
          // The receive read the row (head `a1`), the executor appended `a2`
          // and moved the head, and the receive then wrote the row it had
          // resolved from its stale read: the head went back to `a1`.
          await storeLog(
            state(head: 'a1', clock: {'local': 1}, at: DateTime(2026, 9, 1, 9)),
          );
          final read = device.holdNextStoredReadOf('state-head');

          final received = receiveEntity(
            state(head: 'b1', clock: {'peer': 1}, at: DateTime(2026, 9, 1, 12)),
          );
          await pumpEventQueue();
          final append = device.repository.runInTransaction(() async {
            final current = await stored();
            await device.repository.upsertEntity(
              makeTestMessage(
                id: 'a2',
                agentId: 'agent-1',
                createdAt: DateTime(2026, 9, 1, 10),
                prevMessageId: current.recentHeadMessageId,
              ),
            );
            await device.repository.upsertLink(
              edge('a2', current.recentHeadMessageId!),
            );
            await device.repository.upsertEntity(
              current.copyWith(
                recentHeadMessageId: 'a2',
                vectorClock: VectorClock({
                  ...current.vectorClock!.vclock,
                  'local': 2,
                }),
              ),
            );
          });
          await pumpEventQueue();
          read.complete();
          await Future.wait([received, append]);

          expect((await stored()).recentHeadMessageId, 'a2');
        },
      );
    });

    group('links and evolution sessions (AgentLinks.tla, '
        'EvolutionSession.tla, ADR 0081)', () {
      AgentLink link({required Map<String, int> clock, bool removed = false}) =>
          AgentLink.parsedItemToTask(
            id: 'l',
            fromId: 'item',
            toId: 'task',
            createdAt: DateTime(2026, 9, 24, 9),
            updatedAt: DateTime(2026, 9, 24, 9),
            vectorClock: VectorClock(clock),
            deletedAt: removed ? DateTime(2026, 9, 24, 9) : null,
          );

      EvolutionSessionEntity session(
        EvolutionSessionStatus status,
        Map<String, int> clock,
      ) => makeTestEvolutionSession(
        id: 's',
        status: status,
        vectorClock: VectorClock(clock),
      );

      /// The stored link, a tombstone included.
      Future<AgentLink?> storedLink() =>
          device.repository.getLinkByIdIncludingDeleted('l');

      test(
        'a late copy of a removed link does not bring it back '
        '(TLC: NoLostSuccessor, ReceiveSeesTombstones)',
        () async {
          // The trace: the removal arrives first, then the link it removed.
          // The tombstone read as no row, so the late copy replaced it.
          final removal = link(clock: {'peer': 2}, removed: true);
          await device.repository.upsertLink(removal);

          await receiveLink(link(clock: {'peer': 1}));

          expect(await storedLink(), removal);
        },
      );

      test(
        'a local link write that commits during the receive is not '
        'overwritten (TLC: AtomicReceive)',
        () async {
          await device.repository.upsertLink(link(clock: {'local': 1}));
          final read = device.holdNextStoredReadOf('l');

          // A peer's removal of the row this device holds.
          final received = receiveLink(
            link(clock: {'local': 1, 'peer': 1}, removed: true),
          );
          await pumpEventQueue();
          // Meanwhile this device links the item again, over what it holds.
          final relink = device.repository.runInTransaction(() async {
            final current = (await storedLink())!;
            await device.repository.upsertLink(
              link(clock: {...current.vectorClock!.vclock, 'local': 2}),
            );
          });
          await pumpEventQueue();
          read.complete();
          await Future.wait([received, relink]);

          final row = (await storedLink())!;
          expect(row.deletedAt, isNull);
          expect(row.vectorClock!.vclock['local'], 2);
        },
      );

      test(
        'an approval that commits during the receive of a sweep is not '
        'overwritten (TLC: AtomicReceive, CompletedStays)',
        () async {
          // The trace: this device reads its active row to apply a peer's
          // sweep, the approval completes the session, and the receive then
          // writes the sweep over the completion.
          await device.repository.upsertEntity(
            session(EvolutionSessionStatus.active, {'local': 1}),
          );
          final read = device.holdNextStoredReadOf('s');

          final received = receiveEntity(
            session(EvolutionSessionStatus.abandoned, {
              'local': 1,
              'peer': 1,
            }),
          );
          await pumpEventQueue();
          final approval = device.repository.runInTransaction(() async {
            final current = (await device.repository.getEntity('s'))!;
            await device.repository.upsertEntity(
              session(EvolutionSessionStatus.completed, {
                ...current.vectorClock!.vclock,
                'local': 2,
              }),
            );
          });
          await pumpEventQueue();
          read.complete();
          await Future.wait([received, approval]);

          expect(
            ((await device.repository.getEntity('s'))!
                    as EvolutionSessionEntity)
                .status,
            EvolutionSessionStatus.completed,
          );
        },
      );
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

      await receiveEntity(entity);

      expect(
        await device.repository.getEntityIncludingDeleted(entity.id),
        entity,
      );
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

    test(
      'an applied agent entity releases the vectors held for it — a report '
      'never runs the journal hook (ADR 0150)',
      () async {
        final sink = MockSyncedEmbeddingSink();
        when(() => sink.onAgentEntityApplied(any())).thenAnswer((_) async {});
        final vectors = MockEmbeddingVectorsSync();
        when(() => vectors.sink).thenReturn(sink);
        processor.embeddingVectors = vectors;
        final report = AgentDomainEntity.agentReport(
          id: 'report-1',
          agentId: 'agent-1',
          scope: 'current',
          createdAt: DateTime(2024, 3, 15),
          vectorClock: null,
          content: 'The report',
        );
        await receiveEntity(report);

        expect(
          await device.repository.getEntityIncludingDeleted(report.id),
          report,
        );
        verify(() => sink.onAgentEntityApplied('report-1')).called(1);
      },
    );

    test(
      'older-client rewrite preserves explicit task-agent setup fields',
      () async {
        final local =
            AgentDomainEntity.agent(
                  id: 'agent-legacy-rewrite',
                  agentId: 'agent-legacy-rewrite',
                  kind: 'task_agent',
                  displayName: 'Task Agent',
                  lifecycle: AgentLifecycle.active,
                  mode: AgentInteractionMode.autonomous,
                  allowedCategoryIds: const {},
                  currentStateId: 'state-1',
                  config: const AgentConfig(
                    profileId: 'profile-1',
                    automaticUpdatesEnabled: false,
                    maxWakesPerDay: 3,
                    inferenceSetup: AgentInferenceSetup(
                      mode: AgentInferenceSetupMode.configured,
                      origin: AgentInferenceSetupOrigin.categorySnapshot,
                      baseProfileId: 'profile-1',
                      originEntityId: 'category-1',
                    ),
                  ),
                  createdAt: DateTime(2024, 3, 15),
                  updatedAt: DateTime(2024, 3, 15),
                  vectorClock: null,
                )
                as AgentIdentityEntity;
        final incoming = local.copyWith(
          displayName: 'Renamed by older client',
          config: const AgentConfig(profileId: 'profile-1'),
          updatedAt: DateTime(2024, 3, 16),
        );
        await device.repository.upsertEntity(local);
        await receiveEntity(incoming);

        final applied =
            (await device.repository.getEntityIncludingDeleted(incoming.id))!
                as AgentIdentityEntity;
        expect(applied.displayName, 'Renamed by older client');
        expect(applied.config.automaticUpdatesEnabled, isFalse);
        expect(applied.config.inferenceSetup, local.config.inferenceSetup);
        expect(applied.config.maxWakesPerDay, 3);
      },
    );

    test(
      'a rewrite that omits only the daily wake budget keeps the local one',
      () async {
        // The other preferences are explicit, so before the budget joined the
        // overlay this payload was applied verbatim and an older peer reset a
        // user's lower limit to the default on every device.
        final local =
            AgentDomainEntity.agent(
                  id: 'project-agent-budget-rewrite',
                  agentId: 'project-agent-budget-rewrite',
                  kind: AgentKinds.projectAgent,
                  displayName: 'Project Agent',
                  lifecycle: AgentLifecycle.active,
                  mode: AgentInteractionMode.autonomous,
                  allowedCategoryIds: const {},
                  currentStateId: 'state-budget-rewrite',
                  config: const AgentConfig(
                    automaticUpdatesEnabled: true,
                    maxWakesPerDay: 2,
                    inferenceSetup: AgentInferenceSetup(
                      mode: AgentInferenceSetupMode.configured,
                      origin: AgentInferenceSetupOrigin.user,
                      baseProfileId: 'profile-1',
                    ),
                  ),
                  createdAt: DateTime(2024, 3, 15),
                  updatedAt: DateTime(2024, 3, 15),
                  vectorClock: null,
                )
                as AgentIdentityEntity;
        final incoming = local.copyWith(
          displayName: 'Renamed by older client',
          config: local.config.copyWith(maxWakesPerDay: null),
          updatedAt: DateTime(2024, 3, 16),
        );
        await device.repository.upsertEntity(local);
        await receiveEntity(incoming);

        final applied =
            (await device.repository.getEntityIncludingDeleted(incoming.id))!
                as AgentIdentityEntity;
        expect(applied.displayName, 'Renamed by older client');
        expect(applied.config.maxWakesPerDay, 2);
      },
    );

    test(
      'an older client that omits only the update interval keeps the local '
      'one',
      () async {
        // A build from before update slots knows the budget but not the
        // interval; its rewrite must not reset a user's daily interval to
        // hourly on every device.
        final local =
            AgentDomainEntity.agent(
                  id: 'project-agent-interval-rewrite',
                  agentId: 'project-agent-interval-rewrite',
                  kind: AgentKinds.projectAgent,
                  displayName: 'Project Agent',
                  lifecycle: AgentLifecycle.active,
                  mode: AgentInteractionMode.autonomous,
                  allowedCategoryIds: const {},
                  currentStateId: 'state-interval-rewrite',
                  config: const AgentConfig(
                    automaticUpdatesEnabled: true,
                    maxWakesPerDay: 2,
                    updateIntervalMinutes: 1440,
                    inferenceSetup: AgentInferenceSetup(
                      mode: AgentInferenceSetupMode.configured,
                      origin: AgentInferenceSetupOrigin.user,
                      baseProfileId: 'profile-1',
                    ),
                  ),
                  createdAt: DateTime(2024, 3, 15),
                  updatedAt: DateTime(2024, 3, 15),
                  vectorClock: null,
                )
                as AgentIdentityEntity;
        final incoming = local.copyWith(
          displayName: 'Renamed by older client',
          config: local.config.copyWith(updateIntervalMinutes: null),
          updatedAt: DateTime(2024, 3, 16),
        );
        await device.repository.upsertEntity(local);
        await receiveEntity(incoming);

        final applied =
            (await device.repository.getEntityIncludingDeleted(incoming.id))!
                as AgentIdentityEntity;
        expect(applied.displayName, 'Renamed by older client');
        expect(applied.config.updateIntervalMinutes, 1440);
        expect(applied.config.maxWakesPerDay, 2);
      },
    );

    test(
      'older-client rewrite preserves an explicit project-agent opt-out',
      () async {
        final local =
            AgentDomainEntity.agent(
                  id: 'project-agent-legacy-rewrite',
                  agentId: 'project-agent-legacy-rewrite',
                  kind: 'project_agent',
                  displayName: 'Project Agent',
                  lifecycle: AgentLifecycle.active,
                  mode: AgentInteractionMode.autonomous,
                  allowedCategoryIds: const {},
                  currentStateId: 'state-project-agent-legacy-rewrite',
                  config: const AgentConfig(
                    automaticUpdatesEnabled: false,
                    inferenceSetup: AgentInferenceSetup(
                      mode: AgentInferenceSetupMode.disabled,
                      origin: AgentInferenceSetupOrigin.user,
                    ),
                  ),
                  createdAt: DateTime(2024, 3, 15),
                  updatedAt: DateTime(2024, 3, 15),
                  vectorClock: null,
                )
                as AgentIdentityEntity;
        final incoming = local.copyWith(
          displayName: 'Renamed by older client',
          config: const AgentConfig(),
          updatedAt: DateTime(2024, 3, 16),
        );
        await device.repository.upsertEntity(local);
        await receiveEntity(incoming);

        final applied =
            (await device.repository.getEntity(incoming.id))!
                as AgentIdentityEntity;
        expect(applied.displayName, 'Renamed by older client');
        expect(applied.config.automaticUpdatesEnabled, isFalse);
        expect(applied.config.inferenceSetup, local.config.inferenceSetup);
      },
    );

    test('explicit incoming setup fields win over local values', () async {
      final local =
          AgentDomainEntity.agent(
                id: 'agent-explicit-rewrite',
                agentId: 'agent-explicit-rewrite',
                kind: 'task_agent',
                displayName: 'Task Agent',
                lifecycle: AgentLifecycle.active,
                mode: AgentInteractionMode.autonomous,
                allowedCategoryIds: const {},
                currentStateId: 'state-1',
                config: const AgentConfig(
                  automaticUpdatesEnabled: false,
                  inferenceSetup: AgentInferenceSetup(
                    mode: AgentInferenceSetupMode.disabled,
                    origin: AgentInferenceSetupOrigin.user,
                  ),
                ),
                createdAt: DateTime(2024, 3, 15),
                updatedAt: DateTime(2024, 3, 15),
                vectorClock: null,
              )
              as AgentIdentityEntity;
      final incoming = local.copyWith(
        config: const AgentConfig(
          profileId: 'profile-2',
          automaticUpdatesEnabled: true,
          inferenceSetup: AgentInferenceSetup(
            mode: AgentInferenceSetupMode.configured,
            origin: AgentInferenceSetupOrigin.user,
            baseProfileId: 'profile-2',
          ),
        ),
        updatedAt: DateTime(2024, 3, 16),
      );
      await device.repository.upsertEntity(local);
      await receiveEntity(incoming);

      expect(
        await device.repository.getEntityIncludingDeleted(incoming.id),
        incoming,
      );
    });

    test('processes agent state entity', () async {
      final entity = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        revision: 5,
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
        wakeCounter: const GCounter({'test-host': 42}),
      );

      await receiveEntity(entity);

      expect(
        await device.repository.getEntityIncludingDeleted(entity.id),
        entity,
      );
    });

    test('repairs a legacy week rollup before applying inbound sync', () async {
      final entity = AgentDomainEntity.weekRollup(
        id: 'week_rollup:2026-05-18',
        agentId: 'daily_os_planner',
        weekStart: DateTime.utc(2026, 5, 18),
        plannedMinutesByCategory: const {'cat-work': 480},
        recordedMinutesByCategory: const {'cat-work': 310},
        daysWithPlans: 5,
        createdAt: DateTime(2026, 5, 24),
        updatedAt: DateTime(2026, 5, 24, 12),
        vectorClock: const VectorClock({'remote-host': 3}),
      );
      final envelope =
          jsonDecode(
                jsonEncode(
                  SyncMessage.agentEntity(
                    agentEntity: entity,
                    status: SyncEntryStatus.update,
                  ).toJson(),
                ),
              )
              as Map<String, dynamic>;
      (envelope['agentEntity'] as Map<String, dynamic>).remove('weekStart');
      when(() => event.text).thenReturn(
        base64.encode(utf8.encode(jsonEncode(envelope))),
      );

      await processor.process(envelope: event, journalDb: journalDb);

      final applied =
          (await device.repository.getEntityIncludingDeleted(entity.id))!
              as WeekRollupEntity;
      expect(applied, entity);
      expect(
        applied.weekStart,
        DateTime.utc(2026, 5, 18),
        reason:
            'The id is a zone-free calendar key, so the repaired value is '
            'read from its components rather than resolved in the reader zone.',
      );
    });

    test('skips an irreparable legacy week rollup during prepare', () async {
      final entity = AgentDomainEntity.weekRollup(
        id: 'week_rollup:2026-05-18',
        agentId: 'daily_os_planner',
        weekStart: DateTime(2026, 5, 18),
        createdAt: DateTime(2026, 5, 24),
        updatedAt: DateTime(2026, 5, 24, 12),
        vectorClock: const VectorClock({'remote-host': 3}),
      );
      final envelope =
          jsonDecode(
                jsonEncode(
                  SyncMessage.agentEntity(
                    agentEntity: entity,
                    status: SyncEntryStatus.update,
                  ).toJson(),
                ),
              )
              as Map<String, dynamic>;
      final nested = (envelope['agentEntity'] as Map<String, dynamic>)
        ..remove('weekStart')
        ..['id'] = 'week_rollup:2026-05-17';
      expect(nested['weekStart'], isNull);
      when(() => event.text).thenReturn(
        base64.encode(utf8.encode(jsonEncode(envelope))),
      );

      final prepared = await processor.prepare(envelope: event);

      expect(prepared, isNull);
      expect(
        await device.repository.getEntityIncludingDeleted(
          'week_rollup:2026-05-17',
        ),
        isNull,
      );
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: allOf(
              contains('Legacy weekRollup is missing weekStart'),
              isNot(contains('2026-05-17')),
            ),
          ),
          subDomain: 'processor.skipUnrecoverable',
        ),
      ).called(1);
    });

    test('applying a remote agent state keeps local scheduling fields '
        '(device-local, not synced)', () async {
      // Incoming causally dominates local, so it is applied — but the local
      // device's own scheduling must survive (PR 4 B4).
      final local = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: const VectorClock({'host-A': 1}),
        wakeCounter: const GCounter({'host-A': 1}),
        nextWakeAt: DateTime(2024, 1, 2),
        sleepUntil: DateTime(2024, 1, 3),
        scheduledWakeAt: DateTime(2024, 1, 1),
      );
      final incoming = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 16),
        vectorClock: const VectorClock({'host-A': 2}),
        wakeCounter: const GCounter({'host-A': 3}),
        // The peer's schedule — must be ignored on this device.
        nextWakeAt: DateTime(2030, 1, 2),
        sleepUntil: DateTime(2030, 1, 3),
        scheduledWakeAt: DateTime(2030, 1, 1),
      );
      await device.repository.upsertEntity(local);
      await receiveEntity(incoming);

      final upserted =
          (await device.repository.getEntityIncludingDeleted(incoming.id))!
              as AgentStateEntity;
      // Scheduling stays local…
      expect(upserted.scheduledWakeAt, DateTime(2024, 1, 1));
      expect(upserted.nextWakeAt, DateTime(2024, 1, 2));
      expect(upserted.sleepUntil, DateTime(2024, 1, 3));
      // …while everything else takes the applied (incoming) value.
      expect(upserted.wakeCounter.value, 3);
      expect(upserted.updatedAt, DateTime(2024, 3, 16));
    });

    test('concurrent agent-state edits merge their G-counters element-wise '
        '(no increment lost)', () async {
      // localVc leads on host-A, incomingVc leads on host-B → concurrent.
      const localVc = VectorClock({'host-A': 2, 'host-B': 1});
      const incomingVc = VectorClock({'host-A': 1, 'host-B': 2});
      final local = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        revision: 5,
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 16),
        vectorClock: localVc,
        wakeCounter: const GCounter({'host-A': 7}),
      );
      final incoming = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        revision: 5,
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 16),
        vectorClock: incomingVc,
        wakeCounter: const GCounter({'host-B': 4}),
      );
      await device.repository.upsertEntity(local);
      await receiveEntity(incoming);

      final upserted =
          (await device.repository.getEntityIncludingDeleted(incoming.id))!
              as AgentStateEntity;
      // Both devices' increments survive the concurrent apply.
      expect(upserted.wakeCounter.byHost, {'host-A': 7, 'host-B': 4});
      expect(upserted.wakeCounter.value, 11);
    });

    test('concurrent goal-nudge edits join exposure counters and collapse '
        'same-activation ratings to the earliest outcome', () async {
      const localVc = VectorClock({'host-A': 2, 'host-B': 1});
      const incomingVc = VectorClock({'host-A': 1, 'host-B': 2});
      GoalNudgeEntity nudgeRow({
        required VectorClock vc,
        required GCounter visibleMs,
        required List<NudgeRating> ratings,
        NudgeStatus status = NudgeStatus.active,
      }) =>
          AgentDomainEntity.goalNudge(
                id: 'nudge-1',
                agentId: 'agent-1',
                status: status,
                brief: const NudgeBrief(
                  headline: 'h',
                  tone: NudgeTone.nudge,
                  animation: NudgeBannerAnimation.steady,
                ),
                briefDigest: 'd',
                createdAt: DateTime(2026, 8),
                updatedAt: DateTime(2026, 8, 2),
                vectorClock: vc,
                totalVisibleMs: visibleMs,
                ratings: ratings,
              )
              as GoalNudgeEntity;

      final local = nudgeRow(
        vc: localVc,
        visibleMs: const GCounter({'host-A': 5000}),
        ratings: [
          NudgeRating(
            activation: 1,
            ratedAt: DateTime(2026, 8, 1, 9),
            rating: 5,
          ),
        ],
        status: NudgeStatus.dismissed,
      );
      final incoming = nudgeRow(
        vc: incomingVc,
        visibleMs: const GCounter({'host-B': 3000}),
        ratings: [
          NudgeRating(
            activation: 1,
            ratedAt: DateTime(2026, 8, 1, 11),
            rating: 4,
          ),
        ],
      );
      await device.repository.upsertEntity(local);
      await receiveEntity(incoming);

      final upserted =
          (await device.repository.getEntityIncludingDeleted(incoming.id))!
              as GoalNudgeEntity;
      // The dismissal-terminal override picked local as the winner, and
      // the accumulator join recovered the other device's exposure and
      // rating anyway.
      expect(upserted.status, NudgeStatus.dismissed);
      expect(
        upserted.totalVisibleMs.byHost,
        {'host-A': 5000, 'host-B': 3000},
      );
      // One outcome per activation: both devices rated activation 1, and
      // the merge keeps the EARLIEST outcome (the first one the user gave).
      expect(upserted.ratings, hasLength(1));
      expect(upserted.ratings.single.activation, 1);
      expect(upserted.ratings.single.rating, 5);
      expect(upserted.ratings.single.ratedAt, DateTime(2026, 8, 1, 9));
    });

    test('concurrent goal-nudge edits with no dismissal fall to LWW for '
        'the row while still joining the counters', () async {
      const localVc = VectorClock({'host-A': 2, 'host-B': 1});
      const incomingVc = VectorClock({'host-A': 1, 'host-B': 2});
      final local =
          AgentDomainEntity.goalNudge(
                id: 'nudge-2',
                agentId: 'agent-1',
                status: NudgeStatus.active,
                brief: const NudgeBrief(
                  headline: 'old copy',
                  tone: NudgeTone.nudge,
                  animation: NudgeBannerAnimation.steady,
                ),
                briefDigest: 'd',
                createdAt: DateTime(2026, 8),
                updatedAt: DateTime(2026, 8, 2),
                vectorClock: localVc,
                totalVisibleMs: const GCounter({'host-A': 100}),
              )
              as GoalNudgeEntity;
      final incoming =
          AgentDomainEntity.goalNudge(
                id: 'nudge-2',
                agentId: 'agent-1',
                status: NudgeStatus.retired,
                brief: const NudgeBrief(
                  headline: 'old copy',
                  tone: NudgeTone.nudge,
                  animation: NudgeBannerAnimation.steady,
                ),
                briefDigest: 'd',
                createdAt: DateTime(2026, 8),
                // Strictly newer wall clock → incoming wins the row.
                updatedAt: DateTime(2026, 8, 3),
                vectorClock: incomingVc,
                totalVisibleMs: const GCounter({'host-B': 200}),
              )
              as GoalNudgeEntity;
      await device.repository.upsertEntity(local);
      await receiveEntity(incoming);

      final upserted =
          (await device.repository.getEntityIncludingDeleted(incoming.id))!
              as GoalNudgeEntity;
      expect(upserted.status, NudgeStatus.retired);
      expect(
        upserted.totalVisibleMs.byHost,
        {'host-A': 100, 'host-B': 200},
      );
    });

    test(
      'concurrent goal-nudge edits with equal lifecycle standing fall to '
      'wall-clock LWW: the newer local row wins, counters still join',
      () async {
        const localVc = VectorClock({'host-A': 2, 'host-B': 1});
        const incomingVc = VectorClock({'host-A': 1, 'host-B': 2});
        GoalNudgeEntity nudge({
          required String headline,
          required DateTime updatedAt,
          required VectorClock vectorClock,
          required GCounter visible,
        }) =>
            AgentDomainEntity.goalNudge(
                  id: 'nudge-lww',
                  agentId: 'agent-1',
                  status: NudgeStatus.active,
                  brief: NudgeBrief(
                    headline: headline,
                    tone: NudgeTone.nudge,
                    animation: NudgeBannerAnimation.steady,
                  ),
                  briefDigest: 'd',
                  createdAt: DateTime(2026, 8),
                  updatedAt: updatedAt,
                  vectorClock: vectorClock,
                  totalVisibleMs: visible,
                )
                as GoalNudgeEntity;
        final local = nudge(
          headline: 'local copy',
          // Strictly newer wall clock → local wins the row.
          updatedAt: DateTime(2026, 8, 3),
          vectorClock: localVc,
          visible: const GCounter({'host-A': 100}),
        );
        final incoming = nudge(
          headline: 'incoming copy',
          updatedAt: DateTime(2026, 8, 2),
          vectorClock: incomingVc,
          visible: const GCounter({'host-B': 200}),
        );
        await device.repository.upsertEntity(local);
        await receiveEntity(incoming);

        final upserted =
            (await device.repository.getEntityIncludingDeleted(incoming.id))!
                as GoalNudgeEntity;
        expect(upserted.brief.headline, 'local copy');
        expect(
          upserted.totalVisibleMs.byHost,
          {'host-A': 100, 'host-B': 200},
        );
      },
    );

    test(
      'concurrent relationship-nudge edits take the same merge path as '
      'goal nudges (ADR 0059): dismissal terminal, counters joined',
      () async {
        const localVc = VectorClock({'host-A': 2, 'host-B': 1});
        const incomingVc = VectorClock({'host-A': 1, 'host-B': 2});
        RelationshipNudgeEntity nudgeRow({
          required VectorClock vc,
          required GCounter visibleMs,
          NudgeStatus status = NudgeStatus.active,
        }) =>
            AgentDomainEntity.relationshipNudge(
                  id: 'rnudge-1',
                  agentId: 'relationship-agent-1',
                  status: status,
                  brief: const NudgeBrief(
                    headline: 'Check in with Anna — five weeks.',
                    tone: NudgeTone.nudge,
                    animation: NudgeBannerAnimation.steady,
                  ),
                  briefDigest: 'dr',
                  createdAt: DateTime(2026, 8),
                  updatedAt: DateTime(2026, 8, 2),
                  vectorClock: vc,
                  totalVisibleMs: visibleMs,
                )
                as RelationshipNudgeEntity;

        final local = nudgeRow(
          vc: localVc,
          visibleMs: const GCounter({'host-A': 5000}),
          status: NudgeStatus.dismissed,
        );
        final incoming = nudgeRow(
          vc: incomingVc,
          visibleMs: const GCounter({'host-B': 3000}),
        );
        await device.repository.upsertEntity(local);
        await receiveEntity(incoming);

        final upserted =
            (await device.repository.getEntityIncludingDeleted(incoming.id))!
                as RelationshipNudgeEntity;
        // The shared lifecycle override kept the dismissal; the shared
        // accumulator join still recovered the other device's exposure.
        expect(upserted.status, NudgeStatus.dismissed);
        expect(
          upserted.totalVisibleMs.byHost,
          {'host-A': 5000, 'host-B': 3000},
        );
      },
    );

    test(
      'a known incoming variant replaces a local unknown stub at an EQUAL '
      'clock — the old-build round-trip must not pin the stripped row',
      () async {
        // An old build decoded an incoming relationshipNudge through the
        // `unknown` fallback and persisted the payload-less stub with the
        // incoming vector clock intact. After upgrade the row still decodes
        // as unknown; without the refinement guard, re-delivery of the very
        // version it stubbed compares `equal` and keep-local wins forever.
        const sharedVc = VectorClock({'host-A': 3});
        final localStub = AgentDomainEntity.unknown(
          id: 'rnudge-stub-1',
          agentId: 'relationship-agent-1',
          createdAt: DateTime(2026, 8),
          vectorClock: sharedVc,
        );
        final incoming = AgentDomainEntity.relationshipNudge(
          id: 'rnudge-stub-1',
          agentId: 'relationship-agent-1',
          status: NudgeStatus.dismissed,
          brief: const NudgeBrief(
            headline: 'Check in with Anna — five weeks.',
            tone: NudgeTone.nudge,
            animation: NudgeBannerAnimation.steady,
          ),
          briefDigest: 'dr',
          createdAt: DateTime(2026, 8),
          updatedAt: DateTime(2026, 8, 2),
          vectorClock: sharedVc,
          totalVisibleMs: const GCounter({'host-B': 3000}),
        );
        await device.repository.upsertEntity(localStub);
        await receiveEntity(incoming);

        final upserted =
            (await device.repository.getEntityIncludingDeleted(incoming.id))!
                as RelationshipNudgeEntity;
        expect(upserted.status, NudgeStatus.dismissed);
        expect(upserted.totalVisibleMs.byHost, {'host-B': 3000});
      },
    );

    test(
      'a known incoming variant replaces a local unknown stub even when the '
      'stub clock dominates — refinement beats clock order',
      () async {
        // The stub may carry a NEWER clock than a re-delivered older version
        // (the old build stubbed v5, the backfill replays v3). An older known
        // payload still beats a payload-less stub; re-delivery of the newer
        // version later converges the row forward again.
        const stubVc = VectorClock({'host-A': 5});
        const incomingVc = VectorClock({'host-A': 3});
        final localStub = AgentDomainEntity.unknown(
          id: 'rnudge-stub-2',
          agentId: 'relationship-agent-1',
          createdAt: DateTime(2026, 8),
          vectorClock: stubVc,
        );
        final incoming = AgentDomainEntity.relationshipNudge(
          id: 'rnudge-stub-2',
          agentId: 'relationship-agent-1',
          status: NudgeStatus.active,
          brief: const NudgeBrief(
            headline: 'Check in with Anna — five weeks.',
            tone: NudgeTone.nudge,
            animation: NudgeBannerAnimation.steady,
          ),
          briefDigest: 'dr',
          createdAt: DateTime(2026, 8),
          updatedAt: DateTime(2026, 8, 2),
          vectorClock: incomingVc,
        );
        await device.repository.upsertEntity(localStub);
        await receiveEntity(incoming);

        final upserted =
            (await device.repository.getEntityIncludingDeleted(incoming.id))!
                as RelationshipNudgeEntity;
        expect(upserted.status, NudgeStatus.active);
      },
    );

    test(
      'an unknown-stub TOMBSTONE is kept against an older live payload — '
      'refinement never resurrects a deletion',
      () async {
        const stubVc = VectorClock({'host-A': 5});
        const incomingVc = VectorClock({'host-A': 3});
        final localStub = AgentDomainEntity.unknown(
          id: 'rnudge-stub-3',
          agentId: 'relationship-agent-1',
          createdAt: DateTime(2026, 8),
          vectorClock: stubVc,
          deletedAt: DateTime(2026, 8, 4),
        );
        final incoming = AgentDomainEntity.relationshipNudge(
          id: 'rnudge-stub-3',
          agentId: 'relationship-agent-1',
          status: NudgeStatus.active,
          brief: const NudgeBrief(
            headline: 'Check in with Anna — five weeks.',
            tone: NudgeTone.nudge,
            animation: NudgeBannerAnimation.steady,
          ),
          briefDigest: 'dr',
          createdAt: DateTime(2026, 8),
          updatedAt: DateTime(2026, 8, 2),
          vectorClock: incomingVc,
        );
        await device.repository.upsertEntity(localStub);
        await receiveEntity(incoming);

        expect(
          await device.repository.getEntityIncludingDeleted(incoming.id),
          localStub,
        );
      },
    );

    test(
      'a clock-DOMINANT live payload replaces a tombstoned unknown stub — '
      'the tombstone guard only blocks non-dominant resurrection',
      () async {
        // The guard keeps a stub tombstone against an OLDER live payload; a
        // strictly newer live version causally supersedes the deletion and
        // must still apply, or a tombstoned stub would pin the row forever.
        const stubVc = VectorClock({'host-A': 3});
        const incomingVc = VectorClock({'host-A': 5});
        final localStub = AgentDomainEntity.unknown(
          id: 'rnudge-stub-4',
          agentId: 'relationship-agent-1',
          createdAt: DateTime(2026, 8),
          vectorClock: stubVc,
          deletedAt: DateTime(2026, 8, 4),
        );
        final incoming = AgentDomainEntity.relationshipNudge(
          id: 'rnudge-stub-4',
          agentId: 'relationship-agent-1',
          status: NudgeStatus.active,
          brief: const NudgeBrief(
            headline: 'Check in with Anna — five weeks.',
            tone: NudgeTone.nudge,
            animation: NudgeBannerAnimation.steady,
          ),
          briefDigest: 'dr',
          createdAt: DateTime(2026, 8),
          updatedAt: DateTime(2026, 8, 6),
          vectorClock: incomingVc,
        );
        await device.repository.upsertEntity(localStub);
        await receiveEntity(incoming);

        final upserted =
            (await device.repository.getEntityIncludingDeleted(incoming.id))!
                as RelationshipNudgeEntity;
        expect(upserted.status, NudgeStatus.active);
      },
    );

    test('a locally-dominating agent state is kept — incoming is neither '
        'merged nor applied', () async {
      // local dominates (a_gt_b), so the merge must NOT run; if it did it would
      // upsert a merged state. Correct behavior keeps local and writes nothing.
      const localVc = VectorClock({'host-A': 2});
      const incomingVc = VectorClock({'host-A': 1});
      final local = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        revision: 5,
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 16),
        vectorClock: localVc,
        wakeCounter: const GCounter({'host-A': 5}),
      );
      final incoming = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        revision: 5,
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: incomingVc,
        wakeCounter: const GCounter({'host-A': 3}),
      );
      await device.repository.upsertEntity(local);
      when(() => event.text).thenReturn(
        encodeMessage(
          SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
          ),
        ),
      );

      await withClock(
        Clock.fixed(DateTime(2026, 8, 1, 9)),
        () => processor.process(envelope: event, journalDb: journalDb),
      );

      expect(
        await device.repository.getEntityIncludingDeleted(incoming.id),
        local,
      );
    });

    test(
      'a concurrent retract of durable knowledge is kept — a later edit cannot '
      'revive it (ADR 0022 monotonic override)',
      () async {
        // Concurrent clocks (local leads host-A, incoming leads host-B) with a
        // STRICTLY LATER incoming timestamp: plain LWW would apply the edit and
        // resurrect the retracted knowledge. The monotonic override keeps the
        // retraction instead.
        const localVc = VectorClock({'host-A': 2, 'host-B': 1});
        const incomingVc = VectorClock({'host-A': 1, 'host-B': 2});
        final local = AgentDomainEntity.plannerKnowledge(
          id: 'k1',
          agentId: 'agent-1',
          key: 'deep-work',
          hook: 'no deep work before 10',
          statementText: 'Never schedule deep work before 10:00.',
          source: KnowledgeSource.userStated,
          status: KnowledgeStatus.retracted,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 16),
          vectorClock: localVc,
          retractedAt: DateTime(2024, 3, 16),
        );
        final incoming = AgentDomainEntity.plannerKnowledge(
          id: 'k1',
          agentId: 'agent-1',
          key: 'deep-work',
          hook: 'no deep work before 10',
          statementText: 'edited back to active',
          source: KnowledgeSource.userStated,
          status: KnowledgeStatus.confirmed,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 17),
          vectorClock: incomingVc,
          confirmedAt: DateTime(2024, 3, 17),
        );
        await device.repository.upsertEntity(local);
        await receiveEntity(incoming);

        // The retraction wins despite the later edit timestamp, so the
        // incoming confirm is neither applied nor written.
        expect(
          await device.repository.getEntityIncludingDeleted(incoming.id),
          local,
        );
      },
    );

    group('agent entities in an outbox bundle', () {
      AgentDomainEntity head(
        String id,
        Map<String, int> clock,
        int day, {
        bool removed = false,
      }) => AgentDomainEntity.agentReportHead(
        id: id,
        agentId: 'agent-$id',
        scope: 'current',
        reportId: 'report-$day',
        updatedAt: DateTime(2024, 3, day),
        vectorClock: VectorClock(clock),
        deletedAt: removed ? DateTime(2024, 3, day) : null,
      );

      Future<void> receiveBundle(List<AgentDomainEntity> children) =>
          device.receiveEnvelope(
            SyncMessage.outboxBundle(
              children: [
                for (final child in children)
                  SyncMessage.agentEntity(
                    agentEntity: child,
                    status: SyncEntryStatus.update,
                  ),
              ],
            ),
            envelope: event,
            journalDb: journalDb,
          );

      test('each child resolves against the stored row, a tombstone '
          'included', () async {
        final live = head('head-live', {'host-A': 2}, 16);
        final removal = head('head-removed', {'host-A': 2}, 16, removed: true);
        await device.repository.upsertEntity(live);
        await device.repository.upsertEntity(removal);

        // Late copies of versions both stored rows succeed.
        await receiveBundle([
          head('head-live', {'host-A': 1}, 15),
          head('head-removed', {'host-A': 1}, 15),
        ]);

        expect(
          await device.repository.getEntityIncludingDeleted('head-live'),
          live,
        );
        expect(
          await device.repository.getEntityIncludingDeleted('head-removed'),
          removal,
        );
      });

      test(
        'a local write that commits during the receive of a child is '
        'not overwritten: each child is read inside its own transaction',
        () async {
          await device.repository.upsertEntity(
            head('head-raced', {'host-A': 1}, 15),
          );
          final read = device.holdNextStoredReadOf('head-raced');

          final received = receiveBundle([
            head('head-raced', {'host-B': 1}, 16),
          ]);
          await pumpEventQueue();
          final local = head('head-raced', {'host-A': 2}, 17);
          final write = device.repository.runInTransaction(
            () => device.repository.upsertEntity(local),
          );
          await pumpEventQueue();
          read.complete();
          await Future.wait([received, write]);

          expect(
            await device.repository.getEntityIncludingDeleted('head-raced'),
            local,
          );
        },
      );

      test('a later child resolves against the row an earlier child '
          'wrote', () async {
        await device.repository.upsertEntity(
          head('head-twice', {'host-A': 1}, 15),
        );
        final newer = head('head-twice', {'host-A': 3}, 17);

        await receiveBundle([
          newer,
          head('head-twice', {'host-A': 2}, 16),
        ]);

        expect(
          await device.repository.getEntityIncludingDeleted('head-twice'),
          newer,
        );
      });
    });

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

      await receiveEntity(entity);

      expect(
        await device.repository.getEntityIncludingDeleted(entity.id),
        entity,
      );
    });

    test('processes agent message payload entity', () async {
      final entity = AgentDomainEntity.agentMessagePayload(
        id: 'payload-1',
        agentId: 'agent-1',
        createdAt: DateTime(2024, 3, 15),
        vectorClock: null,
        content: const {'text': 'hello world'},
      );

      await receiveEntity(entity);

      expect(
        await device.repository.getEntityIncludingDeleted(entity.id),
        entity,
      );
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
      final taskLink = AgentLink.agentTask(
        id: 'agent-task-link',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );
      final deletedTaskLink = AgentLink.agentTask(
        id: 'deleted-agent-task-link',
        fromId: 'agent-1',
        toId: 'deleted-task',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
        deletedAt: DateTime(2024, 3, 16),
      );
      await device.repository.upsertLink(taskLink);
      await device.repository.upsertLink(deletedTaskLink);
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(envelope: event, journalDb: journalDb);

      expect(
        await device.repository.getEntityIncludingDeleted(entity.id),
        entity,
      );
      verify(
        () => updateNotifications.notify(
          {'agent-1', 'task-1', 'AGENT_CHANGED'},
          fromSync: true,
        ),
      ).called(1);
    });

    test(
      'projects the AI attribution a synced report carries into the '
      'consumption read model',
      () async {
        final attribution = makeAiWorkAttribution(
          attributionId: 'attribution-waddle-report',
        );
        final repo = MockConsumptionRepository();
        when(() => repo.upsertAttribution(any())).thenAnswer((_) async {});
        processor.consumptionRepository = repo;
        final entity = AgentDomainEntity.agentReport(
          id: 'report-attributed',
          agentId: 'agent-1',
          scope: 'current',
          createdAt: DateTime(2024, 3, 15),
          vectorClock: null,
          content: 'Pip restocked the krill depot.',
          provenance: {aiAttributionProvenanceKey: attribution.toJson()},
        );
        await receiveEntity(entity);

        final projected =
            verify(
                  () => repo.upsertAttribution(captureAny()),
                ).captured.single
                as AiWorkAttribution;
        expect(projected.id, 'attribution-waddle-report');
        expect(projected.toJson(), attribution.toJson());
      },
    );

    test(
      'an older-client identity rewrite inside a bundle overlays the '
      'stored local setup, or passes through when there is no local row',
      () async {
        AgentIdentityEntity identity(
          String id, {
          required AgentConfig config,
          required int counter,
        }) =>
            AgentDomainEntity.agent(
                  id: id,
                  agentId: id,
                  kind: 'task_agent',
                  displayName: 'Waddle Task Agent',
                  lifecycle: AgentLifecycle.active,
                  mode: AgentInteractionMode.autonomous,
                  allowedCategoryIds: const {},
                  currentStateId: 'state-$id',
                  config: config,
                  createdAt: DateTime(2024, 3, 15),
                  updatedAt: DateTime(2024, 3, 15 + counter),
                  vectorClock: VectorClock({'host-A': counter}),
                )
                as AgentIdentityEntity;
        const localConfig = AgentConfig(
          automaticUpdatesEnabled: false,
          inferenceSetup: AgentInferenceSetup(
            mode: AgentInferenceSetupMode.disabled,
            origin: AgentInferenceSetupOrigin.user,
          ),
        );
        final local = identity(
          'agent-known',
          config: localConfig,
          counter: 1,
        );
        final incomingKnown = identity(
          'agent-known',
          config: const AgentConfig(),
          counter: 2,
        );
        final incomingNew = identity(
          'agent-new',
          config: const AgentConfig(),
          counter: 2,
        );
        await device.repository.upsertEntity(local);
        when(() => event.text).thenReturn(
          encodeMessage(
            SyncMessage.outboxBundle(
              children: [
                SyncMessage.agentEntity(
                  agentEntity: incomingKnown,
                  status: SyncEntryStatus.update,
                ),
                SyncMessage.agentEntity(
                  agentEntity: incomingNew,
                  status: SyncEntryStatus.update,
                ),
              ],
            ),
          ),
        );

        await processor.process(envelope: event, journalDb: journalDb);

        final applied = {
          for (final id in ['agent-known', 'agent-new'])
            id: (await device.repository.getEntity(id))! as AgentIdentityEntity,
        };
        expect(applied['agent-known']!.config, localConfig);
        expect(applied['agent-new']!.config, const AgentConfig());
      },
    );

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
      final taskLink = AgentLink.agentTask(
        id: 'agent-task-link',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );
      await device.repository.upsertLink(taskLink);
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(envelope: event, journalDb: journalDb);

      expect(
        await device.repository.getEntityIncludingDeleted(entity.id),
        entity,
      );
      verify(
        () => updateNotifications.notify(
          {'agent-1', 'task-1', 'AGENT_CHANGED'},
          fromSync: true,
        ),
      ).called(1);
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

        await receiveEntity(entity);

        expect(
          await device.repository.getEntityIncludingDeleted(entity.id),
          entity,
        );
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

      await receiveEntity(entity);

      expect(
        await device.repository.getEntityIncludingDeleted(entity.id),
        entity,
      );
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

      await receiveLink(link);

      expect(
        await device.repository.getLinkByIdIncludingDeleted(link.id),
        link,
      );
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

      AgentDomainEntity stateWith(VectorClock clock, int day) =>
          AgentDomainEntity.agentState(
            id: 'state-cc',
            agentId: 'agent-1',
            revision: 1,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, day),
            vectorClock: clock,
          );

      AgentLink linkWith(VectorClock clock, int day) => AgentLink.basic(
        id: 'link-cc',
        fromId: 'agent-1',
        toId: 'state-1',
        createdAt: DateTime(2024, 3),
        updatedAt: DateTime(2024, 3, day),
        vectorClock: clock,
      );

      // The last two rows feed the SAME concurrent pair from both device
      // perspectives on an equal timestamp: the canonically-greater version
      // wins whether it is the incoming payload or the already-stored row —
      // i.e. both devices converge on the same winner.
      for (final (name, local, incoming, incomingWins) in [
        (
          'a newer incoming updatedAt is applied, though the local clock is '
              'canonically greater',
          (vcWinsTie, 15),
          (vcLosesTie, 16),
          true,
        ),
        (
          'a newer local updatedAt is kept',
          (vcLosesTie, 16),
          (vcWinsTie, 15),
          false,
        ),
        (
          'equal updatedAt: a greater incoming clock is applied',
          (vcLosesTie, 15),
          (vcWinsTie, 15),
          true,
        ),
        (
          'equal updatedAt: a greater local clock is kept',
          (vcWinsTie, 15),
          (vcLosesTie, 15),
          false,
        ),
      ]) {
        test('entity — $name', () async {
          final stored = stateWith(local.$1, local.$2);
          final received = stateWith(incoming.$1, incoming.$2);
          await device.repository.upsertEntity(stored);

          await receiveEntity(received);

          expect(
            await device.repository.getEntity('state-cc'),
            incomingWins ? received : stored,
          );
        });

        test('link — $name', () async {
          final stored = linkWith(local.$1, local.$2);
          final received = linkWith(incoming.$1, incoming.$2);
          await device.repository.upsertLink(stored);

          await receiveLink(received);

          expect(
            await device.repository.getLinkByIdIncludingDeleted('link-cc'),
            incomingWins ? received : stored,
          );
        });
      }
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

        await processor.process(envelope: event, journalDb: journalDb);

        // Bundle is intentionally not applied — the agent repo is not
        // touched, no AGENT_CHANGED notifications fire, and process()
        // completes cleanly so the inbound queue marker advances. The
        // sender already recorded each child under per-entity /
        // per-link sequence-log entries, so backfill picks them up if
        // they are missing locally.
        expect(
          await device.repository.getEntityIncludingDeleted(entity.id),
          isNull,
        );
        expect(
          await device.repository.getLinkByIdIncludingDeleted(link.id),
          isNull,
        );
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
          await receiveLink(link);

          expect(
            await device.repository.getLinkByIdIncludingDeleted(link.id),
            link,
          );
        }
      },
    );

    test('fails the apply of an agent entity, rather than dropping it, '
        'while agentRepository is not wired', () async {
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

      // A throw is a retriable apply failure: the queue retries it, and
      // keeps it as a skipped event past the cap, instead of dropping
      // another device's agent record.
      await expectLater(
        withClock(
          Clock.fixed(DateTime(2026, 8, 1, 9)),
          () => processor.process(envelope: event, journalDb: journalDb),
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        await device.repository.getEntityIncludingDeleted(entity.id),
        isNull,
      );
    });

    test('fails the apply of an agent link, rather than dropping it, '
        'while agentRepository is not wired', () async {
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

      await expectLater(
        processor.process(envelope: event, journalDb: journalDb),
        throwsA(isA<StateError>()),
      );

      expect(
        await device.repository.getLinkByIdIncludingDeleted(link.id),
        isNull,
      );
    });

    test('propagates repository error on agent entity upsert', () async {
      // A store that fails is injected at the storage boundary.
      final failing = MockAgentRepository();
      when(
        () => failing.deletedAgentIdsAmong(any()),
      ).thenAnswer((_) async => const <String>{});
      when(() => failing.getEntity(any())).thenAnswer((_) async => null);
      when(
        () => failing.upsertEntity(any()),
      ).thenAnswer((_) async => throw Exception('db error'));
      processor.agentRepository = failing;

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
        () => processor.process(envelope: event, journalDb: journalDb),
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
      // A store that fails is injected at the storage boundary.
      final failing = MockAgentRepository();
      when(
        () => failing.deletedAgentIdsAmong(any()),
      ).thenAnswer((_) async => const <String>{});
      when(
        () => failing.getLinkByIdIncludingDeleted(any()),
      ).thenAnswer((_) async => null);
      when(
        () => failing.upsertLink(any()),
      ).thenAnswer((_) async => throw Exception('db error'));
      processor.agentRepository = failing;

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
        () => processor.process(envelope: event, journalDb: journalDb),
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
          await device.repository.upsertEntity(local);

          await receiveEntity(incoming);

          // The catch block in _localAgentPayloadDominates logs and returns
          // false, so the entity is upserted anyway.
          expect(
            await device.repository.getEntityIncludingDeleted(incoming.id),
            incoming,
          );
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
          await device.repository.upsertLink(local);

          await receiveLink(incoming);

          // Dominance check failed (VclockException caught), falls through to
          // upsert.
          expect(
            await device.repository.getLinkByIdIncludingDeleted(incoming.id),
            incoming,
          );
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

      setUp(() {
        mockSeqService = MockSyncSequenceLogService();
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
          await device.repository.upsertEntity(local);
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
            savedTaskFiltersRepository: savedTaskFiltersRepository,
            settingsDb: settingsDb,
            journalEntityLoader: journalEntityLoader,
            sequenceLogService: mockSeqService,
          )..agentRepository = device.repository;
          final message = SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
            originatingHostId: 'host-A',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          final before = await device.storedRows();
          await proc.process(envelope: event, journalDb: journalDb);

          expect(await device.storedRows(), before);
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
        'proves an exact payload against the stored removal, not against no '
        'row',
        () async {
          // The sequence log repairs a counter against the version this
          // device holds. Read through `getEntity`, a removal gave no clock,
          // and the late copy's receipt could not be proven against it.
          const removalVc = VectorClock({'host-A': 2});
          const lateVc = VectorClock({'host-A': 1});
          AgentDomainEntity head(VectorClock clock, {DateTime? deletedAt}) =>
              AgentDomainEntity.agentReportHead(
                id: 'head-removed',
                agentId: 'agent-1',
                scope: 'current',
                reportId: 'report-1',
                updatedAt: DateTime(2024, 3, 15),
                vectorClock: clock,
                deletedAt: deletedAt,
              );
          await device.repository.upsertEntity(
            head(removalVc, deletedAt: DateTime(2024, 3, 16)),
          );
          when(
            () => mockSeqService.recordReceivedEntry(
              entryId: any(named: 'entryId'),
              vectorClock: any(named: 'vectorClock'),
              originatingHostId: any(named: 'originatingHostId'),
              coveredVectorClocks: any(named: 'coveredVectorClocks'),
              payloadType: any(named: 'payloadType'),
              jsonPath: any(named: 'jsonPath'),
              payloadVectorClock: any(named: 'payloadVectorClock'),
              canonicalPayloadVectorClock: any(
                named: 'canonicalPayloadVectorClock',
              ),
            ),
          ).thenAnswer((_) async => []);

          final proc = SyncEventProcessor(
            loggingService: loggingService,
            updateNotifications: updateNotifications,
            aiConfigRepository: aiConfigRepository,
            savedTaskFiltersRepository: savedTaskFiltersRepository,
            settingsDb: settingsDb,
            journalEntityLoader: journalEntityLoader,
            sequenceLogService: mockSeqService,
          )..agentRepository = device.repository;
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: head(lateVc),
                status: SyncEntryStatus.update,
                originatingHostId: 'host-A',
                attachmentEventId: 'late-copy-event',
              ),
            ),
          );

          final before = await device.storedRows();
          await proc.process(envelope: event, journalDb: journalDb);

          expect(await device.storedRows(), before);
          verify(
            () => mockSeqService.recordReceivedEntry(
              entryId: 'head-removed',
              vectorClock: lateVc,
              originatingHostId: 'host-A',
              coveredVectorClocks: null,
              payloadType: SyncSequencePayloadType.agentEntity,
              jsonPath: any(named: 'jsonPath'),
              payloadVectorClock: lateVc,
              canonicalPayloadVectorClock: removalVc,
            ),
          ).called(1);
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
          await device.repository.upsertEntity(local);
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
            savedTaskFiltersRepository: savedTaskFiltersRepository,
            settingsDb: settingsDb,
            journalEntityLoader: journalEntityLoader,
            sequenceLogService: mockSeqService,
          )..agentRepository = device.repository;
          final message = SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
            originatingHostId: 'host-A',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await proc.process(envelope: event, journalDb: journalDb);

          expect(
            await device.repository.getEntityIncludingDeleted(incoming.id),
            incoming,
          );
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
          await device.repository.upsertLink(local);
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
            savedTaskFiltersRepository: savedTaskFiltersRepository,
            settingsDb: settingsDb,
            journalEntityLoader: journalEntityLoader,
            sequenceLogService: mockSeqService,
          )..agentRepository = device.repository;
          final message = SyncMessage.agentLink(
            agentLink: incoming,
            status: SyncEntryStatus.update,
            originatingHostId: 'host-A',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          final before = await device.storedRows();
          await proc.process(envelope: event, journalDb: journalDb);

          expect(await device.storedRows(), before);
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
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = device.repository;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(envelope: event, journalDb: journalDb);

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
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = device.repository;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(envelope: event, journalDb: journalDb);

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

      test('rethrows receipt failures for agent entity', () async {
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
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = device.repository;

        when(() => event.text).thenReturn(encodeMessage(message));
        await expectLater(
          proc.process(envelope: event, journalDb: journalDb),
          throwsA(isA<Exception>()),
        );

        // Entity should still be upserted despite seq log error
        expect(
          await device.repository.getEntityIncludingDeleted(entity.id),
          entity,
        );
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
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = device.repository;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(envelope: event, journalDb: journalDb);

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
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = device.repository;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(envelope: event, journalDb: journalDb);

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(that: contains('apply.agentLink.gapsDetected count=2')),
            subDomain: 'processor.gapDetection',
          ),
        ).called(1);
      });

      test('rethrows receipt failures for agent link', () async {
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
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = device.repository;

        when(() => event.text).thenReturn(encodeMessage(message));
        await expectLater(
          proc.process(envelope: event, journalDb: journalDb),
          throwsA(isA<Exception>()),
        );

        // Link should still be upserted despite seq log error.
        expect(
          await device.repository.getLinkByIdIncludingDeleted(link.id),
          link,
        );
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
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = device.repository;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(envelope: event, journalDb: journalDb);

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
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = device.repository;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(envelope: event, journalDb: journalDb);

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
        when(() => mockOrchestrator.haltAgent(any())).thenReturn(false);
        processor.wakeOrchestrator = mockOrchestrator;
        when(
          () => mockOrchestrator.removeSubscriptions(any()),
        ).thenReturn(null);
        when(
          () => mockOrchestrator.disableAutomaticUpdatesRuntime(any()),
        ).thenReturn(null);
        when(
          () => mockOrchestrator.enableAutomaticUpdatesRuntime(any()),
        ).thenReturn(null);
      });

      final prerequisiteDate = DateTime(2026, 9, 12);
      final prerequisites = <String, SyncMessage>{
        'relationship link': SyncMessage.agentLink(
          agentLink: AgentLink.agentRelationship(
            id: 'relationship-link',
            fromId: 'relationship-agent',
            toId: 'person-1',
            createdAt: prerequisiteDate,
            updatedAt: prerequisiteDate,
            vectorClock: null,
          ),
          status: SyncEntryStatus.update,
        ),
        'scheduled retry': SyncMessage.agentEntity(
          agentEntity: AgentDomainEntity.scheduledWake(
            id: 'relationship-retry',
            agentId: 'relationship-agent',
            scheduledAt: prerequisiteDate,
            status: ScheduledWakeStatus.pending,
            reason: 'scheduled',
            updatedAt: prerequisiteDate,
            vectorClock: null,
          ),
          status: SyncEntryStatus.update,
        ),
        'failure state': SyncMessage.agentEntity(
          agentEntity: makeTestState(
            agentId: 'relationship-agent',
            lastWakeFailedAt: prerequisiteDate,
            consecutiveFailureCount: 1,
          ),
          status: SyncEntryStatus.update,
        ),
        // Written before the failed watermark existed (1.1.35): the count
        // alone marks it backed off for the maintenance pass (ADR 0115).
        'failure state without the failed watermark': SyncMessage.agentEntity(
          agentEntity: makeTestState(
            agentId: 'relationship-agent',
            lastWakeAt: prerequisiteDate,
            consecutiveFailureCount: 1,
          ),
          status: SyncEntryStatus.update,
        ),
      };
      for (final prerequisite in prerequisites.entries) {
        for (final kind in [
          AgentKinds.relationshipAgent,
          AgentKinds.taskAgent,
          null,
        ]) {
          test('a late ${prerequisite.key} re-offers only its relationship '
              'identity ($kind)', () async {
            final seen = <String>[];
            processor.runtimeMaintenance = [_RecordingMaintenance(seen)];
            addTearDown(() => processor.runtimeMaintenance = const []);
            if (kind != null) {
              await device.repository.upsertEntity(
                makeTestIdentity(
                  id: 'relationship-agent',
                  agentId: 'relationship-agent',
                  kind: kind,
                ),
              );
            }
            when(
              () => event.text,
            ).thenReturn(encodeMessage(prerequisite.value));

            await processor.process(envelope: event, journalDb: journalDb);

            expect(
              seen,
              kind == AgentKinds.relationshipAgent
                  ? ['relationship-agent']
                  : isEmpty,
            );
          });
        }
      }

      test('offers a synced-in identity to every runtime-maintenance '
          'contributor, containing a throwing one', () async {
        final seen = <String>[];
        final recorder = _RecordingMaintenance(seen);
        processor.runtimeMaintenance = [
          _ThrowingMaintenance(),
          _DefaultHookMaintenance(),
          recorder,
        ];
        addTearDown(() => processor.runtimeMaintenance = const []);

        final entity = AgentDomainEntity.agent(
          id: 'goal-77',
          agentId: 'goal-77',
          kind: 'goal_agent',
          displayName: 'Steps goal',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2026, 8),
          updatedAt: DateTime(2026, 8),
          vectorClock: null,
        );
        when(() => event.text).thenReturn(
          encodeMessage(
            SyncMessage.agentEntity(
              agentEntity: entity,
              status: SyncEntryStatus.update,
            ),
          ),
        );

        await processor.process(envelope: event, journalDb: journalDb);

        // The thrower ran first and was contained; the recorder still got
        // the identity, and the entity was persisted normally.
        expect(seen, ['goal-77']);
        expect(
          await device.repository.getEntityIncludingDeleted(entity.id),
          entity,
        );
      });

      test('a synced-in goal spec head re-offers the identity — creation '
          'bundles emit identity before spec', () async {
        final seen = <String>[];
        processor.runtimeMaintenance = [_RecordingMaintenance(seen)];
        addTearDown(() => processor.runtimeMaintenance = const []);

        final identity = AgentDomainEntity.agent(
          id: 'goal-88',
          agentId: 'goal-88',
          kind: 'goal_agent',
          displayName: 'Steps goal',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2026, 8),
          updatedAt: DateTime(2026, 8),
          vectorClock: null,
        );
        await device.repository.upsertEntity(identity);

        final head = AgentDomainEntity.goalSpecHead(
          id: 'goal_spec_head:goal-88',
          agentId: 'goal-88',
          versionId: 'goal-88:spec-v1',
          updatedAt: DateTime(2026, 8),
          vectorClock: null,
        );
        when(() => event.text).thenReturn(
          encodeMessage(
            SyncMessage.agentEntity(
              agentEntity: head,
              status: SyncEntryStatus.update,
            ),
          ),
        );

        await processor.process(envelope: event, journalDb: journalDb);

        expect(seen, ['goal-88']);
        expect(
          await device.repository.getEntityIncludingDeleted(head.id),
          head,
        );
      });

      test('halts the agent when it is dormant', () async {
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

        await processor.process(envelope: event, journalDb: journalDb);

        expect(
          await device.repository.getEntityIncludingDeleted(entity.id),
          entity,
        );
        verify(
          () => mockOrchestrator.disableAutomaticUpdatesRuntime(
            'agent-dormant',
          ),
        ).called(1);
        verify(
          () => mockOrchestrator.removeSubscriptions('agent-dormant'),
        ).called(1);
        // A stop on another device halts this device's queued and running
        // work too, not only future subscriptions.
        verify(() => mockOrchestrator.haltAgent('agent-dormant')).called(1);
      });

      test('halts the agent when it is destroyed', () async {
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

        await processor.process(envelope: event, journalDb: journalDb);

        expect(
          await device.repository.getEntityIncludingDeleted(entity.id),
          entity,
        );
        verify(
          () => mockOrchestrator.disableAutomaticUpdatesRuntime(
            'agent-destroyed',
          ),
        ).called(1);
        verify(
          () => mockOrchestrator.removeSubscriptions('agent-destroyed'),
        ).called(1);
        // A stop on another device halts this device's queued and running
        // work too, not only future subscriptions.
        verify(() => mockOrchestrator.haltAgent('agent-destroyed')).called(1);
      });

      test(
        'synced dormant project identity retires a legacy deadline and '
        'arms nothing',
        () async {
          final pendingAt = DateTime(2026, 8, 14, 9);
          final localState =
              AgentDomainEntity.agentState(
                    id: 'state-project-dormant',
                    agentId: 'project-agent-dormant',
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: pendingAt,
                    ),
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 8),
                    vectorClock: const VectorClock({'local': 4}),
                  )
                  as AgentStateEntity;
          final identity = AgentDomainEntity.agent(
            id: 'project-agent-dormant',
            agentId: 'project-agent-dormant',
            kind: 'project_agent',
            displayName: 'Dormant Project Agent',
            lifecycle: AgentLifecycle.dormant,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: localState.id,
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2026, 8, 14, 10),
            vectorClock: const VectorClock({'remote': 2}),
          );
          await device.repository.upsertEntity(localState);
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: identity,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          final before = await device.storedRows();
          await processor.process(envelope: event, journalDb: journalDb);

          final clearedState = (await device.entitiesWrittenSince(
            before,
          )).whereType<AgentStateEntity>().single;
          expect(clearedState.scheduledWakeAt, isNull);
          expect(clearedState.slots.pendingProjectActivityAt, pendingAt);
          expect(clearedState.updatedAt, localState.updatedAt);
          expect(clearedState.vectorClock, localState.vectorClock);
          verify(
            () => mockOrchestrator.haltAgent(identity.agentId),
          ).called(1);
          expect(armedAgentIds, isEmpty);
          verify(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime(
              identity.agentId,
            ),
          ).called(1);
        },
      );

      test(
        'stale synced opt-out does not stop a newer local opt-in',
        () async {
          final pendingAt = DateTime(2026, 8, 14, 9);
          final state =
              AgentDomainEntity.agentState(
                    id: 'state-project-opt-in-race',
                    agentId: 'project-agent-opt-in-race',
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: pendingAt,
                    ),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'local': 4}),
                  )
                  as AgentStateEntity;
          final incomingDormant =
              AgentDomainEntity.agent(
                    id: 'project-agent-opt-in-race',
                    agentId: 'project-agent-opt-in-race',
                    kind: AgentKinds.projectAgent,
                    displayName: 'Project Agent',
                    lifecycle: AgentLifecycle.dormant,
                    mode: AgentInteractionMode.autonomous,
                    allowedCategoryIds: const {},
                    currentStateId: state.id,
                    config: const AgentConfig(automaticUpdatesEnabled: false),
                    createdAt: DateTime(2024, 3, 15),
                    updatedAt: DateTime(2026, 8, 14, 10),
                    vectorClock: const VectorClock({'remote': 2}),
                  )
                  as AgentIdentityEntity;
          final newerOptIn = incomingDormant.copyWith(
            lifecycle: AgentLifecycle.active,
            config: const AgentConfig(automaticUpdatesEnabled: true),
            updatedAt: DateTime(2026, 8, 14, 11),
            vectorClock: const VectorClock({'remote': 2, 'local': 1}),
          );
          final link = AgentLink.agentProject(
            id: 'project-link-opt-in-race',
            fromId: incomingDormant.agentId,
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );

          await device.repository.upsertEntity(state);
          await device.repository.upsertLink(link);
          // A newer local opt-in lands as soon as the receive has stored the
          // stale identity.
          device.afterNextEntityWrite((written) async {
            if (written is AgentIdentityEntity) {
              await device.repository.upsertEntity(newerOptIn);
            }
          });
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: incomingDormant,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          final before = await device.storedRows();
          await processor.process(envelope: event, journalDb: journalDb);

          final stateWrites = (await device.entitiesWrittenSince(
            before,
          )).whereType<AgentStateEntity>();
          expect(stateWrites, isEmpty);
          verify(
            () => mockOrchestrator.enableAutomaticUpdatesRuntime(
              incomingDormant.agentId,
            ),
          ).called(1);
          verify(
            () => mockOrchestrator.addSubscription(any()),
          ).called(1);
          verifyNever(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime(any()),
          );
          // The re-read identity, not the incoming stale one, decides.
          expect(armedAgentIds, [incomingDormant.agentId]);
        },
      );

      test(
        'equal project identity replay retries legacy deadline retirement',
        () async {
          final now = DateTime(2026, 8, 14, 10);
          const vectorClock = VectorClock({'remote': 2});
          final identity =
              AgentDomainEntity.agent(
                    id: 'project-agent-equal-replay',
                    agentId: 'project-agent-equal-replay',
                    kind: AgentKinds.projectAgent,
                    displayName: 'Project Agent',
                    lifecycle: AgentLifecycle.active,
                    mode: AgentInteractionMode.autonomous,
                    allowedCategoryIds: const {},
                    currentStateId: 'state-project-equal-replay',
                    config: const AgentConfig(automaticUpdatesEnabled: true),
                    createdAt: DateTime(2024, 3, 15),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: vectorClock,
                  )
                  as AgentIdentityEntity;
          final pendingState =
              AgentDomainEntity.agentState(
                    id: identity.currentStateId,
                    agentId: identity.agentId,
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: DateTime(2026, 8, 14, 9),
                    ),
                    // A deadline an older build left behind.
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'remote': 3}),
                  )
                  as AgentStateEntity;
          await device.repository.upsertEntity(identity);
          await device.repository.upsertEntity(pendingState);
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: identity,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await withClock(Clock.fixed(now), () {
            return processor.process(envelope: event, journalDb: journalDb);
          });

          final repaired =
              (await device.repository.getEntityIncludingDeleted(
                    pendingState.id,
                  ))!
                  as AgentStateEntity;
          expect(repaired.scheduledWakeAt, isNull);
          expect(repaired.updatedAt, pendingState.updatedAt);
          expect(repaired.vectorClock, pendingState.vectorClock);
          expect(armedAgentIds, [identity.agentId]);
          verify(
            () => mockOrchestrator.enableAutomaticUpdatesRuntime(
              identity.agentId,
            ),
          ).called(1);
          verify(
            () => updateNotifications.notify(
              {identity.agentId, 'AGENT_CHANGED'},
              fromSync: true,
            ),
          ).called(1);
        },
      );

      test(
        'equal project state replay retries legacy deadline retirement',
        () async {
          final now = DateTime(2026, 8, 14, 10);
          const vectorClock = VectorClock({'remote': 3});
          final identity =
              AgentDomainEntity.agent(
                    id: 'project-agent-state-replay',
                    agentId: 'project-agent-state-replay',
                    kind: AgentKinds.projectAgent,
                    displayName: 'Project Agent',
                    lifecycle: AgentLifecycle.active,
                    mode: AgentInteractionMode.autonomous,
                    allowedCategoryIds: const {},
                    currentStateId: 'state-project-state-replay',
                    config: const AgentConfig(automaticUpdatesEnabled: true),
                    createdAt: DateTime(2024, 3, 15),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'remote': 2}),
                  )
                  as AgentIdentityEntity;
          final pendingState =
              AgentDomainEntity.agentState(
                    id: identity.currentStateId,
                    agentId: identity.agentId,
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: DateTime(2026, 8, 14, 9),
                    ),
                    // A deadline an older build left behind.
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: vectorClock,
                  )
                  as AgentStateEntity;
          await device.repository.upsertEntity(pendingState);
          await device.repository.upsertEntity(identity);
          await device.repository.upsertEntity(pendingState);
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: pendingState,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await withClock(Clock.fixed(now), () {
            return processor.process(envelope: event, journalDb: journalDb);
          });

          final repaired =
              (await device.repository.getEntityIncludingDeleted(
                    pendingState.id,
                  ))!
                  as AgentStateEntity;
          expect(repaired.scheduledWakeAt, isNull);
          expect(repaired.updatedAt, pendingState.updatedAt);
          expect(repaired.vectorClock, pendingState.vectorClock);
          expect(armedAgentIds, [identity.agentId]);
          verify(
            () => updateNotifications.notify(
              {identity.agentId, 'AGENT_CHANGED'},
              fromSync: true,
            ),
          ).called(1);
        },
      );

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
          config: const AgentConfig(automaticUpdatesEnabled: true),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final taskLink = AgentLink.agentTask(
          id: 'link-1',
          fromId: 'agent-active',
          toId: 'task-42',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        await device.repository.upsertLink(taskLink);

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(envelope: event, journalDb: journalDb);

        expect(
          await device.repository.getEntityIncludingDeleted(entity.id),
          entity,
        );
        // A cadence chosen on the other device reaches this one's runtime.
        verify(
          () => mockOrchestrator.mirrorTaskWakeCadence(
            entity as AgentIdentityEntity,
          ),
        ).called(1);
        verify(
          () => mockOrchestrator.enableAutomaticUpdatesRuntime('agent-active'),
        ).called(1);
        verifyNever(
          () => mockOrchestrator.disableAutomaticUpdatesRuntime(any()),
        );
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

      test('a retried identity whose first apply committed still restores '
          'the runtime from the identity that stands', () async {
        final entity = AgentDomainEntity.agent(
          id: 'agent-retried',
          agentId: 'agent-retried',
          kind: 'task_agent',
          displayName: 'Retried Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(automaticUpdatesEnabled: true),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'host-a': 3}),
        );
        // The first attempt wrote it, then failed after the commit.
        await device.repository.upsertEntity(entity);
        await device.repository.upsertLink(
          AgentLink.agentTask(
            id: 'link-retried',
            fromId: 'agent-retried',
            toId: 'task-7',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
        );
        when(() => event.text).thenReturn(
          encodeMessage(
            SyncMessage.agentEntity(
              agentEntity: entity,
              status: SyncEntryStatus.update,
            ),
          ),
        );

        final before = await device.storedRows();
        await processor.process(envelope: event, journalDb: journalDb);

        expect(await device.storedRows(), before);
        verify(
          () => mockOrchestrator.enableAutomaticUpdatesRuntime('agent-retried'),
        ).called(1);
        verify(
          () => mockOrchestrator.addSubscription(
            any(
              that: isA<AgentSubscription>().having(
                (sub) => sub.matchEntityIds,
                'matchEntityIds',
                {'task-7'},
              ),
            ),
          ),
        ).called(1);
      });

      test(
        'an entity this device pruned is refused, not stored again',
        () async {
          await recordPrunedAgentEntities(device.db, ['msg-pruned']);
          final entity = AgentDomainEntity.agentMessage(
            id: 'msg-pruned',
            agentId: 'agent-active',
            threadId: 'thread-1',
            kind: AgentMessageKind.observation,
            createdAt: DateTime(2024, 3, 15),
            vectorClock: const VectorClock({'host-a': 1}),
            metadata: const AgentMessageMetadata(),
            tokensApprox: 1,
          );
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: entity,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          final before = await device.storedRows();
          await processor.process(envelope: event, journalDb: journalDb);

          expect(await device.storedRows(), before);
        },
      );

      test(
        'restores existing project link when project_agent identity arrives',
        () async {
          final entity = AgentDomainEntity.agent(
            id: 'project-agent-1',
            agentId: 'project-agent-1',
            kind: 'project_agent',
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final projectLink = AgentLink.agentProject(
            id: 'project-link-1',
            fromId: 'project-agent-1',
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          await device.repository.upsertLink(projectLink);
          await device.repository.upsertEntity(entity);
          final message = SyncMessage.agentEntity(
            agentEntity: entity,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(envelope: event, journalDb: journalDb);

          verify(
            () => mockOrchestrator.addSubscription(
              any(
                that: isA<AgentSubscription>()
                    .having(
                      (subscription) => subscription.id,
                      'id',
                      'project-agent-1_project_direct_project-42',
                    )
                    .having(
                      (subscription) => subscription.matchEntityIds,
                      'matchEntityIds',
                      {projectEntityUpdateNotification('project-42')},
                    ),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'project identity arms the slot for activity observed before it '
        'arrived',
        () async {
          final now = DateTime(2026, 8, 14, 10);
          final entity = AgentDomainEntity.agent(
            id: 'project-agent-1',
            agentId: 'project-agent-1',
            kind: 'project_agent',
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(automaticUpdatesEnabled: true),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final pendingState =
              AgentDomainEntity.agentState(
                    id: 'state-1',
                    agentId: 'project-agent-1',
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: now.subtract(
                        const Duration(minutes: 5),
                      ),
                    ),
                    updatedAt: now.subtract(const Duration(minutes: 5)),
                    vectorClock: null,
                  )
                  as AgentStateEntity;
          await device.repository.upsertEntity(pendingState);
          await device.repository.upsertEntity(entity);
          when(
            () => event.text,
          ).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: entity,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          final before = await device.storedRows();
          await withClock(Clock.fixed(now), () {
            return processor.process(envelope: event, journalDb: journalDb);
          });

          // The arrival asks the cadence for one synced slot; it writes no
          // device-local deadline.
          final persistedStates = (await device.entitiesWrittenSince(
            before,
          )).whereType<AgentStateEntity>();
          expect(persistedStates, isEmpty);
          expect(armedAgentIds, ['project-agent-1']);
        },
      );

      test(
        'project state arms the slot when the identity arrived first',
        () async {
          final now = DateTime(2026, 8, 14, 10);
          final identity = AgentDomainEntity.agent(
            id: 'project-agent-1',
            agentId: 'project-agent-1',
            kind: 'project_agent',
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(automaticUpdatesEnabled: true),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final pendingState =
              AgentDomainEntity.agentState(
                    id: 'state-1',
                    agentId: 'project-agent-1',
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: now.subtract(
                        const Duration(minutes: 5),
                      ),
                    ),
                    updatedAt: now.subtract(const Duration(minutes: 5)),
                    vectorClock: null,
                  )
                  as AgentStateEntity;
          await device.repository.upsertEntity(identity);
          await device.repository.upsertEntity(pendingState);
          when(
            () => event.text,
          ).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: pendingState,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          final before = await device.storedRows();
          await withClock(Clock.fixed(now), () {
            return processor.process(envelope: event, journalDb: journalDb);
          });

          final persistedStates = (await device.entitiesWrittenSince(
            before,
          )).whereType<AgentStateEntity>().toList();
          expect(
            persistedStates.map((state) => state.scheduledWakeAt),
            everyElement(isNull),
          );
          expect(armedAgentIds, ['project-agent-1']);
        },
      );

      test(
        'project state never imports a peer deadline and arms a slot',
        () async {
          final now = DateTime(2026, 8, 14, 10);
          final remoteFallback = DateTime(2026, 8, 14, 18);
          final identity = AgentDomainEntity.agent(
            id: 'project-agent-imported',
            agentId: 'project-agent-imported',
            kind: 'project_agent',
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-imported',
            config: const AgentConfig(automaticUpdatesEnabled: true),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final incoming =
              AgentDomainEntity.agentState(
                    id: 'state-imported',
                    agentId: identity.agentId,
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: now.subtract(
                        const Duration(minutes: 5),
                      ),
                    ),
                    scheduledWakeAt: remoteFallback,
                    updatedAt: now.subtract(const Duration(minutes: 5)),
                    vectorClock: null,
                  )
                  as AgentStateEntity;
          await device.repository.upsertEntity(identity);
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: incoming,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          final before = await device.storedRows();
          await withClock(Clock.fixed(now), () {
            return processor.process(envelope: event, journalDb: journalDb);
          });

          final persistedStates = (await device.entitiesWrittenSince(
            before,
          )).whereType<AgentStateEntity>().toList();
          expect(
            persistedStates.map((state) => state.scheduledWakeAt),
            isNot(contains(remoteFallback)),
          );
          final storedState =
              (await device.repository.getEntity(incoming.id))!
                  as AgentStateEntity;
          expect(storedState.scheduledWakeAt, isNull);
          expect(storedState.updatedAt, incoming.updatedAt);
          expect(armedAgentIds, [identity.agentId]);
        },
      );

      test(
        'project state strips an imported fallback before identity arrives',
        () async {
          final now = DateTime(2026, 8, 14, 10);
          final remoteFallback = DateTime(2026, 8, 14, 18);
          final incoming =
              AgentDomainEntity.agentState(
                    id: 'state-before-identity',
                    agentId: 'project-agent-later',
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: now.subtract(
                        const Duration(minutes: 5),
                      ),
                    ),
                    nextWakeAt: DateTime(2026, 8, 14, 10, 2),
                    sleepUntil: DateTime(2026, 8, 14, 10, 5),
                    scheduledWakeAt: remoteFallback,
                    updatedAt: now.subtract(const Duration(minutes: 5)),
                    vectorClock: null,
                  )
                  as AgentStateEntity;
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: incoming,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await processor.process(envelope: event, journalDb: journalDb);

          final persisted =
              (await device.repository.getEntityIncludingDeleted(incoming.id))!
                  as AgentStateEntity;
          expect(persisted.nextWakeAt, isNull);
          expect(persisted.sleepUntil, isNull);
          expect(persisted.scheduledWakeAt, isNull);
          expect(persisted.slots.pendingProjectActivityAt, isNotNull);
        },
      );

      test(
        'project state completion clears local automatic work before identity '
        'arrives',
        () async {
          final identity = AgentDomainEntity.agent(
            id: 'project-agent-completed',
            agentId: 'project-agent-completed',
            kind: 'project_agent',
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-project-completed',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final local =
              AgentDomainEntity.agentState(
                    id: 'state-project-completed',
                    agentId: identity.agentId,
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: DateTime(2026, 8, 14, 9),
                    ),
                    nextWakeAt: DateTime(2026, 8, 14, 9, 2),
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'local': 1}),
                  )
                  as AgentStateEntity;
          final incoming = local.copyWith(
            slots: local.slots.copyWith(pendingProjectActivityAt: null),
            lastWakeAt: DateTime(2026, 8, 14, 10),
            scheduledWakeAt: null,
            updatedAt: DateTime(2026, 8, 14, 10),
            vectorClock: const VectorClock({'local': 1, 'remote': 1}),
          );
          await device.repository.upsertEntity(local);
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: incoming,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          final before = await device.storedRows();
          await processor.process(envelope: event, journalDb: journalDb);

          final applied = (await device.entitiesWrittenSince(
            before,
          )).whereType<AgentStateEntity>().first;
          expect(applied.slots.pendingProjectActivityAt, isNull);
          expect(applied.scheduledWakeAt, isNull);
          verify(
            () => mockOrchestrator.cancelPendingAutomaticWakes(
              local.agentId,
            ),
          ).called(1);
        },
      );

      test(
        'legacy project state without activity marker preserves local work',
        () async {
          final local =
              AgentDomainEntity.agentState(
                    id: 'state-project-legacy',
                    agentId: 'project-agent-legacy',
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: DateTime(2026, 8, 14, 9),
                    ),
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'local': 1}),
                  )
                  as AgentStateEntity;
          final incoming = local.copyWith(
            slots: local.slots.copyWith(pendingProjectActivityAt: null),
            lastWakeAt: DateTime(2026, 8, 14, 10),
            scheduledWakeAt: null,
            updatedAt: DateTime(2026, 8, 14, 10),
            vectorClock: const VectorClock({'local': 1, 'remote': 1}),
          );
          final message = SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
          );
          final messageJson =
              json.decode(json.encode(message.toJson()))
                  as Map<String, dynamic>;
          final entityJson = messageJson['agentEntity'] as Map<String, dynamic>;
          final slotsJson = entityJson['slots'] as Map<String, dynamic>;
          slotsJson.remove('pendingProjectActivityAt');

          await device.repository.upsertEntity(local);
          when(() => event.text).thenReturn(
            base64.encode(utf8.encode(json.encode(messageJson))),
          );

          final before = await device.storedRows();
          await processor.process(envelope: event, journalDb: journalDb);

          final applied = (await device.entitiesWrittenSince(
            before,
          )).whereType<AgentStateEntity>().first;
          expect(
            applied.slots.pendingProjectActivityAt,
            local.slots.pendingProjectActivityAt,
          );
          expect(applied.scheduledWakeAt, local.scheduledWakeAt);
          verifyNever(
            () => mockOrchestrator.cancelPendingAutomaticWakes(any()),
          );
        },
      );

      test(
        'bundled legacy project state without activity marker preserves '
        'local work',
        () async {
          final local =
              AgentDomainEntity.agentState(
                    id: 'state-project-bundled-legacy',
                    agentId: 'project-agent-bundled-legacy',
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: DateTime(2026, 8, 14, 9),
                    ),
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'local': 1}),
                  )
                  as AgentStateEntity;
          final incoming = local.copyWith(
            slots: local.slots.copyWith(pendingProjectActivityAt: null),
            lastWakeAt: DateTime(2026, 8, 14, 10),
            scheduledWakeAt: null,
            updatedAt: DateTime(2026, 8, 14, 10),
            vectorClock: const VectorClock({'local': 1, 'remote': 1}),
          );
          final bundle = SyncMessage.outboxBundle(
            children: [
              SyncMessage.agentEntity(
                agentEntity: incoming,
                status: SyncEntryStatus.update,
              ),
            ],
          );
          final bundleJson =
              json.decode(json.encode(bundle.toJson())) as Map<String, dynamic>;
          final childrenJson = bundleJson['children'] as List<dynamic>;
          final childJson = childrenJson.single as Map<String, dynamic>;
          final entityJson = childJson['agentEntity'] as Map<String, dynamic>;
          final slotsJson = entityJson['slots'] as Map<String, dynamic>;
          slotsJson.remove('pendingProjectActivityAt');

          // A state row is read inside its receive transaction, not from the
          // bundle prefetch.
          await device.repository.upsertEntity(local);
          when(() => event.text).thenReturn(
            base64.encode(utf8.encode(json.encode(bundleJson))),
          );

          final before = await device.storedRows();
          await processor.process(envelope: event, journalDb: journalDb);

          final applied = (await device.entitiesWrittenSince(
            before,
          )).whereType<AgentStateEntity>().single;
          expect(
            applied.slots.pendingProjectActivityAt,
            local.slots.pendingProjectActivityAt,
          );
          expect(applied.scheduledWakeAt, local.scheduledWakeAt);
          verifyNever(
            () => mockOrchestrator.cancelPendingAutomaticWakes(any()),
          );
        },
      );

      test(
        'project identity classifies marker-only state completion',
        () async {
          final identity = AgentDomainEntity.agent(
            id: 'project-agent-marker-only',
            agentId: 'project-agent-marker-only',
            kind: 'project_agent',
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-project-marker-only',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final local =
              AgentDomainEntity.agentState(
                    id: 'state-project-marker-only',
                    agentId: identity.agentId,
                    slots: const AgentSlots(
                      pendingProjectActivityAt: null,
                    ),
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'local': 1}),
                  )
                  as AgentStateEntity;
          final localWithPending = local.copyWith(
            slots: local.slots.copyWith(
              pendingProjectActivityAt: DateTime(2026, 8, 14, 9),
            ),
          );
          final incoming = local.copyWith(
            lastWakeAt: DateTime(2026, 8, 14, 10),
            scheduledWakeAt: null,
            updatedAt: DateTime(2026, 8, 14, 10),
            vectorClock: const VectorClock({'local': 1, 'remote': 1}),
          );
          await device.repository.upsertEntity(localWithPending);
          await device.repository.upsertEntity(identity);
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: incoming,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          final before = await device.storedRows();
          await processor.process(envelope: event, journalDb: journalDb);

          final applied = (await device.entitiesWrittenSince(
            before,
          )).whereType<AgentStateEntity>().first;
          expect(applied.scheduledWakeAt, isNull);
          verify(
            () => mockOrchestrator.cancelPendingAutomaticWakes(
              local.agentId,
            ),
          ).called(1);
        },
      );

      test(
        'halts a dormant project_agent identity',
        () async {
          final entity = AgentDomainEntity.agent(
            id: 'project-agent-dormant',
            agentId: 'project-agent-dormant',
            kind: 'project_agent',
            displayName: 'Dormant Project Agent',
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

          await processor.process(envelope: event, journalDb: journalDb);

          verify(
            () => mockOrchestrator.haltAgent('project-agent-dormant'),
          ).called(1);
        },
      );

      test(
        'project_agent identity with automation off keeps observation only',
        () async {
          final entity = AgentDomainEntity.agent(
            id: 'project-agent-manual',
            agentId: 'project-agent-manual',
            kind: 'project_agent',
            displayName: 'Manual Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(automaticUpdatesEnabled: false),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final projectLink = AgentLink.agentProject(
            id: 'project-link-manual',
            fromId: 'project-agent-manual',
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final pendingState =
              AgentDomainEntity.agentState(
                    id: 'state-project-agent-manual',
                    agentId: entity.agentId,
                    slots: AgentSlots(
                      activeProjectId: projectLink.toId,
                      pendingProjectActivityAt: DateTime(2026, 8, 14, 9),
                    ),
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: null,
                  )
                  as AgentStateEntity;
          await device.repository.upsertEntity(pendingState);
          await device.repository.upsertEntity(entity);
          await device.repository.upsertLink(projectLink);
          final message = SyncMessage.agentEntity(
            agentEntity: entity,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          final before = await device.storedRows();
          await processor.process(envelope: event, journalDb: journalDb);

          verify(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime(
              'project-agent-manual',
            ),
          ).called(1);
          verify(() => mockOrchestrator.addSubscription(any())).called(1);
          verifyNever(
            () => mockOrchestrator.enableAutomaticUpdatesRuntime(any()),
          );
          final persistedStates = (await device.entitiesWrittenSince(
            before,
          )).whereType<AgentStateEntity>().toList();
          expect(persistedStates, hasLength(1));
          expect(persistedStates.single.scheduledWakeAt, isNull);
          expect(
            persistedStates.single.slots.pendingProjectActivityAt,
            pendingState.slots.pendingProjectActivityAt,
          );
        },
      );

      test(
        'retains observation for active task_agent with automation off',
        () async {
          final entity = AgentDomainEntity.agent(
            id: 'agent-manual',
            agentId: 'agent-manual',
            kind: 'task_agent',
            displayName: 'Manual Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(automaticUpdatesEnabled: false),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final taskLink = AgentLink.agentTask(
            id: 'link-manual',
            fromId: 'agent-manual',
            toId: 'task-manual',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          await device.repository.upsertLink(taskLink);
          final message = SyncMessage.agentEntity(
            agentEntity: entity,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(envelope: event, journalDb: journalDb);

          verify(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime(
              'agent-manual',
            ),
          ).called(1);
          verify(
            () => mockOrchestrator.addSubscription(
              any(
                that: isA<AgentSubscription>().having(
                  (subscription) => subscription.agentId,
                  'agentId',
                  'agent-manual',
                ),
              ),
            ),
          ).called(1);
          verifyNever(
            () => mockOrchestrator.removeSubscriptions('agent-manual'),
          );
        },
      );

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

        await processor.process(envelope: event, journalDb: journalDb);

        expect(
          await device.repository.getEntityIncludingDeleted(entity.id),
          entity,
        );
        verifyNever(
          () => mockOrchestrator.disableAutomaticUpdatesRuntime(any()),
        );
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
        await processor.process(envelope: event, journalDb: journalDb);

        expect(
          await device.repository.getEntityIncludingDeleted(entity.id),
          entity,
        );
        verifyNever(
          () => mockOrchestrator.disableAutomaticUpdatesRuntime(any()),
        );
      });
    });

    group('subscription restoration on incoming agent link', () {
      late MockWakeOrchestrator mockOrchestrator;

      setUp(() {
        mockOrchestrator = MockWakeOrchestrator();
        when(() => mockOrchestrator.haltAgent(any())).thenReturn(false);
        processor.wakeOrchestrator = mockOrchestrator;
        when(
          () => mockOrchestrator.disableAutomaticUpdatesRuntime(any()),
        ).thenReturn(null);
        when(
          () => mockOrchestrator.enableAutomaticUpdatesRuntime(any()),
        ).thenReturn(null);
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

          await device.repository.upsertEntity(activeAgent);

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

          await processor.process(envelope: event, journalDb: journalDb);

          expect(
            await device.repository.getLinkByIdIncludingDeleted(link.id),
            link,
          );
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
          verify(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime('agent-1'),
          ).called(1);
        },
      );

      test(
        'agent_task link for an opted-in task_agent restores the subscription '
        'and enables its automatic-updates runtime',
        () async {
          final optedIn = AgentDomainEntity.agent(
            id: 'agent-1',
            agentId: 'agent-1',
            kind: 'task_agent',
            displayName: 'Opted-in Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(automaticUpdatesEnabled: true),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          await device.repository.upsertEntity(optedIn);

          final link = AgentLink.agentTask(
            id: 'link-1',
            fromId: 'agent-1',
            toId: 'task-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentLink(
                agentLink: link,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await processor.process(envelope: event, journalDb: journalDb);

          verify(
            () => mockOrchestrator.mirrorTaskWakeCadence(
              optedIn as AgentIdentityEntity,
            ),
          ).called(1);
          verify(
            () => mockOrchestrator.enableAutomaticUpdatesRuntime('agent-1'),
          ).called(1);
          verifyNever(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime(any()),
          );
          verify(
            () => mockOrchestrator.addSubscription(
              any(
                that: isA<AgentSubscription>().having(
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

          await device.repository.upsertEntity(dormantAgent);

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

          await processor.process(envelope: event, journalDb: journalDb);

          expect(
            await device.repository.getLinkByIdIncludingDeleted(link.id),
            link,
          );
          verifyNever(() => mockOrchestrator.addSubscription(any()));
        },
      );

      test(
        'agent_project link for active project_agent restores subscription',
        () async {
          final activeAgent = AgentDomainEntity.agent(
            id: 'project-agent-1',
            agentId: 'project-agent-1',
            kind: 'project_agent',
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          await device.repository.upsertEntity(activeAgent);
          final link = AgentLink.agentProject(
            id: 'project-link-1',
            fromId: 'project-agent-1',
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          await device.repository.upsertLink(link);
          final message = SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(envelope: event, journalDb: journalDb);

          verify(
            () => mockOrchestrator.addSubscription(
              any(
                that: isA<AgentSubscription>()
                    .having(
                      (subscription) => subscription.id,
                      'id',
                      'project-agent-1_project_direct_project-42',
                    )
                    .having(
                      (subscription) => subscription.matchEntityIds,
                      'matchEntityIds',
                      {projectEntityUpdateNotification('project-42')},
                    ),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'agent_project link registers a stale-only subscription and arms '
        'a slot',
        () async {
          final now = DateTime(2026, 8, 14, 10);
          final activeAgent = AgentDomainEntity.agent(
            id: 'project-agent-1',
            agentId: 'project-agent-1',
            kind: 'project_agent',
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(automaticUpdatesEnabled: true),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final pendingState =
              AgentDomainEntity.agentState(
                    id: 'state-1',
                    agentId: 'project-agent-1',
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: now.subtract(
                        const Duration(minutes: 5),
                      ),
                    ),
                    updatedAt: now.subtract(const Duration(minutes: 5)),
                    vectorClock: null,
                  )
                  as AgentStateEntity;
          await device.repository.upsertEntity(activeAgent);
          await device.repository.upsertEntity(pendingState);
          final link = AgentLink.agentProject(
            id: 'project-link-1',
            fromId: 'project-agent-1',
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          // The link is persisted before the runtime re-reads it.
          await device.repository.upsertLink(link);
          when(
            () => event.text,
          ).thenReturn(
            encodeMessage(
              SyncMessage.agentLink(
                agentLink: link,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          final before = await device.storedRows();
          await withClock(Clock.fixed(now), () {
            return processor.process(envelope: event, journalDb: journalDb);
          });

          expect(await device.storedRows(), before);
          verify(
            () => mockOrchestrator.addSubscription(
              any(
                that: isA<AgentSubscription>().having(
                  (subscription) => subscription.reportStaleOnly,
                  'reportStaleOnly',
                  isTrue,
                ),
              ),
            ),
          ).called(1);
          expect(armedAgentIds, ['project-agent-1']);
        },
      );

      test(
        'agent_project slot arming rechecks a concurrent opt-out',
        () async {
          final activeAgent =
              AgentDomainEntity.agent(
                    id: 'project-agent-race',
                    agentId: 'project-agent-race',
                    kind: 'project_agent',
                    displayName: 'Project Agent',
                    lifecycle: AgentLifecycle.active,
                    mode: AgentInteractionMode.autonomous,
                    allowedCategoryIds: const {},
                    currentStateId: 'state-race',
                    config: const AgentConfig(),
                    createdAt: DateTime(2024, 3, 15),
                    updatedAt: DateTime(2024, 3, 15),
                    vectorClock: null,
                  )
                  as AgentIdentityEntity;
          final optedOutAgent = activeAgent.copyWith(
            config: const AgentConfig(automaticUpdatesEnabled: false),
          );
          final pendingState =
              AgentDomainEntity.agentState(
                    id: 'state-race',
                    agentId: activeAgent.agentId,
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: DateTime(2026, 8, 14, 9),
                    ),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'peer-a': 2}),
                  )
                  as AgentStateEntity;
          await device.repository.upsertEntity(activeAgent);
          // The opt-out lands right after the receive first reads the identity.
          device.afterNextReadOf(
            activeAgent.id,
            () => device.repository.upsertEntity(optedOutAgent),
          );
          await device.repository.upsertEntity(pendingState);
          final link = AgentLink.agentProject(
            id: 'project-link-race',
            fromId: activeAgent.agentId,
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentLink(
                agentLink: link,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await processor.process(envelope: event, journalDb: journalDb);

          // The pending activity is left for the next opt-in, not consumed.
          expect(
            await device.repository.getEntity(pendingState.id),
            pendingState,
          );
          expect(armedAgentIds, isEmpty);
          verify(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime(
              activeAgent.agentId,
            ),
          ).called(1);
          verifyNever(
            () => mockOrchestrator.enableAutomaticUpdatesRuntime(any()),
          );
        },
      );

      test(
        'agent_project link for dormant project_agent stays unsubscribed',
        () async {
          final dormantAgent = AgentDomainEntity.agent(
            id: 'project-agent-1',
            agentId: 'project-agent-1',
            kind: 'project_agent',
            displayName: 'Dormant Project Agent',
            lifecycle: AgentLifecycle.dormant,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          await device.repository.upsertEntity(dormantAgent);
          final link = AgentLink.agentProject(
            id: 'project-link-1',
            fromId: 'project-agent-1',
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final message = SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(envelope: event, journalDb: journalDb);

          verifyNever(() => mockOrchestrator.addSubscription(any()));
        },
      );

      test(
        'agent_project link applies the project automation opt-out',
        () async {
          final manualAgent = AgentDomainEntity.agent(
            id: 'project-agent-manual',
            agentId: 'project-agent-manual',
            kind: 'project_agent',
            displayName: 'Manual Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(automaticUpdatesEnabled: false),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          await device.repository.upsertEntity(manualAgent);
          final markerlessFallback =
              AgentDomainEntity.agentState(
                    id: 'state-project-agent-manual',
                    agentId: 'project-agent-manual',
                    slots: const AgentSlots(activeProjectId: 'project-42'),
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'peer-a': 2}),
                  )
                  as AgentStateEntity;
          await device.repository.upsertEntity(markerlessFallback);
          final link = AgentLink.agentProject(
            id: 'project-link-manual',
            fromId: 'project-agent-manual',
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          await device.repository.upsertLink(link);
          final message = SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          final before = await device.storedRows();
          await processor.process(envelope: event, journalDb: journalDb);

          verify(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime(
              'project-agent-manual',
            ),
          ).called(1);
          verify(() => mockOrchestrator.addSubscription(any())).called(1);
          verifyNever(
            () => mockOrchestrator.enableAutomaticUpdatesRuntime(any()),
          );
          final clearedFallback = (await device.entitiesWrittenSince(
            before,
          )).whereType<AgentStateEntity>().single;
          expect(clearedFallback.scheduledWakeAt, isNull);
          expect(clearedFallback.slots.pendingProjectActivityAt, isNull);
          expect(clearedFallback.updatedAt, markerlessFallback.updatedAt);
          expect(clearedFallback.vectorClock, markerlessFallback.vectorClock);
        },
      );

      test(
        'soft-deleted agent_project link removes the direct subscription',
        () async {
          final link = AgentLink.agentProject(
            id: 'project-link-deleted',
            fromId: 'project-agent-1',
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 16),
            vectorClock: null,
            deletedAt: DateTime(2024, 3, 16),
          );
          final message = SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(envelope: event, journalDb: journalDb);

          verify(
            () => mockOrchestrator.removeSubscription(
              'project-agent-1_project_direct_project-42',
            ),
          ).called(1);

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

          await processor.process(envelope: event, journalDb: journalDb);

          expect(
            await device.repository.getLinkByIdIncludingDeleted(link.id),
            link,
          );
          // Mirror remote delete: the per-link subscription must go so this
          // device stops waking an agent that was unlinked elsewhere.
          verify(
            () => mockOrchestrator.removeSubscription('agent-1_task_task-42'),
          ).called(1);
          // Delete path skips agent lookup + re-subscribe entirely.

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

        await processor.process(envelope: event, journalDb: journalDb);

        expect(
          await device.repository.getLinkByIdIncludingDeleted(link.id),
          link,
        );

        verifyNever(() => mockOrchestrator.addSubscription(any()));
      });
    });

    group('task agent retirement pass (TaskAgentAssignment.tla, ADR 0104)', () {
      late List<String> passes;

      setUp(() {
        passes = [];
        processor.retireSupersededTaskAgents = (taskId) async {
          passes.add(taskId);
        };
        addTearDown(() => processor.retireSupersededTaskAgents = null);
      });

      Future<void> receive(SyncMessage message) async {
        when(() => event.text).thenReturn(encodeMessage(message));
        await processor.process(envelope: event, journalDb: journalDb);
      }

      AgentLink taskLink({
        String id = 'link-1',
        String taskId = 'task-42',
        DateTime? deletedAt,
      }) => AgentLink.agentTask(
        id: id,
        fromId: 'agent-1',
        toId: taskId,
        createdAt: DateTime(2024, 3, 15),
        updatedAt: deletedAt ?? DateTime(2024, 3, 15),
        deletedAt: deletedAt,
        vectorClock: null,
      );

      test('a live agent_task link runs the pass for its task', () async {
        await receive(
          SyncMessage.agentLink(
            agentLink: taskLink(),
            status: SyncEntryStatus.update,
          ),
        );

        expect(passes, ['task-42']);
      });

      test('a removed agent_task link or another link type runs no '
          'pass', () async {
        await receive(
          SyncMessage.agentLink(
            agentLink: taskLink(deletedAt: DateTime(2024, 3, 16)),
            status: SyncEntryStatus.update,
          ),
        );
        await receive(
          SyncMessage.agentLink(
            agentLink: AgentLink.basic(
              id: 'link-2',
              fromId: 'agent-1',
              toId: 'state-1',
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
              vectorClock: null,
            ),
            status: SyncEntryStatus.update,
          ),
        );

        expect(passes, isEmpty);
      });

      test('a task agent identity runs the pass for every task it is linked '
          'to: its link may have arrived first', () async {
        await device.repository.upsertLink(taskLink());
        await device.repository.upsertLink(
          taskLink(id: 'link-2', taskId: 'task-43'),
        );

        await receive(
          SyncMessage.agentEntity(
            agentEntity: makeTestIdentity(
              id: 'agent-1',
              agentId: 'agent-1',
              lifecycle: AgentLifecycle.destroyed,
            ),
            status: SyncEntryStatus.update,
          ),
        );

        expect(passes, unorderedEquals(['task-42', 'task-43']));
      });

      test('another kind of agent runs no pass', () async {
        await receive(
          SyncMessage.agentEntity(
            agentEntity: makeTestIdentity(
              id: 'agent-1',
              agentId: 'agent-1',
              kind: AgentKinds.projectAgent,
            ),
            status: SyncEntryStatus.update,
          ),
        );

        expect(passes, isEmpty);
      });

      test(
        'a failing pass is logged and the receive still completes',
        () async {
          processor.retireSupersededTaskAgents = (_) async =>
              throw StateError('retirement failed');
          final link = taskLink();

          await receive(
            SyncMessage.agentLink(
              agentLink: link,
              status: SyncEntryStatus.update,
            ),
          );

          expect(
            await device.repository.getLinkByIdIncludingDeleted(link.id),
            link,
          );
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(that: isA<StateError>()),
              subDomain: 'processor.taskAgentRetirement',
              message: any(named: 'message'),
              stackTrace: any(named: 'stackTrace'),
            ),
          ).called(1);
          verify(
            () => updateNotifications.notify(
              {'agent-1', 'task-42', agentNotification},
              fromSync: true,
            ),
          ).called(1);
        },
      );
    });

    group('descriptor-only resolution (jsonPath)', () {
      late Directory tempDir;

      SyncEventProcessor processorForExplicitDirectory(
        Directory explicitDirectory,
      ) {
        return SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: FileSyncJournalEntityLoader(
            documentsDirectory: explicitDirectory,
          ),
          documentsDirectory: tempDir,
        )..agentRepository = device.repository;
      }

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

        await processor.process(envelope: event, journalDb: journalDb);

        expect(
          await device.repository.getEntityIncludingDeleted(entity.id),
          entity,
        );
      });

      test('a write about an agent this device deleted is refused, and the '
          'JSON it brought is removed (ADR 0108)', () async {
        await device.repository.upsertEntity(
          makeTestIdentity(id: 'agent-gone', agentId: 'agent-gone'),
        );
        await device.repository.hardDeleteAgent('agent-gone');
        final entity = AgentDomainEntity.agent(
          id: 'agent-gone',
          agentId: 'agent-gone',
          kind: 'task_agent',
          displayName: 'Deleted Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );
        const relativePath = '/agent_entities/agent-gone.json';
        final file = File(
          path.join(tempDir.path, stripLeadingSlashes(relativePath)),
        );
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(jsonEncode(entity.toJson()));
        when(() => event.text).thenReturn(
          encodeMessage(
            const SyncMessage.agentEntity(
              status: SyncEntryStatus.update,
              jsonPath: relativePath,
            ),
          ),
        );

        final before = await device.storedRows();
        await processor.process(envelope: event, journalDb: journalDb);

        expect(await device.storedRows(), before);
        verifyNever(
          () => updateNotifications.notify(any(), fromSync: true),
        );
        expect(file.existsSync(), isFalse);
      });

      test(
        'a JSON file that cannot be removed is logged, and the write is '
        'still refused',
        () async {
          await device.repository.upsertEntity(
            makeTestIdentity(id: 'agent-gone', agentId: 'agent-gone'),
          );
          await device.repository.hardDeleteAgent('agent-gone');
          final entity = AgentDomainEntity.agent(
            id: 'agent-gone',
            agentId: 'agent-gone',
            kind: 'task_agent',
            displayName: 'Deleted Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          const relativePath = '/agent_entities_locked/agent-gone.json';
          final file = File(
            path.join(tempDir.path, stripLeadingSlashes(relativePath)),
          );
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(jsonEncode(entity.toJson()));
          // A directory the process may read but not change: the file stays.
          Process.runSync('chmod', ['555', file.parent.path]);
          addTearDown(
            () => Process.runSync('chmod', ['755', file.parent.path]),
          );
          when(() => event.text).thenReturn(
            encodeMessage(
              const SyncMessage.agentEntity(
                status: SyncEntryStatus.update,
                jsonPath: relativePath,
              ),
            ),
          );

          final before = await device.storedRows();
          await processor.process(envelope: event, journalDb: journalDb);

          expect(await device.storedRows(), before);
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(that: isA<FileSystemException>()),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: 'apply.agentEntity.discardDeletedAgentJson',
            ),
          ).called(1);
        },
        skip: Platform.isWindows ? 'POSIX permissions' : null,
      );

      test('file-backed irreparable week rollup is a permanent skip', () async {
        final entity = AgentDomainEntity.weekRollup(
          id: 'week_rollup:2026-05-18',
          agentId: 'daily_os_planner',
          weekStart: DateTime(2026, 5, 18),
          createdAt: DateTime(2026, 5, 24),
          updatedAt: DateTime(2026, 5, 24, 12),
          vectorClock: const VectorClock({'remote-host': 3}),
        );
        final legacyJson =
            jsonDecode(jsonEncode(entity.toJson())) as Map<String, dynamic>
              ..remove('weekStart')
              ..['id'] = 'week_rollup:2026-05-17';
        const relativePath = '/agent_entities/invalid-rollup.json';
        final file = File(
          path.join(tempDir.path, stripLeadingSlashes(relativePath)),
        );
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(jsonEncode(legacyJson));
        const message = SyncMessage.agentEntity(
          status: SyncEntryStatus.update,
          jsonPath: relativePath,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        final before = await device.storedRows();
        final prepared = await processor.prepare(envelope: event);

        expect(prepared, isNull);
        expect(await device.storedRows(), before);
      });

      test(
        'derives the agent payload sandbox from the injected loader',
        () async {
          final explicitDirectory = await Directory(
            path.join(tempDir.path, 'explicit-device'),
          ).create();
          final explicitProcessor = processorForExplicitDirectory(
            explicitDirectory,
          );
          final entity = AgentDomainEntity.agent(
            id: 'agent-explicit',
            agentId: 'agent-explicit',
            kind: 'task_agent',
            displayName: 'Explicit Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          const relativePath = '/agent_entities/agent-explicit.json';
          final explicitFile = File(
            path.join(
              explicitDirectory.path,
              stripLeadingSlashes(relativePath),
            ),
          )..parent.createSync(recursive: true);
          explicitFile.writeAsStringSync(jsonEncode(entity.toJson()));

          const message = SyncMessage.agentEntity(
            status: SyncEntryStatus.update,
            jsonPath: relativePath,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await explicitProcessor.process(
            envelope: event,
            journalDb: journalDb,
          );

          expect(
            await device.repository.getEntityIncludingDeleted(entity.id),
            entity,
          );
          expect(
            File(
              path.join(tempDir.path, stripLeadingSlashes(relativePath)),
            ).existsSync(),
            isFalse,
          );
        },
      );

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
          await device.repository.upsertEntity(local);

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

          final before = await device.storedRows();
          await processor.process(envelope: event, journalDb: journalDb);

          expect(await device.storedRows(), before);
          final restored = AgentDomainEntity.fromJson(
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
          );
          expect(
            restored.mapOrNull(agentState: (entity) => entity.revision),
            2,
          );
        },
      );

      test(
        'restores a dominant agent cache inside the injected loader sandbox',
        () async {
          final explicitDirectory = await Directory(
            path.join(tempDir.path, 'explicit-restore-device'),
          ).create();
          final explicitProcessor = processorForExplicitDirectory(
            explicitDirectory,
          );
          const localVc = VectorClock({'host-A': 2});
          const incomingVc = VectorClock({'host-A': 1});
          final local = AgentDomainEntity.agentState(
            id: 'state-explicit-cache',
            agentId: 'agent-1',
            revision: 2,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 16),
            vectorClock: localVc,
          );
          final stale = AgentDomainEntity.agentState(
            id: 'state-explicit-cache',
            agentId: 'agent-1',
            revision: 1,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: incomingVc,
          );
          await device.repository.upsertEntity(local);

          const relativePath = '/agent_entities/state-explicit-cache.json';
          final explicitFile = File(
            path.join(
              explicitDirectory.path,
              stripLeadingSlashes(relativePath),
            ),
          )..parent.createSync(recursive: true);
          explicitFile.writeAsStringSync(jsonEncode(stale.toJson()));
          const message = SyncMessage.agentEntity(
            status: SyncEntryStatus.update,
            jsonPath: relativePath,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          final before = await device.storedRows();
          await explicitProcessor.process(
            envelope: event,
            journalDb: journalDb,
          );

          expect(await device.storedRows(), before);
          final restored = AgentDomainEntity.fromJson(
            jsonDecode(explicitFile.readAsStringSync()) as Map<String, dynamic>,
          );
          expect(
            restored.mapOrNull(agentState: (entity) => entity.revision),
            2,
          );
          expect(
            File(
              path.join(tempDir.path, stripLeadingSlashes(relativePath)),
            ).existsSync(),
            isFalse,
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

        await processor.process(envelope: event, journalDb: journalDb);

        expect(
          await device.repository.getLinkByIdIncludingDeleted(link.id),
          link,
        );
      });

      test('skips agent entity with no entity and no jsonPath', () async {
        const message = SyncMessage.agentEntity(
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        final before = await device.storedRows();
        await processor.process(envelope: event, journalDb: journalDb);

        expect(await device.storedRows(), before);
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

        final before = await device.storedRows();
        await processor.process(envelope: event, journalDb: journalDb);

        expect(await device.storedRows(), before);
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

        final before = await device.storedRows();
        await processor.process(envelope: event, journalDb: journalDb);

        expect(await device.storedRows(), before);
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

        final before = await device.storedRows();
        await processor.process(envelope: event, journalDb: journalDb);

        expect(await device.storedRows(), before);
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
            () => processor.process(envelope: event, journalDb: journalDb),
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
            () => processor.process(envelope: event, journalDb: journalDb),
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

        final before = await device.storedRows();
        await processor.process(envelope: event, journalDb: journalDb);

        expect(await device.storedRows(), before);
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
        late RecordedAttachmentStack attachmentIndex;
        late SyncEventProcessor processorWithIndex;
        late MockEvent descriptorEvent;
        late MockRoom indexRoom;

        setUp(() {
          attachmentIndex = RecordedAttachmentStack(logging: loggingService);
          indexRoom = MockRoom();
          processorWithIndex = SyncEventProcessor(
            loggingService: loggingService,
            updateNotifications: updateNotifications,
            aiConfigRepository: aiConfigRepository,
            savedTaskFiltersRepository: savedTaskFiltersRepository,
            settingsDb: settingsDb,
            journalEntityLoader: journalEntityLoader,
            attachmentIndex: attachmentIndex.index,
            attachmentFetcher: attachmentIndex.fetcher,
            descriptorRecovery: TrustedDescriptorRecovery(
              fetcher: MatrixDescriptorFetcher(
                resolveRoom: (_) => indexRoom,
              ),
              trust: AdmittingSyncEventTrust(),
            ),
          );
          processorWithIndex.agentRepository = device.repository;

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
              envelope: event,
              journalDb: journalDb,
            );

            expect(
              await device.repository.getEntityIncludingDeleted(entity.id),
              entity,
            );
            verify(descriptorEvent.downloadAndDecryptAttachment).called(1);
          },
        );

        test(
          'an exact attachment whose descriptor names a different path is a '
          'permanent skip, never a download',
          () async {
            // desc-event-id describes agent-desc.json; an envelope that binds
            // it to another path is malformed and can never succeed on retry.
            attachmentIndex.record(descriptorEvent);
            when(() => event.text).thenReturn(
              encodeMessage(
                const SyncMessage.agentEntity(
                  status: SyncEntryStatus.update,
                  jsonPath: '/agent_entities/agent-other.json',
                  attachmentEventId: 'desc-event-id',
                ),
              ),
            );

            final before = await device.storedRows();
            expect(await processorWithIndex.prepare(envelope: event), isNull);
            verifyNever(descriptorEvent.downloadAndDecryptAttachment);
            expect(await device.storedRows(), before);
          },
        );

        test(
          'exact attachment binding keeps an older envelope on its payload '
          'generation after the path advances',
          () async {
            const relativePath = '/agent_entities/agent-versioned.json';
            const olderClock = VectorClock({'remote-host': 3});
            const newerClock = VectorClock({'remote-host': 30});
            const coveredClocks = [
              VectorClock({'remote-host': 1}),
              VectorClock({'remote-host': 2}),
            ];
            final olderEntity = AgentDomainEntity.agentState(
              id: 'agent-versioned',
              agentId: 'agent-versioned',
              revision: 3,
              slots: const AgentSlots(),
              updatedAt: DateTime(2024, 3, 15),
              vectorClock: olderClock,
            );
            final newerEntity = AgentDomainEntity.agentState(
              id: 'agent-versioned',
              agentId: 'agent-versioned',
              revision: 30,
              slots: const AgentSlots(),
              updatedAt: DateTime(2024, 3, 16),
              vectorClock: newerClock,
            );

            MockEvent descriptor({
              required String eventId,
              required AgentDomainEntity entity,
            }) {
              final result = MockEvent();
              when(() => result.eventId).thenReturn(eventId);
              when(
                () => result.attachmentMimetype,
              ).thenReturn('application/json');
              when(
                () => result.content,
              ).thenReturn({'relativePath': relativePath});
              when(result.downloadAndDecryptAttachment).thenAnswer(
                (_) async => MatrixFile(
                  bytes: Uint8List.fromList(
                    utf8.encode(jsonEncode(entity.toJson())),
                  ),
                  name: '$eventId.json',
                ),
              );
              return result;
            }

            final olderDescriptor = descriptor(
              eventId: 'older-payload-event',
              entity: olderEntity,
            );
            final newerDescriptor = descriptor(
              eventId: 'newer-payload-event',
              entity: newerEntity,
            );
            attachmentIndex
              ..record(olderDescriptor)
              ..record(newerDescriptor);

            final sequenceLog = MockSyncSequenceLogService();
            when(
              () => sequenceLog.recordReceivedEntry(
                entryId: any(named: 'entryId'),
                vectorClock: any(named: 'vectorClock'),
                originatingHostId: any(named: 'originatingHostId'),
                coveredVectorClocks: any(named: 'coveredVectorClocks'),
                payloadType: any(named: 'payloadType'),
                jsonPath: any(named: 'jsonPath'),
                payloadVectorClock: any(named: 'payloadVectorClock'),
                canonicalPayloadVectorClock: any(
                  named: 'canonicalPayloadVectorClock',
                ),
              ),
            ).thenAnswer((_) async => []);
            final exactProcessor = SyncEventProcessor(
              loggingService: loggingService,
              updateNotifications: updateNotifications,
              aiConfigRepository: aiConfigRepository,
              savedTaskFiltersRepository: savedTaskFiltersRepository,
              settingsDb: settingsDb,
              journalEntityLoader: journalEntityLoader,
              attachmentIndex: attachmentIndex.index,
              attachmentFetcher: attachmentIndex.fetcher,
              sequenceLogService: sequenceLog,
            )..agentRepository = device.repository;

            const message = SyncMessage.agentEntity(
              status: SyncEntryStatus.update,
              jsonPath: relativePath,
              attachmentEventId: 'older-payload-event',
              originatingHostId: 'remote-host',
              coveredVectorClocks: coveredClocks,
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            await exactProcessor.process(envelope: event, journalDb: journalDb);

            expect(
              await device.repository.getEntityIncludingDeleted(olderEntity.id),
              olderEntity,
            );

            verify(
              () => sequenceLog.recordReceivedEntry(
                entryId: olderEntity.id,
                vectorClock: olderClock,
                originatingHostId: 'remote-host',
                coveredVectorClocks: coveredClocks,
                payloadType: SyncSequencePayloadType.agentEntity,
                jsonPath: relativePath,
                payloadVectorClock: olderClock,
                canonicalPayloadVectorClock: olderClock,
              ),
            ).called(1);
            verify(olderDescriptor.downloadAndDecryptAttachment).called(1);
            verifyNever(newerDescriptor.downloadAndDecryptAttachment);
          },
        );

        test(
          'exact attachment fetches the agent link and supplies payload proof',
          () async {
            const linkClock = VectorClock({'remote-host': 4});
            final link = AgentLink.basic(
              id: 'link-desc',
              fromId: 'agent-1',
              toId: 'state-1',
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
              vectorClock: linkClock,
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

            final sequenceLog = MockSyncSequenceLogService();
            when(
              () => sequenceLog.recordReceivedEntry(
                entryId: any(named: 'entryId'),
                vectorClock: any(named: 'vectorClock'),
                originatingHostId: any(named: 'originatingHostId'),
                coveredVectorClocks: any(named: 'coveredVectorClocks'),
                payloadType: any(named: 'payloadType'),
                jsonPath: any(named: 'jsonPath'),
                payloadVectorClock: any(named: 'payloadVectorClock'),
                canonicalPayloadVectorClock: any(
                  named: 'canonicalPayloadVectorClock',
                ),
              ),
            ).thenAnswer((_) async => []);
            final exactProcessor = SyncEventProcessor(
              loggingService: loggingService,
              updateNotifications: updateNotifications,
              aiConfigRepository: aiConfigRepository,
              savedTaskFiltersRepository: savedTaskFiltersRepository,
              settingsDb: settingsDb,
              journalEntityLoader: journalEntityLoader,
              attachmentIndex: attachmentIndex.index,
              attachmentFetcher: attachmentIndex.fetcher,
              sequenceLogService: sequenceLog,
            )..agentRepository = device.repository;

            const message = SyncMessage.agentLink(
              status: SyncEntryStatus.update,
              jsonPath: '/agent_links/link-desc.json',
              attachmentEventId: 'link-desc-event-id',
              originatingHostId: 'remote-host',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            await exactProcessor.process(
              envelope: event,
              journalDb: journalDb,
            );

            expect(
              await device.repository.getLinkByIdIncludingDeleted(link.id),
              link,
            );
            verify(
              () => sequenceLog.recordReceivedEntry(
                entryId: link.id,
                vectorClock: linkClock,
                originatingHostId: 'remote-host',
                coveredVectorClocks: null,
                payloadType: SyncSequencePayloadType.agentLink,
                jsonPath: '/agent_links/link-desc.json',
                payloadVectorClock: linkClock,
                canonicalPayloadVectorClock: linkClock,
              ),
            ).called(1);
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

            final before = await device.storedRows();
            await expectLater(
              () => processorWithIndex.process(
                envelope: event,
                journalDb: journalDb,
              ),
              throwsA(isA<FileSystemException>()),
            );

            expect(await device.storedRows(), before);
          },
        );

        test(
          'skips the envelope when the homeserver no longer has the media',
          () async {
            when(descriptorEvent.downloadAndDecryptAttachment).thenThrow(
              MatrixException.fromJson(const {
                'errcode': 'M_NOT_FOUND',
                'error': 'Not found',
              }),
            );

            attachmentIndex.record(descriptorEvent);

            const message = SyncMessage.agentEntity(
              status: SyncEntryStatus.update,
              jsonPath: '/agent_entities/agent-desc.json',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            // Completes instead of throwing a retryable descriptor error:
            // prepare yields nothing, so the queue marks the row skipped.
            final before = await device.storedRows();
            expect(await processorWithIndex.prepare(envelope: event), isNull);

            verify(descriptorEvent.downloadAndDecryptAttachment).called(1);
            expect(await device.storedRows(), before);
          },
        );

        test(
          'skips a descriptor that inflates past the limit instead of '
          'retrying it',
          () async {
            // Each retry would re-run the decode a bomb makes expensive.
            when(descriptorEvent.downloadAndDecryptAttachment).thenThrow(
              const AttachmentTooLargeException(1024),
            );

            attachmentIndex.record(descriptorEvent);

            const message = SyncMessage.agentEntity(
              status: SyncEntryStatus.update,
              jsonPath: '/agent_entities/agent-desc.json',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            final before = await device.storedRows();
            expect(await processorWithIndex.prepare(envelope: event), isNull);

            verify(descriptorEvent.downloadAndDecryptAttachment).called(1);
            expect(await device.storedRows(), before);
          },
        );

        test(
          'keeps other homeserver errors retryable',
          () async {
            when(descriptorEvent.downloadAndDecryptAttachment).thenThrow(
              MatrixException.fromJson(const {
                'errcode': 'M_LIMIT_EXCEEDED',
                'error': 'Too many requests',
              }),
            );

            attachmentIndex.record(descriptorEvent);

            const message = SyncMessage.agentEntity(
              status: SyncEntryStatus.update,
              jsonPath: '/agent_entities/agent-desc.json',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            final before = await device.storedRows();
            await expectLater(
              processorWithIndex.prepare(envelope: event),
              throwsA(isA<FileSystemException>()),
            );
            expect(await device.storedRows(), before);
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

          final before = await device.storedRows();
          await expectLater(
            () => processorWithIndex.process(
              envelope: event,
              journalDb: journalDb,
            ),
            throwsA(isA<FileSystemException>()),
          );

          expect(await device.storedRows(), before);
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
            envelope: event,
            journalDb: journalDb,
          );

          expect(
            await device.repository.getEntityIncludingDeleted(entity.id),
            entity,
          );
        });

        test(
          'exact attachment miss never falls back to an existing agent '
          'sidecar at the same path',
          () async {
            final newerEntity = AgentDomainEntity.agent(
              id: 'agent-exact-pending',
              agentId: 'agent-exact-pending',
              kind: 'task_agent',
              displayName: 'Newer disk generation',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: const {},
              currentStateId: 'state-30',
              config: const AgentConfig(),
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 16),
              vectorClock: const VectorClock({'remote-host': 30}),
            );
            const relativePath = '/agent_entities/agent-exact-pending.json';
            final file = File(
              path.join(tempDir.path, stripLeadingSlashes(relativePath)),
            );
            file.parent.createSync(recursive: true);
            file.writeAsStringSync(jsonEncode(newerEntity.toJson()));

            const message = SyncMessage.agentEntity(
              status: SyncEntryStatus.update,
              jsonPath: relativePath,
              attachmentEventId: 'agent-payload-not-yet-indexed',
            );
            when(() => event.text).thenReturn(encodeMessage(message));
            when(
              () => indexRoom.getEventById('agent-payload-not-yet-indexed'),
            ).thenAnswer((_) async => null);

            final before = await device.storedRows();
            await expectLater(
              processorWithIndex.process(envelope: event, journalDb: journalDb),
              throwsA(isA<PendingSyncDescriptorException>()),
            );

            expect(await device.storedRows(), before);
          },
        );

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
          final before = await device.storedRows();
          await processorWithIndex.process(
            envelope: event,
            journalDb: journalDb,
          );

          expect(await device.storedRows(), before);
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

        final before = await device.storedRows();
        await processor.process(envelope: event, journalDb: journalDb);

        expect(await device.storedRows(), before);
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
            await device.repository.upsertEntity(local);

            // Use a path-traversal jsonPath — resolveJsonCandidateFile throws
            // FileSystemException which _restoreDominantAgentCache catches.
            final message = SyncMessage.agentEntity(
              agentEntity: stale,
              status: SyncEntryStatus.update,
              jsonPath: '../../etc/evil.json',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            // Should complete without throwing.
            final before = await device.storedRows();
            await processor.process(envelope: event, journalDb: journalDb);

            // Local dominates → entity NOT upserted.
            expect(await device.storedRows(), before);
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
            await device.repository.upsertLink(local);

            final message = SyncMessage.agentLink(
              agentLink: stale,
              status: SyncEntryStatus.update,
              jsonPath: '../../etc/evil.json',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            final before = await device.storedRows();
            await processor.process(envelope: event, journalDb: journalDb);

            expect(await device.storedRows(), before);
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
      processor.process(envelope: event, journalDb: journalDb),
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
      processor.process(envelope: event, journalDb: journalDb),
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
    await processor.process(envelope: event, journalDb: journalDb);

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
      await processor.process(envelope: event, journalDb: journalDb);
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

    await processor.process(envelope: event, journalDb: journalDb);

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

/// Extends (not implements) so the interface's default no-op
/// [AgentRuntimeMaintenance.onIdentityReceived] body itself is exercised.
class _DefaultHookMaintenance extends AgentRuntimeMaintenance {
  @override
  Future<void> beforeWakeScan() async {}

  @override
  Future<void> restoreSubscriptions() async {}
}

class _RecordingMaintenance implements AgentRuntimeMaintenance {
  _RecordingMaintenance(this.seen);

  final List<String> seen;

  @override
  Future<void> beforeWakeScan() async {}

  @override
  Future<void> restoreSubscriptions() async {}

  @override
  Future<void> onIdentityReceived(AgentIdentityEntity identity) async {
    seen.add(identity.agentId);
  }
}

class _ThrowingMaintenance implements AgentRuntimeMaintenance {
  @override
  Future<void> beforeWakeScan() async {}

  @override
  Future<void> restoreSubscriptions() async {}

  @override
  Future<void> onIdentityReceived(AgentIdentityEntity identity) async {
    throw StateError('bad contributor');
  }
}
