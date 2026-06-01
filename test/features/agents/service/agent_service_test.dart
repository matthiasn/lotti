import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

enum _GeneratedAgentKindSlot { task, project, improver, custom }

enum _GeneratedAgentConfigSlot { defaultConfig, customModel, profile }

enum _GeneratedAgentCategoriesSlot { empty, single, duplicate, pair }

enum _GeneratedAgentLookupSlot {
  missing,
  wrongType,
  active,
  dormant,
  destroyed,
}

enum _GeneratedAgentLifecycleOperation { pause, resume, destroy, delete }

class _GeneratedAgentCreateScenario {
  const _GeneratedAgentCreateScenario({
    required this.kindSlot,
    required this.configSlot,
    required this.categoriesSlot,
  });

  final _GeneratedAgentKindSlot kindSlot;
  final _GeneratedAgentConfigSlot configSlot;
  final _GeneratedAgentCategoriesSlot categoriesSlot;

  String get kind {
    return switch (kindSlot) {
      _GeneratedAgentKindSlot.task => 'task_agent',
      _GeneratedAgentKindSlot.project => 'project_agent',
      _GeneratedAgentKindSlot.improver => 'template_improver',
      _GeneratedAgentKindSlot.custom => 'generated_custom_agent',
    };
  }

  String get displayName => 'Generated ${kindSlot.name} agent';

  AgentConfig get config {
    return switch (configSlot) {
      _GeneratedAgentConfigSlot.defaultConfig => const AgentConfig(),
      _GeneratedAgentConfigSlot.customModel => const AgentConfig(
        modelId: 'models/generated-custom',
        maxTurnsPerWake: 7,
      ),
      _GeneratedAgentConfigSlot.profile => const AgentConfig(
        profileId: 'generated-profile',
        maxTurnsPerWake: 13,
      ),
    };
  }

  Set<String> get allowedCategoryIds {
    return switch (categoriesSlot) {
      _GeneratedAgentCategoriesSlot.empty => const <String>{},
      _GeneratedAgentCategoriesSlot.single => {'generated-cat-1'},
      _GeneratedAgentCategoriesSlot.duplicate => {'generated-cat-1'},
      _GeneratedAgentCategoriesSlot.pair => {
        'generated-cat-1',
        'generated-cat-2',
      },
    };
  }

  @override
  String toString() {
    return '_GeneratedAgentCreateScenario('
        'kindSlot: $kindSlot, configSlot: $configSlot, '
        'categoriesSlot: $categoriesSlot)';
  }
}

class _GeneratedAgentLifecycleScenario {
  const _GeneratedAgentLifecycleScenario({
    required this.lookupSlot,
    required this.operation,
  });

  final _GeneratedAgentLookupSlot lookupSlot;
  final _GeneratedAgentLifecycleOperation operation;

  bool get hasIdentity =>
      lookupSlot == _GeneratedAgentLookupSlot.active ||
      lookupSlot == _GeneratedAgentLookupSlot.dormant ||
      lookupSlot == _GeneratedAgentLookupSlot.destroyed;

  AgentDomainEntity? get lookupEntity {
    return switch (lookupSlot) {
      _GeneratedAgentLookupSlot.missing => null,
      _GeneratedAgentLookupSlot.wrongType => makeTestState(
        id: 'generated-agent',
        agentId: 'generated-agent',
      ),
      _GeneratedAgentLookupSlot.active => makeTestIdentity(
        id: 'generated-agent',
        agentId: 'generated-agent',
      ),
      _GeneratedAgentLookupSlot.dormant => makeTestIdentity(
        id: 'generated-agent',
        agentId: 'generated-agent',
        lifecycle: AgentLifecycle.dormant,
      ),
      _GeneratedAgentLookupSlot.destroyed => makeTestIdentity(
        id: 'generated-agent',
        agentId: 'generated-agent',
        lifecycle: AgentLifecycle.destroyed,
      ),
    };
  }

  AgentIdentityEntity? get identity {
    final entity = lookupEntity;
    return entity is AgentIdentityEntity ? entity : null;
  }

