import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/task_resolution_time_series.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/state/wake_run_chart_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  group('pendingRitualReviewProvider', () {
    test('returns the newest session when it is active', () async {
      // Sessions are newest-first: active is the newest, completed is older.
      final activeSession = makeTestEvolutionSession(
        id: 'evo-active',
        sessionNumber: 2,
      );
      final completedSession = makeTestEvolutionSession(
        id: 'evo-completed',
        status: EvolutionSessionStatus.completed,
      );

      final container = ProviderContainer(
        overrides: [
          evolutionSessionsProvider(kTestTemplateId).overrideWith(
            (ref) async => <AgentDomainEntity>[
              activeSession,
              completedSession,
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        pendingRitualReviewProvider(kTestTemplateId).future,
      );

      expect(result, isNotNull);
      expect(result, isA<EvolutionSessionEntity>());
      final session = result! as EvolutionSessionEntity;
      expect(session.id, 'evo-active');
      expect(session.status, EvolutionSessionStatus.active);
    });

    test(
      'returns null when newest session is completed (stale active ignored)',
      () async {
        // Completed session is newer; the older active session is stale.
        final completedSession = makeTestEvolutionSession(
          id: 'evo-completed',
          sessionNumber: 2,
          status: EvolutionSessionStatus.completed,
        );
        final staleActiveSession = makeTestEvolutionSession(
          id: 'evo-stale',
        );

        final container = ProviderContainer(
          overrides: [
            evolutionSessionsProvider(kTestTemplateId).overrideWith(
              (ref) async => <AgentDomainEntity>[
                completedSession,
                staleActiveSession,
              ],
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          pendingRitualReviewProvider(kTestTemplateId).future,
        );

        expect(result, isNull);
      },
    );

    test('returns null when all sessions are completed or abandoned', () async {
      final container = ProviderContainer(
        overrides: [
          evolutionSessionsProvider(kTestTemplateId).overrideWith(
            (ref) async => <AgentDomainEntity>[
              makeTestEvolutionSession(
                id: 'evo-1',
                status: EvolutionSessionStatus.completed,
              ),
              makeTestEvolutionSession(
                id: 'evo-2',
                sessionNumber: 2,
                status: EvolutionSessionStatus.abandoned,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        pendingRitualReviewProvider(kTestTemplateId).future,
      );

      expect(result, isNull);
    });

    test('returns null when session list is empty', () async {
      final container = ProviderContainer(
        overrides: [
          evolutionSessionsProvider(kTestTemplateId).overrideWith(
            (ref) async => <AgentDomainEntity>[],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        pendingRitualReviewProvider(kTestTemplateId).future,
      );

      expect(result, isNull);
    });

    test('ignores non-EvolutionSessionEntity items', () async {
      final activeSession = makeTestEvolutionSession(
        id: 'evo-active',
      );
      // An EvolutionNoteEntity is NOT an EvolutionSessionEntity, so the
      // whereType filter should skip it.
      final note = makeTestEvolutionNote(id: 'note-1');

      final container = ProviderContainer(
        overrides: [
          evolutionSessionsProvider(kTestTemplateId).overrideWith(
            (ref) async => <AgentDomainEntity>[note, activeSession],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        pendingRitualReviewProvider(kTestTemplateId).future,
      );

      // The note is skipped, active session is the first typed session → newest.
      expect(result, isNotNull);
      expect(result, isA<EvolutionSessionEntity>());
      expect((result! as EvolutionSessionEntity).id, 'evo-active');
    });
  });

  group('templatesPendingReviewProvider', () {
    test('collects distinct template IDs from active sessions', () async {
      final container = ProviderContainer(
        overrides: [
          agentUpdateStreamProvider(agentNotification).overrideWith(
            (ref) => const Stream<Set<String>>.empty(),
          ),
          allEvolutionSessionsProvider.overrideWith(
            (ref) async => <AgentDomainEntity>[
              makeTestEvolutionSession(
                id: 'evo-1',
                templateId: 'template-A',
              ),
              makeTestEvolutionSession(
                id: 'evo-2',
                templateId: 'template-B',
                sessionNumber: 2,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        templatesPendingReviewProvider.future,
      );

      expect(result, {'template-A', 'template-B'});
    });

    test('ignores completed and abandoned sessions', () async {
      final container = ProviderContainer(
        overrides: [
          agentUpdateStreamProvider(agentNotification).overrideWith(
            (ref) => const Stream<Set<String>>.empty(),
          ),
          allEvolutionSessionsProvider.overrideWith(
            (ref) async => <AgentDomainEntity>[
              makeTestEvolutionSession(
                id: 'evo-1',
                templateId: 'template-A',
                status: EvolutionSessionStatus.completed,
              ),
              makeTestEvolutionSession(
                id: 'evo-2',
                templateId: 'template-B',
                sessionNumber: 2,
                status: EvolutionSessionStatus.abandoned,
              ),
              makeTestEvolutionSession(
                id: 'evo-3',
                templateId: 'template-C',
                sessionNumber: 3,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        templatesPendingReviewProvider.future,
      );

      expect(result, {'template-C'});
    });

    test('returns empty set when no active sessions', () async {
      final container = ProviderContainer(
        overrides: [
          agentUpdateStreamProvider(agentNotification).overrideWith(
            (ref) => const Stream<Set<String>>.empty(),
          ),
          allEvolutionSessionsProvider.overrideWith(
            (ref) async => <AgentDomainEntity>[
              makeTestEvolutionSession(
                id: 'evo-1',
                status: EvolutionSessionStatus.completed,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        templatesPendingReviewProvider.future,
      );

      expect(result, isEmpty);
    });

    test(
      'deduplicates when multiple active sessions share a template',
      () async {
        final container = ProviderContainer(
          overrides: [
            agentUpdateStreamProvider(agentNotification).overrideWith(
              (ref) => const Stream<Set<String>>.empty(),
            ),
            allEvolutionSessionsProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[
                makeTestEvolutionSession(
                  id: 'evo-1',
                  templateId: 'template-A',
                ),
                makeTestEvolutionSession(
                  id: 'evo-2',
                  templateId: 'template-A',
                  sessionNumber: 2,
                ),
              ],
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          templatesPendingReviewProvider.future,
        );

        expect(result, hasLength(1));
        expect(result, contains('template-A'));
      },
    );
  });

  group('evolutionSessionStatsProvider', () {
    test('correctly aggregates stats from mixed session statuses', () async {
      final sessions = <AgentDomainEntity>[
        makeTestEvolutionSession(
          id: 'evo-1',
          status: EvolutionSessionStatus.completed,
        ),
        makeTestEvolutionSession(
          id: 'evo-2',
          sessionNumber: 2,
          status: EvolutionSessionStatus.completed,
        ),
        makeTestEvolutionSession(
          id: 'evo-3',
          sessionNumber: 3,
          status: EvolutionSessionStatus.abandoned,
        ),
        makeTestEvolutionSession(
          id: 'evo-4',
          sessionNumber: 4,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          agentUpdateStreamProvider(kTestTemplateId).overrideWith(
            (ref) => const Stream<Set<String>>.empty(),
          ),
          evolutionSessionsProvider(kTestTemplateId).overrideWith(
            (ref) async => sessions,
          ),
        ],
      );
      addTearDown(container.dispose);

      final stats = await container.read(
        evolutionSessionStatsProvider(kTestTemplateId).future,
      );

      expect(stats.totalSessions, 4);
      expect(stats.completedCount, 2);
      expect(stats.abandonedCount, 1);
      expect(stats.approvalRate, 0.5);
    });

    test('returns zero approvalRate when no sessions exist', () async {
      final container = ProviderContainer(
        overrides: [
          agentUpdateStreamProvider(kTestTemplateId).overrideWith(
            (ref) => const Stream<Set<String>>.empty(),
          ),
          evolutionSessionsProvider(kTestTemplateId).overrideWith(
            (ref) async => <AgentDomainEntity>[],
          ),
        ],
      );
      addTearDown(container.dispose);

      final stats = await container.read(
        evolutionSessionStatsProvider(kTestTemplateId).future,
      );

      expect(stats.totalSessions, 0);
      expect(stats.completedCount, 0);
      expect(stats.abandonedCount, 0);
      expect(stats.approvalRate, 0.0);
    });
  });

  group('latestCompletedRitualTimestampProvider', () {
    test('returns completedAt for the newest completed session', () async {
      final completedAt = DateTime(2024, 3, 18, 12);
      final container = ProviderContainer(
        overrides: [
          evolutionSessionsProvider(kTestTemplateId).overrideWith(
            (ref) async => <AgentDomainEntity>[
              makeTestEvolutionSession(
                id: 'completed-1',
                status: EvolutionSessionStatus.completed,
                completedAt: completedAt,
              ),
              makeTestEvolutionSession(
                id: 'active-older',
                sessionNumber: 2,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        latestCompletedRitualTimestampProvider(kTestTemplateId).future,
      );

      expect(result, completedAt);
    });

    test('falls back to createdAt when completedAt is missing', () async {
      final createdAt = DateTime(2024, 3, 17, 8);
      final container = ProviderContainer(
        overrides: [
          evolutionSessionsProvider(kTestTemplateId).overrideWith(
            (ref) async => <AgentDomainEntity>[
              makeTestEvolutionSession(
                id: 'completed-1',
                status: EvolutionSessionStatus.completed,
                createdAt: createdAt,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        latestCompletedRitualTimestampProvider(kTestTemplateId).future,
      );

      expect(result, createdAt);
    });
  });

  group('ritualSessionHistoryProvider', () {
    test('joins non-active sessions with persisted recap payloads', () async {
      final completed = makeTestEvolutionSession(
        id: 'session-completed',
        status: EvolutionSessionStatus.completed,
      );
      final abandoned = makeTestEvolutionSession(
        id: 'session-abandoned',
        sessionNumber: 2,
        status: EvolutionSessionStatus.abandoned,
      );
      final active = makeTestEvolutionSession(
        id: 'session-active',
        sessionNumber: 3,
      );
      final templateService = MockAgentTemplateService();

      when(
        () => templateService.getEvolutionSessionRecaps(kTestTemplateId),
      ).thenAnswer(
        (_) async => [
          makeTestEvolutionSessionRecap(
            sessionId: completed.id,
            tldr: 'Updated the greeting.',
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          agentUpdateStreamProvider(kTestTemplateId).overrideWith(
            (ref) => const Stream<Set<String>>.empty(),
          ),
          agentTemplateServiceProvider.overrideWithValue(templateService),
          evolutionSessionsProvider(kTestTemplateId).overrideWith(
            (ref) async => <AgentDomainEntity>[
              active,
              abandoned,
              completed,
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        ritualSessionHistoryProvider(kTestTemplateId).future,
      );

      expect(result, hasLength(2));
      expect(result.first.session.id, 'session-abandoned');
      expect(result.first.recap, isNull);
      expect(result.last.session.id, 'session-completed');
      expect(result.last.recap?.tldr, 'Updated the greeting.');
    });
  });

  group('ritualSummaryMetricsProvider', () {
    test(
      'aggregates summary metrics relative to the last completed session',
      () async {
        final now = DateTime(2024, 3, 31, 14);
        final today = DateTime(2024, 3, 31);
        final chartStart = DateTime(2024, 3, 2);
        final lastSessionAt = DateTime(2024, 3, 25, 9);
        final templateService = MockAgentTemplateService();
        final repository = MockAgentRepository();

        when(
          () => templateService.getLifetimeWakeCount(kTestTemplateId),
        ).thenAnswer((_) async => 21);
        when(
          () => templateService.getWakeRunsInWindow(
            kTestTemplateId,
            since: chartStart,
            until: now,
          ),
        ).thenAnswer(
          (_) async => [
            makeTestWakeRun(
              templateId: kTestTemplateId,
              createdAt: DateTime(2024, 3, 2, 12),
            ),
            makeTestWakeRun(
              runKey: 'run-2',
              templateId: kTestTemplateId,
              createdAt: DateTime(2024, 3, 31, 8),
            ),
          ],
        );
        when(
          () => templateService.getWakeRunsInWindow(
            kTestTemplateId,
            since: lastSessionAt,
            until: now,
          ),
        ).thenAnswer(
          (_) async => [
            makeTestWakeRun(
              templateId: kTestTemplateId,
              createdAt: DateTime(2024, 3, 26, 10),
            ),
            makeTestWakeRun(
              runKey: 'run-3',
              templateId: kTestTemplateId,
              createdAt: DateTime(2024, 3, 28, 10),
            ),
          ],
        );
        when(
          () => repository.sumTokenUsageForTemplateSince(
            kTestTemplateId,
            since: lastSessionAt,
          ),
        ).thenAnswer(
          (_) async => SumTokenUsageByTemplateSinceResult(
            totalInput: 120,
            totalOutput: 45,
            totalThoughts: 10,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            agentUpdateStreamProvider(kTestTemplateId).overrideWith(
              (ref) => const Stream<Set<String>>.empty(),
            ),
            agentTemplateServiceProvider.overrideWithValue(templateService),
            agentRepositoryProvider.overrideWithValue(repository),
            latestCompletedRitualTimestampProvider(
              kTestTemplateId,
            ).overrideWith((ref) async => lastSessionAt),
            templateTaskResolutionTimeSeriesProvider(
              kTestTemplateId,
            ).overrideWith(
              (ref) async => TaskResolutionTimeSeries(
                dailyBuckets: [
                  DailyResolutionBucket(
                    date: DateTime(2024, 3, 20),
                    resolvedCount: 2,
                    averageMttr: const Duration(hours: 2),
                  ),
                  DailyResolutionBucket(
                    date: DateTime(2024, 3, 21),
                    resolvedCount: 1,
                    averageMttr: const Duration(hours: 5),
                  ),
                ],
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await withClock(
          Clock.fixed(now),
          () => container.read(
            ritualSummaryMetricsProvider(kTestTemplateId).future,
          ),
        );

        expect(result.lifetimeWakeCount, 21);
        expect(result.wakesSinceLastSession, 2);
        expect(result.totalTokenUsageSinceLastSession, 175);
        expect(result.meanTimeToResolution, const Duration(hours: 3));
        expect(result.dailyWakeCounts, hasLength(30));
        expect(result.dailyWakeCounts.first.date, chartStart);
        expect(result.dailyWakeCounts.first.wakeCount, 1);
        expect(result.dailyWakeCounts.last.date, today);
        expect(result.dailyWakeCounts.last.wakeCount, 1);
      },
    );

    test('uses lifetime totals when no completed ritual exists yet', () async {
      final now = DateTime(2024, 3, 31, 14);
      final chartStart = DateTime(2024, 3, 2);
      final templateService = MockAgentTemplateService();
      final repository = MockAgentRepository();

      when(
        () => templateService.getLifetimeWakeCount(kTestTemplateId),
      ).thenAnswer((_) async => 9);
      when(
        () => templateService.getWakeRunsInWindow(
          kTestTemplateId,
          since: chartStart,
          until: now,
        ),
      ).thenAnswer((_) async => const []);
      when(
        () => repository.sumTokenUsageForTemplate(kTestTemplateId),
      ).thenAnswer(
        (_) async => SumTokenUsageByTemplateResult(
          totalInput: 10,
          totalOutput: 5,
          totalThoughts: 1,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          agentUpdateStreamProvider(kTestTemplateId).overrideWith(
            (ref) => const Stream<Set<String>>.empty(),
          ),
          agentTemplateServiceProvider.overrideWithValue(templateService),
          agentRepositoryProvider.overrideWithValue(repository),
          latestCompletedRitualTimestampProvider(
            kTestTemplateId,
          ).overrideWith((ref) async => null),
          templateTaskResolutionTimeSeriesProvider(
            kTestTemplateId,
          ).overrideWith(
            (ref) async => const TaskResolutionTimeSeries(dailyBuckets: []),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await withClock(
        Clock.fixed(now),
        () => container.read(
          ritualSummaryMetricsProvider(kTestTemplateId).future,
        ),
      );

      expect(result.lifetimeWakeCount, 9);
      expect(result.wakesSinceLastSession, 9);
      expect(result.totalTokenUsageSinceLastSession, 16);
      expect(result.meanTimeToResolution, isNull);
      verify(
        () => repository.sumTokenUsageForTemplate(kTestTemplateId),
      ).called(1);
    });
  });
}
