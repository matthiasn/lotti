import 'day_agent_workflow_test_harness.dart';

void main() {
  configureDayAgentWorkflowTestSuite();

  // Owns lazy memory recall and durable-knowledge tool dispatch.
  group('DayAgentWorkflow', () {
    group('search_memory recall', () {
      test('recalls matching log detail through the dispatch', () async {
        when(() => syncService.repository).thenReturn(repository);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getLinksFrom(agentId),
        ).thenAnswer((_) async => []);
        final capture =
            AgentDomainEntity.capture(
                  id: 'cap-1',
                  agentId: agentId,
                  transcript: 'remember to buy oat milk',
                  capturedAt: DateTime(2026, 5, 24, 23),
                  createdAt: DateTime(2026, 5, 25, 7, 1),
                  vectorClock: null,
                  dayId: dayId,
                )
                as CaptureEntity;
        when(
          () => repository.getCaptureEventMetaForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer(
          (_) async => [
            (
              id: capture.id,
              dayId: capture.dayId,
              createdAt: capture.createdAt,
              capturedAt: capture.capturedAt,
            ),
          ],
        );
        when(
          () => repository.getEntity('cap-1'),
        ).thenAnswer((_) async => capture);

        conversationRepository.toolCalls = [
          toolCall(
            name: DayAgentToolNames.searchMemory,
            args: {'query': 'oat milk'},
          ),
        ];

        final result = await execute(workflow());

        expect(result.success, isTrue);
        final response = conversationRepository.toolResponses.single;
        expect(response, contains('remember to buy oat milk'));
        expect(response, contains('(capture'));
      });

      test('rejects a call with neither query nor ids', () async {
        conversationRepository.toolCalls = [
          toolCall(
            name: DayAgentToolNames.searchMemory,
            args: {'query': '   '},
          ),
        ];

        final result = await execute(workflow());

        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          'Error: provide "query" keywords or "ids" to recall.',
        );
      });

      void stubLogReads() {
        when(() => syncService.repository).thenReturn(repository);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getLinksFrom(agentId),
        ).thenAnswer((_) async => []);
      }

      test('reports no match when nothing in the log matches', () async {
        stubLogReads();
        final capture =
            AgentDomainEntity.capture(
                  id: 'cap-1',
                  agentId: agentId,
                  transcript: 'buy oat milk',
                  capturedAt: DateTime(2026, 5, 25, 7),
                  createdAt: DateTime(2026, 5, 25, 7, 1),
                  vectorClock: null,
                )
                as CaptureEntity;
        when(
          () => repository.getCaptureEventMetaForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer(
          (_) async => [
            (
              id: capture.id,
              dayId: capture.dayId,
              createdAt: capture.createdAt,
              capturedAt: capture.capturedAt,
            ),
          ],
        );
        when(
          () => repository.getEntity('cap-1'),
        ).thenAnswer((_) async => capture);
        conversationRepository.toolCalls = [
          toolCall(
            name: DayAgentToolNames.searchMemory,
            args: {'query': 'zzz nonsense'},
          ),
        ];

        final result = await execute(workflow());
        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          contains('No memory entries match'),
        );
      });

      test(
        'absorbs a capture-metadata load failure and still answers',
        () async {
          stubLogReads();
          when(
            () => repository.getCaptureEventMetaForDay(
              agentId: agentId,
              dayId: dayId,
            ),
          ).thenThrow(StateError('meta down'));
          conversationRepository.toolCalls = [
            toolCall(
              name: DayAgentToolNames.searchMemory,
              args: {'query': 'anything'},
            ),
          ];

          final result = await execute(workflow());
          expect(result.success, isTrue);
          expect(
            conversationRepository.toolResponses.single,
            contains('No memory entries match'),
          );
        },
      );

      test('returns a tool error when the log search throws', () async {
        when(() => syncService.repository).thenReturn(repository);
        when(
          () => repository.getCaptureEventMetaForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer((_) async => const []);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
        ).thenThrow(StateError('log down'));
        conversationRepository.toolCalls = [
          toolCall(
            name: DayAgentToolNames.searchMemory,
            args: {'query': 'anything'},
          ),
        ];

        final result = await execute(workflow());
        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          contains('memory search failed'),
        );
      });

      test('follows a link by pulling up the entry by id', () async {
        stubLogReads();
        final capture =
            AgentDomainEntity.capture(
                  id: 'cap-1',
                  agentId: agentId,
                  transcript: 'remember to buy oat milk',
                  capturedAt: DateTime(2026, 5, 25, 7),
                  createdAt: DateTime(2026, 5, 25, 7, 1),
                  vectorClock: null,
                )
                as CaptureEntity;
        when(
          () => repository.getCaptureEventMetaForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer(
          (_) async => [
            (
              id: capture.id,
              dayId: capture.dayId,
              createdAt: capture.createdAt,
              capturedAt: capture.capturedAt,
            ),
          ],
        );
        when(
          () => repository.getEntity('cap-1'),
        ).thenAnswer((_) async => capture);

        conversationRepository.toolCalls = [
          toolCall(
            name: DayAgentToolNames.searchMemory,
            args: {
              'ids': ['cap-1'],
            },
          ),
        ];

        final result = await execute(workflow());
        expect(result.success, isTrue);
        final response = conversationRepository.toolResponses.single;
        expect(response, contains('for ids cap-1'));
        expect(response, contains('(id: cap-1)'));
        expect(response, contains('remember to buy oat milk'));
      });

      test('reports no match when none of the requested ids resolve', () async {
        stubLogReads();
        when(
          () => repository.getCaptureEventMetaForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer((_) async => const []);
        conversationRepository.toolCalls = [
          toolCall(
            name: DayAgentToolNames.searchMemory,
            args: {
              'ids': ['ghost'],
            },
          ),
        ];

        final result = await execute(workflow());
        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          'No memory entries match ids ghost.',
        );
      });

      test('renders author-time links and supersession on hits', () async {
        when(() => syncService.repository).thenReturn(repository);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getLinksFrom(agentId),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getCaptureEventMetaForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer((_) async => const []);

        AgentMessageEntity obs(String id, DateTime at) =>
            AgentDomainEntity.agentMessage(
                  id: id,
                  agentId: agentId,
                  threadId: id,
                  kind: AgentMessageKind.observation,
                  createdAt: at,
                  vectorClock: null,
                  contentEntryId: 'pl-$id',
                  metadata: const AgentMessageMetadata(),
                )
                as AgentMessageEntity;
        AgentMessagePayloadEntity payload(String id, String text) =>
            AgentDomainEntity.agentMessagePayload(
                  id: 'pl-$id',
                  agentId: agentId,
                  createdAt: DateTime.utc(2026, 5, 20),
                  vectorClock: null,
                  content: <String, Object?>{'text': text},
                )
                as AgentMessagePayloadEntity;

        when(
          () => repository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => [
            obs('obs-a', DateTime.utc(2026, 5, 20)),
            obs('obs-b', DateTime.utc(2026, 5, 21)),
            obs('obs-c', DateTime.utc(2026, 5, 22)),
          ],
        );
        stubEntitiesByIds({
          'pl-obs-a': payload('obs-a', 'old gym plan'),
          'pl-obs-b': payload(
            'obs-b',
            'new gym plan [[supersedes:obs-a]] [[relates:ghost]]',
          ),
          'pl-obs-c': payload('obs-c', 'gym recap [[relates:obs-a]]'),
        });

        conversationRepository.toolCalls = [
          toolCall(
            name: DayAgentToolNames.searchMemory,
            args: {'query': 'gym'},
          ),
        ];

        final result = await execute(workflow());
        expect(result.success, isTrue);
        final response = conversationRepository.toolResponses.single;
        // obs-a is flagged as superseded by the newer obs-b.
        expect(
          response,
          contains('(id: obs-a) old gym plan [superseded by obs-b]'),
        );
        // obs-b surfaces its outgoing links: supersedes keeps the old id, the
        // dead one is annotated.
        expect(
          response,
          contains('links: supersedes:obs-a, relates:ghost (not found)'),
        );
        // obs-c's relates link forward-follows the superseded target to live.
        expect(response, contains('links: relates:obs-a → obs-b'));
      });

      test('validates a link to a knowledge entry via its key', () async {
        final ks = MockDayAgentKnowledgeService();
        when(
          () => ks.activeFor(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => const []);
        when(() => ks.allFor(dailyOsPlannerAgentId)).thenAnswer(
          (_) async => [
            AgentDomainEntity.plannerKnowledge(
                  id: 'k1',
                  agentId: agentId,
                  key: 'deep-work',
                  hook: 'h',
                  statementText: 's',
                  source: KnowledgeSource.userStated,
                  status: KnowledgeStatus.confirmed,
                  createdAt: now,
                  updatedAt: now,
                  vectorClock: null,
                )
                as PlannerKnowledgeEntity,
          ],
        );
        when(() => syncService.repository).thenReturn(repository);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getLinksFrom(agentId),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getCaptureEventMetaForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer((_) async => const []);
        when(
          () => repository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => [
            AgentDomainEntity.agentMessage(
                  id: 'obs',
                  agentId: agentId,
                  threadId: 'obs',
                  kind: AgentMessageKind.observation,
                  createdAt: DateTime.utc(2026, 5, 20),
                  vectorClock: null,
                  contentEntryId: 'pl-obs',
                  metadata: const AgentMessageMetadata(),
                )
                as AgentMessageEntity,
          ],
        );
        stubEntitiesByIds({
          'pl-obs':
              AgentDomainEntity.agentMessagePayload(
                    id: 'pl-obs',
                    agentId: agentId,
                    createdAt: DateTime.utc(2026, 5, 20),
                    vectorClock: null,
                    content: const {'text': 'topic map [[relates:deep-work]]'},
                  )
                  as AgentMessagePayloadEntity,
        });

        conversationRepository.toolCalls = [
          toolCall(
            name: DayAgentToolNames.searchMemory,
            args: {'query': 'topic'},
          ),
        ];

        final result = await execute(workflow(knowledgeService: ks));
        expect(result.success, isTrue);
        final response = conversationRepository.toolResponses.single;
        // The knowledge key resolves (not a dead link) because the workflow
        // widened validation with the planner's knowledge keys.
        expect(response, contains('links: relates:deep-work'));
        expect(response, isNot(contains('relates:deep-work (not found)')));
      });
    });

    group('propose_knowledge dispatch', () {
      test('routes propose_knowledge through the knowledge service', () async {
        final knowledgeService = MockDayAgentKnowledgeService();
        when(
          () => knowledgeService.executeTool(
            agentId: dailyOsPlannerAgentId,
            toolName: DayAgentToolNames.proposeKnowledge,
            args: any(named: 'args'),
          ),
        ).thenAnswer(
          (_) async => DayAgentDirectToolResult.success(const {
            'id': 'k1',
            'key': 'deep-work',
            'status': 'confirmed',
          }),
        );
        conversationRepository.toolCalls = [
          toolCall(
            name: DayAgentToolNames.proposeKnowledge,
            args: {
              'key': 'deep-work',
              'hook': 'h',
              'statement': 's',
              'source': 'userStated',
            },
          ),
        ];

        final result = await execute(
          workflow(knowledgeService: knowledgeService),
        );
        expect(result.success, isTrue);
        verify(
          () => knowledgeService.executeTool(
            agentId: dailyOsPlannerAgentId,
            toolName: DayAgentToolNames.proposeKnowledge,
            args: any(named: 'args'),
          ),
        ).called(1);
      });

      test('errors when no knowledge service is configured', () async {
        conversationRepository.toolCalls = [
          toolCall(
            name: DayAgentToolNames.proposeKnowledge,
            args: {'key': 'k', 'hook': 'h', 'statement': 's'},
          ),
        ];

        final result = await execute(workflow());
        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          contains('durable-knowledge tools are not configured'),
        );
      });
    });

    group('knowledge scope edge paths', () {
      test(
        'omits knowledge blocks when the knowledge service throws',
        () async {
          final knowledgeService = MockDayAgentKnowledgeService();
          when(
            () => knowledgeService.activeFor(dailyOsPlannerAgentId),
          ).thenThrow(StateError('knowledge down'));

          final result = await execute(
            workflow(knowledgeService: knowledgeService),
          );
          expect(result.success, isTrue);
          final sent = sentPrompt();
          expect(sent.has('knowledge_index'), isFalse);
          expect(sent.has('knowledge_statements'), isFalse);
        },
      );

      test(
        'injects project-scoped knowledge for a project-targeted claim',
        () async {
          final claim =
              AgentDomainEntity.attentionRequest(
                    id: 'c-proj',
                    agentId: 'task-agent',
                    kind: AttentionRequestKind.project,
                    title: 'Project X',
                    categoryId: 'work',
                    requestedMinutes: 60,
                    impact: 3,
                    urgency: 3,
                    energyFit: AttentionEnergyFit.high,
                    evidenceRefs: const [],
                    createdAt: DateTime.utc(2026, 5, 24),
                    vectorClock: null,
                    targetKind: 'project',
                    targetId: 'proj-1',
                  )
                  as AttentionRequestEntity;
          when(
            () => repository.getAttentionPlanningInputsForWindow(
              start: any(named: 'start'),
              end: any(named: 'end'),
            ),
          ).thenAnswer(
            (_) async => AttentionPlanningInputs(
              claims: [claim],
              standingAgreements: const [],
            ),
          );
          final knowledgeService = MockDayAgentKnowledgeService();
          when(
            () => knowledgeService.activeFor(dailyOsPlannerAgentId),
          ).thenAnswer(
            (_) async => [
              AgentDomainEntity.plannerKnowledge(
                    id: 'k-proj',
                    agentId: agentId,
                    key: 'proj-pref',
                    hook: 'project hook',
                    statementText: 'Protect project X mornings.',
                    source: KnowledgeSource.userStated,
                    status: KnowledgeStatus.confirmed,
                    createdAt: DateTime(2026, 5, 20),
                    updatedAt: DateTime(2026, 5, 20),
                    vectorClock: null,
                    scope: 'project:proj-1',
                  )
                  as PlannerKnowledgeEntity,
            ],
          );

          final result = await execute(
            workflow(knowledgeService: knowledgeService),
          );
          expect(result.success, isTrue);
          // The project-targeted claim put project:proj-1 in touched scopes, so
          // the project-scoped statement is pulled in.
          expect(
            sentPrompt().section('knowledge_statements'),
            contains('Protect project X morn'),
          );
        },
      );
    });
  });
}
