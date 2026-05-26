import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart'
    hide dayAgentProvider;
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  // Default to an empty agent-update stream so providers that watch
  // `agentUpdateStreamProvider(...)` don't try to reach for `UpdateNotifications`
  // from GetIt at test time.
  final silenceAgentUpdates = agentUpdateStreamProvider.overrideWith(
    (ref, agentId) => const Stream<Set<String>>.empty(),
  );

  group('currentDraftPlanProvider', () {
    final asOf = DateTime(2026, 5, 25);

    MockDayAgent freshAgent() => MockDayAgent(
      parseLatency: Duration.zero,
      pendingLatency: Duration.zero,
      triageLatency: Duration.zero,
      draftLatency: Duration.zero,
      summarizeLatency: Duration.zero,
      clock: () => DateTime(2026, 5, 25, 9),
    );

    ProviderContainer makeContainer(DayAgentInterface agent) {
      final container = ProviderContainer(
        overrides: [
          dayAgentProvider.overrideWithValue(agent),
          silenceAgentUpdates,
        ],
      )..listen(currentDraftPlanProvider(asOf), (_, _) {});
      addTearDown(container.dispose);
      return container;
    }

    test('returns null when the agent has no plan for the date', () async {
      // MockDayAgent.currentPlanForDate is hard-wired to return null.
      final plan = await makeContainer(
        freshAgent(),
      ).read(currentDraftPlanProvider(asOf).future);
      expect(plan, isNull);
    });

    test(
      'returns the projected plan when the agent supplies one and forwards '
      'the requested date',
      () async {
        final agent = _PlanProvidingAgent();
        final plan = await makeContainer(
          agent,
        ).read(currentDraftPlanProvider(asOf).future);
        expect(plan, isNotNull);
        expect(plan!.dayDate, asOf);
        expect(agent.requestedDates, [asOf]);
      },
    );
  });

  group('capturesForDateProvider', () {
    final forDate = DateTime(2026, 5, 25, 9);
    final dayAt = DateTime(2026, 5, 25);

    late MockDayAgentService dayAgentService;
    late MockAgentRepository agentRepository;
    late MockJournalDb journalDb;

    setUp(() {
      dayAgentService = MockDayAgentService();
      agentRepository = MockAgentRepository();
      journalDb = MockJournalDb();
    });

    ProviderContainer makeContainer() {
      final container = ProviderContainer(
        overrides: [
          dayAgentServiceProvider.overrideWithValue(dayAgentService),
          agentRepositoryProvider.overrideWithValue(agentRepository),
          journalDbProvider.overrideWithValue(journalDb),
          silenceAgentUpdates,
        ],
      )..listen(capturesForDateProvider(forDate), (_, _) {});
      addTearDown(container.dispose);
      return container;
    }

    CaptureEntity makeCapture({
      required String id,
      required String agentId,
      DateTime? capturedAt,
      String? audioRef,
      DateTime? deletedAt,
    }) {
      return AgentDomainEntity.capture(
            id: id,
            agentId: agentId,
            transcript: 'tx-$id',
            capturedAt: capturedAt ?? forDate,
            createdAt: capturedAt ?? forDate,
            vectorClock: null,
            audioRef: audioRef,
            deletedAt: deletedAt,
          )
          as CaptureEntity;
    }

    test('returns empty when no day agent exists for the date', () async {
      when(
        () => dayAgentService.getDayAgentForDate(any()),
      ).thenAnswer((_) async => null);

      final captures = await makeContainer().read(
        capturesForDateProvider(forDate).future,
      );

      expect(captures, isEmpty);
      verifyNever(
        () => agentRepository.getEntitiesByAgentId(
          any(),
          type: any(named: 'type'),
        ),
      );
    });

    test(
      'queries the agent repo with the day-agent id and the capture entity '
      'type',
      () async {
        const agentId = 'day-agent-001';
        when(() => dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => agentRepository.getEntitiesByAgentId(
            agentId,
            type: AgentEntityTypes.capture,
          ),
        ).thenAnswer((_) async => const <AgentDomainEntity>[]);

        await makeContainer().read(capturesForDateProvider(forDate).future);

        // The provider re-derives the day-agent id from the supplied date.
        verify(() => dayAgentService.getDayAgentForDate(forDate)).called(1);
        verify(
          () => agentRepository.getEntitiesByAgentId(
            agentId,
            type: AgentEntityTypes.capture,
          ),
        ).called(1);
      },
    );

    test(
      'filters out soft-deleted captures and pairs the survivor with its '
      'JournalAudio',
      () async {
        const agentId = 'day-agent-002';
        when(() => dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        final live = makeCapture(
          id: 'cap-live',
          agentId: agentId,
          audioRef: testAudioEntry.meta.id,
        );
        final tombstone = makeCapture(
          id: 'cap-deleted',
          agentId: agentId,
          deletedAt: dayAt,
        );
        when(
          () => agentRepository.getEntitiesByAgentId(
            agentId,
            type: AgentEntityTypes.capture,
          ),
        ).thenAnswer((_) async => [live, tombstone]);
        when(
          () => journalDb.journalEntityById(testAudioEntry.meta.id),
        ).thenAnswer((_) async => testAudioEntry);

        final rows = await makeContainer().read(
          capturesForDateProvider(forDate).future,
        );

        expect(rows, hasLength(1));
        expect(rows.single.capture.id, 'cap-live');
        expect(rows.single.audio?.meta.id, testAudioEntry.meta.id);
      },
    );

    test(
      'leaves audio null when the capture has no audioRef',
      () async {
        const agentId = 'day-agent-003';
        when(() => dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        final typed = makeCapture(id: 'cap-typed', agentId: agentId);
        when(
          () => agentRepository.getEntitiesByAgentId(
            agentId,
            type: AgentEntityTypes.capture,
          ),
        ).thenAnswer((_) async => [typed]);

        final rows = await makeContainer().read(
          capturesForDateProvider(forDate).future,
        );

        expect(rows, hasLength(1));
        expect(rows.single.audio, isNull);
        verifyNever(() => journalDb.journalEntityById(any()));
      },
    );

    test(
      'leaves audio null when the referenced JournalAudio has been deleted',
      () async {
        const agentId = 'day-agent-004';
        const audioRef = 'audio-deleted';
        when(() => dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        final capture = makeCapture(
          id: 'cap-stale-audio',
          agentId: agentId,
          audioRef: audioRef,
        );
        final deletedAudio = JournalAudio(
          meta: testAudioEntry.meta.copyWith(
            id: audioRef,
            deletedAt: dayAt,
          ),
          data: testAudioEntry.data,
        );
        when(
          () => agentRepository.getEntitiesByAgentId(
            agentId,
            type: AgentEntityTypes.capture,
          ),
        ).thenAnswer((_) async => [capture]);
        when(
          () => journalDb.journalEntityById(audioRef),
        ).thenAnswer((_) async => deletedAudio);

        final rows = await makeContainer().read(
          capturesForDateProvider(forDate).future,
        );

        expect(rows, hasLength(1));
        expect(rows.single.audio, isNull);
      },
    );

    test(
      'leaves audio null when the referenced JournalAudio cannot be found',
      () async {
        const agentId = 'day-agent-005';
        const audioRef = 'audio-missing';
        when(() => dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        final capture = makeCapture(
          id: 'cap-no-audio',
          agentId: agentId,
          audioRef: audioRef,
        );
        when(
          () => agentRepository.getEntitiesByAgentId(
            agentId,
            type: AgentEntityTypes.capture,
          ),
        ).thenAnswer((_) async => [capture]);
        when(
          () => journalDb.journalEntityById(audioRef),
        ).thenAnswer((_) async => null);

        final rows = await makeContainer().read(
          capturesForDateProvider(forDate).future,
        );

        expect(rows, hasLength(1));
        expect(rows.single.audio, isNull);
      },
    );
  });
}

/// Mock day agent that records the dates `currentPlanForDate` was called
/// with so we can assert the provider plumbed the right value through. The
/// returned plan is a minimal shape that round-trips the requested date.
class _PlanProvidingAgent extends MockDayAgent {
  _PlanProvidingAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        draftLatency: Duration.zero,
        summarizeLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );

  final List<DateTime> requestedDates = [];

  @override
  Future<DraftPlan?> currentPlanForDate(DateTime date) async {
    requestedDates.add(date);
    return DraftPlan(
      dayDate: date,
      blocks: const [],
      bands: const [],
      capacityMinutes: 480,
      scheduledMinutes: 0,
    );
  }
}
