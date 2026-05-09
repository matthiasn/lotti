import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/project_recommendation_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

enum _GeneratedRecommendationRawStepsSlot { missing, nonList, list }

enum _GeneratedRecommendationStepSlot {
  validTitleOnly,
  validWithRationale,
  validWithPriority,
  validWithEmptyMetadata,
  blankTitle,
  missingTitle,
  nonStringTitle,
  nonMap,
}

enum _GeneratedRecommendationExistingSlot {
  activeSameProject,
  activeOtherProject,
  dismissedSameProject,
  resolvedSameProject,
  wrongType,
}

enum _GeneratedRecommendationLookupSlot {
  missing,
  wrongType,
  active,
  resolved,
  dismissed,
  superseded,
}

enum _GeneratedRecommendationTransitionOperation { resolve, dismiss }

final _generatedRecommendationNow = DateTime(2026, 5, 21, 12, 30);

class _GeneratedRecommendationDraft {
  const _GeneratedRecommendationDraft({
    required this.title,
    this.rationale,
    this.priority,
  });

  final String title;
  final String? rationale;
  final String? priority;
}

class _GeneratedRecommendationRecordScenario {
  const _GeneratedRecommendationRecordScenario({
    required this.rawStepsSlot,
    required this.stepSlots,
    required this.existingSlots,
  });

  final _GeneratedRecommendationRawStepsSlot rawStepsSlot;
  final List<_GeneratedRecommendationStepSlot> stepSlots;
  final List<_GeneratedRecommendationExistingSlot> existingSlots;

  List<Object?> get rawStepValues {
    return [
      for (final (index, slot) in stepSlots.indexed) _rawStep(index, slot),
    ];
  }

  Map<String, dynamic>? get decisionArgs {
    return switch (rawStepsSlot) {
      _GeneratedRecommendationRawStepsSlot.missing => const {},
      _GeneratedRecommendationRawStepsSlot.nonList => const {'steps': 'nope'},
      _GeneratedRecommendationRawStepsSlot.list => {'steps': rawStepValues},
    };
  }

  List<_GeneratedRecommendationDraft> get validDrafts {
    if (rawStepsSlot != _GeneratedRecommendationRawStepsSlot.list) {
      return const [];
    }
    return [
      for (final (index, slot) in stepSlots.indexed)
        if (_expectedDraft(index, slot) != null) _expectedDraft(index, slot)!,
    ];
  }

  List<AgentDomainEntity> get existingEntities {
    return [
      for (final (index, slot) in existingSlots.indexed)
        _existingEntity(index, slot),
    ];
  }

  List<ProjectRecommendationEntity> get supersededRecommendations {
    return [
      for (final entity in existingEntities)
        if (entity is ProjectRecommendationEntity &&
            entity.projectId == 'generated-project' &&
            entity.status == ProjectRecommendationStatus.active)
          entity,
    ];
  }

  Object? _rawStep(int index, _GeneratedRecommendationStepSlot slot) {
    return switch (slot) {
      _GeneratedRecommendationStepSlot.validTitleOnly => {
        'title': '  Generated step $index  ',
      },
      _GeneratedRecommendationStepSlot.validWithRationale => {
        'title': 'Generated rationale step $index',
        'rationale': '  Explain step $index  ',
      },
      _GeneratedRecommendationStepSlot.validWithPriority => {
        'title': 'Generated priority step $index',
        'priority': ' high ',
      },
      _GeneratedRecommendationStepSlot.validWithEmptyMetadata => {
        'title': 'Generated clean step $index',
        'rationale': '   ',
        'priority': '',
      },
      _GeneratedRecommendationStepSlot.blankTitle => {'title': '   '},
      _GeneratedRecommendationStepSlot.missingTitle => {
        'rationale': 'missing title',
      },
      _GeneratedRecommendationStepSlot.nonStringTitle => {'title': index},
      _GeneratedRecommendationStepSlot.nonMap => 'not-a-step-$index',
    };
  }

