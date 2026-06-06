import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/service/standing_agreement_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const agentId = 'fitness-agent-001';
  final now = DateTime(2026, 6, 6, 9);

  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late StandingAgreementService service;

  setUp(() {
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    service = StandingAgreementService(
      repository: repository,
      syncService: syncService,
    );

    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
  });

  group('createAgreement', () {
    test('writes a normalized active agreement through sync', () async {
      when(
        () => repository.getEntity('agreement-001'),
      ).thenAnswer((_) async => null);

      final agreement = await withClock(Clock.fixed(now), () {
        return service.createAgreement(
          agreementId: 'agreement-001',
          agentId: agentId,
          title: '  Strength three times per week  ',
          scope: StandingAgreementScope.fitness,
          cadence: StandingAgreementCadence.weekly,
          enforcement: StandingAgreementEnforcement.nonNegotiable,
          approvalMode: StandingAgreementApprovalMode.autoAccept,
          categoryId: ' health ',
          targetId: ' strength ',
          targetKind: ' habit ',
          minCount: 3,
          maxCount: 4,
          minMinutes: 135,
          maxMinutes: 240,
          preferredSessionMinutes: 45,
          canPreempt: true,
          priority: 90,
          preemptibleCategoryIds: const [' admin ', 'admin', ''],
          protectedCategoryIds: const [' sleep ', 'sleep'],
          evidenceRefs: const [
            AttentionEvidenceRef(
              kind: AttentionEvidenceKind.health,
              id: 'workout-history',
              label: 'Recent workouts',
            ),
          ],
          activeFrom: DateTime(2026, 6),
          activeUntil: DateTime(2026, 7),
          rationale: '  Current fitness baseline  ',
        );
      });

      expect(agreement.id, 'agreement-001');
      expect(agreement.agentId, agentId);
      expect(agreement.title, 'Strength three times per week');
      expect(agreement.status, StandingAgreementStatus.active);
      expect(agreement.enforcement, StandingAgreementEnforcement.nonNegotiable);
      expect(agreement.approvalMode, StandingAgreementApprovalMode.autoAccept);
      expect(agreement.categoryId, 'health');
      expect(agreement.targetId, 'strength');
      expect(agreement.targetKind, 'habit');
      expect(agreement.minCount, 3);
      expect(agreement.maxCount, 4);
      expect(agreement.minMinutes, 135);
      expect(agreement.maxMinutes, 240);
      expect(agreement.preferredSessionMinutes, 45);
      expect(agreement.canPreempt, isTrue);
      expect(agreement.priority, 90);
      expect(agreement.preemptibleCategoryIds, ['admin']);
      expect(agreement.protectedCategoryIds, ['sleep']);
      expect(agreement.evidenceRefs.single.id, 'workout-history');
      expect(agreement.rationale, 'Current fitness baseline');
      expect(agreement.createdAt, now);
      expect(agreement.updatedAt, now);
      expect(agreement.vectorClock, isNull);

      final captured =
          verify(
                () => syncService.upsertEntity(captureAny()),
              ).captured.single
              as StandingAgreementEntity;
      expect(captured, same(agreement));
    });

    test('rejects duplicate explicit ids before writing', () async {
      when(
        () => repository.getEntity('agreement-001'),
      ).thenAnswer((_) async => _agreement());

      await expectLater(
        () => service.createAgreement(
          agreementId: 'agreement-001',
          agentId: agentId,
          title: 'Exercise',
          scope: StandingAgreementScope.fitness,
          cadence: StandingAgreementCadence.weekly,
        ),
        throwsA(isA<StateError>()),
      );

      verifyNever(() => syncService.upsertEntity(any()));
    });

    test('validates required and bounded agreement fields', () async {
      await expectLater(
        () => service.createAgreement(
          agentId: agentId,
          title: ' ',
          scope: StandingAgreementScope.fitness,
          cadence: StandingAgreementCadence.weekly,
        ),
        throwsA(isA<ArgumentError>()),
      );

      await expectLater(
        () => service.createAgreement(
          agentId: '   ',
          title: 'Blank agent id',
          scope: StandingAgreementScope.fitness,
          cadence: StandingAgreementCadence.weekly,
        ),
        throwsA(isA<ArgumentError>()),
      );

      await expectLater(
        () => service.createAgreement(
          agreementId: '   ',
          agentId: agentId,
          title: 'Blank agreement id',
          scope: StandingAgreementScope.fitness,
          cadence: StandingAgreementCadence.weekly,
        ),
        throwsA(isA<ArgumentError>()),
      );

      await expectLater(
        () => service.createAgreement(
          agentId: agentId,
          title: 'Custom scope',
          scope: StandingAgreementScope.custom,
          cadence: StandingAgreementCadence.weekly,
        ),
        throwsA(isA<ArgumentError>()),
      );

      await expectLater(
        () => service.createAgreement(
          agentId: agentId,
          title: 'Custom cadence',
          scope: StandingAgreementScope.fitness,
          cadence: StandingAgreementCadence.custom,
        ),
        throwsA(isA<ArgumentError>()),
      );

      await expectLater(
        () => service.createAgreement(
          agentId: agentId,
          title: 'Negative count',
          scope: StandingAgreementScope.fitness,
          cadence: StandingAgreementCadence.weekly,
          minCount: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );

      await expectLater(
        () => service.createAgreement(
          agentId: agentId,
          title: 'Bad session length',
          scope: StandingAgreementScope.fitness,
          cadence: StandingAgreementCadence.weekly,
          preferredSessionMinutes: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      await expectLater(
        () => service.createAgreement(
          agentId: agentId,
          title: 'Inverted minutes',
          scope: StandingAgreementScope.fitness,
          cadence: StandingAgreementCadence.weekly,
          minMinutes: 90,
          maxMinutes: 30,
        ),
        throwsA(isA<ArgumentError>()),
      );

      await expectLater(
        () => service.createAgreement(
          agentId: agentId,
          title: 'Preferred session exceeds max minutes',
          scope: StandingAgreementScope.fitness,
          cadence: StandingAgreementCadence.weekly,
          preferredSessionMinutes: 45,
          maxMinutes: 30,
        ),
        throwsA(isA<ArgumentError>()),
      );

      await expectLater(
        () => service.createAgreement(
          agentId: agentId,
          title: 'Inverted active dates',
          scope: StandingAgreementScope.fitness,
          cadence: StandingAgreementCadence.weekly,
          activeFrom: DateTime(2026, 6, 10),
          activeUntil: DateTime(2026, 6),
        ),
        throwsA(isA<ArgumentError>()),
      );

      verifyNever(() => syncService.upsertEntity(any()));
    });
  });

  group('saveAgreement', () {
    test('normalizes caller-edited agreements and stamps updatedAt', () async {
      final agreement = _agreement(
        title: '  Keep paperwork bounded  ',
        scope: StandingAgreementScope.custom,
        cadence: StandingAgreementCadence.custom,
        customScope: '  admin load  ',
        customCadence: '  every work week  ',
        categoryId: ' admin ',
        targetId: ' taxes ',
        targetKind: ' task ',
        rationale: '  Avoid late scramble  ',
        preemptibleCategoryIds: const [' inbox ', 'inbox'],
        protectedCategoryIds: const [' deep-work ', ''],
      );

      final saved = await withClock(Clock.fixed(now), () {
        return service.saveAgreement(agreement);
      });

      expect(saved.title, 'Keep paperwork bounded');
      expect(saved.customScope, 'admin load');
      expect(saved.customCadence, 'every work week');
      expect(saved.categoryId, 'admin');
      expect(saved.targetId, 'taxes');
      expect(saved.targetKind, 'task');
      expect(saved.rationale, 'Avoid late scramble');
      expect(saved.preemptibleCategoryIds, ['inbox']);
      expect(saved.protectedCategoryIds, ['deep-work']);
      expect(saved.updatedAt, now);

      verify(() => syncService.upsertEntity(saved)).called(1);
    });
  });

  group('lifecycle', () {
    test('pauses, activates, and retires agreements by id', () async {
      final active = _agreement();
      final paused = active.copyWith(status: StandingAgreementStatus.paused);

      when(() => repository.getEntity('agreement-001')).thenAnswer(
        (_) async => active,
      );
      final pausedResult = await withClock(Clock.fixed(now), () {
        return service.pauseAgreement(agreementId: 'agreement-001');
      });
      expect(pausedResult.status, StandingAgreementStatus.paused);
      expect(pausedResult.updatedAt, now);

      when(() => repository.getEntity('agreement-001')).thenAnswer(
        (_) async => paused,
      );
      final activeResult = await withClock(Clock.fixed(now), () {
        return service.activateAgreement(agreementId: 'agreement-001');
      });
      expect(activeResult.status, StandingAgreementStatus.active);
      expect(activeResult.updatedAt, now);

      final retiredResult = await withClock(Clock.fixed(now), () {
        return service.retireAgreement(agreementId: 'agreement-001');
      });
      expect(retiredResult.status, StandingAgreementStatus.retired);
      expect(retiredResult.updatedAt, now);

      final written = verify(
        () => syncService.upsertEntity(captureAny()),
      ).captured.cast<StandingAgreementEntity>();
      expect(
        written.map((agreement) => agreement.status),
        [
          StandingAgreementStatus.paused,
          StandingAgreementStatus.active,
          StandingAgreementStatus.retired,
        ],
      );
    });

    test('does not rewrite an unchanged status', () async {
      final paused = _agreement(
        status: StandingAgreementStatus.paused,
      );
      when(
        () => repository.getEntity('agreement-001'),
      ).thenAnswer((_) async => paused);

      final result = await service.pauseAgreement(agreementId: 'agreement-001');

      expect(result, same(paused));
      verifyNever(() => syncService.upsertEntity(any()));
    });

    test(
      'soft deletes once and leaves an already deleted record unchanged',
      () async {
        final active = _agreement();
        when(
          () => repository.getEntity('agreement-001'),
        ).thenAnswer((_) async => active);

        final deleted = await withClock(Clock.fixed(now), () {
          return service.deleteAgreement(agreementId: 'agreement-001');
        });

        expect(deleted.deletedAt, now);
        expect(deleted.updatedAt, now);
        verify(() => syncService.upsertEntity(deleted)).called(1);

        clearInteractions(syncService);
        when(() => repository.getEntity('agreement-001')).thenAnswer(
          (_) async => deleted,
        );

        final unchanged = await service.deleteAgreement(
          agreementId: 'agreement-001',
        );

        expect(unchanged, same(deleted));
        verifyNever(() => syncService.upsertEntity(any()));
      },
    );

    test('throws when the id does not point at a live agreement', () async {
      when(
        () => repository.getEntity('missing-agreement'),
      ).thenAnswer((_) async => null);
      await expectLater(
        () => service.pauseAgreement(agreementId: 'missing-agreement'),
        throwsA(isA<StateError>()),
      );

      when(() => repository.getEntity('agent-entity')).thenAnswer(
        (_) async => AgentDomainEntity.agent(
          id: 'agent-entity',
          agentId: 'agent-entity',
          kind: 'task_agent',
          displayName: 'Task Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-entity',
          config: const AgentConfig(),
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        ),
      );
      await expectLater(
        () => service.pauseAgreement(agreementId: 'agent-entity'),
        throwsA(isA<StateError>()),
      );

      when(() => repository.getEntity('deleted-agreement')).thenAnswer(
        (_) async => _agreement(
          id: 'deleted-agreement',
          deletedAt: now,
        ),
      );
      await expectLater(
        () => service.pauseAgreement(agreementId: 'deleted-agreement'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('getAgreement', () {
    test('returns only non-deleted standing agreements', () async {
      final agreement = _agreement();
      when(
        () => repository.getEntity('agreement-001'),
      ).thenAnswer((_) async => agreement);
      expect(await service.getAgreement('agreement-001'), same(agreement));

      when(() => repository.getEntity('deleted-agreement')).thenAnswer(
        (_) async => _agreement(
          id: 'deleted-agreement',
          deletedAt: now,
        ),
      );
      expect(await service.getAgreement('deleted-agreement'), isNull);

      when(() => repository.getEntity('agent-entity')).thenAnswer(
        (_) async => AgentDomainEntity.agent(
          id: 'agent-entity',
          agentId: 'agent-entity',
          kind: 'task_agent',
          displayName: 'Task Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-entity',
          config: const AgentConfig(),
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        ),
      );
      expect(await service.getAgreement('agent-entity'), isNull);
    });
  });

  test('created agreements surface in planner-window inputs', () async {
    final db = AgentDatabase(inMemoryDatabase: true, background: false);
    addTearDown(db.close);
    final realRepository = AgentRepository(db);
    final writer = MockAgentSyncService();
    final projectionService = StandingAgreementService(
      repository: realRepository,
      syncService: writer,
    );

    when(() => writer.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.single as AgentDomainEntity;
      await realRepository.upsertEntity(entity);
    });

    final agreement = await withClock(Clock.fixed(now), () {
      return projectionService.createAgreement(
        agentId: agentId,
        title: 'Exercise three times per week',
        scope: StandingAgreementScope.fitness,
        cadence: StandingAgreementCadence.weekly,
        minCount: 3,
        preferredSessionMinutes: 45,
        activeFrom: DateTime(2026, 6),
      );
    });

    final inputs = await realRepository.getAttentionPlanningInputsForWindow(
      start: DateTime(2026, 6, 8),
      end: DateTime(2026, 6, 9),
      agreementScopes: const {StandingAgreementScope.fitness},
    );

    expect(inputs.claims, isEmpty);
    expect(inputs.standingAgreements.map((item) => item.id), [agreement.id]);
  });
}

StandingAgreementEntity _agreement({
  String id = 'agreement-001',
  String agentId = 'fitness-agent-001',
  String title = 'Exercise three times per week',
  StandingAgreementScope scope = StandingAgreementScope.fitness,
  StandingAgreementCadence cadence = StandingAgreementCadence.weekly,
  StandingAgreementStatus status = StandingAgreementStatus.active,
  StandingAgreementEnforcement enforcement =
      StandingAgreementEnforcement.target,
  StandingAgreementApprovalMode approvalMode =
      StandingAgreementApprovalMode.ask,
  String? categoryId,
  String? targetId,
  String? targetKind,
  String? customScope,
  String? customCadence,
  int? minCount = 3,
  int? maxCount,
  int? minMinutes = 135,
  int? maxMinutes,
  int? preferredSessionMinutes = 45,
  bool canPreempt = false,
  int priority = 0,
  List<String> preemptibleCategoryIds = const [],
  List<String> protectedCategoryIds = const [],
  String? rationale,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? deletedAt,
}) {
  final effectiveCreatedAt = createdAt ?? DateTime(2026, 6);
  final effectiveUpdatedAt = updatedAt ?? DateTime(2026, 6);

  return AgentDomainEntity.standingAgreement(
        id: id,
        agentId: agentId,
        title: title,
        scope: scope,
        cadence: cadence,
        status: status,
        enforcement: enforcement,
        approvalMode: approvalMode,
        categoryId: categoryId,
        targetId: targetId,
        targetKind: targetKind,
        customScope: customScope,
        customCadence: customCadence,
        minCount: minCount,
        maxCount: maxCount,
        minMinutes: minMinutes,
        maxMinutes: maxMinutes,
        preferredSessionMinutes: preferredSessionMinutes,
        canPreempt: canPreempt,
        priority: priority,
        preemptibleCategoryIds: preemptibleCategoryIds,
        protectedCategoryIds: protectedCategoryIds,
        rationale: rationale,
        createdAt: effectiveCreatedAt,
        updatedAt: effectiveUpdatedAt,
        vectorClock: const VectorClock({'node-1': 1}),
        deletedAt: deletedAt,
      )
      as StandingAgreementEntity;
}
