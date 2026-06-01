import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/database/agent_repository_exception.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/improver_slot_keys.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/improver_agent_service.dart';
import 'package:lotti/features/sync/g_counter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

enum _GeneratedImproverTargetSlot { present, missing }

enum _GeneratedExistingImproverSlot { none, staleLink, active }

enum _GeneratedImproverTemplateSlot {
  defaultPresent,
  defaultMissing,
  overridePresent,
  overrideMissing,
}

enum _GeneratedImproverStateSlot { present, missing }

enum _GeneratedImproverInsertSlot { succeeds, duplicate }

enum _GeneratedImproverDisplaySlot { defaultName, customName }

enum _GeneratedImproverRecursionSlot {
  depth0,
  depth1,
  maxDepth,
  negative,
  tooDeep,
}

class _GeneratedImproverAgentCreateScenario {
  const _GeneratedImproverAgentCreateScenario({
    required this.targetSlot,
    required this.existingSlot,
    required this.improverTemplateSlot,
    required this.stateSlot,
    required this.insertSlot,
    required this.displaySlot,
    required this.recursionSlot,
  });

  final _GeneratedImproverTargetSlot targetSlot;
  final _GeneratedExistingImproverSlot existingSlot;
  final _GeneratedImproverTemplateSlot improverTemplateSlot;
  final _GeneratedImproverStateSlot stateSlot;
  final _GeneratedImproverInsertSlot insertSlot;
  final _GeneratedImproverDisplaySlot displaySlot;
  final _GeneratedImproverRecursionSlot recursionSlot;

  bool get recursionIsValid {
    final depth = recursionDepth;
    return depth >= 0 && depth <= ImproverSlotDefaults.maxRecursionDepth;
  }

  bool get targetExists => targetSlot == _GeneratedImproverTargetSlot.present;

  bool get existingImproverExists =>
      existingSlot == _GeneratedExistingImproverSlot.active;

  bool get improverTemplateExists {
    return switch (improverTemplateSlot) {
      _GeneratedImproverTemplateSlot.defaultPresent ||
      _GeneratedImproverTemplateSlot.overridePresent => true,
      _GeneratedImproverTemplateSlot.defaultMissing ||
      _GeneratedImproverTemplateSlot.overrideMissing => false,
    };
  }

  bool get stateExists => stateSlot == _GeneratedImproverStateSlot.present;

  bool get insertSucceeds =>
      insertSlot == _GeneratedImproverInsertSlot.succeeds;

  bool get shouldCreateAgent =>
      recursionIsValid &&
      targetExists &&
      !existingImproverExists &&
      improverTemplateExists;

  bool get shouldWriteState => shouldCreateAgent && stateExists;

  bool get shouldSucceed => shouldWriteState && insertSucceeds;

  String? get overrideImproverTemplateId {
    return switch (improverTemplateSlot) {
      _GeneratedImproverTemplateSlot.defaultPresent ||
      _GeneratedImproverTemplateSlot.defaultMissing => null,
      _GeneratedImproverTemplateSlot.overridePresent ||
      _GeneratedImproverTemplateSlot.overrideMissing =>
        'generated-override-improver-template',
    };
  }

  String get resolvedImproverTemplateId =>
      overrideImproverTemplateId ?? improverTemplateId;

  String? get displayName {
    return switch (displaySlot) {
      _GeneratedImproverDisplaySlot.defaultName => null,
      _GeneratedImproverDisplaySlot.customName => 'Generated Custom Improver',
    };
  }

  String get expectedDisplayName =>
      displayName ?? 'Generated Target Template Improver';

  int get recursionDepth {
    return switch (recursionSlot) {
      _GeneratedImproverRecursionSlot.depth0 => 0,
      _GeneratedImproverRecursionSlot.depth1 => 1,
      _GeneratedImproverRecursionSlot.maxDepth =>
        ImproverSlotDefaults.maxRecursionDepth,
      _GeneratedImproverRecursionSlot.negative => -1,
      _GeneratedImproverRecursionSlot.tooDeep =>
        ImproverSlotDefaults.maxRecursionDepth + 1,
    };
  }

  int get expectedFeedbackWindowDays {
    return recursionDepth > 0
        ? ImproverSlotDefaults.defaultMetaFeedbackWindowDays
        : ImproverSlotDefaults.defaultFeedbackWindowDays;
  }

  @override
  String toString() {
    return '_GeneratedImproverAgentCreateScenario('
        'targetSlot: $targetSlot, existingSlot: $existingSlot, '
        'improverTemplateSlot: $improverTemplateSlot, '
        'stateSlot: $stateSlot, insertSlot: $insertSlot, '
        'displaySlot: $displaySlot, recursionSlot: $recursionSlot)';
  }
}

extension _AnyGeneratedImproverAgentServiceScenario on glados.Any {
  glados.Generator<_GeneratedImproverTargetSlot> get improverTargetSlot =>
      glados.any.choose(_GeneratedImproverTargetSlot.values);