  _GeneratedRecommendationDraft? _expectedDraft(
    int index,
    _GeneratedRecommendationStepSlot slot,
  ) {
    return switch (slot) {
      _GeneratedRecommendationStepSlot.validTitleOnly =>
        _GeneratedRecommendationDraft(title: 'Generated step $index'),
      _GeneratedRecommendationStepSlot.validWithRationale =>
        _GeneratedRecommendationDraft(
          title: 'Generated rationale step $index',
          rationale: 'Explain step $index',
        ),
      _GeneratedRecommendationStepSlot.validWithPriority =>
        _GeneratedRecommendationDraft(
          title: 'Generated priority step $index',
          priority: 'HIGH',
        ),
      _GeneratedRecommendationStepSlot.validWithEmptyMetadata =>
        _GeneratedRecommendationDraft(title: 'Generated clean step $index'),
      _GeneratedRecommendationStepSlot.blankTitle ||
      _GeneratedRecommendationStepSlot.missingTitle ||
      _GeneratedRecommendationStepSlot.nonStringTitle ||
      _GeneratedRecommendationStepSlot.nonMap => null,
    };
  }

  AgentDomainEntity _existingEntity(
    int index,
    _GeneratedRecommendationExistingSlot slot,
  ) {
    return switch (slot) {
      _GeneratedRecommendationExistingSlot.activeSameProject =>
        makeTestProjectRecommendation(
          id: 'generated-existing-$index',
          agentId: 'generated-agent',
          projectId: 'generated-project',
          title: 'Existing active $index',
        ),
      _GeneratedRecommendationExistingSlot.activeOtherProject =>
        makeTestProjectRecommendation(
          id: 'generated-existing-$index',
          agentId: 'generated-agent',
          projectId: 'other-project',
          title: 'Other active $index',
        ),
      _GeneratedRecommendationExistingSlot.dismissedSameProject =>
        makeTestProjectRecommendation(
          id: 'generated-existing-$index',
          agentId: 'generated-agent',
          projectId: 'generated-project',
          status: ProjectRecommendationStatus.dismissed,
          title: 'Dismissed $index',
        ),
      _GeneratedRecommendationExistingSlot.resolvedSameProject =>
        makeTestProjectRecommendation(
          id: 'generated-existing-$index',
          agentId: 'generated-agent',
          projectId: 'generated-project',
          status: ProjectRecommendationStatus.resolved,
          title: 'Resolved $index',
        ),
      _GeneratedRecommendationExistingSlot.wrongType => makeTestState(
        id: 'generated-state-$index',
        agentId: 'generated-agent',
      ),
    };
  }

  @override
  String toString() {
    return '_GeneratedRecommendationRecordScenario('
        'rawStepsSlot: $rawStepsSlot, stepSlots: $stepSlots, '
        'existingSlots: $existingSlots)';
  }
}

class _GeneratedRecommendationTransitionScenario {
  const _GeneratedRecommendationTransitionScenario({
    required this.lookupSlot,
    required this.operation,
  });

  final _GeneratedRecommendationLookupSlot lookupSlot;
  final _GeneratedRecommendationTransitionOperation operation;

  AgentDomainEntity? get lookupEntity {
    return switch (lookupSlot) {
      _GeneratedRecommendationLookupSlot.missing => null,
      _GeneratedRecommendationLookupSlot.wrongType => makeTestState(
        id: 'generated-rec',
        agentId: 'generated-agent',
      ),
      _GeneratedRecommendationLookupSlot.active =>
        makeTestProjectRecommendation(
          id: 'generated-rec',
          agentId: 'generated-agent',
          projectId: 'generated-project',
        ),
      _GeneratedRecommendationLookupSlot.resolved =>
        makeTestProjectRecommendation(
          id: 'generated-rec',
          agentId: 'generated-agent',
          projectId: 'generated-project',
          status: ProjectRecommendationStatus.resolved,
          resolvedAt: DateTime(2026, 5, 20),
        ),
      _GeneratedRecommendationLookupSlot.dismissed =>
        makeTestProjectRecommendation(
          id: 'generated-rec',
          agentId: 'generated-agent',
          projectId: 'generated-project',
          status: ProjectRecommendationStatus.dismissed,
          dismissedAt: DateTime(2026, 5, 20),
        ),
      _GeneratedRecommendationLookupSlot.superseded =>
        makeTestProjectRecommendation(
          id: 'generated-rec',
          agentId: 'generated-agent',
          projectId: 'generated-project',
          status: ProjectRecommendationStatus.superseded,
          supersededAt: DateTime(2026, 5, 20),
        ),
    };
  }