  bool get expectsLifecycleWrite {
    return switch (operation) {
      _GeneratedAgentLifecycleOperation.pause ||
      _GeneratedAgentLifecycleOperation.resume ||
      _GeneratedAgentLifecycleOperation.destroy => hasIdentity,
      _GeneratedAgentLifecycleOperation.delete =>
        hasIdentity && identity!.lifecycle != AgentLifecycle.destroyed,
    };
  }

  bool get expectsRemoveSubscriptions {
    return switch (operation) {
      _GeneratedAgentLifecycleOperation.pause ||
      _GeneratedAgentLifecycleOperation.destroy => hasIdentity,
      _GeneratedAgentLifecycleOperation.resume => false,
      _GeneratedAgentLifecycleOperation.delete => true,
    };
  }

  bool get expectsHardDelete =>
      operation == _GeneratedAgentLifecycleOperation.delete;

  AgentLifecycle? get expectedLifecycle {
    return switch (operation) {
      _GeneratedAgentLifecycleOperation.pause => AgentLifecycle.dormant,
      _GeneratedAgentLifecycleOperation.resume => AgentLifecycle.active,
      _GeneratedAgentLifecycleOperation.destroy ||
      _GeneratedAgentLifecycleOperation.delete =>
        expectsLifecycleWrite ? AgentLifecycle.destroyed : null,
    };
  }

  bool get expectedBoolResult {
    return operation != _GeneratedAgentLifecycleOperation.delete && hasIdentity;
  }

  Future<Object?> run(AgentService service, String agentId) {
    return switch (operation) {
      _GeneratedAgentLifecycleOperation.pause => service.pauseAgent(agentId),
      _GeneratedAgentLifecycleOperation.resume => service.resumeAgent(agentId),
      _GeneratedAgentLifecycleOperation.destroy => service.destroyAgent(
        agentId,
      ),
      _GeneratedAgentLifecycleOperation.delete => service.deleteAgent(agentId),
    };
  }

  @override
  String toString() {
    return '_GeneratedAgentLifecycleScenario('
        'lookupSlot: $lookupSlot, operation: $operation)';
  }
}

extension _AnyGeneratedAgentServiceScenario on glados.Any {
  glados.Generator<_GeneratedAgentKindSlot> get agentKindSlot =>
      glados.AnyUtils(this).choose(_GeneratedAgentKindSlot.values);

  glados.Generator<_GeneratedAgentConfigSlot> get agentConfigSlot =>
      glados.AnyUtils(this).choose(_GeneratedAgentConfigSlot.values);

  glados.Generator<_GeneratedAgentCategoriesSlot> get agentCategoriesSlot =>
      glados.AnyUtils(this).choose(_GeneratedAgentCategoriesSlot.values);

  glados.Generator<_GeneratedAgentLookupSlot> get agentLookupSlot =>
      glados.AnyUtils(this).choose(_GeneratedAgentLookupSlot.values);

  glados.Generator<_GeneratedAgentLifecycleOperation>
  get agentLifecycleOperation =>
      glados.AnyUtils(this).choose(_GeneratedAgentLifecycleOperation.values);

  glados.Generator<_GeneratedAgentCreateScenario> get agentCreateScenario =>
      glados.CombinableAny(this).combine3(
        agentKindSlot,
        agentConfigSlot,
        agentCategoriesSlot,
        (
          _GeneratedAgentKindSlot kindSlot,
          _GeneratedAgentConfigSlot configSlot,
          _GeneratedAgentCategoriesSlot categoriesSlot,
        ) => _GeneratedAgentCreateScenario(
          kindSlot: kindSlot,
          configSlot: configSlot,
          categoriesSlot: categoriesSlot,
        ),
      );

  glados.Generator<_GeneratedAgentLifecycleScenario>
  get agentLifecycleScenario => glados.CombinableAny(this).combine2(
    agentLookupSlot,
    agentLifecycleOperation,
    (
      _GeneratedAgentLookupSlot lookupSlot,
      _GeneratedAgentLifecycleOperation operation,
    ) => _GeneratedAgentLifecycleScenario(
      lookupSlot: lookupSlot,
      operation: operation,
    ),
  );
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository mockRepository;
  late MockWakeOrchestrator mockOrchestrator;
  late MockAgentSyncService mockSyncService;
  late AgentService service;
  late List<String> notifiedAgentIds;