  glados.Generator<_GeneratedExistingImproverSlot> get existingImproverSlot =>
      glados.any.choose(_GeneratedExistingImproverSlot.values);

  glados.Generator<_GeneratedImproverTemplateSlot> get improverTemplateSlot =>
      glados.any.choose(_GeneratedImproverTemplateSlot.values);

  glados.Generator<_GeneratedImproverStateSlot> get improverStateSlot =>
      glados.any.choose(_GeneratedImproverStateSlot.values);

  glados.Generator<_GeneratedImproverInsertSlot> get improverInsertSlot =>
      glados.any.choose(_GeneratedImproverInsertSlot.values);

  glados.Generator<_GeneratedImproverDisplaySlot> get improverDisplaySlot =>
      glados.any.choose(_GeneratedImproverDisplaySlot.values);

  glados.Generator<_GeneratedImproverRecursionSlot> get improverRecursionSlot =>
      glados.any.choose(_GeneratedImproverRecursionSlot.values);

  glados.Generator<_GeneratedImproverAgentCreateScenario>
  get improverAgentCreateScenario => glados.any.combine7(
    improverTargetSlot,
    existingImproverSlot,
    improverTemplateSlot,
    improverStateSlot,
    improverInsertSlot,
    improverDisplaySlot,
    improverRecursionSlot,
    (
      _GeneratedImproverTargetSlot targetSlot,
      _GeneratedExistingImproverSlot existingSlot,
      _GeneratedImproverTemplateSlot improverTemplateSlot,
      _GeneratedImproverStateSlot stateSlot,
      _GeneratedImproverInsertSlot insertSlot,
      _GeneratedImproverDisplaySlot displaySlot,
      _GeneratedImproverRecursionSlot recursionSlot,
    ) => _GeneratedImproverAgentCreateScenario(
      targetSlot: targetSlot,
      existingSlot: existingSlot,
      improverTemplateSlot: improverTemplateSlot,
      stateSlot: stateSlot,
      insertSlot: insertSlot,
      displaySlot: displaySlot,
      recursionSlot: recursionSlot,
    ),
  );
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentService mockAgentService;
  late MockAgentTemplateService mockTemplateService;
  late MockAgentRepository mockRepository;
  late MockAgentSyncService mockSyncService;
  late MockWakeOrchestrator mockOrchestrator;
  late ImproverAgentService service;
  late List<String> notifiedAgentIds;

  final testDate = DateTime(2024, 3, 15, 10, 30);
  const targetTemplateId = 'target-template-001';

  AgentTemplateEntity makeTargetTemplate({
    String id = 'target-template-001',
    String displayName = 'Laura',
  }) {
    return makeTestTemplate(
      id: id,
      agentId: id,
      displayName: displayName,
    );
  }

  AgentTemplateEntity makeImproverTemplate() {
    return makeTestTemplate(
      id: improverTemplateId,
      agentId: improverTemplateId,
      displayName: 'Template Improver',
    );
  }

  AgentIdentityEntity makeIdentity({
    String agentId = 'improver-agent-1',
    String displayName = 'Laura Improver',
  }) {
    return makeTestIdentity(
      id: agentId,
      agentId: agentId,
      kind: AgentKinds.templateImprover,
      displayName: displayName,
      currentStateId: 'state-$agentId',
    );
  }

  AgentStateEntity makeState({
    String id = 'state-improver-agent-1',
    String agentId = 'improver-agent-1',
    AgentSlots slots = const AgentSlots(),
    DateTime? scheduledWakeAt,
  }) {
    return makeTestState(
      id: id,
      agentId: agentId,
      revision: 0,
      slots: slots,
      scheduledWakeAt: scheduledWakeAt,
    );
  }