  bool get expectsTransition =>
      lookupSlot == _GeneratedRecommendationLookupSlot.active;

  ProjectRecommendationStatus get expectedStatus {
    return switch (operation) {
      _GeneratedRecommendationTransitionOperation.resolve =>
        ProjectRecommendationStatus.resolved,
      _GeneratedRecommendationTransitionOperation.dismiss =>
        ProjectRecommendationStatus.dismissed,
    };
  }

  Future<bool> run(ProjectRecommendationService service) {
    return switch (operation) {
      _GeneratedRecommendationTransitionOperation.resolve =>
        service.markResolved('generated-rec'),
      _GeneratedRecommendationTransitionOperation.dismiss =>
        service.dismissRecommendation('generated-rec'),
    };
  }

  @override
  String toString() {
    return '_GeneratedRecommendationTransitionScenario('
        'lookupSlot: $lookupSlot, operation: $operation)';
  }
}

extension _AnyGeneratedProjectRecommendationScenario on glados.Any {
  glados.Generator<_GeneratedRecommendationRawStepsSlot>
  get recommendationRawStepsSlot =>
      glados.AnyUtils(this).choose(_GeneratedRecommendationRawStepsSlot.values);

  glados.Generator<_GeneratedRecommendationStepSlot>
  get recommendationStepSlot =>
      glados.AnyUtils(this).choose(_GeneratedRecommendationStepSlot.values);

  glados.Generator<_GeneratedRecommendationExistingSlot>
  get recommendationExistingSlot =>
      glados.AnyUtils(this).choose(_GeneratedRecommendationExistingSlot.values);

  glados.Generator<_GeneratedRecommendationLookupSlot>
  get recommendationLookupSlot =>
      glados.AnyUtils(this).choose(_GeneratedRecommendationLookupSlot.values);

  glados.Generator<_GeneratedRecommendationTransitionOperation>
  get recommendationTransitionOperation => glados.AnyUtils(
    this,
  ).choose(_GeneratedRecommendationTransitionOperation.values);

  glados.Generator<_GeneratedRecommendationRecordScenario>
  get recommendationRecordScenario => glados.CombinableAny(this).combine3(
    recommendationRawStepsSlot,
    glados.ListAnys(this).listWithLengthInRange(0, 7, recommendationStepSlot),
    glados.ListAnys(
      this,
    ).listWithLengthInRange(0, 5, recommendationExistingSlot),
    (
      _GeneratedRecommendationRawStepsSlot rawStepsSlot,
      List<_GeneratedRecommendationStepSlot> stepSlots,
      List<_GeneratedRecommendationExistingSlot> existingSlots,
    ) => _GeneratedRecommendationRecordScenario(
      rawStepsSlot: rawStepsSlot,
      stepSlots: stepSlots,
      existingSlots: existingSlots,
    ),
  );

  glados.Generator<_GeneratedRecommendationTransitionScenario>
  get recommendationTransitionScenario => glados.CombinableAny(this).combine2(
    recommendationLookupSlot,
    recommendationTransitionOperation,
    (
      _GeneratedRecommendationLookupSlot lookupSlot,
      _GeneratedRecommendationTransitionOperation operation,
    ) => _GeneratedRecommendationTransitionScenario(
      lookupSlot: lookupSlot,
      operation: operation,
    ),
  );
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentSyncService mockSyncService;
  late MockAgentRepository mockRepository;
  late MockUpdateNotifications mockNotifications;
  late MockDomainLogger mockDomainLogger;
  late ProjectRecommendationService service;

