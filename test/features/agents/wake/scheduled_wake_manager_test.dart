import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/scheduled_wake_manager.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

enum _GeneratedScheduledWakeStateKind {
  nonProjectNeverWoken,
  nonProjectPreviouslyWoken,
  projectNeverWoken,
  projectDormant,
  projectPendingActivity,
}

enum _GeneratedScheduledWakeTimeSlot {
  beforeNow,
  exactlyNow,
  afterNow,
  midnight,
  endOfDay,
}

enum _GeneratedScheduledWakeFailureSlot {
  none,
  firstFastForward,
  everyFastForward,
}

enum _GeneratedScheduledWakeManagerOperationKind { start, stop, tick }

final _generatedScheduledWakeNow = DateTime(2026, 5, 20, 10, 30);

class _GeneratedScheduledWakeSpec {
  const _GeneratedScheduledWakeSpec({
    required this.kind,
    required this.timeSlot,
  });

  final _GeneratedScheduledWakeStateKind kind;
  final _GeneratedScheduledWakeTimeSlot timeSlot;

  bool get expectsFastForward =>
      kind == _GeneratedScheduledWakeStateKind.projectDormant;

  bool get expectsEnqueue => !expectsFastForward;

  DateTime get scheduledWakeAt {
    final (hour, minute) = switch (timeSlot) {
      _GeneratedScheduledWakeTimeSlot.beforeNow => (6, 15),
      _GeneratedScheduledWakeTimeSlot.exactlyNow => (10, 30),
      _GeneratedScheduledWakeTimeSlot.afterNow => (16, 45),
      _GeneratedScheduledWakeTimeSlot.midnight => (0, 5),
      _GeneratedScheduledWakeTimeSlot.endOfDay => (23, 55),
    };
    return DateTime(2026, 5, 17, hour, minute);
  }

  DateTime expectedFastForwardWakeAt(DateTime now) {
    final scheduled = scheduledWakeAt;
    var nextWake = DateTime(
      now.year,
      now.month,
      now.day,
      scheduled.hour,
      scheduled.minute,
    );
    if (!nextWake.isAfter(now)) {
      nextWake = DateTime(
        now.year,
        now.month,
        now.day + 1,
        scheduled.hour,
        scheduled.minute,
      );
    }
    return nextWake;
  }

  AgentStateEntity toState(int index) {
    final agentId = 'generated-scheduled-agent-$index';
    final projectId = 'generated-project-$index';
    return makeTestState(
      id: 'generated-scheduled-state-$index',
      agentId: agentId,
      scheduledWakeAt: scheduledWakeAt,
      lastWakeAt: switch (kind) {
        _GeneratedScheduledWakeStateKind.nonProjectNeverWoken ||
        _GeneratedScheduledWakeStateKind.projectNeverWoken => null,
        _GeneratedScheduledWakeStateKind.nonProjectPreviouslyWoken ||
        _GeneratedScheduledWakeStateKind.projectDormant ||
        _GeneratedScheduledWakeStateKind.projectPendingActivity => DateTime(
          2026,
          5,
          17,
          11,
        ),
      },
      slots: switch (kind) {
        _GeneratedScheduledWakeStateKind.nonProjectNeverWoken ||
        _GeneratedScheduledWakeStateKind.nonProjectPreviouslyWoken =>
          const AgentSlots(),
        _GeneratedScheduledWakeStateKind.projectNeverWoken ||
        _GeneratedScheduledWakeStateKind.projectDormant => AgentSlots(
          activeProjectId: projectId,
        ),
        _GeneratedScheduledWakeStateKind.projectPendingActivity => AgentSlots(
          activeProjectId: projectId,
          pendingProjectActivityAt: DateTime(2026, 5, 20, 9),
        ),
      },
    );
  }

  @override
  String toString() {
    return '_GeneratedScheduledWakeSpec('
        'kind: $kind, timeSlot: $timeSlot)';
  }
}

class _GeneratedScheduledWakeBatchScenario {
  const _GeneratedScheduledWakeBatchScenario({
    required this.specs,
    required this.failureSlot,
  });

  final List<_GeneratedScheduledWakeSpec> specs;
  final _GeneratedScheduledWakeFailureSlot failureSlot;

  Set<String> failingFastForwardAgentIds(List<AgentStateEntity> states) {
    final fastForwardIds = <String>[
      for (var i = 0; i < specs.length; i++)
        if (specs[i].expectsFastForward) states[i].agentId,
    ];
    return switch (failureSlot) {
      _GeneratedScheduledWakeFailureSlot.none => const <String>{},
      _GeneratedScheduledWakeFailureSlot.firstFastForward =>
        fastForwardIds.isEmpty ? const <String>{} : {fastForwardIds.first},
      _GeneratedScheduledWakeFailureSlot.everyFastForward =>
        fastForwardIds.toSet(),
    };
  }

  @override
  String toString() {
    return '_GeneratedScheduledWakeBatchScenario('
        'specs: $specs, failureSlot: $failureSlot)';
  }
}

class _GeneratedScheduledWakeManagerOperation {
  const _GeneratedScheduledWakeManagerOperation({required this.kind});

  final _GeneratedScheduledWakeManagerOperationKind kind;

  @override
  String toString() {
    return '_GeneratedScheduledWakeManagerOperation(kind: $kind)';
  }
}

class _GeneratedScheduledWakeManagerLifecycleScenario {
  const _GeneratedScheduledWakeManagerLifecycleScenario({
    required this.operations,
  });

  final List<_GeneratedScheduledWakeManagerOperation> operations;

  @override
  String toString() {
    return '_GeneratedScheduledWakeManagerLifecycleScenario('
        'operations: $operations)';
  }
}

extension _AnyGeneratedScheduledWakeScenario on glados.Any {
  glados.Generator<_GeneratedScheduledWakeStateKind>
  get scheduledWakeStateKind =>
      glados.AnyUtils(this).choose(_GeneratedScheduledWakeStateKind.values);

  glados.Generator<_GeneratedScheduledWakeTimeSlot> get scheduledWakeTimeSlot =>
      glados.AnyUtils(this).choose(_GeneratedScheduledWakeTimeSlot.values);

  glados.Generator<_GeneratedScheduledWakeSpec> get scheduledWakeSpec =>
      glados.CombinableAny(this).combine2(
        scheduledWakeStateKind,
        scheduledWakeTimeSlot,
        (
          _GeneratedScheduledWakeStateKind kind,
          _GeneratedScheduledWakeTimeSlot timeSlot,
        ) => _GeneratedScheduledWakeSpec(kind: kind, timeSlot: timeSlot),
      );

  glados.Generator<_GeneratedScheduledWakeFailureSlot>
  get scheduledWakeFailureSlot =>
      glados.AnyUtils(this).choose(_GeneratedScheduledWakeFailureSlot.values);

  glados.Generator<_GeneratedScheduledWakeBatchScenario>
  get scheduledWakeBatchScenario => glados.CombinableAny(this).combine2(
    glados.ListAnys(this).listWithLengthInRange(0, 8, scheduledWakeSpec),
    scheduledWakeFailureSlot,
    (
      List<_GeneratedScheduledWakeSpec> specs,
      _GeneratedScheduledWakeFailureSlot failureSlot,
    ) => _GeneratedScheduledWakeBatchScenario(
      specs: specs,
      failureSlot: failureSlot,
    ),
  );

  glados.Generator<_GeneratedScheduledWakeManagerOperationKind>
  get scheduledWakeManagerOperationKind => glados.AnyUtils(
    this,
  ).choose(_GeneratedScheduledWakeManagerOperationKind.values);