  setUp(() {
    mockAgentService = MockAgentService();
    mockTemplateService = MockAgentTemplateService();
    mockRepository = MockAgentRepository();
    mockSyncService = MockAgentSyncService();
    mockOrchestrator = MockWakeOrchestrator();
    notifiedAgentIds = [];

    // Stub syncService write methods.
    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockSyncService.upsertLink(any())).thenAnswer((_) async {});
    when(
      () => mockSyncService.insertLinkExclusive(any()),
    ).thenAnswer((_) async {});

    service = ImproverAgentService(
      agentService: mockAgentService,
      agentTemplateService: mockTemplateService,
      repository: mockRepository,
      syncService: mockSyncService,
      orchestrator: mockOrchestrator,
      onPersistedStateChanged: notifiedAgentIds.add,
    );
  });

  group('ImproverAgentService', () {
    group('createImproverAgent', () {
      glados.Glados(
        glados.any.improverAgentCreateScenario,
        glados.ExploreConfig(numRuns: 260),
      ).test('matches generated create-flow invariants', (scenario) async {
        final generatedAgentService = MockAgentService();
        final generatedTemplateService = MockAgentTemplateService();
        final generatedRepository = MockAgentRepository();
        final generatedSyncService = MockAgentSyncService();
        final generatedOrchestrator = MockWakeOrchestrator();
        final generatedNotifiedAgentIds = <String>[];
        final generatedService = ImproverAgentService(
          agentService: generatedAgentService,
          agentTemplateService: generatedTemplateService,
          repository: generatedRepository,
          syncService: generatedSyncService,
          orchestrator: generatedOrchestrator,
          onPersistedStateChanged: generatedNotifiedAgentIds.add,
        );
        const generatedTargetTemplateId = 'generated-target-template';
        const agentId = 'generated-improver-agent';
        final identity = makeIdentity(agentId: agentId);
        final existingIdentity = makeIdentity(agentId: 'existing-improver');
        final initialState = makeState(
          id: 'state-$agentId',
          agentId: agentId,
          slots: const AgentSlots(activeTemplateId: 'previous-template'),
        );
        final targetTemplate = makeTargetTemplate(
          id: generatedTargetTemplateId,
          displayName: 'Generated Target Template',
        );
        final defaultImproverTemplate = makeTestTemplate(
          id: improverTemplateId,
          agentId: improverTemplateId,
          modelId: 'generated-default-improver-model',
          displayName: 'Generated Default Improver Template',
        );
        final overrideImproverTemplate = makeTestTemplate(
          id: 'generated-override-improver-template',
          agentId: 'generated-override-improver-template',
          modelId: 'generated-override-improver-model',
          displayName: 'Generated Override Improver Template',
        );
        final staleLink = AgentLink.improverTarget(
          id: 'generated-stale-link',
          fromId: 'missing-improver',
          toId: generatedTargetTemplateId,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );
        final activeLink = AgentLink.improverTarget(
          id: 'generated-active-link',
          fromId: existingIdentity.agentId,
          toId: generatedTargetTemplateId,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        when(
          () => generatedSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => generatedSyncService.upsertLink(any()),
        ).thenAnswer((_) async {});
        if (scenario.insertSucceeds) {
          when(
            () => generatedSyncService.insertLinkExclusive(any()),
          ).thenAnswer((_) async {});
        } else {
          when(
            () => generatedSyncService.insertLinkExclusive(any()),
          ).thenThrow(
            const DuplicateInsertException(
              'agent_links',
              generatedTargetTemplateId,
            ),
          );
        }
        when(
          () => generatedTemplateService.getTemplate(
            generatedTargetTemplateId,
          ),
        ).thenAnswer(
          (_) async => scenario.targetExists ? targetTemplate : null,
        );
        when(
          () => generatedRepository.getLinksTo(
            generatedTargetTemplateId,
            type: AgentLinkTypes.improverTarget,
          ),
        ).thenAnswer((_) async {
          return switch (scenario.existingSlot) {
            _GeneratedExistingImproverSlot.none => <AgentLink>[],
            _GeneratedExistingImproverSlot.staleLink => [staleLink],
            _GeneratedExistingImproverSlot.active => [activeLink],
          };
        });
        when(
          () => generatedAgentService.getAgent('missing-improver'),
        ).thenAnswer((_) async => null);
        when(
          () => generatedAgentService.getAgent(existingIdentity.agentId),
        ).thenAnswer((_) async => existingIdentity);
        when(
          () => generatedTemplateService.getTemplate(improverTemplateId),
        ).thenAnswer((_) async {
          return switch (scenario.improverTemplateSlot) {
            _GeneratedImproverTemplateSlot.defaultPresent =>
              defaultImproverTemplate,
            _GeneratedImproverTemplateSlot.defaultMissing => null,
            _ => defaultImproverTemplate,
          };
        });
        when(
          () => generatedTemplateService.getTemplate(
            'generated-override-improver-template',
          ),
        ).thenAnswer((_) async {
          return switch (scenario.improverTemplateSlot) {
            _GeneratedImproverTemplateSlot.overridePresent =>
              overrideImproverTemplate,
            _GeneratedImproverTemplateSlot.overrideMissing => null,
            _ => overrideImproverTemplate,
          };
        });
        when(
          () => generatedAgentService.createAgent(
            kind: any(named: 'kind'),
            displayName: any(named: 'displayName'),
            config: any(named: 'config'),
          ),
        ).thenAnswer((_) async => identity);
        when(
          () => generatedRepository.getAgentState(agentId),
        ).thenAnswer(
          (_) async => scenario.stateExists ? initialState : null,
        );

        Future<AgentIdentityEntity> create() {
          return withClock(Clock.fixed(testDate), () {
            return generatedService.createImproverAgent(
              targetTemplateId: generatedTargetTemplateId,
              overrideImproverTemplateId: scenario.overrideImproverTemplateId,
              displayName: scenario.displayName,
              recursionDepth: scenario.recursionDepth,
            );
          });
        }

        if (!scenario.shouldSucceed) {
          await expectLater(
            create,
            scenario.recursionIsValid
                ? throwsA(isA<StateError>())
                : throwsA(isA<ArgumentError>()),
            reason: '$scenario',
          );

          if (scenario.shouldCreateAgent) {
            verify(
              () => generatedAgentService.createAgent(
                kind: any(named: 'kind'),
                displayName: any(named: 'displayName'),
                config: any(named: 'config'),
              ),
            ).called(1);
          } else {
            verifyNever(
              () => generatedAgentService.createAgent(
                kind: any(named: 'kind'),
                displayName: any(named: 'displayName'),
                config: any(named: 'config'),
              ),
            );
          }

          if (scenario.shouldWriteState) {
            final entityWrites = verify(
              () => generatedSyncService.upsertEntity(captureAny()),
            ).captured;
            expect(entityWrites, hasLength(1), reason: '$scenario');
            final updatedState = entityWrites.single as AgentStateEntity;
            expect(
              updatedState.slots.activeTemplateId,
              generatedTargetTemplateId,
              reason: '$scenario',
            );
            final exclusiveLinks = verify(
              () => generatedSyncService.insertLinkExclusive(captureAny()),
            ).captured;
            expect(exclusiveLinks, hasLength(1), reason: '$scenario');
          } else {
            verifyNever(() => generatedSyncService.upsertEntity(any()));
            verifyNever(() => generatedSyncService.insertLinkExclusive(any()));
          }
          verifyNever(() => generatedSyncService.upsertLink(any()));
          expect(generatedNotifiedAgentIds, isEmpty, reason: '$scenario');
          return;
        }

        final result = await create();

        expect(result, same(identity), reason: '$scenario');
        final createCall = verify(
          () => generatedAgentService.createAgent(
            kind: captureAny(named: 'kind'),
            displayName: captureAny(named: 'displayName'),
            config: captureAny(named: 'config'),
          ),
        ).captured;
        expect(
          createCall[0],
          AgentKinds.templateImprover,
          reason: '$scenario',
        );
        expect(
          createCall[1],
          scenario.expectedDisplayName,
          reason: '$scenario',
        );
        final config = createCall[2] as AgentConfig;
        expect(
          config.modelId,
          switch (scenario.resolvedImproverTemplateId) {
            improverTemplateId => defaultImproverTemplate.modelId,
            'generated-override-improver-template' =>
              overrideImproverTemplate.modelId,
            _ => null,
          },
          reason: '$scenario',
        );

        final entityWrites = verify(
          () => generatedSyncService.upsertEntity(captureAny()),
        ).captured;
        expect(entityWrites, hasLength(1), reason: '$scenario');
        final updatedState = entityWrites.single as AgentStateEntity;
        expect(updatedState.agentId, agentId, reason: '$scenario');
        expect(
          updatedState.slots.activeTemplateId,
          generatedTargetTemplateId,
          reason: '$scenario',
        );
        expect(
          updatedState.slots.feedbackWindowDays,
          scenario.expectedFeedbackWindowDays,
          reason: '$scenario',
        );
        expect(
          updatedState.slots.recursionDepth,
          scenario.recursionDepth,
          reason: '$scenario',
        );
        expect(updatedState.slots.totalSessionsCompleted.value, 0);
        expect(
          updatedState.scheduledWakeAt,
          testDate.add(Duration(days: scenario.expectedFeedbackWindowDays)),
          reason: '$scenario',
        );
        expect(updatedState.updatedAt, testDate, reason: '$scenario');

        final exclusiveLinks = verify(
          () => generatedSyncService.insertLinkExclusive(captureAny()),
        ).captured;
        expect(exclusiveLinks, hasLength(1), reason: '$scenario');
        final improverTargetLink = exclusiveLinks.single as ImproverTargetLink;
        expect(improverTargetLink.fromId, agentId, reason: '$scenario');
        expect(
          improverTargetLink.toId,
          generatedTargetTemplateId,
          reason: '$scenario',
        );

        final linkWrites = verify(
          () => generatedSyncService.upsertLink(captureAny()),
        ).captured;
        expect(linkWrites, hasLength(1), reason: '$scenario');
        final templateLink = linkWrites.single as TemplateAssignmentLink;
        expect(
          templateLink.fromId,
          scenario.resolvedImproverTemplateId,
          reason: '$scenario',
        );
        expect(templateLink.toId, agentId, reason: '$scenario');
        expect(generatedNotifiedAgentIds, [agentId], reason: '$scenario');
      }, tags: 'glados');

      test('creates agent identity, updates state slots, '
          'and creates both links', () async {
        await withClock(Clock.fixed(testDate), () async {
          final identity = makeIdentity();
          final state = makeState();

          // Target template exists.
          when(
            () => mockTemplateService.getTemplate(targetTemplateId),
          ).thenAnswer((_) async => makeTargetTemplate());

          // No existing improver for this template.
          when(
            () => mockRepository.getLinksTo(
              targetTemplateId,
              type: AgentLinkTypes.improverTarget,
            ),
          ).thenAnswer((_) async => []);

          // Improver template exists.
          when(
            () => mockTemplateService.getTemplate(improverTemplateId),
          ).thenAnswer((_) async => makeImproverTemplate());

          // Agent creation.
          when(
            () => mockAgentService.createAgent(
              kind: AgentKinds.templateImprover,
              displayName: 'Laura Improver',
              config: const AgentConfig(),
            ),
          ).thenAnswer((_) async => identity);

          // State retrieval after creation.
          when(
            () => mockRepository.getAgentState(identity.agentId),
          ).thenAnswer((_) async => state);

          final result = await service.createImproverAgent(
            targetTemplateId: targetTemplateId,
          );

          expect(result.agentId, identity.agentId);
          expect(result.kind, AgentKinds.templateImprover);

          // Verify state was updated with improver slots.
          final capturedEntities = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final updatedState = capturedEntities
              .whereType<AgentStateEntity>()
              .first;
          expect(
            updatedState.slots.activeTemplateId,
            targetTemplateId,
          );
          expect(
            updatedState.slots.feedbackWindowDays,
            ImproverSlotDefaults.defaultFeedbackWindowDays,
          );
          expect(updatedState.slots.recursionDepth, 0);
          expect(updatedState.slots.totalSessionsCompleted.value, 0);
          expect(updatedState.scheduledWakeAt, isNotNull);

          // Verify improverTarget link via insertLinkExclusive.
          final capturedExclusive = verify(
            () => mockSyncService.insertLinkExclusive(captureAny()),
          ).captured;
          expect(capturedExclusive, hasLength(1));

          final improverTargetLink = capturedExclusive
              .whereType<ImproverTargetLink>()
              .first;
          expect(improverTargetLink.fromId, identity.agentId);
          expect(improverTargetLink.toId, targetTemplateId);

          // Verify templateAssignment link via upsertLink.
          final capturedLinks = verify(
            () => mockSyncService.upsertLink(captureAny()),
          ).captured;
          expect(capturedLinks, hasLength(1));

          final templateAssignmentLink = capturedLinks
              .whereType<TemplateAssignmentLink>()
              .first;
          expect(templateAssignmentLink.fromId, improverTemplateId);
          expect(templateAssignmentLink.toId, identity.agentId);
          expect(notifiedAgentIds, [identity.agentId]);
        });
      });

      test('sets scheduledWakeAt to now + feedbackWindowDays', () async {
        await withClock(Clock.fixed(testDate), () async {
          final identity = makeIdentity();
          final state = makeState();

          when(
            () => mockTemplateService.getTemplate(targetTemplateId),
          ).thenAnswer((_) async => makeTargetTemplate());
          when(
            () => mockRepository.getLinksTo(
              targetTemplateId,
              type: AgentLinkTypes.improverTarget,
            ),
          ).thenAnswer((_) async => []);
          when(
            () => mockTemplateService.getTemplate(improverTemplateId),
          ).thenAnswer((_) async => makeImproverTemplate());
          when(
            () => mockAgentService.createAgent(
              kind: any(named: 'kind'),
              displayName: any(named: 'displayName'),
              config: any(named: 'config'),
            ),
          ).thenAnswer((_) async => identity);
          when(
            () => mockRepository.getAgentState(identity.agentId),
          ).thenAnswer((_) async => state);

          await service.createImproverAgent(
            targetTemplateId: targetTemplateId,
          );

          final capturedEntities = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final updatedState = capturedEntities
              .whereType<AgentStateEntity>()
              .first;

          final expectedWake = testDate.add(
            const Duration(
              days: ImproverSlotDefaults.defaultFeedbackWindowDays,
            ),
          );
          expect(updatedState.scheduledWakeAt, expectedWake);
          expect(notifiedAgentIds, [identity.agentId]);
        });
      });

      test('throws ArgumentError when recursionDepth is negative', () {
        expect(
          () => service.createImproverAgent(
            targetTemplateId: targetTemplateId,
            recursionDepth: -1,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('must be >= 0'),
            ),
          ),
        );
      });

      test('throws StateError when target template not found', () async {
        when(
          () => mockTemplateService.getTemplate(targetTemplateId),
        ).thenAnswer((_) async => null);

        expect(
          () => service.createImproverAgent(
            targetTemplateId: targetTemplateId,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Target template'),
            ),
          ),
        );
      });

      test('throws StateError when improver already exists '
          'for target template', () async {
        final existingIdentity = makeIdentity(agentId: 'existing-improver');

        when(
          () => mockTemplateService.getTemplate(targetTemplateId),
        ).thenAnswer((_) async => makeTargetTemplate());

        // An improver link already exists.
        when(
          () => mockRepository.getLinksTo(
            targetTemplateId,
            type: AgentLinkTypes.improverTarget,
          ),
        ).thenAnswer(
          (_) async => [
            AgentLink.improverTarget(
              id: 'link-1',
              fromId: existingIdentity.agentId,
              toId: targetTemplateId,
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
          ],
        );

        when(
          () => mockAgentService.getAgent(existingIdentity.agentId),
        ).thenAnswer((_) async => existingIdentity);

        expect(
          () => service.createImproverAgent(
            targetTemplateId: targetTemplateId,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('already exists'),
            ),
          ),
        );
      });

      test('throws StateError on concurrent creation '
          '(DB unique constraint)', () async {
        await withClock(Clock.fixed(testDate), () async {
          final identity = makeIdentity();
          final state = makeState();

          when(
            () => mockTemplateService.getTemplate(targetTemplateId),
          ).thenAnswer((_) async => makeTargetTemplate());
          // No improver found in initial check (TOCTOU gap).
          when(
            () => mockRepository.getLinksTo(
              targetTemplateId,
              type: AgentLinkTypes.improverTarget,
            ),
          ).thenAnswer((_) async => []);
          when(
            () => mockTemplateService.getTemplate(improverTemplateId),
          ).thenAnswer((_) async => makeImproverTemplate());
          when(
            () => mockAgentService.createAgent(
              kind: AgentKinds.templateImprover,
              displayName: 'Laura Improver',
              config: const AgentConfig(),
            ),
          ).thenAnswer((_) async => identity);
          when(
            () => mockRepository.getAgentState(identity.agentId),
          ).thenAnswer((_) async => state);

          // Simulate concurrent creation: insertLinkExclusive throws.
          when(() => mockSyncService.insertLinkExclusive(any())).thenThrow(
            const DuplicateInsertException(
              'agent_links',
              'target-template-001',
            ),
          );

          expect(
            () => service.createImproverAgent(
              targetTemplateId: targetTemplateId,
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('concurrent creation detected'),
              ),
            ),
          );
        });
      });

      test('throws StateError when improver template not found', () async {
        when(
          () => mockTemplateService.getTemplate(targetTemplateId),
        ).thenAnswer((_) async => makeTargetTemplate());
        when(
          () => mockRepository.getLinksTo(
            targetTemplateId,
            type: AgentLinkTypes.improverTarget,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockTemplateService.getTemplate(improverTemplateId),
        ).thenAnswer((_) async => null);

        expect(
          () => service.createImproverAgent(
            targetTemplateId: targetTemplateId,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Improver template'),
            ),
          ),
        );
      });

      test('uses custom display name when provided', () async {
        await withClock(Clock.fixed(testDate), () async {
          final identity = makeIdentity(displayName: 'My Custom Improver');
          final state = makeState();

          when(
            () => mockTemplateService.getTemplate(targetTemplateId),
          ).thenAnswer((_) async => makeTargetTemplate());
          when(
            () => mockRepository.getLinksTo(
              targetTemplateId,
              type: AgentLinkTypes.improverTarget,
            ),
          ).thenAnswer((_) async => []);
          when(
            () => mockTemplateService.getTemplate(improverTemplateId),
          ).thenAnswer((_) async => makeImproverTemplate());
          when(
            () => mockAgentService.createAgent(
              kind: AgentKinds.templateImprover,
              displayName: 'My Custom Improver',
              config: any(named: 'config'),
            ),
          ).thenAnswer((_) async => identity);
          when(
            () => mockRepository.getAgentState(identity.agentId),
          ).thenAnswer((_) async => state);

          await service.createImproverAgent(
            targetTemplateId: targetTemplateId,
            displayName: 'My Custom Improver',
          );

          verify(
            () => mockAgentService.createAgent(
              kind: AgentKinds.templateImprover,
              displayName: 'My Custom Improver',
              config: any(named: 'config'),
            ),
          ).called(1);
        });
      });

      test('throws ArgumentError when recursionDepth exceeds max', () {
        expect(
          () => service.createImproverAgent(
            targetTemplateId: targetTemplateId,
            recursionDepth: ImproverSlotDefaults.maxRecursionDepth + 1,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('exceeds maximum depth'),
            ),
          ),
        );
      });

      test('uses monthly feedback window for depth 1', () async {
        await withClock(Clock.fixed(testDate), () async {
          final identity = makeIdentity();
          final state = makeState();

          when(
            () => mockTemplateService.getTemplate(targetTemplateId),
          ).thenAnswer((_) async => makeTargetTemplate());
          when(
            () => mockRepository.getLinksTo(
              targetTemplateId,
              type: AgentLinkTypes.improverTarget,
            ),
          ).thenAnswer((_) async => []);
          when(
            () => mockTemplateService.getTemplate(improverTemplateId),
          ).thenAnswer((_) async => makeImproverTemplate());
          when(
            () => mockAgentService.createAgent(
              kind: any(named: 'kind'),
              displayName: any(named: 'displayName'),
              config: any(named: 'config'),
            ),
          ).thenAnswer((_) async => identity);
          when(
            () => mockRepository.getAgentState(identity.agentId),
          ).thenAnswer((_) async => state);

          await service.createImproverAgent(
            targetTemplateId: targetTemplateId,
            recursionDepth: 1,
          );

          final capturedEntities = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final updatedState = capturedEntities
              .whereType<AgentStateEntity>()
              .first;
          expect(
            updatedState.slots.feedbackWindowDays,
            ImproverSlotDefaults.defaultMetaFeedbackWindowDays,
          );
          expect(
            updatedState.scheduledWakeAt,
            testDate.add(
              const Duration(
                days: ImproverSlotDefaults.defaultMetaFeedbackWindowDays,
              ),
            ),
          );
        });
      });

      test('uses weekly feedback window for depth 0', () async {
        await withClock(Clock.fixed(testDate), () async {
          final identity = makeIdentity();
          final state = makeState();

          when(
            () => mockTemplateService.getTemplate(targetTemplateId),
          ).thenAnswer((_) async => makeTargetTemplate());
          when(
            () => mockRepository.getLinksTo(
              targetTemplateId,
              type: AgentLinkTypes.improverTarget,
            ),
          ).thenAnswer((_) async => []);
          when(
            () => mockTemplateService.getTemplate(improverTemplateId),
          ).thenAnswer((_) async => makeImproverTemplate());
          when(
            () => mockAgentService.createAgent(
              kind: any(named: 'kind'),
              displayName: any(named: 'displayName'),
              config: any(named: 'config'),
            ),
          ).thenAnswer((_) async => identity);
          when(
            () => mockRepository.getAgentState(identity.agentId),
          ).thenAnswer((_) async => state);

          await service.createImproverAgent(
            targetTemplateId: targetTemplateId,
          );

          final capturedEntities = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final updatedState = capturedEntities
              .whereType<AgentStateEntity>()
              .first;
          expect(
            updatedState.slots.feedbackWindowDays,
            ImproverSlotDefaults.defaultFeedbackWindowDays,
          );
        });
      });

      test('passes recursionDepth to state slots', () async {
        await withClock(Clock.fixed(testDate), () async {
          final identity = makeIdentity();
          final state = makeState();

          when(
            () => mockTemplateService.getTemplate(targetTemplateId),
          ).thenAnswer((_) async => makeTargetTemplate());
          when(
            () => mockRepository.getLinksTo(
              targetTemplateId,
              type: AgentLinkTypes.improverTarget,
            ),
          ).thenAnswer((_) async => []);
          when(
            () => mockTemplateService.getTemplate(improverTemplateId),
          ).thenAnswer((_) async => makeImproverTemplate());
          when(
            () => mockAgentService.createAgent(
              kind: any(named: 'kind'),
              displayName: any(named: 'displayName'),
              config: any(named: 'config'),
            ),
          ).thenAnswer((_) async => identity);
          when(
            () => mockRepository.getAgentState(identity.agentId),
          ).thenAnswer((_) async => state);

          await service.createImproverAgent(
            targetTemplateId: targetTemplateId,
            recursionDepth: 1,
          );

          final capturedEntities = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final updatedState = capturedEntities
              .whereType<AgentStateEntity>()
              .first;
          expect(updatedState.slots.recursionDepth, 1);
        });
      });
    });

    group('getImproverForTemplate', () {
      test('returns identity when improver link exists', () async {
        final identity = makeIdentity();

        when(
          () => mockRepository.getLinksTo(
            targetTemplateId,
            type: AgentLinkTypes.improverTarget,
          ),
        ).thenAnswer(
          (_) async => [
            AgentLink.improverTarget(
              id: 'link-1',
              fromId: identity.agentId,
              toId: targetTemplateId,
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
          ],
        );

        when(
          () => mockAgentService.getAgent(identity.agentId),
        ).thenAnswer((_) async => identity);

        final result = await service.getImproverForTemplate(targetTemplateId);

        expect(result, isNotNull);
        expect(result!.agentId, identity.agentId);
      });

      test('skips stale links and returns first valid agent', () async {
        final identity = makeIdentity();

        when(
          () => mockRepository.getLinksTo(
            targetTemplateId,
            type: AgentLinkTypes.improverTarget,
          ),
        ).thenAnswer(
          (_) async => [
            AgentLink.improverTarget(
              id: 'stale-link',
              fromId: 'missing-agent',
              toId: targetTemplateId,
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
            AgentLink.improverTarget(
              id: 'valid-link',
              fromId: identity.agentId,
              toId: targetTemplateId,
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
          ],
        );

        when(
          () => mockAgentService.getAgent('missing-agent'),
        ).thenAnswer((_) async => null);
        when(
          () => mockAgentService.getAgent(identity.agentId),
        ).thenAnswer((_) async => identity);

        final result = await service.getImproverForTemplate(targetTemplateId);

        expect(result, isNotNull);
        expect(result!.agentId, identity.agentId);
      });

      test('returns null when no improver link exists', () async {
        when(
          () => mockRepository.getLinksTo(
            targetTemplateId,
            type: AgentLinkTypes.improverTarget,
          ),
        ).thenAnswer((_) async => []);

        final result = await service.getImproverForTemplate(targetTemplateId);

        expect(result, isNull);
      });
    });

    group('scheduleNextRitual', () {
      test('updates scheduledWakeAt, lastOneOnOneAt, '
          'and increments totalSessionsCompleted', () async {
        await withClock(Clock.fixed(testDate), () async {
          const agentId = 'improver-agent-1';
          final state = makeState(
            slots: const AgentSlots(
              activeTemplateId: 'target-template-001',
              feedbackWindowDays: 7,
              totalSessionsCompleted: GCounter({'test-host': 2}),
              recursionDepth: 0,
            ),
          );

          when(
            () => mockRepository.getAgentState(agentId),
          ).thenAnswer((_) async => state);

          await service.scheduleNextRitual(agentId);

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final updatedState = captured.first as AgentStateEntity;
          expect(
            updatedState.scheduledWakeAt,
            testDate.add(const Duration(days: 7)),
          );
          expect(updatedState.slots.lastOneOnOneAt, testDate);
          // Host-attributed: the increment lands under the local host bucket.
          expect(updatedState.slots.totalSessionsCompleted.byHost, {
            'test-host': 3,
          });
          expect(updatedState.updatedAt, testDate);
          expect(notifiedAgentIds, [agentId]);
        });
      });

      test('uses default feedbackWindowDays when slot is null', () async {
        await withClock(Clock.fixed(testDate), () async {
          const agentId = 'improver-agent-1';
          final state = makeState(
            slots: const AgentSlots(
              activeTemplateId: 'target-template-001',
            ),
          );

          when(
            () => mockRepository.getAgentState(agentId),
          ).thenAnswer((_) async => state);

          await service.scheduleNextRitual(agentId);

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final updatedState = captured.first as AgentStateEntity;
          expect(
            updatedState.scheduledWakeAt,
            testDate.add(
              const Duration(
                days: ImproverSlotDefaults.defaultFeedbackWindowDays,
              ),
            ),
          );
        });
      });

      test('falls back to default when feedbackWindowDays is zero', () async {
        await withClock(Clock.fixed(testDate), () async {
          const agentId = 'improver-agent-1';
          final state = makeState(
            slots: const AgentSlots(
              activeTemplateId: 'target-template-001',
              feedbackWindowDays: 0,
            ),
          );

          when(
            () => mockRepository.getAgentState(agentId),
          ).thenAnswer((_) async => state);

          await service.scheduleNextRitual(agentId);

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final updatedState = captured.first as AgentStateEntity;
          expect(
            updatedState.scheduledWakeAt,
            testDate.add(
              const Duration(
                days: ImproverSlotDefaults.defaultFeedbackWindowDays,
              ),
            ),
          );
        });
      });

      test(
        'falls back to default when feedbackWindowDays is negative',
        () async {
          await withClock(Clock.fixed(testDate), () async {
            const agentId = 'improver-agent-1';
            final state = makeState(
              slots: const AgentSlots(
                activeTemplateId: 'target-template-001',
                feedbackWindowDays: -5,
              ),
            );

            when(
              () => mockRepository.getAgentState(agentId),
            ).thenAnswer((_) async => state);

            await service.scheduleNextRitual(agentId);

            final captured = verify(
              () => mockSyncService.upsertEntity(captureAny()),
            ).captured;

            final updatedState = captured.first as AgentStateEntity;
            expect(
              updatedState.scheduledWakeAt,
              testDate.add(
                const Duration(
                  days: ImproverSlotDefaults.defaultFeedbackWindowDays,
                ),
              ),
            );
          });
        },
      );

      test('throws StateError when agent state not found', () async {
        when(
          () => mockRepository.getAgentState('missing-agent'),
        ).thenAnswer((_) async => null);

        expect(
          () => service.scheduleNextRitual('missing-agent'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Agent state not found'),
            ),
          ),
        );
      });

      test(
        'increments from zero when totalSessionsCompleted is null',
        () async {
          await withClock(Clock.fixed(testDate), () async {
            const agentId = 'improver-agent-1';
            final state = makeState(
              slots: const AgentSlots(
                activeTemplateId: 'target-template-001',
                feedbackWindowDays: 14,
              ),
            );

            when(
              () => mockRepository.getAgentState(agentId),
            ).thenAnswer((_) async => state);

            await service.scheduleNextRitual(agentId);

            final captured = verify(
              () => mockSyncService.upsertEntity(captureAny()),
            ).captured;

            final updatedState = captured.first as AgentStateEntity;
            expect(updatedState.slots.totalSessionsCompleted.byHost, {
              'test-host': 1,
            });
            expect(
              updatedState.scheduledWakeAt,
              testDate.add(const Duration(days: 14)),
            );
          });
        },
      );
    });
  });
}