  setUp(() {
    mockSyncService = MockAgentSyncService();
    mockRepository = MockAgentRepository();
    mockNotifications = MockUpdateNotifications();
    mockDomainLogger = MockDomainLogger();

    when(() => mockSyncService.repository).thenReturn(mockRepository);
    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    when(
      () => mockNotifications.notify(any(), fromSync: any(named: 'fromSync')),
    ).thenReturn(null);
    when(
      () => mockDomainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    service = ProjectRecommendationService(
      syncService: mockSyncService,
      notifications: mockNotifications,
      domainLogger: mockDomainLogger,
    );
  });

  glados.Glados(
    glados.any.recommendationRecordScenario,
    glados.ExploreConfig(numRuns: 180),
  ).test('matches generated recommendation recording semantics', (
    scenario,
  ) async {
    final generatedSyncService = MockAgentSyncService();
    final generatedRepository = MockAgentRepository();
    final generatedNotifications = MockUpdateNotifications();
    final generatedLogger = MockDomainLogger();
    final writtenEntities = <AgentDomainEntity>[];
    final uiNotifications = <Set<String>>[];

    when(() => generatedSyncService.repository).thenReturn(
      generatedRepository,
    );
    when(
      () => generatedRepository.getEntitiesByAgentId(
        'generated-agent',
        type: AgentEntityTypes.projectRecommendation,
      ),
    ).thenAnswer((_) async => scenario.existingEntities);
    when(() => generatedSyncService.upsertEntity(any())).thenAnswer((
      invocation,
    ) async {
      writtenEntities.add(
        invocation.positionalArguments.single as AgentDomainEntity,
      );
    });
    when(() => generatedNotifications.notifyUiOnly(any())).thenAnswer((
      invocation,
    ) {
      uiNotifications.add(
        Set<String>.from(invocation.positionalArguments.single as Set<String>),
      );
    });
    when(
      () => generatedLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    final generatedService = ProjectRecommendationService(
      syncService: generatedSyncService,
      notifications: generatedNotifications,
      domainLogger: generatedLogger,
    );
    final changeSet = makeTestChangeSet(
      id: 'generated-change-set',
      agentId: 'generated-agent',
      taskId: 'generated-project',
    );
    final decision = makeTestChangeDecision(
      id: 'generated-decision',
      agentId: 'generated-agent',
      changeSetId: changeSet.id,
      toolName: 'recommend_next_steps',
      taskId: 'generated-project',
      args: scenario.decisionArgs,
    );

    await withClock(Clock.fixed(_generatedRecommendationNow), () async {
      if (scenario.validDrafts.isEmpty) {
        await expectLater(
          () => generatedService.recordConfirmedRecommendations(
            changeSet: changeSet,
            decision: decision,
          ),
          throwsA(isA<ArgumentError>()),
        );
        verifyNever(
          () => generatedRepository.getEntitiesByAgentId(
            any(),
            type: any(named: 'type'),
            limit: any(named: 'limit'),
          ),
        );
        expect(writtenEntities, isEmpty);
        expect(uiNotifications, isEmpty);
        return;
      }

      await generatedService.recordConfirmedRecommendations(
        changeSet: changeSet,
        decision: decision,
      );
    });

    if (scenario.validDrafts.isEmpty) return;

    final superseded = writtenEntities
        .take(scenario.supersededRecommendations.length)
        .cast<ProjectRecommendationEntity>()
        .toList();
    expect(
      superseded.map((entity) => entity.id).toList(),
      scenario.supersededRecommendations.map((entity) => entity.id).toList(),
      reason: '$scenario',
    );
    for (final entity in superseded) {
      expect(entity.status, ProjectRecommendationStatus.superseded);
      expect(entity.updatedAt, _generatedRecommendationNow);
      expect(entity.supersededAt, _generatedRecommendationNow);
    }

    final created = writtenEntities
        .skip(scenario.supersededRecommendations.length)
        .cast<ProjectRecommendationEntity>()
        .toList();
    expect(created, hasLength(scenario.validDrafts.length));
    for (final (index, draft) in scenario.validDrafts.indexed) {
      final entity = created[index];
      expect(entity.agentId, 'generated-agent');
      expect(entity.projectId, 'generated-project');
      expect(entity.title, draft.title);
      expect(entity.position, index);
      expect(entity.status, ProjectRecommendationStatus.active);
      expect(entity.createdAt, _generatedRecommendationNow);
      expect(entity.updatedAt, _generatedRecommendationNow);
      expect(entity.sourceChangeSetId, changeSet.id);
      expect(entity.sourceDecisionId, decision.id);
      expect(entity.rationale, draft.rationale);
      expect(entity.priority, draft.priority);
    }

    expect(uiNotifications, [
      {'generated-agent', 'generated-project', agentNotification},
    ]);
  });

  glados.Glados(
    glados.any.recommendationTransitionScenario,
    glados.ExploreConfig(numRuns: 120),
  ).test('matches generated active-only transition semantics', (
    scenario,
  ) async {
    final generatedSyncService = MockAgentSyncService();
    final generatedRepository = MockAgentRepository();
    final generatedNotifications = MockUpdateNotifications();
    final writtenEntities = <AgentDomainEntity>[];
    final uiNotifications = <Set<String>>[];

    when(() => generatedSyncService.repository).thenReturn(
      generatedRepository,
    );
    when(() => generatedRepository.getEntity('generated-rec')).thenAnswer(
      (_) async => scenario.lookupEntity,
    );
    when(() => generatedSyncService.upsertEntity(any())).thenAnswer((
      invocation,
    ) async {
      writtenEntities.add(
        invocation.positionalArguments.single as AgentDomainEntity,
      );
    });
    when(() => generatedNotifications.notifyUiOnly(any())).thenAnswer((
      invocation,
    ) {
      uiNotifications.add(
        Set<String>.from(invocation.positionalArguments.single as Set<String>),
      );
    });

    final generatedService = ProjectRecommendationService(
      syncService: generatedSyncService,
      notifications: generatedNotifications,
    );

    final result = await withClock(
      Clock.fixed(_generatedRecommendationNow),
      () => scenario.run(generatedService),
    );

    expect(result, scenario.expectsTransition, reason: '$scenario');
    if (!scenario.expectsTransition) {
      expect(writtenEntities, isEmpty);
      expect(uiNotifications, isEmpty);
      return;
    }

    final updated = writtenEntities.single as ProjectRecommendationEntity;
    expect(updated.status, scenario.expectedStatus);
    expect(updated.updatedAt, _generatedRecommendationNow);
    expect(
      updated.resolvedAt,
      scenario.expectedStatus == ProjectRecommendationStatus.resolved
          ? _generatedRecommendationNow
          : isNull,
    );
    expect(
      updated.dismissedAt,
      scenario.expectedStatus == ProjectRecommendationStatus.dismissed
          ? _generatedRecommendationNow
          : isNull,
    );
    expect(uiNotifications, [
      {'generated-agent', 'generated-project', agentNotification},
    ]);
  });

  test(
    'records active recommendations and supersedes previous active ones',
    () async {
      final changeSet = makeTestChangeSet(
        agentId: 'agent-1',
        taskId: 'project-1',
        items: const [
          ChangeItem(
            toolName: 'recommend_next_steps',
            args: {
              'steps': [
                {'title': 'Verify sync stability with George'},
                {'title': 'Close the project', 'priority': 'high'},
              ],
            },
            humanSummary: 'Recommend next steps',
          ),
        ],
      );
      final decision = makeTestChangeDecision(
        id: 'decision-1',
        agentId: 'agent-1',
        changeSetId: changeSet.id,
        toolName: 'recommend_next_steps',
        taskId: 'project-1',
        args: const {
          'steps': [
            {
              'title': 'Verify sync stability with George',
              'rationale': 'Confirm the fix with the user',
            },
            {'title': 'Close the project', 'priority': 'high'},
          ],
        },
      );
      final existing = makeTestProjectRecommendation(
        id: 'existing',
        agentId: 'agent-1',
        projectId: 'project-1',
        title: 'Old recommendation',
      );

      when(
        () => mockRepository.getEntitiesByAgentId(
          'agent-1',
          type: AgentEntityTypes.projectRecommendation,
        ),
      ).thenAnswer((_) async => [existing]);

      await service.recordConfirmedRecommendations(
        changeSet: changeSet,
        decision: decision,
      );

      final captured = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;

      expect(captured, hasLength(3));
      final superseded = captured[0] as ProjectRecommendationEntity;
      final firstActive = captured[1] as ProjectRecommendationEntity;
      final secondActive = captured[2] as ProjectRecommendationEntity;

      expect(superseded.id, 'existing');
      expect(superseded.status, ProjectRecommendationStatus.superseded);
      expect(firstActive.status, ProjectRecommendationStatus.active);
      expect(firstActive.title, 'Verify sync stability with George');
      expect(firstActive.position, 0);
      expect(firstActive.rationale, 'Confirm the fix with the user');
      expect(secondActive.title, 'Close the project');
      expect(secondActive.priority, 'HIGH');
      expect(secondActive.position, 1);

      verify(
        () => mockNotifications.notifyUiOnly(
          {'agent-1', 'project-1', agentNotification},
        ),
      ).called(1);
    },
  );

  test('markResolved updates an active recommendation and notifies', () async {
    final recommendation = makeTestProjectRecommendation(
      id: 'rec-1',
      agentId: 'agent-1',
      projectId: 'project-1',
    );
    when(() => mockRepository.getEntity('rec-1')).thenAnswer(
      (_) async => recommendation,
    );

    final success = await service.markResolved('rec-1');

    expect(success, isTrue);
    final updated =
        verify(
              () => mockSyncService.upsertEntity(captureAny()),
            ).captured.single
            as ProjectRecommendationEntity;
    expect(updated.status, ProjectRecommendationStatus.resolved);
    expect(updated.resolvedAt, isNotNull);
    verify(
      () => mockNotifications.notifyUiOnly(
        {'agent-1', 'project-1', agentNotification},
      ),
    ).called(1);
  });

  test(
    'dismissRecommendation returns false for non-active recommendations',
    () async {
      final dismissed = makeTestProjectRecommendation(
        id: 'rec-1',
        agentId: 'agent-1',
        projectId: 'project-1',
        status: ProjectRecommendationStatus.dismissed,
      );
      when(() => mockRepository.getEntity('rec-1')).thenAnswer(
        (_) async => dismissed,
      );

      final success = await service.dismissRecommendation('rec-1');

      expect(success, isFalse);
      verifyNever(() => mockSyncService.upsertEntity(any()));
      verifyNever(
        () => mockNotifications.notifyUiOnly(any()),
      );
    },
  );

  test(
    'dismissRecommendation updates an active recommendation and notifies',
    () async {
      final recommendation = makeTestProjectRecommendation(
        id: 'rec-2',
        agentId: 'agent-1',
        projectId: 'project-1',
      );
      when(() => mockRepository.getEntity('rec-2')).thenAnswer(
        (_) async => recommendation,
      );

      final success = await service.dismissRecommendation('rec-2');

      expect(success, isTrue);
      final updated =
          verify(
                () => mockSyncService.upsertEntity(captureAny()),
              ).captured.single
              as ProjectRecommendationEntity;
      expect(updated.status, ProjectRecommendationStatus.dismissed);
      expect(updated.dismissedAt, isNotNull);
      verify(
        () => mockNotifications.notifyUiOnly(
          {'agent-1', 'project-1', agentNotification},
        ),
      ).called(1);
    },
  );

  test(
    'recordConfirmedRecommendations throws when no valid steps are provided',
    () async {
      final changeSet = makeTestChangeSet(
        agentId: 'agent-1',
        taskId: 'project-1',
      );
      final decision = makeTestChangeDecision(
        id: 'decision-invalid',
        agentId: 'agent-1',
        changeSetId: changeSet.id,
        toolName: 'recommend_next_steps',
        taskId: 'project-1',
        args: const {
          'steps': [
            {'title': '   '},
            {'rationale': 'missing title'},
            'invalid',
          ],
        },
      );

      await expectLater(
        () => service.recordConfirmedRecommendations(
          changeSet: changeSet,
          decision: decision,
        ),
        throwsA(isA<ArgumentError>()),
      );
      verifyNever(
        () => mockRepository.getEntitiesByAgentId(
          any(),
          type: any(named: 'type'),
          limit: any(named: 'limit'),
        ),
      );
    },
  );
}
