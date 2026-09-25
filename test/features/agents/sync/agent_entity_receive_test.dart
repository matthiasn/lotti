import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/sync/agent_entity_receive.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../../../helpers/fallbacks.dart';
import '../agent_test_device.dart';
import '../test_data/entity_factories.dart';
import 'agent_replica_bench.dart';

part 'agent_removal_model_conformance.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  final at = DateTime(2026, 9, 25, 9);
  final planId = makeTestDayPlan().id;
  final itemId = makeTestParsedItem().id;

  group('resolveReceivedAgentEntity', () {
    late AgentTestDevice device;

    setUp(() {
      device = AgentTestDevice('host-a', background: false);
      addTearDown(device.close);
    });

    Future<AgentEntityReceipt> receipt(AgentDomainEntity incoming) =>
        device.repository.runInTransaction(
          () => resolveReceivedAgentEntity(
            device.repository,
            incoming,
            onMalformedClock: Error.throwWithStackTrace,
          ),
        );

    test('writes the incoming version when no version is stored', () async {
      final incoming = makeTestDayPlan(
        vectorClock: const VectorClock({'host-b': 1}),
      );

      final result = await receipt(incoming);

      expect(result.stored, isNull);
      expect(result.toWrite, same(incoming));
    });

    test(
      'reads a removal as the stored version, and keeps it against a late '
      'copy of the live version it removed',
      () async {
        await device.sync.upsertEntity(makeTestDayPlan(updatedAt: at));
        final live = device.sentEntities.last;
        await device.sync.upsertEntity(
          (live as DayPlanEntity).copyWith(deletedAt: at, updatedAt: at),
        );

        final result = await receipt(live);

        expect(result.stored!.deletedAt, at);
        expect(result.toWrite, isNull);
      },
    );

    test(
      'reports a clock it cannot compare and writes the incoming version',
      () async {
        await device.repository.upsertEntity(
          makeTestDayPlan(vectorClock: const VectorClock({'host-a': -1})),
        );
        final incoming = makeTestDayPlan(
          vectorClock: const VectorClock({'host-b': 1}),
        );
        final reported = <Object>[];

        final result = await device.repository.runInTransaction(
          () => resolveReceivedAgentEntity(
            device.repository,
            incoming,
            onMalformedClock: (error, _) => reported.add(error),
          ),
        );

        expect(reported.single, isA<VclockException>());
        expect(result.toWrite, same(incoming));
      },
    );
  });

  group('removals stick on every device (ReplicaNetwork)', () {
    late ReplicaNetwork network;
    late AgentReplica a;
    late AgentReplica b;

    setUp(() {
      network = ReplicaNetwork();
      a = network.join('hA');
      b = network.join('hB');
      addTearDown(network.close);
    });

    Future<AgentDomainEntity?> storedOn(AgentReplica device, String id) =>
        device.repository.getEntityIncludingDeleted(id);

    /// A creates the plan, B receives it, A deletes it the way
    /// `deletePlanForDay` does, and everything is delivered.
    Future<void> createAndRemoveOnA() async {
      await a.syncService.upsertEntity(makeTestDayPlan(updatedAt: at));
      await network.deliverAll();
      final live = (await a.repository.getEntity(planId))! as DayPlanEntity;
      final removedAt = at.add(const Duration(minutes: 5));
      await a.syncService.upsertEntity(
        live.copyWith(deletedAt: removedAt, updatedAt: removedAt),
      );
    }

    test('a removal on one device reaches the other', () async {
      await createAndRemoveOnA();
      await network.deliverAll();

      final onB = await storedOn(b, planId);
      expect(onB!.deletedAt, at.add(const Duration(minutes: 5)));
      expect(onB.vectorClock, (await storedOn(a, planId))!.vectorClock);
      expect(await b.repository.getEntity(planId), isNull);
    });

    test(
      'a late copy of the live version brings the entity back on neither '
      'device (TLC: ReceiveSeesTombstones)',
      () async {
        // The copy a peer resends, a backfill answers with, or the network
        // delivers late. Read through `getEntity`, the removal was no row,
        // and the copy was written over it.
        await createAndRemoveOnA();
        await network.deliverAll();
        final lateCopy = network.sent.first.message.mapOrNull(
          agentEntity: (m) => m.agentEntity,
        )!;
        expect(lateCopy.deletedAt, isNull);

        for (final device in [a, b]) {
          await device.device.receiveEntity(lateCopy);
          expect(
            (await storedOn(device, planId))!.deletedAt,
            isNotNull,
            reason: device.host,
          );
        }
      },
    );

    test(
      'a device that missed the removal converges on the backfill answer '
      '(TLC: BackfillServesTombstones)',
      () async {
        await createAndRemoveOnA();
        // B's delivery of the removal is lost.
        final removal = network.pendingFor(b).single;
        b.received.add(removal);
        expect((await storedOn(b, planId))!.deletedAt, isNull);

        // B asks A for the counter; A answers with its stored version of the
        // id, which the backfill responder reads with its tombstone.
        final answer = (await a.repository.getEntityIncludingDeleted(planId))!;
        await b.device.receiveEntity(answer);

        expect(
          (await storedOn(b, planId))!.toJson(),
          (await storedOn(a, planId))!.toJson(),
        );
        expect((await storedOn(b, planId))!.deletedAt, isNotNull);
      },
    );

    group('a removal concurrent with an edit: the later of the two stands', () {
      Future<void> removeOnAEditOnB({
        required Duration removedAfter,
        required Duration editedAfter,
      }) async {
        await a.syncService.upsertEntity(makeTestDayPlan(updatedAt: at));
        await network.deliverAll();
        final onA = (await a.repository.getEntity(planId))! as DayPlanEntity;
        final onB = (await b.repository.getEntity(planId))! as DayPlanEntity;
        await a.syncService.upsertEntity(
          onA.copyWith(
            deletedAt: at.add(removedAfter),
            updatedAt: at.add(removedAfter),
          ),
        );
        await b.syncService.upsertEntity(
          onB.copyWith(capacityMinutes: 300, updatedAt: at.add(editedAfter)),
        );
        await network.deliverAll();
      }

      Future<void> expectEverywhere({required bool removed}) async {
        final rows = [
          for (final device in [a, b]) (await storedOn(device, planId))!,
        ];
        expect(rows[1].toJson(), rows[0].toJson());
        expect(rows[0].deletedAt != null, removed);
      }

      test('an edit made after the removal keeps the plan', () async {
        await removeOnAEditOnB(
          removedAfter: const Duration(minutes: 1),
          editedAfter: const Duration(minutes: 2),
        );
        await expectEverywhere(removed: false);
      });

      test('a removal made after the edit removes the plan', () async {
        await removeOnAEditOnB(
          removedAfter: const Duration(minutes: 2),
          editedAfter: const Duration(minutes: 1),
        );
        await expectEverywhere(removed: true);
      });

      test(
        'an append-only row, which an edit cannot restamp, stays removed '
        'whichever clock the tiebreak prefers',
        () async {
          // A links the parsed item to a task, B removes it. The edit keeps
          // the item's createdAt, the only timestamp it has; ordered by
          // createdAt the pair tied, and the canonical clock order — A's
          // clock is the greater — brought the item back on both devices.
          await a.syncService.upsertEntity(makeTestParsedItem(createdAt: at));
          await network.deliverAll();
          final onA =
              (await a.repository.getEntity(itemId))! as ParsedItemEntity;
          final onB = (await b.repository.getEntity(itemId))!;
          await a.syncService.upsertEntity(
            onA.copyWith(matchedTaskId: 'task-1'),
          );
          await b.syncService.upsertEntity(
            onB.copyWith(deletedAt: at.add(const Duration(minutes: 1))),
          );
          await network.deliverAll();

          for (final device in [a, b]) {
            expect(
              (await storedOn(device, itemId))!.deletedAt,
              isNotNull,
              reason: device.host,
            );
          }
        },
      );
    });
  });

  registerRemovalModelConformance();
}
