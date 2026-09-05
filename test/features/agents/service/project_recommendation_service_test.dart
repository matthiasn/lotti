import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/project_recommendation_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';
import 'project_recommendation_service_test_helpers.dart';

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
    when(
      () => mockRepository.getEntitiesByAgentId(
        any(),
        type: AgentEntityTypes.projectRecommendationRun,
      ),
    ).thenAnswer((_) async => []);
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

  group('current next steps', () {
    late Map<String, AgentDomainEntity> rows;
    late Map<String, DateTime> starts;
    final now = DateTime(2026, 9, 5);
    final proposal = <Map<String, dynamic>>[
      {
        'toolName': 'recommend_next_steps',
        'args': {
          'steps': [
            {
              'title': 'Review penguin launch',
              'rationale': 'Check seals',
              'priority': 'high',
            },
            {'title': 'Pack fish'},
          ],
        },
      },
    ];
    setUp(() {
      rows = {};
      starts = {};
      when(
        () => mockRepository.getEntitiesByAgentId(
          any(),
          type: AgentEntityTypes.projectRecommendationRun,
        ),
      ).thenAnswer(
        (_) async =>
            rows.values.whereType<ProjectRecommendationRunEntity>().toList(),
      );

      when(
        () => mockRepository.getLatestReport(any(), any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepository.getEntitiesByAgentId(
          any(),
          type: AgentEntityTypes.projectRecommendation,
        ),
      ).thenAnswer(
        (_) async =>
            rows.values.whereType<ProjectRecommendationEntity>().toList(),
      );
      when(
        () => mockRepository.getPendingChangeSets(
          any(),
          taskId: any(named: 'taskId'),
        ),
      ).thenAnswer(
        (_) async => rows.values
            .whereType<ChangeSetEntity>()
            .where(
              (set) => set.items.any(
                (item) => item.status == ChangeItemStatus.pending,
              ),
            )
            .toList(),
      );
      when(() => mockRepository.getEntity(any())).thenAnswer(
        (call) async => rows[call.positionalArguments.first],
      );
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((call) async {
        final row = call.positionalArguments.first as AgentDomainEntity;
        rows[row.id] = row;
      });
    });

    Future<void> publish(
      String run,
      List<Map<String, dynamic>> items, {
      DateTime? startedAt,
    }) => withClock(
      Clock.fixed(now),
      () => service.replaceForRun(
        agentId: 'agent-1',
        projectId: 'project-1',
        runKey: run,
        runStartedAt:
            startedAt ??
            starts.putIfAbsent(
              run,
              () => now.add(Duration(microseconds: starts.length)),
            ),
        deferredItems: items,
      ),
    );
    List<ProjectRecommendationEntity> active() => rows.values
        .whereType<ProjectRecommendationEntity>()
        .where(
          (row) => row.status == ProjectRecommendationStatus.active,
        )
        .toList();

    test(
      'last recommendation call replaces earlier payloads within a run',
      () async {
        await publish('revised', [
          ...proposal,
          {
            'toolName': 'recommend_next_steps',
            'args': {
              'steps': [
                {'title': 'Inspect habitat'},
              ],
            },
          },
        ]);
        expect(active().map((row) => row.title), ['Inspect habitat']);
        await publish('cleared', [
          ...proposal,
          {
            'toolName': 'recommend_next_steps',
            'args': {'steps': <Object>[]},
          },
        ]);
        expect(active(), isEmpty);
      },
    );

    test(
      'late older completion cannot replace newer suggestions or retract pending changes',
      () async {
        await publish('newer', proposal);
        rows['pending'] = makeTestChangeSet(
          id: 'pending',
          agentId: 'agent-1',
          taskId: 'project-1',
          items: const [
            ChangeItem(
              toolName: 'recommend_next_steps',
              args: {},
              humanSummary: 'Pending',
            ),
          ],
        );
        final before = Map<String, AgentDomainEntity>.of(rows);
        await publish(
          'older',
          [],
          startedAt: now.subtract(const Duration(hours: 1)),
        );
        expect(rows, before);
        expect(active().map((row) => row.title), [
          'Review penguin launch',
          'Pack fish',
        ]);
      },
    );

    test(
      'migration uses the final pending payload of the newest batch',
      () async {
        rows['legacy'] = makeTestChangeSet(
          id: 'legacy',
          agentId: 'agent-1',
          taskId: 'project-1',
          items: [
            ChangeItem(
              toolName: 'recommend_next_steps',
              args: proposal.single['args'] as Map<String, dynamic>,
              humanSummary: 'Earlier',
            ),
            const ChangeItem(
              toolName: 'recommend_next_steps',
              args: {
                'steps': [
                  {'title': 'Inspect habitat'},
                ],
              },
              humanSummary: 'Latest',
            ),
          ],
        );
        await service.migratePendingBatches('agent-1', 'project-1');
        expect(active().map((row) => row.title), ['Inspect habitat']);
      },
    );

    test('disconnected runs converge in either sync arrival order', () async {
      await publish('offline-a', proposal);
      final replicaA = Map<String, AgentDomainEntity>.of(rows);
      rows.clear();
      await publish('offline-b', [
        {
          'toolName': 'recommend_next_steps',
          'args': {
            'steps': [
              {'title': 'Inspect habitat'},
            ],
          },
        },
      ], startedAt: now);
      final replicaB = Map<String, AgentDomainEntity>.of(rows);
      final runA = replicaA.values
          .whereType<ProjectRecommendationRunEntity>()
          .single;
      final runB = replicaB.values
          .whereType<ProjectRecommendationRunEntity>()
          .single;
      final winner = runA.id.compareTo(runB.id) > 0 ? runA : runB;
      rows = Map<String, AgentDomainEntity>.of(
        winner == runA ? replicaA : replicaB,
      );
      final winningRows = Map<String, AgentDomainEntity>.of(rows);
      await publish(
        winner == runA ? 'offline-b' : 'offline-a',
        proposal,
        startedAt: now,
      );
      expect(rows, winningRows);

      for (final replicas in [
        [replicaA, replicaB],
        [replicaB, replicaA],
      ]) {
        rows = {...replicas.first, ...replicas.last};
        final current = await service.currentRecommendations(
          'agent-1',
          'project-1',
        );
        expect(
          current.map((row) => row.id).toSet(),
          winner.recommendationIds.toSet(),
        );
        expect(
          active().map((row) => row.id).toSet(),
          winner.recommendationIds.toSet(),
        );
        final loser = rows.values
            .whereType<ProjectRecommendationEntity>()
            .firstWhere((row) => !winner.recommendationIds.contains(row.id));
        expect(loser.status, ProjectRecommendationStatus.superseded);
      }
    });

    test(
      'empty remote run clears suggestions and older retries stay retired',
      () async {
        await publish('offline-a', proposal);
        final old = Map<String, AgentDomainEntity>.of(rows);
        rows.clear();
        await withClock(
          Clock.fixed(now.add(const Duration(hours: 1))),
          () => service.replaceForRun(
            agentId: 'agent-1',
            projectId: 'project-1',
            runKey: 'offline-empty',
            runStartedAt: now.add(const Duration(hours: 1)),
            deferredItems: [],
          ),
        );
        rows.addAll(old);
        expect(
          await service.currentRecommendations('agent-1', 'project-1'),
          isEmpty,
        );
        await publish('offline-a', proposal);
        expect(active(), isEmpty);
      },
    );

    test(
      'rows arriving before their run remain hidden without destroying the winner',
      () async {
        await publish('offline-a', proposal);
        final old = Map<String, AgentDomainEntity>.of(rows);
        rows.clear();
        await withClock(
          Clock.fixed(now.add(const Duration(hours: 1))),
          () => service.replaceForRun(
            agentId: 'agent-1',
            projectId: 'project-1',
            runKey: 'offline-b',
            runStartedAt: now.add(const Duration(hours: 1)),
            deferredItems: proposal,
          ),
        );
        final incoming = Map<String, AgentDomainEntity>.of(rows);
        final snapshot = incoming.values
            .whereType<ProjectRecommendationRunEntity>()
            .single;
        rows = {...old, ...incoming}..remove(snapshot.id);
        final before = await service.currentRecommendations(
          'agent-1',
          'project-1',
        );
        expect(
          before.map((row) => row.id).toSet(),
          old.values
              .whereType<ProjectRecommendationEntity>()
              .map((row) => row.id)
              .toSet(),
        );
        for (final id in snapshot.recommendationIds) {
          expect(
            (rows[id]! as ProjectRecommendationEntity).status,
            ProjectRecommendationStatus.active,
          );
          expect(await service.markResolved(id), isFalse);
        }
        rows[snapshot.id] = snapshot;
        final after = await service.currentRecommendations(
          'agent-1',
          'project-1',
        );
        expect(
          after.map((row) => row.id).toSet(),
          snapshot.recommendationIds.toSet(),
        );
      },
    );

    test(
      'failed task creation does not restore a step after a reportless run',
      () async {
        await publish('first', proposal);
        final first = active().first;
        service = ProjectRecommendationService(
          syncService: mockSyncService,
          taskDispatcher: (tool, args, projectId) async {
            await publish('second', []);
            return const ToolExecutionResult(success: false, output: 'retry');
          },
        );
        expect((await service.createTask(first.id)).success, isFalse);
        expect(
          (rows[first.id]! as ProjectRecommendationEntity).status,
          ProjectRecommendationStatus.superseded,
        );
        expect(rows.values.whereType<ChangeDecisionEntity>(), isEmpty);
      },
    );

    test(
      'retry before snapshot delivery preserves an already decided row',
      () async {
        await publish('first', proposal);
        final first = active().first;
        await service.dismissRecommendation(first.id);
        rows.remove(first.sourceRunId);
        expect(
          await service.currentRecommendations('agent-1', 'project-1'),
          isEmpty,
        );
        expect(await service.markResolved(active().single.id), isFalse);
        await publish('first', proposal);
        expect(active().map((row) => row.title), ['Pack fish']);
        expect(
          (rows[first.id]! as ProjectRecommendationEntity).status,
          ProjectRecommendationStatus.dismissed,
        );
      },
    );

    test(
      'individual verdicts retain their summary and arguments for feedback',
      () async {
        await publish('run-1', proposal);
        final first = active().first;
        final second = active().last;
        await service.markResolved(first.id);
        await service.dismissRecommendation(second.id);
        final decisions = rows.values
            .whereType<ChangeDecisionEntity>()
            .toList();
        expect(decisions.map((row) => row.verdict), [
          ChangeDecisionVerdict.confirmed,
          ChangeDecisionVerdict.rejected,
        ]);
        expect(decisions.first.humanSummary, first.title);
        expect(decisions.first.args, {
          'steps': [
            {
              'title': first.title,
              'rationale': 'Check seals',
              'priority': 'HIGH',
            },
          ],
        });
        expect(decisions.last.humanSummary, second.title);
        for (final decision in decisions) {
          expect(decision.actor, DecisionActor.user);
          expect(decision.taskId, 'project-1');
          final set = rows[decision.changeSetId]! as ChangeSetEntity;
          expect(
            set.items[decision.itemIndex].humanSummary,
            decision.humanSummary,
          );
          expect(set.resolvedAt, decision.createdAt);
        }
        expect(await service.markResolved(first.id), isFalse);
        expect(rows.values.whereType<ChangeDecisionEntity>(), hasLength(2));
      },
    );

    test(
      'migration stamps final retractions and clears partial resolution timestamps',
      () async {
        const item = ChangeItem(
          toolName: 'recommend_next_steps',
          args: {'steps': <Object>[]},
          humanSummary: 'Old steps',
        );
        rows['only'] = makeTestChangeSet(
          id: 'only',
          agentId: 'agent-1',
          taskId: 'project-1',
          items: [item],
        );
        rows['mixed'] = makeTestChangeSet(
          id: 'mixed',
          agentId: 'agent-1',
          taskId: 'project-1',
          items: [
            item,
            const ChangeItem(
              toolName: 'create_task',
              args: {},
              humanSummary: 'Task',
            ),
          ],
        ).copyWith(resolvedAt: now.subtract(const Duration(days: 1)));
        await publish('new', []);
        final only = rows['only']! as ChangeSetEntity;
        final mixed = rows['mixed']! as ChangeSetEntity;
        expect(only.resolvedAt, now);
        expect(only.status, ChangeSetStatus.resolved);
        expect(mixed.resolvedAt, isNull);
        expect(mixed.status, ChangeSetStatus.partiallyResolved);
      },
    );

    test(
      'new runs replace suggestions and empty runs retract the list',
      () async {
        await publish('run-1', proposal);
        final previous = active().map((row) => row.id).toList();
        expect(active().map((row) => row.title), [
          'Review penguin launch',
          'Pack fish',
        ]);
        await publish('run-2', proposal);
        expect(active(), hasLength(2));
        for (final id in previous) {
          expect(
            (rows[id]! as ProjectRecommendationEntity).status,
            ProjectRecommendationStatus.superseded,
          );
        }
        await publish('run-3', []);
        expect(active(), isEmpty);
      },
    );

    test(
      'current list excludes tombstones and leaves other projects untouched',
      () async {
        await publish('run-1', proposal);
        final first = active().first;
        rows[first.id] = first.copyWith(deletedAt: now);
        final other = makeTestProjectRecommendation(
          id: 'other-project',
          agentId: 'agent-1',
          projectId: 'project-2',
        );
        rows[other.id] = other;
        final current = await service.currentRecommendations(
          'agent-1',
          'project-1',
        );
        expect(current.map((row) => row.title), ['Pack fish']);
        expect(rows[other.id], other);
        expect((rows[first.id]! as ProjectRecommendationEntity).deletedAt, now);
      },
    );

    test(
      'retrying a run never revives individually decided suggestions',
      () async {
        await publish('run-1', proposal);
        final first = active().first;
        expect(await service.markResolved(first.id), isTrue);
        await publish('run-1', proposal);
        expect(active().map((row) => row.title), ['Pack fish']);
        expect(
          rows.values.whereType<ProjectRecommendationEntity>(),
          hasLength(2),
        );
      },
    );

    test(
      'migration keeps newest run and retracts only pending recommendations',
      () async {
        for (final index in [1, 2]) {
          rows['set-$index'] = makeTestChangeSet(
            id: 'set-$index',
            agentId: 'agent-1',
            taskId: 'project-1',
            runKey: 'run-$index',
            createdAt: now.subtract(Duration(days: 3 - index)),
            items: [
              ChangeItem(
                toolName: 'recommend_next_steps',
                args: {
                  'steps': [
                    {'title': 'Step $index'},
                  ],
                },
                humanSummary: 'opaque',
              ),
              const ChangeItem(
                toolName: 'create_task',
                args: {'title': 'Existing task proposal'},
                humanSummary: 'Keep me',
              ),
            ],
          );
        }
        await withClock(
          Clock.fixed(now),
          () => service.migratePendingBatches('agent-1', 'project-1'),
        );
        expect(active().map((row) => row.title), ['Step 2']);
        for (final set in rows.values.whereType<ChangeSetEntity>()) {
          expect(set.items.map((item) => item.status), [
            ChangeItemStatus.retracted,
            ChangeItemStatus.pending,
          ]);
          expect(set.status, ChangeSetStatus.partiallyResolved);
        }
        final id = active().single.id;
        await service.dismissRecommendation(id);
        await service.migratePendingBatches('agent-1', 'project-1');
        expect(active(), isEmpty);
      },
    );

    test(
      'successful run retracts legacy batches while retaining other tools',
      () async {
        rows['legacy'] = makeTestChangeSet(
          id: 'legacy',
          agentId: 'agent-1',
          taskId: 'project-1',
          items: [
            const ChangeItem(
              toolName: 'recommend_next_steps',
              args: {'steps': <Object>[]},
              humanSummary: 'old',
            ),
            const ChangeItem(
              toolName: 'update_project_status',
              args: {'status': 'completed'},
              humanSummary: 'Keep',
            ),
          ],
        );
        await publish('new', proposal);
        final legacy = rows['legacy']! as ChangeSetEntity;
        expect(legacy.items.first.status, ChangeItemStatus.retracted);
        expect(legacy.items.last.status, ChangeItemStatus.pending);
        expect(active(), hasLength(2));
      },
    );

    for (final succeeds in [true, false]) {
      test(
        'task creation forwards project, text and priority; success=$succeeds',
        () async {
          var calls = 0;
          service = ProjectRecommendationService(
            syncService: mockSyncService,
            notifications: mockNotifications,
            taskDispatcher: (tool, args, projectId) async {
              calls++;
              expect(tool, 'create_task');
              expect(projectId, 'project-1');
              expect(args, {
                'title': 'Review penguin launch',
                'description': 'Check seals',
                'priority': 'HIGH',
              });
              return ToolExecutionResult(
                success: succeeds,
                output: '',
                mutatedEntityId: succeeds ? 'task-1' : null,
              );
            },
          );
          await publish('run-1', proposal);
          final id = active().first.id;
          expect((await service.createTask(id)).success, succeeds);
          expect(calls, 1);
          final decisions = rows.values
              .whereType<ChangeDecisionEntity>()
              .toList();
          expect(decisions, hasLength(succeeds ? 1 : 0));
          if (succeeds) {
            expect(decisions.single.verdict, ChangeDecisionVerdict.confirmed);
            expect(decisions.single.humanSummary, 'Review penguin launch');
          }
          expect(
            (rows[id]! as ProjectRecommendationEntity).status,
            succeeds
                ? ProjectRecommendationStatus.resolved
                : ProjectRecommendationStatus.active,
          );
          if (succeeds) {
            expect((await service.createTask(id)).success, isFalse);
            expect(calls, 1);
          }
        },
      );
    }

    ChangeSetEntity decisionSourceFor(String title) => rows.values
        .whereType<ChangeSetEntity>()
        .singleWhere((set) => set.items.single.humanSummary == title);

    test(
      'currentRunSnapshot lists the newest run in position order, decided '
      'rows included, and names when the run was published',
      () async {
        await publish('run-1', proposal);
        final first = active().singleWhere(
          (row) => row.title == 'Review penguin launch',
        );
        expect(await service.dismissRecommendation(first.id), isTrue);

        final snapshot = await service.currentRunSnapshot(
          'agent-1',
          'project-1',
        );

        expect(
          snapshot.steps.map((row) => row.title),
          ['Review penguin launch', 'Pack fish'],
          reason: 'A decided row keeps its place instead of leaving the run.',
        );
        expect(
          snapshot.steps.first.status,
          ProjectRecommendationStatus.dismissed,
        );
        expect(snapshot.pending.map((row) => row.title), ['Pack fish']);
        expect(snapshot.hasPending, isTrue);
        expect(snapshot.runCreatedAt, starts['run-1']);
        expect(
          (await service.currentRecommendations(
            'agent-1',
            'project-1',
          )).map((row) => row.title),
          ['Pack fish'],
        );
      },
    );

    test('currentRunSnapshot is empty before any run was published', () async {
      final snapshot = await service.currentRunSnapshot('agent-1', 'project-1');
      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.hasPending, isFalse);
      expect(snapshot.runCreatedAt, isNull);
    });

    test('createTask records the created task on the resolved step', () async {
      service = ProjectRecommendationService(
        syncService: mockSyncService,
        notifications: mockNotifications,
        taskDispatcher: (tool, args, projectId) async =>
            const ToolExecutionResult(
              success: true,
              output: '',
              mutatedEntityId: 'task-1',
            ),
      );
      await publish('run-1', proposal);
      final id = active().first.id;

      expect((await service.createTask(id)).success, isTrue);

      final row = rows[id]! as ProjectRecommendationEntity;
      expect(row.status, ProjectRecommendationStatus.resolved);
      expect(row.createdTaskId, 'task-1');
      final snapshot = await service.currentRunSnapshot('agent-1', 'project-1');
      expect(snapshot.steps.map((step) => step.createdTaskId), [
        'task-1',
        null,
      ]);
    });

    test(
      'restoreRecommendation reopens a dismissed step and withdraws its '
      'decision from the feedback history',
      () async {
        await publish('run-1', proposal);
        final id = active().first.id;
        await withClock(Clock.fixed(now), () async {
          expect(await service.dismissRecommendation(id), isTrue);
        });
        expect(decisionSourceFor('Review penguin launch').deletedAt, isNull);
        clearInteractions(mockNotifications);

        final restoredAt = now.add(const Duration(minutes: 5));
        final restored = await withClock(
          Clock.fixed(restoredAt),
          () => service.restoreRecommendation(id),
        );

        expect(restored, isTrue);
        final row = rows[id]! as ProjectRecommendationEntity;
        expect(row.status, ProjectRecommendationStatus.active);
        expect(row.dismissedAt, isNull);
        expect(row.updatedAt, restoredAt);
        expect(
          decisionSourceFor('Review penguin launch').deletedAt,
          restoredAt,
          reason: 'An undone verdict must not train the template.',
        );
        final decision = rows.values.whereType<ChangeDecisionEntity>().single;
        expect(
          decision.verdict,
          ChangeDecisionVerdict.deferred,
          reason: 'Feedback extraction reads the verdict off the decision.',
        );
        expect(
          decision.createdAt,
          restoredAt,
          reason: 'A fresh timestamp lets the rewrite win last-writer-wins.',
        );

        verify(
          () => mockNotifications.notifyUiOnly({
            'agent-1',
            'project-1',
            agentNotification,
          }),
        ).called(1);
        expect(active().map((step) => step.id), contains(id));

        expect(await service.dismissRecommendation(id), isTrue);
        expect(
          rows.values.whereType<ChangeDecisionEntity>().single.verdict,
          ChangeDecisionVerdict.rejected,
          reason: 'Deciding again revives the deterministic decision.',
        );
        expect(decisionSourceFor('Review penguin launch').deletedAt, isNull);
      },
    );

    for (final taskRemoved in [true, false]) {
      test(
        'restoreRecommendation on an added step removes the task first and '
        '${taskRemoved ? 'reopens the step' : 'keeps the step resolved'}',
        () async {
          final removed = <String>[];
          service = ProjectRecommendationService(
            syncService: mockSyncService,
            notifications: mockNotifications,
            taskDispatcher: (tool, args, projectId) async =>
                const ToolExecutionResult(
                  success: true,
                  output: '',
                  mutatedEntityId: 'task-1',
                ),
            taskRemover: (taskId) async {
              removed.add(taskId);
              return taskRemoved;
            },
          );
          await publish('run-1', proposal);
          final id = active().first.id;
          expect((await service.createTask(id)).success, isTrue);

          expect(await service.restoreRecommendation(id), taskRemoved);

          expect(removed, ['task-1']);
          final row = rows[id]! as ProjectRecommendationEntity;
          expect(
            row.status,
            taskRemoved
                ? ProjectRecommendationStatus.active
                : ProjectRecommendationStatus.resolved,
          );
          expect(row.createdTaskId, taskRemoved ? isNull : 'task-1');
          expect(row.resolvedAt, taskRemoved ? isNull : isNotNull);
        },
      );
    }

    test(
      'restoreRecommendation gives up when a newer run wins while the task '
      'is being removed',
      () async {
        final removed = <String>[];
        service = ProjectRecommendationService(
          syncService: mockSyncService,
          notifications: mockNotifications,
          taskDispatcher: (tool, args, projectId) async =>
              const ToolExecutionResult(
                success: true,
                output: '',
                mutatedEntityId: 'task-1',
              ),
          taskRemover: (taskId) async {
            removed.add(taskId);
            await publish('run-2', [
              {
                'toolName': 'recommend_next_steps',
                'args': {
                  'steps': [
                    {'title': 'Inspect habitat'},
                  ],
                },
              },
            ]);
            return true;
          },
        );
        await publish('run-1', proposal);
        final id = active().first.id;
        expect((await service.createTask(id)).success, isTrue);

        expect(await service.restoreRecommendation(id), isFalse);

        expect(removed, ['task-1']);
        final row = rows[id]! as ProjectRecommendationEntity;
        expect(
          row.status,
          ProjectRecommendationStatus.resolved,
          reason: 'A step the newer run replaced must not come back to life.',
        );
        expect(
          (await service.currentRunSnapshot(
            'agent-1',
            'project-1',
          )).steps.map((step) => step.title),
          ['Inspect habitat'],
        );
      },
    );

    test(
      'currentRunSnapshot orders legacy rows by position, then creation, '
      'then id',
      () async {
        final base = now.subtract(const Duration(days: 1));
        rows['legacy-b'] = makeTestProjectRecommendation(
          id: 'legacy-b',
          agentId: 'agent-1',
          projectId: 'project-1',
          title: 'Same slot, same time, later id',
          createdAt: base,
        );
        rows['legacy-a'] = makeTestProjectRecommendation(
          id: 'legacy-a',
          agentId: 'agent-1',
          projectId: 'project-1',
          title: 'Same slot, same time, earlier id',
          createdAt: base,
        );
        rows['legacy-later'] = makeTestProjectRecommendation(
          id: 'legacy-later',
          agentId: 'agent-1',
          projectId: 'project-1',
          title: 'Same slot, newer batch',
          createdAt: base.add(const Duration(hours: 1)),
        );
        rows['legacy-second'] = makeTestProjectRecommendation(
          id: 'legacy-second',
          agentId: 'agent-1',
          projectId: 'project-1',
          title: 'Second slot',
          position: 1,
          createdAt: base,
        );

        final snapshot = await service.currentRunSnapshot(
          'agent-1',
          'project-1',
        );

        expect(
          snapshot.steps.map((step) => step.id),
          ['legacy-a', 'legacy-b', 'legacy-later', 'legacy-second'],
        );
        expect(snapshot.runCreatedAt, isNull);
      },
    );

    test(
      'restoreRecommendation throws without a task remover for an added step',
      () async {
        service = ProjectRecommendationService(
          syncService: mockSyncService,
          notifications: mockNotifications,
          taskDispatcher: (tool, args, projectId) async =>
              const ToolExecutionResult(
                success: true,
                output: '',
                mutatedEntityId: 'task-1',
              ),
        );
        await publish('run-1', proposal);
        final id = active().first.id;
        expect((await service.createTask(id)).success, isTrue);

        await expectLater(service.restoreRecommendation(id), throwsStateError);
        expect(
          (rows[id]! as ProjectRecommendationEntity).status,
          ProjectRecommendationStatus.resolved,
        );
      },
    );

    test(
      'restoreRecommendation refuses steps that are open or replaced by a '
      'newer run',
      () async {
        await publish('run-1', proposal);
        final open = active().first.id;
        expect(
          await service.restoreRecommendation(open),
          isFalse,
          reason: 'There is nothing to undo on an open step.',
        );
        expect(await service.dismissRecommendation(open), isTrue);
        await publish('run-2', [
          {
            'toolName': 'recommend_next_steps',
            'args': {
              'steps': [
                {'title': 'Inspect habitat'},
              ],
            },
          },
        ]);

        expect(await service.restoreRecommendation(open), isFalse);
        expect(
          (rows[open]! as ProjectRecommendationEntity).status,
          ProjectRecommendationStatus.dismissed,
        );
        expect(await service.restoreRecommendation('missing'), isFalse);
      },
    );

    test(
      'migration does not revive steps from before the latest report',
      () async {
        rows['legacy'] = makeTestChangeSet(
          id: 'legacy',
          agentId: 'agent-1',
          taskId: 'project-1',
          createdAt: now.subtract(const Duration(days: 1)),
          items: [
            const ChangeItem(
              toolName: 'recommend_next_steps',
              args: {
                'steps': [
                  {'title': 'Stale'},
                ],
              },
              humanSummary: 'old',
            ),
          ],
        );
        when(
          () => mockRepository.getLatestReport(any(), any()),
        ).thenAnswer((_) async => makeTestReport(createdAt: now));
        await service.migratePendingBatches('agent-1', 'project-1');
        expect(active(), isEmpty);
        expect(
          (rows['legacy']! as ChangeSetEntity).items.single.status,
          ChangeItemStatus.retracted,
        );
      },
    );

    test(
      'failed creation cannot revive a step superseded by a newer report',
      () async {
        service = ProjectRecommendationService(
          syncService: mockSyncService,
          taskDispatcher: (_, _, _) async {
            when(() => mockRepository.getLatestReport(any(), any())).thenAnswer(
              (_) async =>
                  makeTestReport(createdAt: now.add(const Duration(hours: 1))),
            );
            return const ToolExecutionResult(success: false, output: 'failed');
          },
        );
        await publish('run-1', proposal);
        final id = active().first.id;
        expect((await service.createTask(id)).success, isFalse);
        expect(
          (rows[id]! as ProjectRecommendationEntity).status,
          ProjectRecommendationStatus.superseded,
        );
      },
    );

    test('a task whose rollback failed stays consumed', () async {
      service = ProjectRecommendationService(
        syncService: mockSyncService,
        taskDispatcher: (_, _, _) async => const ToolExecutionResult(
          success: false,
          nonRetryable: true,
          output: 'rollback failed',
        ),
      );
      await publish('run-1', proposal);
      final id = active().first.id;
      expect((await service.createTask(id)).success, isFalse);
      expect(
        (rows[id]! as ProjectRecommendationEntity).status,
        ProjectRecommendationStatus.resolved,
      );
    });

    test(
      'migration retains a newer individually decided recommendation',
      () async {
        rows['newer'] = makeTestProjectRecommendation(
          id: 'newer',
          projectId: 'project-1',
          createdAt: now,
          status: ProjectRecommendationStatus.dismissed,
        );
        rows['legacy'] = makeTestChangeSet(
          id: 'legacy',
          agentId: 'agent-1',
          taskId: 'project-1',
          createdAt: now.subtract(const Duration(days: 1)),
          items: const [
            ChangeItem(
              toolName: 'recommend_next_steps',
              args: {
                'steps': [
                  {'title': 'Old step'},
                ],
              },
              humanSummary: 'Old',
            ),
          ],
        );
        final newer = rows['newer'];
        await service.migratePendingBatches('agent-1', 'project-1');
        expect(rows['newer'], newer);
        expect(active(), isEmpty);
        expect(
          (rows['legacy']! as ChangeSetEntity).items.single.status,
          ChangeItemStatus.retracted,
        );
      },
    );

    test(
      'creating a task without a dispatcher fails before consuming a step',
      () async {
        await publish('run-1', proposal);
        final id = active().first.id;
        await expectLater(service.createTask(id), throwsStateError);
        expect(
          (rows[id]! as ProjectRecommendationEntity).status,
          ProjectRecommendationStatus.active,
        );
      },
    );

    test(
      'uncertain task failure stays consumed to prevent a duplicate retry',
      () async {
        service = ProjectRecommendationService(
          syncService: mockSyncService,
          taskDispatcher: (_, _, _) async =>
              throw StateError('unknown commit outcome'),
        );
        await publish('run-1', proposal);
        final id = active().first.id;
        await expectLater(service.createTask(id), throwsStateError);
        expect((await service.createTask(id)).success, isFalse);
      },
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

    await withClock(Clock.fixed(hGeneratedRecommendationNow), () async {
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
      expect(entity.updatedAt, hGeneratedRecommendationNow);
      expect(entity.supersededAt, hGeneratedRecommendationNow);
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
      expect(entity.createdAt, hGeneratedRecommendationNow);
      expect(entity.updatedAt, hGeneratedRecommendationNow);
      expect(entity.sourceChangeSetId, changeSet.id);
      expect(entity.sourceDecisionId, decision.id);
      expect(entity.rationale, draft.rationale);
      expect(entity.priority, draft.priority);
    }

    expect(uiNotifications, [
      {'generated-agent', 'generated-project', agentNotification},
    ]);
  }, tags: 'glados');

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
    when(
      () => generatedRepository.getEntitiesByAgentId(
        any(),
        type: AgentEntityTypes.projectRecommendationRun,
      ),
    ).thenAnswer((_) async => []);
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
      Clock.fixed(hGeneratedRecommendationNow),
      () => scenario.run(generatedService),
    );

    expect(result, scenario.expectsTransition, reason: '$scenario');
    if (!scenario.expectsTransition) {
      expect(writtenEntities, isEmpty);
      expect(uiNotifications, isEmpty);
      return;
    }

    final updated = writtenEntities
        .whereType<ProjectRecommendationEntity>()
        .single;
    expect(updated.status, scenario.expectedStatus);
    expect(updated.updatedAt, hGeneratedRecommendationNow);
    expect(
      updated.resolvedAt,
      scenario.expectedStatus == ProjectRecommendationStatus.resolved
          ? hGeneratedRecommendationNow
          : isNull,
    );
    expect(
      updated.dismissedAt,
      scenario.expectedStatus == ProjectRecommendationStatus.dismissed
          ? hGeneratedRecommendationNow
          : isNull,
    );
    expect(uiNotifications, [
      {'generated-agent', 'generated-project', agentNotification},
    ]);
  }, tags: 'glados');

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
    final updated = verify(
      () => mockSyncService.upsertEntity(captureAny()),
    ).captured.whereType<ProjectRecommendationEntity>().single;
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
      final updated = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured.whereType<ProjectRecommendationEntity>().single;
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
