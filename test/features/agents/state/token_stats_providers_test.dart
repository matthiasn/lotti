import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/token_stats_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository mockRepository;

  setUp(() {
    mockRepository = MockAgentRepository();
    when(
      () => mockRepository.getGlobalTokenUsageSince(since: any(named: 'since')),
    ).thenAnswer((_) async => <WakeTokenUsageEntity>[]);
    when(
      () => mockRepository.getWakeRunsInWindow(
        since: any(named: 'since'),
        until: any(named: 'until'),
      ),
    ).thenAnswer((_) async => <WakeRunLogData>[]);
  });

  ProviderContainer createContainer({
    List<WakeTokenUsageEntity> tokenRecords = const [],
    List<WakeRunLogData> wakeRuns = const [],
  }) {
    when(
      () => mockRepository.getGlobalTokenUsageSince(since: any(named: 'since')),
    ).thenAnswer((_) async => tokenRecords);
    when(
      () => mockRepository.getWakeRunsInWindow(
        since: any(named: 'since'),
        until: any(named: 'until'),
      ),
    ).thenAnswer((_) async => wakeRuns);

    final container = ProviderContainer(
      overrides: [
        agentRepositoryProvider.overrideWithValue(mockRepository),
        agentUpdateStreamProvider(agentNotification).overrideWithValue(
          const AsyncValue<Set<String>>.loading(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  WakeTokenUsageEntity makeTokenRecord({
    required DateTime createdAt,
    required int inputTokens,
    int outputTokens = 0,
    int thoughtsTokens = 0,
    String? templateId,
    String agentId = 'agent-1',
  }) {
    return AgentDomainEntity.wakeTokenUsage(
          id: 'usage-${createdAt.millisecondsSinceEpoch}',
          agentId: agentId,
          runKey: 'run-${createdAt.millisecondsSinceEpoch}',
          threadId: 'thread-1',
          modelId: 'models/test-model',
          createdAt: createdAt,
          vectorClock: null,
          templateId: templateId,
          inputTokens: inputTokens,
          outputTokens: outputTokens,
          thoughtsTokens: thoughtsTokens,
        )
        as WakeTokenUsageEntity;
  }

  group('dailyTokenUsageProvider', () {
    test('returns 7 days of data with correct structure', () async {
      final now = DateTime(2024, 3, 15, 14, 30);
      await withClock(Clock.fixed(now), () async {
        final container = createContainer();
        final result = await container.read(dailyTokenUsageProvider(7).future);

        expect(result, hasLength(7));
        expect(result.last.isToday, isTrue);
        expect(result.first.isToday, isFalse);
        expect(result.last.date, DateTime(2024, 3, 15));
        expect(result.first.date, DateTime(2024, 3, 9));
      });
    });

    test('groups token records by day', () async {
      final now = DateTime(2024, 3, 15, 14, 30);
      await withClock(Clock.fixed(now), () async {
        final records = [
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 15, 10),
            inputTokens: 1000,
          ),
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 15, 12),
            inputTokens: 2000,
          ),
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 14, 8),
            inputTokens: 500,
          ),
        ];

        final container = createContainer(tokenRecords: records);
        final result = await container.read(dailyTokenUsageProvider(7).future);

        // Today (March 15) should have 3000 tokens.
        final today = result.last;
        expect(today.isToday, isTrue);
        expect(today.totalTokens, 3000);

        // Yesterday (March 14) should have 500 tokens.
        final yesterday = result[result.length - 2];
        expect(yesterday.totalTokens, 500);
      });
    });

    test('computes tokensByTimeOfDay for past days', () async {
      final now = DateTime(2024, 3, 15, 14, 30);
      await withClock(Clock.fixed(now), () async {
        final records = [
          // March 14 at 10:00 — before 14:30 cutoff
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 14, 10),
            inputTokens: 1000,
          ),
          // March 14 at 16:00 — after 14:30 cutoff
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 14, 16),
            inputTokens: 2000,
          ),
        ];

        final container = createContainer(tokenRecords: records);
        final result = await container.read(dailyTokenUsageProvider(7).future);

        final yesterday = result[result.length - 2];
        expect(yesterday.totalTokens, 3000);
        expect(yesterday.tokensByTimeOfDay, 1000);
      });
    });

    test('today tokensByTimeOfDay equals totalTokens', () async {
      final now = DateTime(2024, 3, 15, 14, 30);
      await withClock(Clock.fixed(now), () async {
        final records = [
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 15, 10),
            inputTokens: 1000,
          ),
        ];

        final container = createContainer(tokenRecords: records);
        final result = await container.read(dailyTokenUsageProvider(7).future);

        final today = result.last;
        expect(today.tokensByTimeOfDay, today.totalTokens);
      });
    });

    test('returns zeros for days with no records', () async {
      final now = DateTime(2024, 3, 15, 14, 30);
      await withClock(Clock.fixed(now), () async {
        final container = createContainer();
        final result = await container.read(dailyTokenUsageProvider(7).future);

        for (final day in result) {
          expect(day.totalTokens, 0);
          expect(day.tokensByTimeOfDay, 0);
        }
      });
    });
  });

  group('tokenUsageComparisonProvider', () {
    test('computes average from past days', () async {
      final now = DateTime(2024, 3, 15, 14, 30);
      await withClock(Clock.fixed(now), () async {
        final records = [
          // Today: 5000 tokens
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 15, 10),
            inputTokens: 5000,
          ),
          // Yesterday: 2000 by cutoff
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 14, 10),
            inputTokens: 2000,
          ),
          // 2 days ago: 4000 by cutoff
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 13, 12),
            inputTokens: 4000,
          ),
        ];

        final container = createContainer(tokenRecords: records);
        final result = await container.read(
          tokenUsageComparisonProvider(7).future,
        );

        // Average of past days: (2000 + 4000 + 0 + 0 + 0 + 0) / 6 = 1000
        expect(result.averageTokensByTimeOfDay, 1000);
        expect(result.todayTokens, 5000);
        expect(result.isAboveAverage, isTrue);
      });
    });

    test('below average when today is lower', () async {
      final now = DateTime(2024, 3, 15, 14, 30);
      await withClock(Clock.fixed(now), () async {
        final records = [
          // Today: 100 tokens
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 15, 10),
            inputTokens: 100,
          ),
          // Past days: 5000 each by cutoff
          for (var i = 1; i <= 6; i++)
            makeTokenRecord(
              createdAt: DateTime(2024, 3, 15 - i, 10),
              inputTokens: 5000,
            ),
        ];

        final container = createContainer(tokenRecords: records);
        final result = await container.read(
          tokenUsageComparisonProvider(7).future,
        );

        expect(result.isAboveAverage, isFalse);
        expect(result.todayTokens, 100);
        expect(result.averageTokensByTimeOfDay, 5000);
      });
    });
  });

  group('tokenSourceBreakdownProvider', () {
    test('groups tokens by templateId and computes percentages', () async {
      final now = DateTime(2024, 3, 15, 14, 30);
      await withClock(Clock.fixed(now), () async {
        final records = [
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 15, 10),
            inputTokens: 8000,
            templateId: 'tpl-a',
          ),
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 15, 12),
            inputTokens: 2000,
            templateId: 'tpl-b',
            agentId: 'agent-2',
          ),
        ];

        final templateA = makeTestTemplate(
          id: 'tpl-a',
          agentId: 'tpl-a',
          displayName: 'Agent Alpha',
        );
        final templateB = makeTestTemplate(
          id: 'tpl-b',
          agentId: 'tpl-b',
          displayName: 'Agent Beta',
        );

        when(() => mockRepository.getEntity('tpl-a')).thenAnswer(
          (_) async => templateA,
        );
        when(() => mockRepository.getEntity('tpl-b')).thenAnswer(
          (_) async => templateB,
        );

        final container = createContainer(tokenRecords: records);
        final result = await container.read(
          tokenSourceBreakdownProvider.future,
        );

        expect(result, hasLength(2));
        // Sorted by total descending.
        expect(result.first.displayName, 'Agent Alpha');
        expect(result.first.totalTokens, 8000);
        expect(result.first.percentage, 80);
        expect(result.last.displayName, 'Agent Beta');
        expect(result.last.totalTokens, 2000);
        expect(result.last.percentage, 20);
      });
    });

    test('flags high usage sources', () async {
      final now = DateTime(2024, 3, 15, 14, 30);
      await withClock(Clock.fixed(now), () async {
        final records = [
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 15, 10),
            inputTokens: 9000,
            templateId: 'tpl-heavy',
          ),
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 15, 11),
            inputTokens: 500,
            templateId: 'tpl-light-1',
          ),
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 15, 12),
            inputTokens: 500,
            templateId: 'tpl-light-2',
          ),
        ];

        for (final id in ['tpl-heavy', 'tpl-light-1', 'tpl-light-2']) {
          when(() => mockRepository.getEntity(id)).thenAnswer(
            (_) async => makeTestTemplate(
              id: id,
              agentId: id,
              displayName: id,
            ),
          );
        }

        final container = createContainer(tokenRecords: records);
        final result = await container.read(
          tokenSourceBreakdownProvider.future,
        );

        // Fair share = 100/3 = 33.3%. Threshold = 33.3 * 2.5 = 83.3%.
        // Heavy source at 90% > 83.3% -> flagged.
        final heavySource = result.firstWhere(
          (s) => s.templateId == 'tpl-heavy',
        );
        expect(heavySource.isHighUsage, isTrue);
        expect(heavySource.percentage, 90);

        // Light sources at 5% < 83.3% -> not flagged.
        final lightSource = result.firstWhere(
          (s) => s.templateId == 'tpl-light-1',
        );
        expect(lightSource.isHighUsage, isFalse);
      });
    });

    test('returns empty list when no records', () async {
      final now = DateTime(2024, 3, 15, 14, 30);
      await withClock(Clock.fixed(now), () async {
        final container = createContainer();
        final result = await container.read(
          tokenSourceBreakdownProvider.future,
        );

        expect(result, isEmpty);
      });
    });
  });

  group('dailyTokenUsageByModelProvider', () {
    test('groups records by modelId and sorts by total descending', () async {
      final now = DateTime(2024, 3, 15, 14, 30);
      await withClock(Clock.fixed(now), () async {
        final records = [
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 15, 10),
            inputTokens: 1000,
          ),
          makeTokenRecord(
            createdAt: DateTime(2024, 3, 14, 8),
            inputTokens: 5000,
          ),
        ];

        // Both use default modelId 'models/test-model', so one model group.
        final container = createContainer(tokenRecords: records);
        final result = await container.read(
          dailyTokenUsageByModelProvider(7).future,
        );

        expect(result, hasLength(1));
        expect(result.keys.first, 'models/test-model');
        expect(result.values.first, hasLength(7));
      });
    });

    test('separates different models', () async {
      final now = DateTime(2024, 3, 15, 14, 30);
      await withClock(Clock.fixed(now), () async {
        final recordA =
            AgentDomainEntity.wakeTokenUsage(
                  id: 'usage-a',
                  agentId: 'agent-1',
                  runKey: 'run-a',
                  threadId: 'thread-1',
                  modelId: 'models/model-a',
                  createdAt: DateTime(2024, 3, 15, 10),
                  vectorClock: null,
                  inputTokens: 8000,
                )
                as WakeTokenUsageEntity;

        final recordB =
            AgentDomainEntity.wakeTokenUsage(
                  id: 'usage-b',
                  agentId: 'agent-1',
                  runKey: 'run-b',
                  threadId: 'thread-1',
                  modelId: 'models/model-b',
                  createdAt: DateTime(2024, 3, 15, 12),
                  vectorClock: null,
                  inputTokens: 2000,
                )
                as WakeTokenUsageEntity;

        final container = createContainer(
          tokenRecords: [recordA, recordB],
        );
        final result = await container.read(
          dailyTokenUsageByModelProvider(7).future,
        );

        expect(result, hasLength(2));
        // Sorted by total descending — model-a (8000) first.
        expect(result.keys.first, 'models/model-a');
        expect(result.keys.last, 'models/model-b');
      });
    });

    test('returns empty map when no records', () async {
      final now = DateTime(2024, 3, 15, 14, 30);
      await withClock(Clock.fixed(now), () async {
        final container = createContainer();
        final result = await container.read(
          dailyTokenUsageByModelProvider(7).future,
        );

        expect(result, isEmpty);
      });
    });
  });

  group('_wakeRunCountsProvider (via dailyTokenUsageProvider)', () {
    test(
      'accumulates multiple wake runs on the same day into wakeCount',
      () async {
        final now = DateTime(2024, 3, 15, 14, 30);
        await withClock(Clock.fixed(now), () async {
          // Three runs on March 14 — same day key, so count should be 3.
          final wakeRuns = [
            makeTestWakeRun(
              createdAt: DateTime(2024, 3, 14, 8),
              agentId: 'agent-1',
            ),
            makeTestWakeRun(
              runKey: 'run-key-002',
              createdAt: DateTime(2024, 3, 14, 10),
              agentId: 'agent-1',
            ),
            makeTestWakeRun(
              runKey: 'run-key-003',
              createdAt: DateTime(2024, 3, 14, 12),
              agentId: 'agent-1',
            ),
          ];

          final container = createContainer(wakeRuns: wakeRuns);
          final result = await container.read(
            dailyTokenUsageProvider(7).future,
          );

          final march14 = result[result.length - 2];
          expect(march14.date, DateTime(2024, 3, 14));
          // All three runs on March 14 must be counted.
          expect(march14.wakeCount, 3);
        });
      },
    );

    test('splits wake runs across different days', () async {
      final now = DateTime(2024, 3, 15, 14, 30);
      await withClock(Clock.fixed(now), () async {
        final wakeRuns = [
          makeTestWakeRun(
            createdAt: DateTime(2024, 3, 15, 9),
            agentId: 'agent-1',
          ),
          makeTestWakeRun(
            runKey: 'run-key-002',
            createdAt: DateTime(2024, 3, 14, 9),
            agentId: 'agent-1',
          ),
        ];

        final container = createContainer(wakeRuns: wakeRuns);
        final result = await container.read(dailyTokenUsageProvider(7).future);

        final today = result.last;
        final yesterday = result[result.length - 2];
        expect(today.wakeCount, 1);
        expect(yesterday.wakeCount, 1);
      });
    });
  });

  group('tokenUsageComparisonProvider — no-today edge case', () {
    test(
      'synthesises zero-token today when dailyTokenUsageProvider omits it',
      () async {
        // Supply a dailyUsage list that contains NO isToday entry.  This drives
        // the orElse branch at lines 107-108 that builds a zero-token sentinel.
        final now = DateTime(2024, 3, 15, 14, 30);
        await withClock(Clock.fixed(now), () async {
          // Two past-day entries, neither has isToday == true.
          final pastOnly = [
            DailyTokenUsage(
              date: DateTime.utc(2024, 3, 14),
              totalTokens: 6000,
              tokensByTimeOfDay: 3000,
              isToday: false,
            ),
            DailyTokenUsage(
              date: DateTime.utc(2024, 3, 13),
              totalTokens: 4000,
              tokensByTimeOfDay: 2000,
              isToday: false,
            ),
          ];

          final container = ProviderContainer(
            overrides: [
              agentRepositoryProvider.overrideWithValue(mockRepository),
              agentUpdateStreamProvider(agentNotification).overrideWithValue(
                const AsyncValue<Set<String>>.loading(),
              ),
              dailyTokenUsageProvider(7).overrideWith(
                (ref) async => pastOnly,
              ),
            ],
          );
          addTearDown(container.dispose);

          final result = await container.read(
            tokenUsageComparisonProvider(7).future,
          );

          // orElse branch: today sentinel has totalTokens == 0.
          expect(result.todayTokens, 0);
          // average of tokensByTimeOfDay from 2 past days: (3000+2000)/2 = 2500.
          expect(result.averageTokensByTimeOfDay, 2500);
          expect(result.isAboveAverage, isFalse);
        });
      },
    );
  });

  group(
    'tokenSourceBreakdownProvider — wake duration & identity resolution',
    () {
      test(
        'accumulates totalDuration from startedAt/completedAt on wake runs',
        () async {
          final now = DateTime(2024, 3, 15, 14, 30);
          await withClock(Clock.fixed(now), () async {
            final records = [
              makeTokenRecord(
                createdAt: DateTime(2024, 3, 15, 10),
                inputTokens: 5000,
                templateId: 'tpl-x',
              ),
            ];

            // Two runs for the same template, each 2 minutes long.
            final wakeRuns = [
              makeTestWakeRun(
                agentId: 'agent-1',
                templateId: 'tpl-x',
                createdAt: DateTime(2024, 3, 15, 10),
                startedAt: DateTime(2024, 3, 15, 10),
                completedAt: DateTime(2024, 3, 15, 10, 2),
              ),
              makeTestWakeRun(
                runKey: 'run-key-002',
                agentId: 'agent-1',
                templateId: 'tpl-x',
                createdAt: DateTime(2024, 3, 15, 11),
                startedAt: DateTime(2024, 3, 15, 11),
                completedAt: DateTime(2024, 3, 15, 11, 2),
              ),
            ];

            when(() => mockRepository.getEntity('tpl-x')).thenAnswer(
              (_) async => makeTestTemplate(
                id: 'tpl-x',
                agentId: 'tpl-x',
                displayName: 'Agent X',
              ),
            );

            final container = createContainer(
              tokenRecords: records,
              wakeRuns: wakeRuns,
            );
            final result = await container.read(
              tokenSourceBreakdownProvider.future,
            );

            expect(result, hasLength(1));
            final breakdown = result.first;
            // Both runs are 2 minutes each → total 4 minutes.
            expect(breakdown.totalDuration, const Duration(minutes: 4));
            expect(breakdown.wakeCount, 2);
          });
        },
      );

      test('ignores duration when startedAt or completedAt is null', () async {
        final now = DateTime(2024, 3, 15, 14, 30);
        await withClock(Clock.fixed(now), () async {
          final records = [
            makeTokenRecord(
              createdAt: DateTime(2024, 3, 15, 10),
              inputTokens: 1000,
              templateId: 'tpl-y',
            ),
          ];

          // Run with no timing info — duration should stay at zero.
          final wakeRuns = [
            makeTestWakeRun(
              agentId: 'agent-1',
              templateId: 'tpl-y',
              createdAt: DateTime(2024, 3, 15, 10),
            ),
          ];

          when(() => mockRepository.getEntity('tpl-y')).thenAnswer(
            (_) async => makeTestTemplate(
              id: 'tpl-y',
              agentId: 'tpl-y',
              displayName: 'Agent Y',
            ),
          );

          final container = createContainer(
            tokenRecords: records,
            wakeRuns: wakeRuns,
          );
          final result = await container.read(
            tokenSourceBreakdownProvider.future,
          );

          expect(result, hasLength(1));
          expect(result.first.totalDuration, Duration.zero);
          expect(result.first.wakeCount, 1);
        });
      });

      test(
        'resolves AgentIdentityEntity display name (isTemplate false)',
        () async {
          final now = DateTime(2024, 3, 15, 14, 30);
          await withClock(Clock.fixed(now), () async {
            // Record with no templateId so the agentId is used as the key.
            final record =
                AgentDomainEntity.wakeTokenUsage(
                      id: 'usage-identity',
                      agentId: 'agent-identity-1',
                      runKey: 'run-identity',
                      threadId: 'thread-1',
                      modelId: 'models/test-model',
                      createdAt: DateTime(2024, 3, 15, 10),
                      vectorClock: null,
                      // ignore: avoid_redundant_argument_values
                      templateId: null, // forces agentId as key
                      inputTokens: 4000,
                    )
                    as WakeTokenUsageEntity;

            final identity = makeTestIdentity(
              id: 'agent-identity-1',
              agentId: 'agent-identity-1',
              displayName: 'Identity Agent',
            );

            when(() => mockRepository.getEntity('agent-identity-1')).thenAnswer(
              (_) async => identity,
            );

            final container = createContainer(tokenRecords: [record]);
            final result = await container.read(
              tokenSourceBreakdownProvider.future,
            );

            expect(result, hasLength(1));
            final breakdown = result.first;
            // AgentIdentityEntity branch: isTemplate must be false.
            expect(breakdown.isTemplate, isFalse);
            expect(breakdown.displayName, 'Identity Agent');
            expect(breakdown.totalTokens, 4000);
            expect(breakdown.percentage, 100.0);
          });
        },
      );

      test('falls back to id as displayName when getEntity throws', () async {
        final now = DateTime(2024, 3, 15, 14, 30);
        await withClock(Clock.fixed(now), () async {
          final record =
              AgentDomainEntity.wakeTokenUsage(
                    id: 'usage-err',
                    agentId: 'agent-err-1',
                    runKey: 'run-err',
                    threadId: 'thread-1',
                    modelId: 'models/test-model',
                    createdAt: DateTime(2024, 3, 15, 10),
                    vectorClock: null,
                    // ignore: avoid_redundant_argument_values
                    templateId: null, // uses agentId as lookup key
                    inputTokens: 2000,
                  )
                  as WakeTokenUsageEntity;

          // Simulate a repository exception for this agent id.
          when(() => mockRepository.getEntity('agent-err-1')).thenThrow(
            Exception('entity not found'),
          );

          final container = createContainer(tokenRecords: [record]);
          final result = await container.read(
            tokenSourceBreakdownProvider.future,
          );

          expect(result, hasLength(1));
          // sourceInfo is null → displayName falls back to the key itself.
          expect(result.first.displayName, 'agent-err-1');
          // isTemplate defaults to true per the production code's fallback.
          expect(result.first.isTemplate, isTrue);
        });
      });

      test('fairShare uses 100% when there is exactly one source', () async {
        final now = DateTime(2024, 3, 15, 14, 30);
        await withClock(Clock.fixed(now), () async {
          final records = [
            makeTokenRecord(
              createdAt: DateTime(2024, 3, 15, 10),
              inputTokens: 6000,
              templateId: 'tpl-only',
            ),
          ];

          when(() => mockRepository.getEntity('tpl-only')).thenAnswer(
            (_) async => makeTestTemplate(
              id: 'tpl-only',
              agentId: 'tpl-only',
              displayName: 'Only Source',
            ),
          );

          final container = createContainer(tokenRecords: records);
          final result = await container.read(
            tokenSourceBreakdownProvider.future,
          );

          expect(result, hasLength(1));
          final breakdown = result.first;
          // Single source: percentage == 100, fairShare == 100 → not flagged as
          // high usage (100 > 100 * 2.5 = 250 is false).
          expect(breakdown.percentage, 100.0);
          expect(breakdown.isHighUsage, isFalse);
        });
      });
    },
  );
}