  setUp(() {
    mockRepository = MockAgentRepository();
    mockOrchestrator = MockWakeOrchestrator();
    mockSyncService = MockAgentSyncService();
    notifiedAgentIds = [];

    // Stub syncService write methods
    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockSyncService.upsertLink(any())).thenAnswer((_) async {});

    service = AgentService(
      repository: mockRepository,
      orchestrator: mockOrchestrator,
      syncService: mockSyncService,
      onPersistedStateChanged: notifiedAgentIds.add,
    );
  });

  group('AgentService', () {
    group('createAgent', () {
      glados.Glados(
        glados.any.agentCreateScenario,
        glados.ExploreConfig(numRuns: 120),
      ).test('matches generated identity/state/link invariants', (
        scenario,
      ) async {
        final generatedRepository = MockAgentRepository();
        final generatedOrchestrator = MockWakeOrchestrator();
        final generatedSyncService = MockAgentSyncService();
        final generatedService = AgentService(
          repository: generatedRepository,
          orchestrator: generatedOrchestrator,
          syncService: generatedSyncService,
        );
        final testDate = DateTime(2026, 4, 24, 10, 30);

        when(
          () => generatedSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => generatedSyncService.upsertLink(any()),
        ).thenAnswer((_) async {});

        final identity = await withClock(Clock.fixed(testDate), () {
          return generatedService.createAgent(
            kind: scenario.kind,
            displayName: scenario.displayName,
            config: scenario.config,
            allowedCategoryIds: scenario.allowedCategoryIds,
          );
        });

        final entityWrites = verify(
          () => generatedSyncService.upsertEntity(captureAny()),
        ).captured.cast<AgentDomainEntity>();
        expect(entityWrites, hasLength(2), reason: '$scenario');

        final savedIdentity = entityWrites.first as AgentIdentityEntity;
        final savedState = entityWrites.last as AgentStateEntity;
        expect(identity, savedIdentity, reason: '$scenario');
        expect(savedIdentity.id, isNotEmpty, reason: '$scenario');
        expect(savedIdentity.id, savedIdentity.agentId, reason: '$scenario');
        expect(savedIdentity.kind, scenario.kind, reason: '$scenario');
        expect(
          savedIdentity.displayName,
          scenario.displayName,
          reason: '$scenario',
        );
        expect(
          savedIdentity.lifecycle,
          AgentLifecycle.active,
          reason: '$scenario',
        );
        expect(
          savedIdentity.mode,
          AgentInteractionMode.autonomous,
          reason: '$scenario',
        );
        expect(
          savedIdentity.allowedCategoryIds,
          scenario.allowedCategoryIds,
          reason: '$scenario',
        );
        expect(savedIdentity.config, scenario.config, reason: '$scenario');
        expect(savedIdentity.createdAt, testDate, reason: '$scenario');
        expect(savedIdentity.updatedAt, testDate, reason: '$scenario');
        expect(savedIdentity.destroyedAt, isNull, reason: '$scenario');
        expect(
          savedIdentity.currentStateId,
          savedState.id,
          reason: '$scenario',
        );

        expect(savedState.id, isNotEmpty, reason: '$scenario');
        expect(savedState.agentId, savedIdentity.agentId, reason: '$scenario');
        expect(savedState.revision, 0, reason: '$scenario');
        expect(savedState.slots, const AgentSlots(), reason: '$scenario');
        expect(savedState.updatedAt, testDate, reason: '$scenario');
        expect(savedState.vectorClock, isNull, reason: '$scenario');

        final linkWrites = verify(
          () => generatedSyncService.upsertLink(captureAny()),
        ).captured.cast<AgentLink>();
        expect(linkWrites, hasLength(1), reason: '$scenario');
        final stateLink = linkWrites.single as AgentStateLink;
        expect(stateLink.id, isNotEmpty, reason: '$scenario');
        expect(stateLink.fromId, savedIdentity.agentId, reason: '$scenario');
        expect(stateLink.toId, savedState.id, reason: '$scenario');
        expect(stateLink.createdAt, testDate, reason: '$scenario');
        expect(stateLink.updatedAt, testDate, reason: '$scenario');
        expect(stateLink.vectorClock, isNull, reason: '$scenario');
      }, tags: 'glados');

      test(
        'creates identity, state, and link, then returns identity',
        () async {
          final identity = await service.createAgent(
            kind: 'task_agent',
            displayName: 'Test Agent',
            config: const AgentConfig(),
            allowedCategoryIds: {'cat-1', 'cat-2'},
          );

          expect(identity, isA<AgentIdentityEntity>());
          expect(identity.kind, 'task_agent');
          expect(identity.displayName, 'Test Agent');
          expect(identity.lifecycle, AgentLifecycle.active);
          expect(identity.mode, AgentInteractionMode.autonomous);
          expect(identity.allowedCategoryIds, {'cat-1', 'cat-2'});
          expect(identity.config, const AgentConfig());
          expect(identity.id, identity.agentId);

          // Verify identity entity was persisted
          final identityCalls = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;
          expect(identityCalls, hasLength(2));

          final savedIdentity = identityCalls[0] as AgentIdentityEntity;
          expect(savedIdentity.kind, 'task_agent');
          expect(savedIdentity.displayName, 'Test Agent');

          final savedState = identityCalls[1] as AgentStateEntity;
          expect(savedState.agentId, identity.agentId);
          expect(savedState.revision, 0);
          expect(savedState.slots, const AgentSlots());

          // Verify link was created
          verify(() => mockSyncService.upsertLink(any())).called(1);
        },
      );

      test('creates identity with default empty allowedCategoryIds', () async {
        final identity = await service.createAgent(
          kind: 'task_agent',
          displayName: 'Agent No Categories',
          config: const AgentConfig(),
        );

        expect(identity.allowedCategoryIds, isEmpty);
      });

      test(
        'creates state with currentStateId matching state entity id',
        () async {
          final identity = await service.createAgent(
            kind: 'task_agent',
            displayName: 'Agent',
            config: const AgentConfig(),
          );

          final calls = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;
          final savedState = calls[1] as AgentStateEntity;

          expect(identity.currentStateId, savedState.id);
        },
      );
    });

    group('getAgent', () {
      test('returns identity for existing agent', () async {
        final identity = makeTestIdentity(id: 'agent-1', agentId: 'agent-1');

        when(
          () => mockRepository.getEntity('agent-1'),
        ).thenAnswer((_) async => identity);

        final result = await service.getAgent('agent-1');

        expect(result, isNotNull);
        expect(result!.id, 'agent-1');
        expect(result.kind, 'task_agent');
        expect(result.displayName, 'Test Agent');
      });

      test('returns null for non-existent agent', () async {
        when(
          () => mockRepository.getEntity('non-existent'),
        ).thenAnswer((_) async => null);

        final result = await service.getAgent('non-existent');

        expect(result, isNull);
      });

      test('returns null when entity is not an agent identity', () async {
        final stateEntity = AgentDomainEntity.agentState(
          id: 'state-1',
          agentId: 'agent-1',
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        when(
          () => mockRepository.getEntity('state-1'),
        ).thenAnswer((_) async => stateEntity);

        final result = await service.getAgent('state-1');

        expect(result, isNull);
      });
    });

    group('listAgents', () {
      test('returns all agents from repository', () async {
        when(
          () => mockRepository.getAllAgentIdentities(),
        ).thenAnswer((_) async => <AgentIdentityEntity>[]);

        final result = await service.listAgents();

        expect(result, isEmpty);
        verify(() => mockRepository.getAllAgentIdentities()).called(1);
      });

      test('filters by lifecycle when provided', () async {
        final activeAgent = makeTestIdentity(
          id: 'a1',
          agentId: 'a1',
          displayName: 'Active',
        );
        final dormantAgent = makeTestIdentity(
          id: 'a2',
          agentId: 'a2',
          displayName: 'Dormant',
          lifecycle: AgentLifecycle.dormant,
        );

        when(
          () => mockRepository.getAllAgentIdentities(),
        ).thenAnswer((_) async => [activeAgent, dormantAgent]);

        final result = await service.listAgents(
          lifecycle: AgentLifecycle.active,
        );

        expect(result, hasLength(1));
        expect(result.first.id, 'a1');
      });
    });

    group('getAgentReport', () {
      test('delegates to repository with default scope', () async {
        final report =
            AgentDomainEntity.agentReport(
                  id: 'report-1',
                  agentId: 'agent-1',
                  scope: 'current',
                  createdAt: DateTime(2024, 3, 15),
                  vectorClock: null,
                  content: 'All good',
                )
                as AgentReportEntity;

        when(
          () => mockRepository.getLatestReport('agent-1', 'current'),
        ).thenAnswer((_) async => report);

        final result = await service.getAgentReport('agent-1');

        expect(result, isNotNull);
        expect(result!.id, 'report-1');
        expect(result.scope, 'current');
        expect(result.content, 'All good');
        verify(
          () => mockRepository.getLatestReport('agent-1', 'current'),
        ).called(1);
      });

      test('delegates to repository with custom scope', () async {
        when(
          () => mockRepository.getLatestReport('agent-1', 'weekly'),
        ).thenAnswer((_) async => null);

        final result = await service.getAgentReport('agent-1', 'weekly');

        expect(result, isNull);
        verify(
          () => mockRepository.getLatestReport('agent-1', 'weekly'),
        ).called(1);
      });
    });

    group('cancelPendingWake', () {
      test('clears throttle and removes queued jobs for the agent', () {
        final queue = WakeQueue()
          ..enqueue(
            WakeJob(
              runKey: 'run-1',
              agentId: 'agent-1',
              reason: 'subscription',
              triggerTokens: {'task-1'},
              createdAt: kAgentTestDate,
            ),
          );

        when(() => mockOrchestrator.clearThrottle('agent-1')).thenReturn(null);
        when(() => mockOrchestrator.queue).thenReturn(queue);

        expect(queue.removeByAgent('agent-1'), hasLength(1));
        queue.enqueue(
          WakeJob(
            runKey: 'run-1',
            agentId: 'agent-1',
            reason: 'subscription',
            triggerTokens: {'task-1'},
            createdAt: kAgentTestDate,
          ),
        );

        service.cancelPendingWake('agent-1');

        verify(() => mockOrchestrator.clearThrottle('agent-1')).called(1);
        expect(queue.removeByAgent('agent-1'), isEmpty);
      });
    });

    group('abortRunningWake', () {
      test(
        'returns true when the orchestrator signals an in-flight run',
        () {
          when(
            () => mockOrchestrator.abortRunningWake('agent-1'),
          ).thenReturn(true);

          final aborted = service.abortRunningWake('agent-1');

          expect(aborted, isTrue);
          verify(() => mockOrchestrator.abortRunningWake('agent-1')).called(1);
        },
      );

      test(
        'returns false when the agent is not currently running '
        '(orchestrator returns false on a no-op abort)',
        () {
          when(
            () => mockOrchestrator.abortRunningWake('agent-cold'),
          ).thenReturn(false);

          final aborted = service.abortRunningWake('agent-cold');

          expect(aborted, isFalse);
          verify(
            () => mockOrchestrator.abortRunningWake('agent-cold'),
          ).called(1);
        },
      );
    });

    group('clearScheduledWake', () {
      test('persists state with scheduledWakeAt cleared', () async {
        final state = makeTestState(
          agentId: 'agent-1',
          scheduledWakeAt: kAgentTestDate.add(const Duration(hours: 2)),
        );

        when(
          () => mockRepository.getAgentState('agent-1'),
        ).thenAnswer((_) async => state);

        await service.clearScheduledWake('agent-1');

        final captured =
            verify(
                  () => mockSyncService.upsertEntity(captureAny()),
                ).captured.last
                as AgentStateEntity;
        expect(captured.scheduledWakeAt, isNull);
        expect(notifiedAgentIds, ['agent-1']);
      });

      test('does nothing when no state exists', () async {
        when(
          () => mockRepository.getAgentState('missing'),
        ).thenAnswer((_) async => null);

        await service.clearScheduledWake('missing');

        verifyNever(() => mockSyncService.upsertEntity(any()));
      });
    });

    group('pauseAgent', () {
      glados.Glados(
        glados.any.agentLifecycleScenario,
        glados.ExploreConfig(numRuns: 160),
      ).test('matches generated lifecycle/delete invariants', (scenario) async {
        final generatedRepository = MockAgentRepository();
        final generatedOrchestrator = MockWakeOrchestrator();
        final generatedSyncService = MockAgentSyncService();
        final generatedService = AgentService(
          repository: generatedRepository,
          orchestrator: generatedOrchestrator,
          syncService: generatedSyncService,
        );
        final testDate = DateTime(2026, 4, 24, 11, 15);
        const agentId = 'generated-agent';

        when(
          () => generatedRepository.getEntity(agentId),
        ).thenAnswer((_) async => scenario.lookupEntity);
        when(
          () => generatedSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => generatedOrchestrator.removeSubscriptions(agentId),
        ).thenReturn(null);
        when(
          () => generatedRepository.hardDeleteAgent(agentId),
        ).thenAnswer((_) async {});

        final result = await withClock(Clock.fixed(testDate), () {
          return scenario.run(generatedService, agentId);
        });

        if (scenario.operation != _GeneratedAgentLifecycleOperation.delete) {
          expect(result, scenario.expectedBoolResult, reason: '$scenario');
        } else {
          expect(result, isNull, reason: '$scenario');
        }

        if (scenario.expectsLifecycleWrite) {
          final writes = verify(
            () => generatedSyncService.upsertEntity(captureAny()),
          ).captured.cast<AgentDomainEntity>();
          expect(writes, hasLength(1), reason: '$scenario');
          final updated = writes.single as AgentIdentityEntity;
          expect(updated.id, agentId, reason: '$scenario');
          expect(
            updated.lifecycle,
            scenario.expectedLifecycle,
            reason: '$scenario',
          );
          expect(updated.updatedAt, testDate, reason: '$scenario');
          if (scenario.expectedLifecycle == AgentLifecycle.destroyed) {
            expect(updated.destroyedAt, testDate, reason: '$scenario');
          } else {
            expect(updated.destroyedAt, isNull, reason: '$scenario');
          }
        } else {
          verifyNever(() => generatedSyncService.upsertEntity(any()));
        }

        if (scenario.expectsRemoveSubscriptions) {
          verify(
            () => generatedOrchestrator.removeSubscriptions(agentId),
          ).called(1);
        } else {
          verifyNever(
            () => generatedOrchestrator.removeSubscriptions(agentId),
          );
        }

        if (scenario.expectsHardDelete) {
          verify(() => generatedRepository.hardDeleteAgent(agentId)).called(1);
        } else {
          verifyNever(() => generatedRepository.hardDeleteAgent(agentId));
        }
      }, tags: 'glados');

      test('sets lifecycle to dormant and unregisters subscriptions', () async {
        final identity = makeTestIdentity(id: 'agent-1', agentId: 'agent-1');

        when(
          () => mockRepository.getEntity('agent-1'),
        ).thenAnswer((_) async => identity);
        // syncService stubs set up in setUp
        when(
          () => mockOrchestrator.removeSubscriptions('agent-1'),
        ).thenReturn(null);

        final result = await service.pauseAgent('agent-1');

        expect(result, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final updated = captured.first as AgentIdentityEntity;
        expect(updated.lifecycle, AgentLifecycle.dormant);
        expect(updated.destroyedAt, isNull);

        verify(() => mockOrchestrator.removeSubscriptions('agent-1')).called(1);
      });
    });

    group('resumeAgent', () {
      test('sets lifecycle to active and returns true', () async {
        final identity = makeTestIdentity(
          id: 'agent-1',
          agentId: 'agent-1',
          lifecycle: AgentLifecycle.dormant,
        );

        when(
          () => mockRepository.getEntity('agent-1'),
        ).thenAnswer((_) async => identity);
        // syncService stubs set up in setUp

        final result = await service.resumeAgent('agent-1');

        expect(result, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final updated = captured.first as AgentIdentityEntity;
        expect(updated.lifecycle, AgentLifecycle.active);
        expect(updated.destroyedAt, isNull);
      });
    });

    group('destroyAgent', () {
      test('sets lifecycle to destroyed, sets destroyedAt, '
          'and unregisters subscriptions', () async {
        final identity = makeTestIdentity(id: 'agent-1', agentId: 'agent-1');

        when(
          () => mockRepository.getEntity('agent-1'),
        ).thenAnswer((_) async => identity);
        // syncService stubs set up in setUp
        when(
          () => mockOrchestrator.removeSubscriptions('agent-1'),
        ).thenReturn(null);

        final result = await service.destroyAgent('agent-1');

        expect(result, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final updated = captured.first as AgentIdentityEntity;
        expect(updated.lifecycle, AgentLifecycle.destroyed);
        expect(updated.destroyedAt, isNotNull);

        verify(() => mockOrchestrator.removeSubscriptions('agent-1')).called(1);
      });
    });

    // Consolidated: all three lifecycle methods return false for missing agents.
    for (final entry in <String, Future<bool> Function(AgentService, String)>{
      'pauseAgent': (s, id) => s.pauseAgent(id),
      'resumeAgent': (s, id) => s.resumeAgent(id),
      'destroyAgent': (s, id) => s.destroyAgent(id),
    }.entries) {
      test('${entry.key} returns false for non-existent agent', () async {
        when(
          () => mockRepository.getEntity('non-existent'),
        ).thenAnswer((_) async => null);

        final result = await entry.value(service, 'non-existent');

        expect(result, isFalse);
        verifyNever(() => mockSyncService.upsertEntity(any()));
      });
    }

    group('deleteAgent', () {
      test(
        'destroys agent first if not already destroyed, then hard-deletes',
        () async {
          final identity = makeTestIdentity(id: 'agent-1', agentId: 'agent-1');

          when(
            () => mockRepository.getEntity('agent-1'),
          ).thenAnswer((_) async => identity);
          // syncService stubs set up in setUp
          when(
            () => mockOrchestrator.removeSubscriptions('agent-1'),
          ).thenReturn(null);
          when(
            () => mockRepository.hardDeleteAgent('agent-1'),
          ).thenAnswer((_) async {});

          await service.deleteAgent('agent-1');

          // destroyAgent path: upsertEntity called with destroyed lifecycle
          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;
          expect(captured, hasLength(1));
          final updated = captured.first as AgentIdentityEntity;
          expect(updated.lifecycle, AgentLifecycle.destroyed);
          expect(updated.destroyedAt, isNotNull);

          // subscriptions removed via destroyAgent
          verify(
            () => mockOrchestrator.removeSubscriptions('agent-1'),
          ).called(1);

          // hard-delete called after destroy
          verify(() => mockRepository.hardDeleteAgent('agent-1')).called(1);
        },
      );

      test('skips lifecycle update for already-destroyed agent', () async {
        final destroyedIdentity = makeTestIdentity(
          id: 'agent-2',
          agentId: 'agent-2',
          displayName: 'Destroyed Agent',
          lifecycle: AgentLifecycle.destroyed,
        );

        when(
          () => mockRepository.getEntity('agent-2'),
        ).thenAnswer((_) async => destroyedIdentity);
        when(
          () => mockOrchestrator.removeSubscriptions('agent-2'),
        ).thenReturn(null);
        when(
          () => mockRepository.hardDeleteAgent('agent-2'),
        ).thenAnswer((_) async {});

        await service.deleteAgent('agent-2');

        // no lifecycle update for an already-destroyed agent
        verifyNever(() => mockSyncService.upsertEntity(any()));

        // subscriptions still removed
        verify(() => mockOrchestrator.removeSubscriptions('agent-2')).called(1);

        // hard-delete still called
        verify(() => mockRepository.hardDeleteAgent('agent-2')).called(1);
      });

      test('handles non-existent agent gracefully', () async {
        when(
          () => mockRepository.getEntity('non-existent'),
        ).thenAnswer((_) async => null);
        when(
          () => mockOrchestrator.removeSubscriptions('non-existent'),
        ).thenReturn(null);
        when(
          () => mockRepository.hardDeleteAgent('non-existent'),
        ).thenAnswer((_) async {});

        await service.deleteAgent('non-existent');

        // no lifecycle update when agent not found
        verifyNever(() => mockSyncService.upsertEntity(any()));

        // subscriptions removed even when agent not found
        verify(
          () => mockOrchestrator.removeSubscriptions('non-existent'),
        ).called(1);

        // hard-delete still called
        verify(() => mockRepository.hardDeleteAgent('non-existent')).called(1);
      });
    });
  });
}
