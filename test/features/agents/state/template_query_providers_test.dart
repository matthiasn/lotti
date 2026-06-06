import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';
import 'agent_providers_test_helpers.dart';

void main() {
  const templateId = kTestTemplateId;
  const agentId = 'agent-001';

  late MockAgentTemplateService templateService;
  late MockAgentRepository repository;
  late ProviderContainer container;

  setUp(() {
    templateService = MockAgentTemplateService();
    repository = MockAgentRepository();

    container = ProviderContainer(
      overrides: [
        agentTemplateServiceProvider.overrideWithValue(templateService),
        agentRepositoryProvider.overrideWithValue(repository),
        // The reactive rebuild hook; the queries only read it.
        agentUpdateStreamProvider.overrideWith(
          (ref, id) => const Stream<Set<String>>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('agentTemplateProvider delegates to getTemplate', () async {
    final template = makeTestTemplate();
    when(
      () => templateService.getTemplate(templateId),
    ).thenAnswer((_) async => template);

    final result = await container.read(
      agentTemplateProvider(templateId).future,
    );

    expect(result, same(template));
  });

  test('activeTemplateVersionProvider delegates to getActiveVersion', () async {
    final version = makeTestTemplateVersion();
    when(
      () => templateService.getActiveVersion(templateId),
    ).thenAnswer((_) async => version);

    final result = await container.read(
      activeTemplateVersionProvider(templateId).future,
    );

    expect(result, same(version));
  });

  test(
    'templateVersionHistoryProvider delegates to getVersionHistory',
    () async {
      final versions = [
        makeTestTemplateVersion(id: 'v2', version: 2),
        makeTestTemplateVersion(),
      ];
      when(
        () => templateService.getVersionHistory(templateId),
      ).thenAnswer((_) async => versions);

      final result = await container.read(
        templateVersionHistoryProvider(templateId).future,
      );

      expect(result, versions);
    },
  );

  test('templateForAgentProvider delegates to getTemplateForAgent', () async {
    final template = makeTestTemplate();
    when(
      () => templateService.getTemplateForAgent(agentId),
    ).thenAnswer((_) async => template);

    final result = await container.read(
      templateForAgentProvider(agentId).future,
    );

    expect(result, same(template));
  });

  test('evolutionNotesProvider delegates to getRecentEvolutionNotes', () async {
    when(
      () => templateService.getRecentEvolutionNotes(templateId),
    ).thenAnswer((_) async => <EvolutionNoteEntity>[]);

    final result = await container.read(
      evolutionNotesProvider(templateId).future,
    );

    expect(result, isEmpty);
    verify(
      () => templateService.getRecentEvolutionNotes(templateId),
    ).called(1);
  });

  test(
    'templatePerformanceMetricsProvider delegates to computeMetrics',
    () async {
      const metrics = TemplatePerformanceMetrics(
        templateId: templateId,
        totalWakes: 10,
        successCount: 9,
        failureCount: 1,
        successRate: 0.9,
        averageDuration: Duration(seconds: 12),
        firstWakeAt: null,
        lastWakeAt: null,
        activeInstanceCount: 2,
      );
      when(
        () => templateService.computeMetrics(templateId),
      ).thenAnswer((_) async => metrics);

      final result = await container.read(
        templatePerformanceMetricsProvider(templateId).future,
      );

      expect(result, metrics);
    },
  );

  test(
    'allEvolutionSessionsProvider reads all sessions from the repository',
    () async {
      final session = makeTestEvolutionSession();
      when(
        repository.getAllEvolutionSessions,
      ).thenAnswer((_) async => [session]);

      final result = await container.read(
        allEvolutionSessionsProvider.future,
      );

      expect(result, [session]);
    },
  );

  // ── Provider wiring tests moved from agent_providers_test.dart so this
  // file is the single mirror of its source (one-test-file-per-source). ──
  group('provider wiring', () {
    late MockAgentService mockService;
    late MockAgentRepository mockRepository;

    setUpAll(() {
      registerAllFallbackValues();
      registerFallbackValue(const Stream<Set<String>>.empty());
    });

    setUp(() {
      mockService = MockAgentService();
      mockRepository = MockAgentRepository();
    });

    group('template providers', () {
      late MockAgentTemplateService mockTemplateService;

      setUp(() {
        mockTemplateService = MockAgentTemplateService();
      });

      ProviderContainer makeContainer() => createTemplateContainer(
        mockTemplateService: mockTemplateService,
        mockService: mockService,
        mockRepository: mockRepository,
      );

      test('agentTemplatesProvider delegates to listTemplates', () async {
        final templates = [
          makeTestTemplate(id: 'tpl-a', agentId: 'tpl-a'),
        ];
        when(
          () => mockTemplateService.listTemplates(),
        ).thenAnswer((_) async => templates);

        final container = makeContainer();
        final result = await container.read(agentTemplatesProvider.future);

        expect(result, hasLength(1));
        verify(() => mockTemplateService.listTemplates()).called(1);
      });

      test('agentTemplateProvider delegates to getTemplate', () async {
        final template = makeTestTemplate();
        when(
          () => mockTemplateService.getTemplate(kTestTemplateId),
        ).thenAnswer((_) async => template);

        final container = makeContainer();
        final result = await container.read(
          agentTemplateProvider(kTestTemplateId).future,
        );

        expect(result, isNotNull);
        expect((result! as AgentTemplateEntity).id, kTestTemplateId);
      });

      test('agentTemplateProvider returns null when not found', () async {
        when(
          () => mockTemplateService.getTemplate('missing'),
        ).thenAnswer((_) async => null);

        final container = makeContainer();
        final result = await container.read(
          agentTemplateProvider('missing').future,
        );

        expect(result, isNull);
      });

      test(
        'activeTemplateVersionProvider delegates to getActiveVersion',
        () async {
          final version = makeTestTemplateVersion();
          when(
            () => mockTemplateService.getActiveVersion(kTestTemplateId),
          ).thenAnswer((_) async => version);

          final container = makeContainer();
          final result = await container.read(
            activeTemplateVersionProvider(kTestTemplateId).future,
          );

          expect(result, isNotNull);
          expect((result! as AgentTemplateVersionEntity).version, 1);
        },
      );

      test(
        'templateVersionHistoryProvider delegates to getVersionHistory',
        () async {
          final versions = [
            makeTestTemplateVersion(id: 'v2', version: 2),
            makeTestTemplateVersion(id: 'v1'),
          ];
          when(
            () => mockTemplateService.getVersionHistory(kTestTemplateId),
          ).thenAnswer((_) async => versions);

          final container = makeContainer();
          final result = await container.read(
            templateVersionHistoryProvider(kTestTemplateId).future,
          );

          expect(result, hasLength(2));
        },
      );

      test(
        'templateForAgentProvider delegates to getTemplateForAgent',
        () async {
          final template = makeTestTemplate();
          when(
            () => mockTemplateService.getTemplateForAgent(kTestAgentId),
          ).thenAnswer((_) async => template);

          final container = makeContainer();
          final result = await container.read(
            templateForAgentProvider(kTestAgentId).future,
          );

          expect(result, isNotNull);
          expect((result! as AgentTemplateEntity).id, kTestTemplateId);
        },
      );

      test(
        'templatePerformanceMetricsProvider delegates to computeMetrics',
        () async {
          final metrics = makeTestMetrics();
          when(
            () => mockTemplateService.computeMetrics(kTestTemplateId),
          ).thenAnswer((_) async => metrics);

          final container = makeContainer();
          final result = await container.read(
            templatePerformanceMetricsProvider(kTestTemplateId).future,
          );

          expect(result.totalWakes, 10);
          expect(result.successRate, 0.8);
        },
      );

      test(
        'activeTemplateVersionProvider returns null when not found',
        () async {
          when(
            () => mockTemplateService.getActiveVersion('missing'),
          ).thenAnswer((_) async => null);

          final container = makeContainer();
          final result = await container.read(
            activeTemplateVersionProvider('missing').future,
          );

          expect(result, isNull);
        },
      );

      test(
        'templateForAgentProvider returns null when agent has no template',
        () async {
          when(
            () => mockTemplateService.getTemplateForAgent('no-template'),
          ).thenAnswer((_) async => null);

          final container = makeContainer();
          final result = await container.read(
            templateForAgentProvider('no-template').future,
          );

          expect(result, isNull);
        },
      );

      test('templateVersionHistoryProvider returns empty list', () async {
        when(
          () => mockTemplateService.getVersionHistory('empty'),
        ).thenAnswer((_) async => []);

        final container = makeContainer();
        final result = await container.read(
          templateVersionHistoryProvider('empty').future,
        );

        expect(result, isEmpty);
      });

      test('agentTemplatesProvider returns empty list', () async {
        when(
          () => mockTemplateService.listTemplates(),
        ).thenAnswer((_) async => []);

        final container = makeContainer();
        final result = await container.read(agentTemplatesProvider.future);

        expect(result, isEmpty);
      });
    });

    group('evolutionSessionsProvider', () {
      late MockAgentTemplateService mockTemplateService;

      setUp(() {
        mockTemplateService = MockAgentTemplateService();
      });

      ProviderContainer makeEvolutionContainer() => createTemplateContainer(
        mockTemplateService: mockTemplateService,
        mockService: mockService,
        mockRepository: mockRepository,
      );

      test('delegates to getEvolutionSessions', () async {
        final sessions = [
          makeTestEvolutionSession(id: 's1'),
          makeTestEvolutionSession(
            id: 's2',
            status: EvolutionSessionStatus.completed,
          ),
        ];
        when(
          () => mockTemplateService.getEvolutionSessions(kTestTemplateId),
        ).thenAnswer((_) async => sessions);

        final container = makeEvolutionContainer();
        final result = await container.read(
          evolutionSessionsProvider(kTestTemplateId).future,
        );

        expect(result, hasLength(2));
        final first = result[0] as EvolutionSessionEntity;
        expect(first.id, 's1');
        expect(first.status, EvolutionSessionStatus.active);
        final second = result[1] as EvolutionSessionEntity;
        expect(second.id, 's2');
        expect(second.status, EvolutionSessionStatus.completed);
      });

      test('returns empty list when no sessions exist', () async {
        when(
          () => mockTemplateService.getEvolutionSessions(kTestTemplateId),
        ).thenAnswer((_) async => []);

        final container = makeEvolutionContainer();
        final result = await container.read(
          evolutionSessionsProvider(kTestTemplateId).future,
        );

        expect(result, isEmpty);
      });

      test('refetches when agentUpdateStream emits for template', () async {
        var fetchCount = 0;
        when(
          () => mockTemplateService.getEvolutionSessions(kTestTemplateId),
        ).thenAnswer((_) async {
          fetchCount++;
          return [];
        });

        final setup = await setUpUpdateStreamTest(
          containerFactory: () => ProviderContainer(
            overrides: [
              agentTemplateServiceProvider.overrideWithValue(
                mockTemplateService,
              ),
              agentServiceProvider.overrideWithValue(mockService),
              agentRepositoryProvider.overrideWithValue(mockRepository),
            ],
          ),
        );

        // Initial fetch.
        final sub = setup.container.listen(
          evolutionSessionsProvider(kTestTemplateId),
          (_, _) {},
        );
        addTearDown(sub.close);
        await setup.container.read(
          evolutionSessionsProvider(kTestTemplateId).future,
        );
        expect(fetchCount, 1);

        // Fire update notification for the template.
        setup.controller.add({kTestTemplateId});
        await pumpEventQueue();

        // Provider should have refetched.
        await setup.container.read(
          evolutionSessionsProvider(kTestTemplateId).future,
        );
        expect(fetchCount, 2);
      });
    });

    group('allEvolutionSessionsProvider', () {
      test(
        'aggregates sessions across templates sorted by updatedAt',
        () async {
          final session1 = makeTestEvolutionSession(
            id: 's1',
            agentId: 'tpl-1',
            updatedAt: DateTime(2024, 3, 15, 10),
          );
          final session2 = makeTestEvolutionSession(
            id: 's2',
            agentId: 'tpl-2',
            updatedAt: DateTime(2024, 3, 15, 12),
          );
          when(
            () => mockRepository.getAllEvolutionSessions(),
          ).thenAnswer((_) async => [session2, session1]);

          final container = ProviderContainer(
            overrides: [
              agentRepositoryProvider.overrideWithValue(mockRepository),
            ],
          );
          addTearDown(container.dispose);

          final result = await container.read(
            allEvolutionSessionsProvider.future,
          );

          expect(result, hasLength(2));
          // Most recent first (returned pre-sorted by the query)
          expect((result[0] as EvolutionSessionEntity).id, 's2');
          expect((result[1] as EvolutionSessionEntity).id, 's1');
        },
      );

      test('returns empty when no sessions exist', () async {
        when(
          () => mockRepository.getAllEvolutionSessions(),
        ).thenAnswer((_) async => []);

        final container = ProviderContainer(
          overrides: [
            agentRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          allEvolutionSessionsProvider.future,
        );

        expect(result, isEmpty);
      });
    });

    group('evolutionNotesProvider', () {
      late MockAgentTemplateService mockTemplateService;

      setUp(() {
        mockTemplateService = MockAgentTemplateService();
      });

      ProviderContainer makeNotesContainer() => createTemplateContainer(
        mockTemplateService: mockTemplateService,
        mockService: mockService,
        mockRepository: mockRepository,
      );

      test('delegates to getRecentEvolutionNotes', () async {
        final notes = [
          makeTestEvolutionNote(id: 'n1'),
          makeTestEvolutionNote(
            id: 'n2',
            kind: EvolutionNoteKind.decision,
          ),
          makeTestEvolutionNote(
            id: 'n3',
            kind: EvolutionNoteKind.pattern,
          ),
        ];
        when(
          () => mockTemplateService.getRecentEvolutionNotes(kTestTemplateId),
        ).thenAnswer((_) async => notes);

        final container = makeNotesContainer();
        final result = await container.read(
          evolutionNotesProvider(kTestTemplateId).future,
        );

        expect(result, hasLength(3));
        final first = result[0] as EvolutionNoteEntity;
        expect(first.id, 'n1');
        expect(first.kind, EvolutionNoteKind.reflection);
        final second = result[1] as EvolutionNoteEntity;
        expect(second.kind, EvolutionNoteKind.decision);
        final third = result[2] as EvolutionNoteEntity;
        expect(third.kind, EvolutionNoteKind.pattern);
      });

      test('returns empty list when no notes exist', () async {
        when(
          () => mockTemplateService.getRecentEvolutionNotes(kTestTemplateId),
        ).thenAnswer((_) async => []);

        final container = makeNotesContainer();
        final result = await container.read(
          evolutionNotesProvider(kTestTemplateId).future,
        );

        expect(result, isEmpty);
      });

      test('refetches when agentUpdateStream emits for template', () async {
        var fetchCount = 0;
        when(
          () => mockTemplateService.getRecentEvolutionNotes(kTestTemplateId),
        ).thenAnswer((_) async {
          fetchCount++;
          return [];
        });

        final setup = await setUpUpdateStreamTest(
          containerFactory: () => ProviderContainer(
            overrides: [
              agentTemplateServiceProvider.overrideWithValue(
                mockTemplateService,
              ),
              agentServiceProvider.overrideWithValue(mockService),
              agentRepositoryProvider.overrideWithValue(mockRepository),
            ],
          ),
        );

        // Initial fetch.
        final sub = setup.container.listen(
          evolutionNotesProvider(kTestTemplateId),
          (_, _) {},
        );
        addTearDown(sub.close);
        await setup.container.read(
          evolutionNotesProvider(kTestTemplateId).future,
        );
        expect(fetchCount, 1);

        // Fire update notification for the template.
        setup.controller.add({kTestTemplateId});
        await pumpEventQueue();

        // Provider should have refetched.
        await setup.container.read(
          evolutionNotesProvider(kTestTemplateId).future,
        );
        expect(fetchCount, 2);
      });
    });

    group('templateTokenUsageSummariesProvider', () {
      test('returns empty list when no records', () async {
        final container = createTemplateTokenContainer(
          templateId: kTestTemplateId,
          records: [],
        );
        final result = await container.read(
          templateTokenUsageSummariesProvider(kTestTemplateId).future,
        );
        expect(result, isEmpty);
      });

      test('aggregates records across multiple instances by model', () async {
        final now = DateTime(2025, 6, 15);
        final container = createTemplateTokenContainer(
          templateId: kTestTemplateId,
          records: [
            WakeTokenUsageEntity(
              id: 'u1',
              agentId: 'agent-a',
              runKey: 'run-1',
              threadId: 't1',
              modelId: 'gemini-2.5-pro',
              createdAt: now,
              vectorClock: null,
              inputTokens: 100,
              outputTokens: 50,
              thoughtsTokens: 20,
              cachedInputTokens: 10,
            ),
            WakeTokenUsageEntity(
              id: 'u2',
              agentId: 'agent-b',
              runKey: 'run-2',
              threadId: 't2',
              modelId: 'gemini-2.5-pro',
              createdAt: now,
              vectorClock: null,
              inputTokens: 200,
              outputTokens: 80,
              thoughtsTokens: 30,
              cachedInputTokens: 5,
            ),
            WakeTokenUsageEntity(
              id: 'u3',
              agentId: 'agent-a',
              runKey: 'run-3',
              threadId: 't3',
              modelId: 'claude-sonnet',
              createdAt: now,
              vectorClock: null,
              inputTokens: 500,
              outputTokens: 100,
            ),
          ],
        );

        final result = await container.read(
          templateTokenUsageSummariesProvider(kTestTemplateId).future,
        );

        expect(result, hasLength(2));

        // Sorted by totalTokens descending: claude-sonnet (600) > gemini (480)
        expect(result[0].modelId, 'claude-sonnet');
        expect(result[0].inputTokens, 500);
        expect(result[0].outputTokens, 100);
        expect(result[0].wakeCount, 1);

        expect(result[1].modelId, 'gemini-2.5-pro');
        expect(result[1].inputTokens, 300);
        expect(result[1].outputTokens, 130);
        expect(result[1].thoughtsTokens, 50);
        expect(result[1].cachedInputTokens, 15);
        expect(result[1].wakeCount, 2);
      });

      test('sorts by totalTokens descending', () async {
        final now = DateTime(2025, 6, 15);
        final container = createTemplateTokenContainer(
          templateId: kTestTemplateId,
          records: [
            WakeTokenUsageEntity(
              id: 'u1',
              agentId: 'agent-a',
              runKey: 'run-1',
              threadId: 't1',
              modelId: 'small-model',
              createdAt: now,
              vectorClock: null,
              inputTokens: 10,
              outputTokens: 5,
            ),
            WakeTokenUsageEntity(
              id: 'u2',
              agentId: 'agent-a',
              runKey: 'run-2',
              threadId: 't2',
              modelId: 'big-model',
              createdAt: now,
              vectorClock: null,
              inputTokens: 1000,
              outputTokens: 500,
            ),
            WakeTokenUsageEntity(
              id: 'u3',
              agentId: 'agent-a',
              runKey: 'run-3',
              threadId: 't3',
              modelId: 'medium-model',
              createdAt: now,
              vectorClock: null,
              inputTokens: 100,
              outputTokens: 50,
            ),
          ],
        );

        final result = await container.read(
          templateTokenUsageSummariesProvider(kTestTemplateId).future,
        );

        expect(result, hasLength(3));
        expect(result[0].modelId, 'big-model');
        expect(result[1].modelId, 'medium-model');
        expect(result[2].modelId, 'small-model');
      });

      test('handles null token fields', () async {
        final now = DateTime(2025, 6, 15);
        final container = createTemplateTokenContainer(
          templateId: kTestTemplateId,
          records: [
            WakeTokenUsageEntity(
              id: 'u1',
              agentId: 'agent-a',
              runKey: 'run-1',
              threadId: 't1',
              modelId: 'model-a',
              createdAt: now,
              vectorClock: null,
              // All token fields null
            ),
          ],
        );

        final result = await container.read(
          templateTokenUsageSummariesProvider(kTestTemplateId).future,
        );

        expect(result, hasLength(1));
        expect(result[0].inputTokens, 0);
        expect(result[0].outputTokens, 0);
        expect(result[0].thoughtsTokens, 0);
        expect(result[0].cachedInputTokens, 0);
        expect(result[0].wakeCount, 1);
      });
    });

    group('templateInstanceTokenBreakdownProvider', () {
      ProviderContainer createBreakdownContainer({
        required List<WakeTokenUsageEntity> records,
        required List<AgentIdentityEntity> agents,
      }) {
        final repo = MockAgentRepository();
        when(
          () => repo.getTokenUsageForTemplate(
            kTestTemplateId,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => records);

        final templateService = MockAgentTemplateService();
        when(
          () => templateService.getAgentsForTemplate(kTestTemplateId),
        ).thenAnswer((_) async => agents);

        final container = ProviderContainer(
          overrides: [
            agentRepositoryProvider.overrideWithValue(repo),
            agentTemplateServiceProvider.overrideWithValue(templateService),
            agentUpdateStreamProvider.overrideWith(
              (ref, agentId) => const Stream.empty(),
            ),
          ],
        );
        addTearDown(container.dispose);
        return container;
      }

      test('returns empty list for template with no instances', () async {
        final container = createBreakdownContainer(
          records: [],
          agents: [],
        );

        final result = await container.read(
          templateInstanceTokenBreakdownProvider(kTestTemplateId).future,
        );

        expect(result, isEmpty);
      });

      test(
        'groups records by instance and by model within each instance',
        () async {
          final now = DateTime(2025, 6, 15);
          final agentA = makeTestIdentity(
            id: 'agent-a',
            agentId: 'agent-a',
            displayName: 'Agent A',
          );
          final agentB = makeTestIdentity(
            id: 'agent-b',
            agentId: 'agent-b',
            displayName: 'Agent B',
          );

          final container = createBreakdownContainer(
            records: [
              WakeTokenUsageEntity(
                id: 'u1',
                agentId: 'agent-a',
                runKey: 'run-1',
                threadId: 't1',
                modelId: 'gemini-2.5-pro',
                createdAt: now,
                vectorClock: null,
                inputTokens: 100,
                outputTokens: 50,
              ),
              WakeTokenUsageEntity(
                id: 'u2',
                agentId: 'agent-a',
                runKey: 'run-2',
                threadId: 't2',
                modelId: 'claude-sonnet',
                createdAt: now,
                vectorClock: null,
                inputTokens: 200,
                outputTokens: 100,
              ),
              WakeTokenUsageEntity(
                id: 'u3',
                agentId: 'agent-b',
                runKey: 'run-3',
                threadId: 't3',
                modelId: 'gemini-2.5-pro',
                createdAt: now,
                vectorClock: null,
                inputTokens: 50,
                outputTokens: 25,
              ),
            ],
            agents: [agentA, agentB],
          );

          final result = await container.read(
            templateInstanceTokenBreakdownProvider(kTestTemplateId).future,
          );

          expect(result, hasLength(2));

          // Agent A has more tokens (150+300=450) than Agent B (75)
          expect(result[0].agentId, 'agent-a');
          expect(result[0].displayName, 'Agent A');
          expect(result[0].summaries, hasLength(2));
          expect(result[0].totalTokens, 450);

          expect(result[1].agentId, 'agent-b');
          expect(result[1].displayName, 'Agent B');
          expect(result[1].summaries, hasLength(1));
          expect(result[1].totalTokens, 75);
        },
      );

      test('sorts instances by totalTokens descending', () async {
        final now = DateTime(2025, 6, 15);
        final agentSmall = makeTestIdentity(
          id: 'agent-small',
          agentId: 'agent-small',
          displayName: 'Small Agent',
        );
        final agentBig = makeTestIdentity(
          id: 'agent-big',
          agentId: 'agent-big',
          displayName: 'Big Agent',
        );

        final container = createBreakdownContainer(
          records: [
            WakeTokenUsageEntity(
              id: 'u1',
              agentId: 'agent-small',
              runKey: 'run-1',
              threadId: 't1',
              modelId: 'model-a',
              createdAt: now,
              vectorClock: null,
              inputTokens: 10,
              outputTokens: 5,
            ),
            WakeTokenUsageEntity(
              id: 'u2',
              agentId: 'agent-big',
              runKey: 'run-2',
              threadId: 't2',
              modelId: 'model-a',
              createdAt: now,
              vectorClock: null,
              inputTokens: 1000,
              outputTokens: 500,
            ),
          ],
          agents: [agentSmall, agentBig],
        );

        final result = await container.read(
          templateInstanceTokenBreakdownProvider(kTestTemplateId).future,
        );

        expect(result, hasLength(2));
        expect(result[0].agentId, 'agent-big');
        expect(result[0].totalTokens, 1500);
        expect(result[1].agentId, 'agent-small');
        expect(result[1].totalTokens, 15);
      });

      test(
        'includes instances with no token records (with empty summaries)',
        () async {
          final agentWithTokens = makeTestIdentity(
            id: 'agent-with',
            agentId: 'agent-with',
            displayName: 'With Tokens',
          );
          final agentWithout = makeTestIdentity(
            id: 'agent-without',
            agentId: 'agent-without',
            displayName: 'Without Tokens',
          );
          final now = DateTime(2025, 6, 15);

          final container = createBreakdownContainer(
            records: [
              WakeTokenUsageEntity(
                id: 'u1',
                agentId: 'agent-with',
                runKey: 'run-1',
                threadId: 't1',
                modelId: 'model-a',
                createdAt: now,
                vectorClock: null,
                inputTokens: 100,
                outputTokens: 50,
              ),
            ],
            agents: [agentWithTokens, agentWithout],
          );

          final result = await container.read(
            templateInstanceTokenBreakdownProvider(kTestTemplateId).future,
          );

          expect(result, hasLength(2));

          // Agent with tokens sorted first (150 > 0)
          expect(result[0].agentId, 'agent-with');
          expect(result[0].totalTokens, 150);
          expect(result[0].summaries, hasLength(1));

          expect(result[1].agentId, 'agent-without');
          expect(result[1].totalTokens, 0);
          expect(result[1].summaries, isEmpty);
        },
      );

      test(
        'returns all instances with empty summaries when no records exist',
        () async {
          final agentA = makeTestIdentity(
            id: 'agent-a',
            agentId: 'agent-a',
            displayName: 'Agent A',
          );
          final agentB = makeTestIdentity(
            id: 'agent-b',
            agentId: 'agent-b',
            displayName: 'Agent B',
          );

          final container = createBreakdownContainer(
            records: [],
            agents: [agentA, agentB],
          );

          final result = await container.read(
            templateInstanceTokenBreakdownProvider(kTestTemplateId).future,
          );

          expect(result, hasLength(2));
          expect(
            result.map((r) => r.agentId),
            containsAll(<String>['agent-a', 'agent-b']),
          );
          for (final breakdown in result) {
            expect(breakdown.totalTokens, 0);
            expect(breakdown.summaries, isEmpty);
          }
        },
      );
    });

    group('templateRecentReportsProvider', () {
      test('returns reports from repository', () async {
        final report1 = makeTestReport(
          id: 'report-1',
          agentId: 'agent-a',
          content: 'First report',
        );
        final report2 = makeTestReport(
          id: 'report-2',
          agentId: 'agent-b',
          content: 'Second report',
        );

        final repo = MockAgentRepository();
        when(
          () => repo.getRecentReportsByTemplate(
            kTestTemplateId,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [report1, report2]);

        final container = ProviderContainer(
          overrides: [
            agentRepositoryProvider.overrideWithValue(repo),
            agentUpdateStreamProvider.overrideWith(
              (ref, agentId) => const Stream.empty(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          templateRecentReportsProvider(kTestTemplateId).future,
        );

        expect(result, hasLength(2));
        expect((result[0] as AgentReportEntity).id, 'report-1');
        expect((result[1] as AgentReportEntity).id, 'report-2');
      });

      test('returns empty list when no reports', () async {
        final repo = MockAgentRepository();
        when(
          () => repo.getRecentReportsByTemplate(
            kTestTemplateId,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => []);

        final container = ProviderContainer(
          overrides: [
            agentRepositoryProvider.overrideWithValue(repo),
            agentUpdateStreamProvider.overrideWith(
              (ref, agentId) => const Stream.empty(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          templateRecentReportsProvider(kTestTemplateId).future,
        );

        expect(result, isEmpty);
      });
    });
  });
}