  glados.Generator<_GeneratedScheduledWakeManagerOperation>
  get scheduledWakeManagerOperation => scheduledWakeManagerOperationKind.map(
    (kind) => _GeneratedScheduledWakeManagerOperation(kind: kind),
  );

  glados.Generator<_GeneratedScheduledWakeManagerLifecycleScenario>
  get scheduledWakeManagerLifecycleScenario => glados.ListAnys(this)
      .listWithLengthInRange(1, 24, scheduledWakeManagerOperation)
      .map(
        (operations) => _GeneratedScheduledWakeManagerLifecycleScenario(
          operations: operations,
        ),
      );
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository repository;
  late MockWakeOrchestrator orchestrator;
  late MockAgentSyncService syncService;

  setUp(() {
    repository = MockAgentRepository();
    orchestrator = MockWakeOrchestrator();
    syncService = MockAgentSyncService();
    // Default: no persisted scheduled-wake records. Individual record tests
    // override this.
    when(
      () => repository.getDueScheduledWakeRecords(any()),
    ).thenAnswer((_) async => []);
    // Default: every due agent's identity is live, so the lifecycle guard lets
    // it through. Archived-agent tests override this.
    when(
      () => repository.getEntity(any()),
    ).thenAnswer((_) async => makeTestIdentity());
    // Default run-key stub so unstubbed enqueueManualWake calls (this test
    // file mostly asserts via `verify`, not `when`) don't throw on the
    // now-non-void return type.
    when(
      () => orchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
        workspaceKey: any(named: 'workspaceKey'),
        supersede: any(named: 'supersede'),
        initiator: any(named: 'initiator'),
      ),
    ).thenReturn('run-key-stub');
  });

  ScheduledWakeManager createAndStart({
    Duration checkInterval = const Duration(minutes: 1),
  }) {
    return ScheduledWakeManager(
      repository: repository,
      orchestrator: orchestrator,
      syncService: syncService,
      checkInterval: checkInterval,
    )..start();
  }

  group('ScheduledWakeManager', () {
    glados.Glados(
      glados.any.scheduledWakeBatchScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'matches generated due-batch enqueue and fast-forward semantics',
      (
        scenario,
      ) {
        final states = [
          for (final (index, spec) in scenario.specs.indexed)
            spec.toState(index),
        ];
        final failingFastForwardIds = scenario.failingFastForwardAgentIds(
          states,
        );
        final generatedRepository = MockAgentRepository();
        final generatedOrchestrator = MockWakeOrchestrator();
        final generatedSyncService = MockAgentSyncService();
        final attemptedFastForwardWrites = <AgentStateEntity>[];
        final notifiedAgentIds = <String>[];

        fakeAsync((async) {
          withClock(Clock.fixed(_generatedScheduledWakeNow), () {
            when(
              () => generatedRepository.getDueScheduledAgentStates(any()),
            ).thenAnswer((_) async => states);
            when(
              () => generatedRepository.getDueScheduledWakeRecords(any()),
            ).thenAnswer((_) async => []);
            // Every generated agent is live, so the lifecycle guard passes and
            // the enqueue/fast-forward model is exercised unchanged.
            when(
              () => generatedRepository.getEntity(any()),
            ).thenAnswer((_) async => makeTestIdentity());
            when(() => generatedSyncService.upsertEntity(any())).thenAnswer((
              invocation,
            ) async {
              final entity =
                  invocation.positionalArguments.single as AgentStateEntity;
              attemptedFastForwardWrites.add(entity);
              if (failingFastForwardIds.contains(entity.agentId)) {
                throw StateError('generated sync failure');
              }
            });

            final manager = ScheduledWakeManager(
              repository: generatedRepository,
              orchestrator: generatedOrchestrator,
              syncService: generatedSyncService,
              checkInterval: const Duration(minutes: 7),
              onPersistedStateChanged: notifiedAgentIds.add,
            )..start();
            async.flushMicrotasks();

            final expectedEnqueuedIds = <String>[
              for (var i = 0; i < scenario.specs.length; i++)
                if (scenario.specs[i].expectsEnqueue) states[i].agentId,
            ];
            final expectedFastForwardIds = <String>[
              for (var i = 0; i < scenario.specs.length; i++)
                if (scenario.specs[i].expectsFastForward) states[i].agentId,
            ];
            final expectedNotifiedIds = expectedFastForwardIds
                .where((agentId) => !failingFastForwardIds.contains(agentId))
                .toList();

            if (expectedEnqueuedIds.isEmpty) {
              verifyNever(
                () => generatedOrchestrator.enqueueManualWake(
                  agentId: any(named: 'agentId'),
                  reason: any(named: 'reason'),
                ),
              );
            } else {
              final capturedAgentIds = verify(
                () => generatedOrchestrator.enqueueManualWake(
                  agentId: captureAny(named: 'agentId'),
                  reason: WakeReason.scheduled.name,
                ),
              ).captured.cast<String>();
              expect(
                capturedAgentIds,
                expectedEnqueuedIds,
                reason: '$scenario',
              );
            }

            expect(
              attemptedFastForwardWrites.map((state) => state.agentId).toList(),
              expectedFastForwardIds,
              reason: '$scenario',
            );

            for (final write in attemptedFastForwardWrites) {
              final index = states.indexWhere(
                (state) => state.agentId == write.agentId,
              );
              expect(index, isNonNegative, reason: '$scenario');
              expect(
                write.scheduledWakeAt,
                scenario.specs[index].expectedFastForwardWakeAt(
                  _generatedScheduledWakeNow,
                ),
                reason: '$scenario',
              );
              expect(write.updatedAt, _generatedScheduledWakeNow);
            }

            expect(notifiedAgentIds, expectedNotifiedIds, reason: '$scenario');

            manager.stop();
          });
        });
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.scheduledWakeManagerLifecycleScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'matches generated start stop and timer replacement semantics',
      (
        scenario,
      ) {
        const checkInterval = Duration(minutes: 11);
        final generatedRepository = MockAgentRepository();
        final generatedOrchestrator = MockWakeOrchestrator();
        final generatedSyncService = MockAgentSyncService();
        var repositoryChecks = 0;
        var expectedChecks = 0;
        var running = false;

        fakeAsync((async) {
          withClock(Clock.fixed(_generatedScheduledWakeNow), () {
            when(
              () => generatedRepository.getDueScheduledAgentStates(any()),
            ).thenAnswer((_) async {
              repositoryChecks++;
              return <AgentStateEntity>[];
            });
            when(
              () => generatedRepository.getDueScheduledWakeRecords(any()),
            ).thenAnswer((_) async => []);

            final manager = ScheduledWakeManager(
              repository: generatedRepository,
              orchestrator: generatedOrchestrator,
              syncService: generatedSyncService,
              checkInterval: checkInterval,
            );

            for (final operation in scenario.operations) {
              switch (operation.kind) {
                case _GeneratedScheduledWakeManagerOperationKind.start:
                  manager.start();
                  running = true;
                  expectedChecks++;
                  async.flushMicrotasks();

                case _GeneratedScheduledWakeManagerOperationKind.stop:
                  manager.stop();
                  running = false;
                  async.flushMicrotasks();

                case _GeneratedScheduledWakeManagerOperationKind.tick:
                  async.elapse(checkInterval);
                  if (running) expectedChecks++;
                  async.flushMicrotasks();
              }

              expect(repositoryChecks, expectedChecks, reason: '$scenario');
            }

            manager.stop();
          });
        });
      },
      tags: 'glados',
    );

    test('enqueues wake for agent with scheduledWakeAt in the past', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final pastSchedule = DateTime(2024, 3, 15, 9);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [makeTestState(scheduledWakeAt: pastSchedule)],
          );

          final manager = createAndStart();
          async.flushMicrotasks();

          verify(
            () => orchestrator.enqueueManualWake(
              agentId: kTestAgentId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);

          manager.stop();
        });
      });
    });

    test('enqueues wake for agent with scheduledWakeAt exactly at now', () {
      final now = DateTime(2024, 3, 15, 10, 30);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [makeTestState(scheduledWakeAt: now)],
          );

          final manager = createAndStart();
          async.flushMicrotasks();

          verify(
            () => orchestrator.enqueueManualWake(
              agentId: kTestAgentId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);

          manager.stop();
        });
      });
    });

    test('does not enqueue wake when no agents are due', () {
      final now = DateTime(2024, 3, 15, 10, 30);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [],
          );

          final manager = createAndStart();
          async.flushMicrotasks();

          verifyNever(
            () => orchestrator.enqueueManualWake(
              agentId: any(named: 'agentId'),
              reason: any(named: 'reason'),
            ),
          );

          manager.stop();
        });
      });
    });

    group('archived-agent guard (ADR 0022)', () {
      test('skips and clears the wake for a dormant (archived) agent', () {
        final now = DateTime(2024, 3, 15, 10, 30);
        final pastSchedule = DateTime(2024, 3, 15, 9);

        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
              (_) async => [makeTestState(scheduledWakeAt: pastSchedule)],
            );
            // The identity was archived by the planner cutover (or never
            // migrated on this device) — it must not wake.
            when(() => repository.getEntity(any())).thenAnswer(
              (_) async => makeTestIdentity(lifecycle: AgentLifecycle.dormant),
            );
            when(
              () => syncService.upsertEntity(any()),
            ).thenAnswer((_) async {});

            final manager = createAndStart();
            async.flushMicrotasks();

            verifyNever(
              () => orchestrator.enqueueManualWake(
                agentId: any(named: 'agentId'),
                reason: any(named: 'reason'),
              ),
            );
            // Its stale scheduledWakeAt is cleared so it stops surfacing.
            final cleared =
                verify(
                      () => syncService.upsertEntity(captureAny()),
                    ).captured.single
                    as AgentStateEntity;
            expect(cleared.scheduledWakeAt, isNull);

            manager.stop();
          });
        });
      });

      test('skips and clears the wake when the identity is missing', () {
        final now = DateTime(2024, 3, 15, 10, 30);
        final pastSchedule = DateTime(2024, 3, 15, 9);

        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
              (_) async => [makeTestState(scheduledWakeAt: pastSchedule)],
            );
            when(
              () => repository.getEntity(any()),
            ).thenAnswer((_) async => null);
            when(
              () => syncService.upsertEntity(any()),
            ).thenAnswer((_) async {});

            final manager = createAndStart();
            async.flushMicrotasks();

            verifyNever(
              () => orchestrator.enqueueManualWake(
                agentId: any(named: 'agentId'),
                reason: any(named: 'reason'),
              ),
            );
            verify(() => syncService.upsertEntity(any())).called(1);

            manager.stop();
          });
        });
      });

      test('still enqueues for an active agent (regression)', () {
        final now = DateTime(2024, 3, 15, 10, 30);
        final pastSchedule = DateTime(2024, 3, 15, 9);

        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
              (_) async => [makeTestState(scheduledWakeAt: pastSchedule)],
            );
            // Default setUp stub already returns an active identity.

            final manager = createAndStart();
            async.flushMicrotasks();

            verify(
              () => orchestrator.enqueueManualWake(
                agentId: kTestAgentId,
                reason: WakeReason.scheduled.name,
              ),
            ).called(1);

            manager.stop();
          });
        });
      });
    });

    group('one-device lease for a shared record (lotti3-hkb.11)', () {
      const digestWorkspace = 'coordinator:digest';
      final now = DateTime(2026, 5, 20, 6);

      ScheduledWakeEntity leased({
        String? leaseHostId,
        DateTime? leaseUntil,
        DateTime? updatedAt,
      }) {
        return AgentDomainEntity.scheduledWake(
              id: 'scheduled_wake:planner:coordinator:digest',
              agentId: 'daily_os_planner',
              scheduledAt: now,
              status: ScheduledWakeStatus.pending,
              reason: 'digest',
              updatedAt: updatedAt ?? now,
              vectorClock: null,
              triggerTokens: const ['digest:dayplan-2026-05-20'],
              workspaceKey: digestWorkspace,
              leaseHostId: leaseHostId,
              leaseUntil: leaseUntil,
            )
            as ScheduledWakeEntity;
      }

      ScheduledWakeManager managerFor(
        ScheduledWakeEntity record, {
        String hostId = 'host-a',
        // Tests about an armed timer must not be rescued by the periodic tick,
        // or they pass with no timer at all.
        Duration checkInterval = const Duration(minutes: 1),
        Completer<void>? hostLookupGate,
      }) {
        when(
          () => repository.getDueScheduledAgentStates(any()),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getDueScheduledWakeRecords(any()),
        ).thenAnswer((_) async => [record]);
        when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
        // The fire path re-reads the record so a `consumed` version applied
        // during the host lookup cannot be fired from a stale copy.
        when(
          () => repository.getEntity(record.id),
        ).thenAnswer((_) async => record);
        return ScheduledWakeManager(
          repository: repository,
          orchestrator: orchestrator,
          syncService: syncService,
          checkInterval: checkInterval,
          requiresLease: (r) => r.workspaceKey == digestWorkspace,
          localHostId: () async {
            // Gated on a Completer the test releases, rather than a delay:
            // the suite forbids real waits, and this gives the test exact
            // control over when the lookup resolves.
            if (hostLookupGate != null) await hostLookupGate.future;
            return hostId;
          },
        )..start();
      }

      void expectNoWake() {
        verifyNever(
          () => orchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
            workspaceKey: any(named: 'workspaceKey'),
          ),
        );
      }

      test('an unclaimed record is claimed, not fired', () {
        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            final manager = managerFor(leased());
            async.flushMicrotasks();

            // Claiming and firing in one pass would be the bug: the claim has
            // to converge through sync before anyone can know it won.
            expectNoWake();
            final claimed =
                verify(
                      () => syncService.upsertEntity(captureAny()),
                    ).captured.single
                    as ScheduledWakeEntity;
            expect(claimed.leaseHostId, 'host-a');
            expect(
              claimed.leaseUntil,
              now.toUtc().add(const Duration(minutes: 30)),
            );
            expect(claimed.status, ScheduledWakeStatus.pending);

            manager.stop();
          });
        });
      });

      test('the deadline survives a peer in another timezone', () {
        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            final manager = managerFor(leased());
            async.flushMicrotasks();

            final claimed =
                verify(
                      () => syncService.upsertEntity(captureAny()),
                    ).captured.single
                    as ScheduledWakeEntity;

            // The entity crosses devices as JSON. `toIso8601String()` on a
            // local DateTime emits no offset, so a peer would re-read the same
            // wall-clock components in its own zone: a west-to-east claim would
            // look already expired and be taken over at once — both devices
            // firing, the very duplicate this lease prevents — while the other
            // direction would stretch 30 minutes into hours.
            final wire = claimed.leaseUntil!.toIso8601String();
            expect(
              wire,
              endsWith('Z'),
              reason: 'Only a UTC stamp names the same instant everywhere.',
            );
            expect(
              DateTime.parse(wire).isAtSameMomentAs(claimed.leaseUntil!),
              isTrue,
            );

            manager.stop();
          });
        });
      });

      test('takes over the moment a foreign lease lapses', () {
        fakeAsync((async) {
          withClock(Clock(() => now.add(async.elapsed)), () {
            final manager = managerFor(
              leased(
                leaseHostId: 'host-b',
                leaseUntil: now.toUtc().add(const Duration(minutes: 10)),
                updatedAt: now,
              ),
              checkInterval: const Duration(hours: 1),
            );
            async.flushMicrotasks();
            expectNoWake();

            // The periodic tick is hourly, so without a timer of its own a
            // crashed claimant would hold the window for the rest of the hour
            // on top of its lease.
            async
              ..elapse(const Duration(minutes: 10, seconds: 1))
              ..flushMicrotasks();

            verify(() => syncService.upsertEntity(any())).called(1);
            manager.stop();
          });
        });
      });

      test('a restart inside the settle arms the remainder', () {
        fakeAsync((async) {
          // Claimed one minute ago by this host; two minutes of settle left.
          final restart = now.add(const Duration(minutes: 1));
          withClock(Clock(() => restart.add(async.elapsed)), () {
            final manager = managerFor(
              leased(
                leaseHostId: 'host-a',
                leaseUntil: now.toUtc().add(const Duration(minutes: 30)),
                updatedAt: now,
              ),
              checkInterval: const Duration(hours: 1),
            );
            async.flushMicrotasks();
            expectNoWake();

            // The restart lost the original settle timer. Without a
            // replacement the next check is the hourly tick, by which point
            // the lease has expired and the device reclaims its own record.
            async
              ..elapse(const Duration(minutes: 1, seconds: 59))
              ..flushMicrotasks();
            expectNoWake();

            async
              ..elapse(const Duration(seconds: 2))
              ..flushMicrotasks();
            verify(
              () => orchestrator.enqueueManualWake(
                agentId: 'daily_os_planner',
                reason: 'digest',
                triggerTokens: {'digest:dayplan-2026-05-20'},
                workspaceKey: digestWorkspace,
              ),
            ).called(1);
            manager.stop();
          });
        });
      });

      test('a stopped manager does not fire from a pending settle', () {
        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            final manager = managerFor(
              leased(),
              checkInterval: const Duration(hours: 1),
            );

            // Stop *while the claim is still in flight* — before the
            // continuation reaches the line that arms the settle timer. Only
            // then is there a timer for stop() to have missed; flushing first
            // would let stop() cancel an already-armed one and prove nothing.
            // ignore: cascade_invocations
            manager.stop();
            async
              ..flushMicrotasks()
              ..elapse(const Duration(minutes: 10))
              ..flushMicrotasks();

            // Not one claim written, not merely no wake fired: the pass
            // re-checks its generation before touching each record, so a
            // manager stopped mid-flight claims nothing at all. A disposed
            // manager that kept claiming would race its replacement for the
            // same digest, on a timer the stop never saw.
            verifyNever(() => syncService.upsertEntity(any()));
            expectNoWake();
          });
        });
      });

      test('a settled claim does not fire through a stopped manager', () {
        fakeAsync((async) {
          // Already past the settle, so the very next check would fire — but
          // stop() lands while the host lookup is still awaiting.
          withClock(Clock.fixed(now.add(const Duration(minutes: 4))), () {
            final manager = managerFor(
              leased(
                leaseHostId: 'host-a',
                leaseUntil: now.toUtc().add(const Duration(minutes: 30)),
                updatedAt: now,
              ),
              checkInterval: const Duration(hours: 1),
            );

            // ignore: cascade_invocations
            manager.stop();
            async
              ..flushMicrotasks()
              ..elapse(const Duration(minutes: 5))
              ..flushMicrotasks();

            expectNoWake();
          });
        });
      });

      test('a consumed version applied during the lookup stops the fire', () {
        fakeAsync((async) {
          withClock(Clock.fixed(now.add(const Duration(minutes: 4))), () {
            final record = leased(
              leaseHostId: 'host-a',
              leaseUntil: now.toUtc().add(const Duration(minutes: 30)),
              updatedAt: now,
            );
            final manager = managerFor(record);
            // Sync applies the peer's completion while _holdsLease is awaiting
            // the host lookup, so the in-memory record is stale by the time
            // the fire path is reached.
            when(() => repository.getEntity(record.id)).thenAnswer(
              (_) async => record.copyWith(
                status: ScheduledWakeStatus.consumed,
                consumedAt: now,
              ),
            );
            async.flushMicrotasks();

            expectNoWake();
            manager.stop();
          });
        });
      });

      test('a claim is not written over a newer version', () {
        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            final record = leased();
            final manager = managerFor(record);
            // Sync applies the peer's completion while the host lookup is
            // awaiting. Claiming from the due snapshot would copy its stale
            // pending fields straight over that newer row.
            when(() => repository.getEntity(record.id)).thenAnswer(
              (_) async => record.copyWith(
                status: ScheduledWakeStatus.consumed,
                consumedAt: now,
              ),
            );
            async.flushMicrotasks();

            verifyNever(() => syncService.upsertEntity(any()));
            expectNoWake();
            manager.stop();
          });
        });
      });

      test('a re-armed next window is not claimed from the old snapshot', () {
        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            final record = leased();
            final manager = managerFor(record);
            when(() => repository.getEntity(record.id)).thenAnswer(
              (_) async => record.copyWith(
                scheduledAt: record.scheduledAt.add(const Duration(days: 1)),
              ),
            );
            async.flushMicrotasks();

            verifyNever(() => syncService.upsertEntity(any()));
            manager.stop();
          });
        });
      });

      test('a crossing claim between the checks stops the fire', () {
        fakeAsync((async) {
          withClock(Clock.fixed(now.add(const Duration(minutes: 4))), () {
            final record = leased(
              leaseHostId: 'host-a',
              leaseUntil: now.toUtc().add(const Duration(minutes: 30)),
              updatedAt: now,
            );
            final manager = managerFor(record);
            // A peer's claim lands after the lease check approved the record
            // but before the final read. It is still pending, so a
            // status-only check would fire — on a lease this device has lost.
            var reads = 0;
            when(() => repository.getEntity(record.id)).thenAnswer((_) async {
              reads++;
              return reads == 1
                  ? record
                  : record.copyWith(
                      leaseHostId: 'host-b',
                      leaseUntil: now.toUtc().add(const Duration(minutes: 45)),
                    );
            });
            async.flushMicrotasks();

            expectNoWake();
            manager.stop();
          });
        });
      });

      test('a lease that expires during the lookup is not approved', () {
        fakeAsync((async) {
          // Clock advances with fake time; the lease has one minute left when
          // the pass starts, and the host lookup takes two.
          final start = now.add(const Duration(minutes: 29));
          final gate = Completer<void>();
          withClock(Clock(() => start.add(async.elapsed)), () {
            final manager = managerFor(
              leased(
                leaseHostId: 'host-a',
                leaseUntil: now.toUtc().add(const Duration(minutes: 30)),
                updatedAt: now,
              ),
              hostLookupGate: gate,
              checkInterval: const Duration(hours: 1),
            );
            // Two minutes pass with the lookup outstanding, so the lease
            // lapses before it resolves.
            async
              ..elapse(const Duration(minutes: 2))
              ..flushMicrotasks();
            gate.complete();
            async.flushMicrotasks();

            // Comparing against the time captured before the lookup would
            // approve a claim that expired while it was outstanding.
            expectNoWake();
            manager.stop();
          });
        });
      });

      test('a retired agent does not fire its scheduled-wake record', () {
        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            final record = leased();
            final manager = managerFor(
              record,
              checkInterval: const Duration(hours: 1),
            );
            // getDueScheduledWakeRecords filters on the deadline, not
            // lifecycle. A retired per-day agent still holding a
            // `set_next_wake` record would keep firing without this guard —
            // and that record path is the one per-day agents actually use.
            when(() => repository.getEntity(record.agentId)).thenAnswer(
              (_) async => makeTestIdentity().copyWith(
                lifecycle: AgentLifecycle.dormant,
              ),
            );
            async.flushMicrotasks();

            expectNoWake();
            final written = verify(
              () => syncService.upsertEntity(captureAny()),
            ).captured.whereType<ScheduledWakeEntity>().single;
            // Consumed, so it stops surfacing on every tick.
            expect(written.status, ScheduledWakeStatus.consumed);
            manager.stop();
          });
        });
      });

      test('a wake whose identity has not synced stays pending', () {
        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            final record = leased();
            final manager = managerFor(
              record,
              checkInterval: const Duration(hours: 1),
            );
            // Sync can deliver a wake record before the identity it belongs
            // to. Consuming is terminal, so treating "missing" as "inactive"
            // would destroy the wake rather than delay it.
            when(
              () => repository.getEntity(record.agentId),
            ).thenAnswer((_) async => null);
            async.flushMicrotasks();

            expectNoWake();
            verifyNever(() => syncService.upsertEntity(any()));
            manager.stop();
          });
        });
      });

      test('a claim confirmed after the settle fires exactly once', () {
        fakeAsync((async) {
          withClock(Clock.fixed(now.add(const Duration(minutes: 4))), () {
            final manager = managerFor(
              leased(
                leaseHostId: 'host-a',
                leaseUntil: now.add(const Duration(minutes: 30)),
                updatedAt: now,
              ),
            );
            async.flushMicrotasks();

            verify(
              () => orchestrator.enqueueManualWake(
                agentId: 'daily_os_planner',
                reason: 'digest',
                triggerTokens: {'digest:dayplan-2026-05-20'},
                workspaceKey: digestWorkspace,
              ),
            ).called(1);

            manager.stop();
          });
        });
      });

      test('the claimant waits out the settle before firing', () {
        fakeAsync((async) {
          withClock(Clock.fixed(now.add(const Duration(minutes: 1))), () {
            final manager = managerFor(
              leased(
                leaseHostId: 'host-a',
                leaseUntil: now.add(const Duration(minutes: 30)),
                updatedAt: now,
              ),
            );
            async.flushMicrotasks();

            expectNoWake();
            manager.stop();
          });
        });
      });

      test('a device whose claim lost the race skips the window', () {
        fakeAsync((async) {
          withClock(Clock.fixed(now.add(const Duration(minutes: 4))), () {
            // host-b's crossing claim is what survived on the shared register.
            final manager = managerFor(
              leased(
                leaseHostId: 'host-b',
                leaseUntil: now.add(const Duration(minutes: 30)),
                updatedAt: now,
              ),
            );
            async.flushMicrotasks();

            expectNoWake();
            verifyNever(() => syncService.upsertEntity(any()));
            manager.stop();
          });
        });
      });

      test('a lapsed claim is taken over rather than lost', () {
        fakeAsync((async) {
          // host-b claimed, then went offline without consuming the record.
          withClock(Clock.fixed(now.add(const Duration(hours: 1))), () {
            final manager = managerFor(
              leased(
                leaseHostId: 'host-b',
                leaseUntil: now.add(const Duration(minutes: 30)),
                updatedAt: now,
              ),
            );
            async.flushMicrotasks();

            final claimed =
                verify(
                      () => syncService.upsertEntity(captureAny()),
                    ).captured.single
                    as ScheduledWakeEntity;
            expect(
              claimed.leaseHostId,
              'host-a',
              reason:
                  'Without takeover a device that claims and disappears would '
                  'drop that digest window forever.',
            );
            manager.stop();
          });
        });
      });

      test('three devices sharing one record produce exactly one wake', () {
        fakeAsync((async) {
          // One synced last-write-wins register, three devices reading and
          // writing it. Nothing here coordinates them: the register's own
          // convergence is the election.
          var shared = leased();
          var wakes = 0;

          ScheduledWakeManager device(String hostId) {
            final repo = MockAgentRepository();
            final orch = MockWakeOrchestrator();
            final sync = MockAgentSyncService();
            when(
              () => repo.getDueScheduledAgentStates(any()),
            ).thenAnswer((_) async => []);
            when(() => repo.getDueScheduledWakeRecords(any())).thenAnswer(
              (_) async => shared.status == ScheduledWakeStatus.pending
                  ? [shared]
                  : <ScheduledWakeEntity>[],
            );
            // The fire path re-reads the register, so a `consumed` version
            // another device wrote during this one's host lookup is seen.
            // Id-aware: the record id resolves to the shared register, the
            // agent id to a live identity for the lifecycle guard.
            when(() => repo.getEntity(any())).thenAnswer((invocation) async {
              final id = invocation.positionalArguments.single as String;
              return id == shared.id ? shared : makeTestIdentity();
            });
            when(() => sync.upsertEntity(any())).thenAnswer((invocation) async {
              final incoming =
                  invocation.positionalArguments.single as ScheduledWakeEntity;
              // Last write wins, exactly as the sync layer resolves it.
              if (!incoming.updatedAt.isBefore(shared.updatedAt)) {
                shared = incoming;
              }
            });
            when(
              () => orch.enqueueManualWake(
                agentId: any(named: 'agentId'),
                reason: any(named: 'reason'),
                triggerTokens: any(named: 'triggerTokens'),
                workspaceKey: any(named: 'workspaceKey'),
              ),
            ).thenAnswer((_) {
              wakes++;
              return 'run-key';
            });
            return ScheduledWakeManager(
              repository: repo,
              orchestrator: orch,
              syncService: sync,
              checkInterval: const Duration(minutes: 1),
              requiresLease: (r) => r.workspaceKey == digestWorkspace,
              localHostId: () async => hostId,
            );
          }

          final devices = [
            for (final host in ['host-a', 'host-b', 'host-c']) device(host),
          ];

          // Every device sees the record become due in the same window.
          withClock(Clock.fixed(now), () {
            for (final manager in devices) {
              manager.start();
              async.flushMicrotasks();
            }
          });
          expect(
            wakes,
            0,
            reason: 'Claiming is not firing; the settle has not elapsed.',
          );

          // After the settle, only the device whose claim survived proceeds.
          withClock(Clock.fixed(now.add(const Duration(minutes: 4))), () {
            for (final manager in devices) {
              manager
                ..stop()
                ..start();
              async.flushMicrotasks();
            }
          });

          expect(
            wakes,
            1,
            reason:
                'Three devices, one digest window, one inference billed — the '
                'whole point of the lease.',
          );
          expect(shared.status, ScheduledWakeStatus.consumed);
          for (final manager in devices) {
            manager.stop();
          }
        });
      });

      test('an unleased record still fires immediately', () {
        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            final manager = managerFor(
              leased().copyWith(workspaceKey: 'day:dayplan-2026-05-20'),
            );
            async.flushMicrotasks();

            verify(
              () => orchestrator.enqueueManualWake(
                agentId: any(named: 'agentId'),
                reason: any(named: 'reason'),
                triggerTokens: any(named: 'triggerTokens'),
                workspaceKey: any(named: 'workspaceKey'),
              ),
            ).called(1);
            manager.stop();
          });
        });
      });

      test('a device with no sync host fires rather than stalling', () {
        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            when(
              () => repository.getDueScheduledAgentStates(any()),
            ).thenAnswer((_) async => []);
            when(
              () => repository.getDueScheduledWakeRecords(any()),
            ).thenAnswer((_) async => [leased()]);
            when(
              () => syncService.upsertEntity(any()),
            ).thenAnswer((_) async {});
            final manager = ScheduledWakeManager(
              repository: repository,
              orchestrator: orchestrator,
              syncService: syncService,
              checkInterval: const Duration(minutes: 1),
              requiresLease: (r) => r.workspaceKey == digestWorkspace,
              localHostId: () async => null,
            )..start();
            async.flushMicrotasks();

            verify(
              () => orchestrator.enqueueManualWake(
                agentId: any(named: 'agentId'),
                reason: any(named: 'reason'),
                triggerTokens: any(named: 'triggerTokens'),
                workspaceKey: any(named: 'workspaceKey'),
              ),
            ).called(1);
            manager.stop();
          });
        });
      });
    });

    group('persisted scheduled-wake records (ADR 0022)', () {
      const dayId = 'dayplan-2024-03-15';
      final now = DateTime(2024, 3, 15, 10, 30);

      ScheduledWakeEntity record({
        ScheduledWakeStatus status = ScheduledWakeStatus.pending,
        DateTime? scheduledAt,
        String agentId = kTestAgentId,
        String? id,
      }) {
        return AgentDomainEntity.scheduledWake(
              id: id ?? 'scheduled_wake:$agentId:day:$dayId',
              agentId: agentId,
              scheduledAt: scheduledAt ?? now,
              status: status,
              reason: WakeReason.scheduled.name,
              updatedAt: now,
              vectorClock: null,
              triggerTokens: ['planning_day:$dayId'],
              workspaceKey: 'day:$dayId',
            )
            as ScheduledWakeEntity;
      }

      test('fires a due record with its day context and consumes it', () {
        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            when(
              () => repository.getDueScheduledAgentStates(any()),
            ).thenAnswer((_) async => []);
            when(
              () => repository.getDueScheduledWakeRecords(any()),
            ).thenAnswer((_) async => [record()]);
            when(
              () => syncService.upsertEntity(any()),
            ).thenAnswer((_) async {});

            final manager = createAndStart();
            async.flushMicrotasks();

            // The wake restores with the record's workspace key + tokens —
            // not a context-less scheduled wake.
            verify(
              () => orchestrator.enqueueManualWake(
                agentId: kTestAgentId,
                reason: WakeReason.scheduled.name,
                triggerTokens: {'planning_day:$dayId'},
                workspaceKey: 'day:$dayId',
              ),
            ).called(1);

            // The record is flipped to consumed (not hard-deleted).
            final consumed =
                verify(
                      () => syncService.upsertEntity(captureAny()),
                    ).captured.single
                    as ScheduledWakeEntity;
            expect(consumed.status, ScheduledWakeStatus.consumed);
            expect(consumed.consumedAt, now);

            manager.stop();
          });
        });
      });

      test(
        'a failing record is swallowed and the next record still fires',
        () {
          fakeAsync((async) {
            withClock(Clock.fixed(now), () {
              final failing = record(
                agentId: 'agent-fail',
                id: 'wake-fail',
              );
              final healthy = record(
                agentId: 'agent-ok',
                id: 'wake-ok',
              );
              final notifiedAgentIds = <String>[];

              when(
                () => repository.getDueScheduledAgentStates(any()),
              ).thenAnswer((_) async => []);
              when(
                () => repository.getDueScheduledWakeRecords(any()),
              ).thenAnswer((_) async => [failing, healthy]);
              // The first record blows up at enqueue time; the second is fine.
              when(
                () => orchestrator.enqueueManualWake(
                  agentId: any(named: 'agentId'),
                  reason: any(named: 'reason'),
                  triggerTokens: any(named: 'triggerTokens'),
                  workspaceKey: any(named: 'workspaceKey'),
                ),
              ).thenAnswer((invocation) {
                if (invocation.namedArguments[#agentId] == 'agent-fail') {
                  throw StateError('enqueue blew up');
                }
                return 'run-key-stub';
              });
              when(
                () => syncService.upsertEntity(any()),
              ).thenAnswer((_) async {});

              final manager = ScheduledWakeManager(
                repository: repository,
                orchestrator: orchestrator,
                syncService: syncService,
                checkInterval: const Duration(minutes: 1),
                onPersistedStateChanged: notifiedAgentIds.add,
              )..start();
              async.flushMicrotasks();

              // The healthy record is consumed despite the earlier failure.
              final consumed =
                  verify(
                        () => syncService.upsertEntity(captureAny()),
                      ).captured.single
                      as ScheduledWakeEntity;
              expect(consumed.id, 'wake-ok');
              expect(consumed.status, ScheduledWakeStatus.consumed);
              // The failed record never reached the consume/notify steps.
              expect(notifiedAgentIds, ['agent-ok']);

              manager.stop();
            });
          });
        },
      );

      test('an already-consumed record is never returned as due', () {
        // The Drift due-query filters status='pending'; the repository fake
        // models that by returning only pending records. A consumed record
        // must therefore not re-fire.
        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            when(
              () => repository.getDueScheduledAgentStates(any()),
            ).thenAnswer((_) async => []);
            when(
              () => repository.getDueScheduledWakeRecords(any()),
            ).thenAnswer((_) async => []);

            final manager = createAndStart();
            async.flushMicrotasks();

            verifyNever(
              () => orchestrator.enqueueManualWake(
                agentId: any(named: 'agentId'),
                reason: any(named: 'reason'),
                triggerTokens: any(named: 'triggerTokens'),
                workspaceKey: any(named: 'workspaceKey'),
              ),
            );

            manager.stop();
          });
        });
      });
    });

    test('enqueues wakes for multiple due agents', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final pastSchedule = DateTime(2024, 3, 15, 8);

      const agentId2 = 'agent-002';

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [
              makeTestState(scheduledWakeAt: pastSchedule),
              makeTestState(
                agentId: agentId2,
                scheduledWakeAt: pastSchedule,
              ),
            ],
          );

          final manager = createAndStart();
          async.flushMicrotasks();

          verify(
            () => orchestrator.enqueueManualWake(
              agentId: kTestAgentId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: agentId2,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);

          manager.stop();
        });
      });
    });

    test('periodic timer fires and checks again', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final pastSchedule = DateTime(2024, 3, 15, 9);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [makeTestState(scheduledWakeAt: pastSchedule)],
          );

          final manager = createAndStart();
          async.flushMicrotasks();

          // First immediate check.
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: kTestAgentId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);

          // Advance past one check interval.
          async
            ..elapse(const Duration(minutes: 1))
            ..flushMicrotasks();

          // Second check from periodic timer.
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: kTestAgentId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);

          manager.stop();
        });
      });
    });

    test('stop cancels the periodic timer', () {
      final now = DateTime(2024, 3, 15, 10, 30);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [],
          );

          final manager = createAndStart();
          async.flushMicrotasks();

          manager.stop();

          // Clear any previous interactions.
          reset(repository);

          // Advance past check interval — no more calls should happen.
          async
            ..elapse(const Duration(minutes: 2))
            ..flushMicrotasks();

          verifyNever(
            () => repository.getDueScheduledAgentStates(any()),
          );
        });
      });
    });

    test('handles repository errors gracefully without crashing', () {
      final now = DateTime(2024, 3, 15, 10, 30);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(
            () => repository.getDueScheduledAgentStates(any()),
          ).thenThrow(Exception('DB error'));

          // Should not throw.
          final manager = createAndStart();
          async.flushMicrotasks();

          // Clear invocation history so verify below only sees the recovery
          // call.
          clearInteractions(repository);

          // Timer should still be running — next tick should try again.
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [],
          );

          async
            ..elapse(const Duration(minutes: 1))
            ..flushMicrotasks();

          // Verify it recovered and called again after the error.
          verify(() => repository.getDueScheduledAgentStates(any())).called(1);

          manager.stop();
        });
      });
    });

    test('fast-forwards dormant project agents without enqueuing a wake', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final pastSchedule = DateTime(2024, 3, 13, 6);
      final dormantState = makeTestState(
        scheduledWakeAt: pastSchedule,
        lastWakeAt: DateTime(2024, 3, 13, 6, 5),
        slots: const AgentSlots(activeProjectId: 'project-1'),
      );

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [dormantState],
          );
          when(
            () => syncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          final manager = createAndStart();
          async.flushMicrotasks();

          verifyNever(
            () => orchestrator.enqueueManualWake(
              agentId: any(named: 'agentId'),
              reason: any(named: 'reason'),
            ),
          );

          final captured =
              verify(
                    () => syncService.upsertEntity(captureAny()),
                  ).captured.single
                  as AgentStateEntity;
          expect(captured.scheduledWakeAt, DateTime(2024, 3, 16, 6));

          manager.stop();
        });
      });
    });

    test(
      'enqueues never-woken project agents even without pending activity',
      () {
        final now = DateTime(2024, 3, 15, 10, 30);
        final pastSchedule = DateTime(2024, 3, 14, 6);
        // lastWakeAt is null → first run, must execute.
        final neverWokenState = makeTestState(
          scheduledWakeAt: pastSchedule,
          slots: const AgentSlots(activeProjectId: 'project-1'),
        );

        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
              (_) async => [neverWokenState],
            );

            final manager = createAndStart();
            async.flushMicrotasks();

            verify(
              () => orchestrator.enqueueManualWake(
                agentId: kTestAgentId,
                reason: WakeReason.scheduled.name,
              ),
            ).called(1);

            manager.stop();
          });
        });
      },
    );

    test('mixed batch: fast-forwards dormant, enqueues active', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final pastSchedule = DateTime(2024, 3, 13, 6);

      const activeId = 'agent-active';
      const dormantId = 'agent-dormant';

      final dormantState = makeTestState(
        agentId: dormantId,
        scheduledWakeAt: pastSchedule,
        lastWakeAt: DateTime(2024, 3, 13, 6, 5),
        slots: const AgentSlots(activeProjectId: 'project-1'),
      );
      final activeState = makeTestState(
        agentId: activeId,
        scheduledWakeAt: pastSchedule,
        lastWakeAt: DateTime(2024, 3, 13, 6, 5),
        slots: AgentSlots(
          activeProjectId: 'project-2',
          pendingProjectActivityAt: DateTime(2024, 3, 15, 9),
        ),
      );

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [dormantState, activeState],
          );
          when(
            () => syncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          final manager = createAndStart();
          async.flushMicrotasks();

          // Active agent enqueued.
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: activeId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);

          // Dormant agent NOT enqueued.
          verifyNever(
            () => orchestrator.enqueueManualWake(
              agentId: dormantId,
              reason: any(named: 'reason'),
            ),
          );

          // Dormant agent fast-forwarded via syncService.
          verify(() => syncService.upsertEntity(any())).called(1);

          manager.stop();
        });
      });
    });

    test('fast-forward fires onPersistedStateChanged callback', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final dormantState = makeTestState(
        scheduledWakeAt: DateTime(2024, 3, 13, 6),
        lastWakeAt: DateTime(2024, 3, 13, 6, 5),
        slots: const AgentSlots(activeProjectId: 'project-1'),
      );
      String? notifiedAgentId;

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [dormantState],
          );
          when(
            () => syncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          final manager = ScheduledWakeManager(
            repository: repository,
            orchestrator: orchestrator,
            syncService: syncService,
            onPersistedStateChanged: (id) => notifiedAgentId = id,
          )..start();
          async.flushMicrotasks();

          expect(notifiedAgentId, kTestAgentId);

          manager.stop();
        });
      });
    });

    test('enqueues non-project agents even without pending activity', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final pastSchedule = DateTime(2024, 3, 14, 6);
      // No activeProjectId → not a project agent → always enqueue.
      final improverState = makeTestState(
        scheduledWakeAt: pastSchedule,
        lastWakeAt: DateTime(2024, 3, 14, 6, 5),
      );

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [improverState],
          );

          final manager = createAndStart();
          async.flushMicrotasks();

          verify(
            () => orchestrator.enqueueManualWake(
              agentId: kTestAgentId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);

          manager.stop();
        });
      });
    });

    test(
      'enqueues project agents with pending activity even if previously woken',
      () {
        final now = DateTime(2024, 3, 15, 10, 30);
        final pastSchedule = DateTime(2024, 3, 14, 6);
        final activeState = makeTestState(
          scheduledWakeAt: pastSchedule,
          lastWakeAt: DateTime(2024, 3, 14, 6, 5),
          slots: AgentSlots(
            activeProjectId: 'project-1',
            pendingProjectActivityAt: DateTime(2024, 3, 15, 8),
          ),
        );

        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
              (_) async => [activeState],
            );

            final manager = createAndStart();
            async.flushMicrotasks();

            verify(
              () => orchestrator.enqueueManualWake(
                agentId: kTestAgentId,
                reason: WakeReason.scheduled.name,
              ),
            ).called(1);

            manager.stop();
          });
        });
      },
    );
    test('fast-forward preserves agent schedule hour and keeps today slot', () {
      // now is 5:00 AM, schedule was for 9:00 AM two days ago.
      // Fast-forward should schedule for TODAY at 9:00 AM, not tomorrow.
      final now = DateTime(2024, 3, 15, 5);
      final pastSchedule = DateTime(2024, 3, 13, 9);
      final dormantState = makeTestState(
        scheduledWakeAt: pastSchedule,
        lastWakeAt: DateTime(2024, 3, 13, 9, 5),
        slots: const AgentSlots(activeProjectId: 'project-1'),
      );

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [dormantState],
          );
          when(
            () => syncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          final manager = createAndStart();
          async.flushMicrotasks();

          final captured =
              verify(
                    () => syncService.upsertEntity(captureAny()),
                  ).captured.single
                  as AgentStateEntity;
          // Today at 9:00 AM, not tomorrow.
          expect(captured.scheduledWakeAt, DateTime(2024, 3, 15, 9));

          manager.stop();
        });
      });
    });

    test('per-agent failure does not stop remaining agents', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final pastSchedule = DateTime(2024, 3, 13, 6);

      const failingId = 'agent-failing';
      const succeedingId = 'agent-succeeding';

      final failingState = makeTestState(
        agentId: failingId,
        scheduledWakeAt: pastSchedule,
        lastWakeAt: DateTime(2024, 3, 13, 6, 5),
        slots: const AgentSlots(activeProjectId: 'project-1'),
      );
      final succeedingState = makeTestState(
        agentId: succeedingId,
        scheduledWakeAt: pastSchedule,
      );

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [failingState, succeedingState],
          );
          // First agent's upsert fails.
          when(
            () => syncService.upsertEntity(any()),
          ).thenThrow(Exception('sync error'));

          final manager = createAndStart();
          async.flushMicrotasks();

          // Second agent should still be enqueued despite first failing.
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: succeedingId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);

          manager.stop();
        });
      });
    });

    group('overlapping triggers', () {
      /// Stubs the due query so the first pass blocks on [gate], and counts
      /// how many passes reached it.
      int Function() gatedDueQuery(Completer<void> gate, List<int> counter) {
        when(() => repository.getDueScheduledAgentStates(any())).thenAnswer((
          _,
        ) async {
          counter[0]++;
          if (counter[0] == 1) await gate.future;
          return <AgentStateEntity>[];
        });
        return () => counter[0];
      }

      test('a tick during an in-flight pass re-runs it once, not never', () {
        final now = DateTime(2024, 3, 15, 10, 30);

        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            final gate = Completer<void>();
            final passes = gatedDueQuery(gate, [0]);

            final manager = createAndStart();
            async.flushMicrotasks();
            expect(passes(), 1, reason: 'first pass is blocked on the gate');

            // The periodic tick lands while that pass is still running. The
            // re-checks armed for lease expiry are one-shot timers, so
            // dropping this would lose the trigger, not merely delay it.
            async
              ..elapse(const Duration(minutes: 1))
              ..flushMicrotasks();
            expect(passes(), 1, reason: 'still one pass — the tick coalesced');

            gate.complete();
            async.flushMicrotasks();

            // Re-run happens on completion, without waiting for another tick.
            expect(passes(), 2);

            manager.stop();
          });
        });
      });

      test(
        'several triggers during one pass coalesce into a single re-run',
        () {
          final now = DateTime(2024, 3, 15, 10, 30);

          fakeAsync((async) {
            withClock(Clock.fixed(now), () {
              final gate = Completer<void>();
              final passes = gatedDueQuery(gate, [0]);

              final manager = createAndStart();
              async
                ..flushMicrotasks()
                ..elapse(const Duration(minutes: 3))
                ..flushMicrotasks();

              gate.complete();
              async.flushMicrotasks();

              // Three ticks were absorbed; the point is to answer them, not to
              // replay one pass per dropped trigger.
              expect(passes(), 2);

              manager.stop();
            });
          });
        },
      );

      test('a stop during the pass cancels the queued re-run', () {
        final now = DateTime(2024, 3, 15, 10, 30);

        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            final gate = Completer<void>();
            final passes = gatedDueQuery(gate, [0]);

            final manager = createAndStart();
            async
              ..flushMicrotasks()
              ..elapse(const Duration(minutes: 1))
              ..flushMicrotasks();

            // The generation the re-run was queued under is gone; a restarted
            // manager owns the schedule from here.
            manager.stop();
            gate.complete();
            async.flushMicrotasks();

            expect(passes(), 1);
          });
        });
      });
    });

    group('beforeCheck', () {
      test('runs before every due-record pass, not just the first', () {
        final now = DateTime(2024, 3, 15, 10, 30);
        final calls = <String>[];

        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
              (_) async {
                calls.add('due');
                return <AgentStateEntity>[];
              },
            );

            final manager = ScheduledWakeManager(
              repository: repository,
              orchestrator: orchestrator,
              syncService: syncService,
              checkInterval: const Duration(minutes: 1),
              beforeCheck: () async => calls.add('before'),
            )..start();
            async.flushMicrotasks();

            // The immediate check must be preceded by the repair, or a day
            // agent about to be retired fires on the very pass that retires it.
            expect(calls, ['before', 'due']);

            async
              ..elapse(const Duration(minutes: 1))
              ..flushMicrotasks();

            // And the hourly tick — the boundary a long-running session
            // crosses — repairs before it fires, too.
            expect(calls, ['before', 'due', 'before', 'due']);

            manager.stop();
          });
        });
      });

      test('an agent it retires does not fire on that same pass', () {
        final now = DateTime(2024, 3, 15, 10, 30);
        final pastSchedule = DateTime(2024, 3, 14, 9);
        var retired = false;

        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
              (_) async => [makeTestState(scheduledWakeAt: pastSchedule)],
            );
            // The repair flips the identity dormant; the lifecycle guard in the
            // pass then reads the post-repair value.
            when(() => repository.getEntity(any())).thenAnswer(
              (_) async => makeTestIdentity(
                lifecycle: retired
                    ? AgentLifecycle.dormant
                    : AgentLifecycle.active,
              ),
            );

            final manager = ScheduledWakeManager(
              repository: repository,
              orchestrator: orchestrator,
              syncService: syncService,
              checkInterval: const Duration(minutes: 1),
              beforeCheck: () async => retired = true,
            )..start();
            async.flushMicrotasks();

            verifyNever(
              () => orchestrator.enqueueManualWake(
                agentId: kTestAgentId,
                reason: any(named: 'reason'),
              ),
            );

            manager.stop();
          });
        });
      });

      test('repeats the pre-check when it crosses local midnight', () {
        // The repair keys on the calendar day; the due query below reads the
        // clock after it. Straddling midnight, those disagree.
        var currentTime = DateTime(2024, 3, 15, 23, 59, 59);
        var calls = 0;

        fakeAsync((async) {
          withClock(Clock(() => currentTime), () {
            when(
              () => repository.getDueScheduledAgentStates(any()),
            ).thenAnswer((_) async => <AgentStateEntity>[]);

            final manager = ScheduledWakeManager(
              repository: repository,
              orchestrator: orchestrator,
              syncService: syncService,
              checkInterval: const Duration(minutes: 1),
              beforeCheck: () async {
                calls++;
                // The first repair runs long enough to cross the boundary.
                if (calls == 1) currentTime = DateTime(2024, 3, 16, 0, 0, 1);
              },
            )..start();
            async.flushMicrotasks();

            // Repeated under the new day, so an agent whose handover expired
            // at midnight is retired before this pass reads what is due.
            expect(calls, 2);

            manager.stop();
          });
        });
      });

      test('does not repeat the pre-check within one local day', () {
        var currentTime = DateTime(2024, 3, 15, 10, 30);
        var calls = 0;

        fakeAsync((async) {
          withClock(Clock(() => currentTime), () {
            when(
              () => repository.getDueScheduledAgentStates(any()),
            ).thenAnswer((_) async => <AgentStateEntity>[]);

            final manager = ScheduledWakeManager(
              repository: repository,
              orchestrator: orchestrator,
              syncService: syncService,
              checkInterval: const Duration(minutes: 1),
              beforeCheck: () async {
                calls++;
                currentTime = DateTime(2024, 3, 15, 10, 31);
              },
            )..start();
            async.flushMicrotasks();

            expect(calls, 1);

            manager.stop();
          });
        });
      });

      test('a stop during the pre-check abandons the pass', () {
        final now = DateTime(2024, 3, 15, 10, 30);

        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            // Created inside the zone: a Completer from the root zone
            // resolves outside it, and `flushMicrotasks` would never run the
            // continuation — the pass would stall before the due query and the
            // test would pass without proving anything.
            final gate = Completer<void>();
            when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
              (_) async => [
                makeTestState(scheduledWakeAt: DateTime(2024, 3, 15, 9)),
              ],
            );

            final manager = ScheduledWakeManager(
              repository: repository,
              orchestrator: orchestrator,
              syncService: syncService,
              checkInterval: const Duration(minutes: 1),
              beforeCheck: () => gate.future,
            )..start();
            async.flushMicrotasks();

            // The stop lands while the repair is still awaiting.
            manager.stop();
            gate.complete();
            async.flushMicrotasks();

            // A disposed pass that carried on would enqueue against the
            // manager that replaced it.
            verifyNever(() => repository.getDueScheduledAgentStates(any()));
            verifyNever(
              () => orchestrator.enqueueManualWake(
                agentId: any(named: 'agentId'),
                reason: any(named: 'reason'),
              ),
            );
          });
        });
      });

      test('a failing pre-check does not strand the due records', () {
        final now = DateTime(2024, 3, 15, 10, 30);
        final pastSchedule = DateTime(2024, 3, 15, 9);

        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
              (_) async => [makeTestState(scheduledWakeAt: pastSchedule)],
            );

            final manager = ScheduledWakeManager(
              repository: repository,
              orchestrator: orchestrator,
              syncService: syncService,
              checkInterval: const Duration(minutes: 1),
              beforeCheck: () async => throw Exception('retirement failed'),
            )..start();
            async.flushMicrotasks();

            // Stale retirement costs one wake; skipping the pass would strand
            // every genuinely due record behind it.
            verify(
              () => orchestrator.enqueueManualWake(
                agentId: kTestAgentId,
                reason: WakeReason.scheduled.name,
              ),
            ).called(1);

            manager.stop();
          });
        });
      });
    });
  });
}
