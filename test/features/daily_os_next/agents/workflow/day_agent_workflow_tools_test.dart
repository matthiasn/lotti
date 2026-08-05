import 'day_agent_workflow_test_harness.dart';

void main() {
  configureDayAgentWorkflowTestSuite();

  // Owns day-agent tool exposure, validation, and collaborator delegation.
  group('DayAgentWorkflow', () {
    test('surfaces the baseline plan for refine-token wakes', () async {
      final planService = MockDayAgentPlanService();
      final baselinePlan =
          AgentDomainEntity.dayPlan(
                id: 'day_agent_plan:$dayId',
                agentId: agentId,
                dayId: dayId,
                planDate: DateTime(2026, 5, 25),
                data: DayPlanData(
                  planDate: DateTime(2026, 5, 25),
                  status: const DayPlanStatus.draft(),
                  plannedBlocks: [
                    PlannedBlock(
                      id: 'block-1',
                      categoryId: 'work',
                      startTime: DateTime(2026, 5, 25, 9),
                      endTime: DateTime(2026, 5, 25, 10),
                      title: 'Prep demo',
                      reason: 'Morning focus.',
                    ),
                  ],
                ),
                capacityMinutes: 360,
                scheduledMinutes: 60,
                createdAt: DateTime(2026, 5, 25, 8),
                updatedAt: DateTime(2026, 5, 25, 8),
                vectorClock: null,
              )
              as DayPlanEntity;
      when(
        () => planService.draftPlanForDay(agentId: agentId, dayId: dayId),
      ).thenAnswer((_) async => baselinePlan);

      final result = await execute(
        workflow(planService: planService),
        triggerTokens: {
          dayAgentRefineToken(dayId),
          dayAgentPlanningDayToken(dayId),
        },
      );

      expect(result.success, isTrue);
      final systemPrompt = conversationRepository.lastSystemMessage!;
      expect(systemPrompt, contains('Refine rules:'));
      expect(systemPrompt, contains('`propose_plan_diff`'));
      expect(systemPrompt, isNot(contains('Capture matching rules:')));
      expect(systemPrompt, isNot(contains('`parse_capture_to_items`')));
      expect(systemPrompt, isNot(contains('`draft_day_plan`')));
      expect(systemPrompt, isNot(contains('`set_next_wake`')));
      expect(systemPrompt, isNot(contains('schedule one useful future wake')));
      expect(systemPrompt, isNot(contains('On `drafting:<dayId>` wakes')));
      final refinePayload =
          sentPrompt().json('refine')! as Map<String, dynamic>;
      expect(refinePayload['requested'], isTrue);
      final plan = refinePayload['baselinePlan'] as Map<String, dynamic>;
      expect(plan['planId'], 'day_agent_plan:$dayId');
      final blocks = plan['blocks'] as List<dynamic>;
      expect((blocks.single as Map<String, dynamic>)['id'], 'block-1');
      final offeredTools = conversationRepository.sendMessageCalls.single.tools
          .map((tool) => tool.function.name)
          .toSet();
      expect(offeredTools, contains(DayAgentToolNames.proposePlanDiff));
      expect(offeredTools, isNot(contains(DayAgentToolNames.draftDayPlan)));
      // hydrateDecidedTasks must NOT be called on a refine wake.
      verifyNever(
        () => planService.hydrateDecidedTasks(
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
          explicitTaskIds: any(named: 'explicitTaskIds'),
          parsedItems: any(named: 'parsedItems'),
        ),
      );
    });

    test(
      'refine context carries a null baselinePlan when no draft exists',
      () async {
        final planService = MockDayAgentPlanService();
        when(
          () => planService.draftPlanForDay(agentId: agentId, dayId: dayId),
        ).thenAnswer((_) async => null);

        final result = await execute(
          workflow(planService: planService),
          triggerTokens: {
            dayAgentRefineToken(dayId),
            dayAgentPlanningDayToken(dayId),
          },
        );

        expect(result.success, isTrue);
        final refinePayload =
            sentPrompt().json('refine')! as Map<String, dynamic>;
        expect(refinePayload['requested'], isTrue);
        expect(refinePayload['baselinePlan'], isNull);
      },
    );

    test('omits the refine context when no refine token is present', () async {
      final planService = MockDayAgentPlanService();

      final result = await execute(
        workflow(planService: planService),
        triggerTokens: {dayAgentPlanningDayToken(dayId)},
      );

      expect(result.success, isTrue);
      expect(sentPrompt().has('refine'), isFalse);
    });

    test('delegates capture tools to the configured capture service', () async {
      final captureService = MockDayAgentCaptureService();
      when(
        () => captureService.executeTool(
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          toolName: DayAgentToolNames.matchToCorpus,
          args: any(named: 'args'),
        ),
      ).thenAnswer(
        (_) async =>
            DayAgentDirectToolResult.success(const {'candidates': <Object?>[]}),
      );
      conversationRepository.toolCalls = [
        toolCall(
          name: DayAgentToolNames.matchToCorpus,
          args: {'phrase': 'prep demo'},
        ),
      ];

      final result = await execute(workflow(captureService: captureService));

      expect(result.success, isTrue);
      expect(conversationRepository.toolResponses.single, contains('[]'));
      final args =
          verify(
                () => captureService.executeTool(
                  agentId: agentId,
                  threadId: threadId,
                  runKey: runKey,
                  toolName: DayAgentToolNames.matchToCorpus,
                  args: captureAny(named: 'args'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(args, {'phrase': 'prep demo'});
    });

    test(
      'returns a tool error when capture tools are not configured',
      () async {
        conversationRepository.toolCalls = [
          toolCall(
            name: DayAgentToolNames.matchToCorpus,
            args: {'phrase': 'prep demo'},
          ),
        ];

        final result = await execute(workflow());

        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          contains('capture/reconcile tools are not configured'),
        );
      },
    );

    test('delegates plan tools to the configured plan service', () async {
      final planService = MockDayAgentPlanService();
      when(
        () => planService.executeTool(
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          toolName: DayAgentToolNames.draftDayPlan,
          args: any(named: 'args'),
          planningConfig: any(named: 'planningConfig'),
          planningSnapshotAt: any(named: 'planningSnapshotAt'),
          planningBaselinePlan: any(named: 'planningBaselinePlan'),
        ),
      ).thenAnswer(
        (_) async => DayAgentDirectToolResult.success(const {
          'planId': 'day_agent_plan:dayplan-2026-05-25',
        }),
      );
      conversationRepository.toolCalls = [
        toolCall(
          name: DayAgentToolNames.draftDayPlan,
          args: {'dayId': dayId, 'blocks': <Object?>[]},
        ),
      ];

      final result = await execute(workflow(planService: planService));

      expect(result.success, isTrue);
      expect(
        conversationRepository.toolResponses.single,
        contains('day_agent_plan:dayplan-2026-05-25'),
      );
      final args =
          verify(
                () => planService.executeTool(
                  agentId: agentId,
                  threadId: threadId,
                  runKey: runKey,
                  toolName: DayAgentToolNames.draftDayPlan,
                  args: captureAny(named: 'args'),
                  planningConfig: any(named: 'planningConfig'),
                  planningSnapshotAt: now,
                  // The no-drafting-context dispatch is intentionally null.
                  // ignore: avoid_redundant_argument_values
                  planningBaselinePlan: null,
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(args, {'dayId': dayId, 'blocks': <Object?>[]});
    });

    test('rejects a tool call targeting a different day workspace', () async {
      // ADR 0022 Decision 4: under one planner the model must never mutate a
      // day other than the wake's workspace.
      final planService = MockDayAgentPlanService();
      conversationRepository.toolCalls = [
        toolCall(
          name: DayAgentToolNames.draftDayPlan,
          args: const {'dayId': 'dayplan-2026-05-26', 'blocks': <Object?>[]},
        ),
      ];

      final result = await execute(workflow(planService: planService));

      expect(result.success, isTrue);
      expect(
        conversationRepository.toolResponses.single,
        contains('does not match the wake workspace'),
      );
      // The mismatched call is rejected before reaching the plan service.
      verifyNever(
        () => planService.executeTool(
          agentId: any(named: 'agentId'),
          threadId: any(named: 'threadId'),
          runKey: any(named: 'runKey'),
          toolName: any(named: 'toolName'),
          args: any(named: 'args'),
          planningConfig: any(named: 'planningConfig'),
          planningSnapshotAt: any(named: 'planningSnapshotAt'),
          planningBaselinePlan: any(named: 'planningBaselinePlan'),
        ),
      );
    });

    test(
      'injects the durable-knowledge hook index + scoped statements',
      () async {
        final knowledgeService = MockDayAgentKnowledgeService();
        final globalEntry =
            AgentDomainEntity.plannerKnowledge(
                  id: 'k-global',
                  agentId: agentId,
                  key: 'deep-work',
                  hook: 'no deep work before 10',
                  statementText: 'Never schedule deep work before 10:00.',
                  source: KnowledgeSource.userStated,
                  status: KnowledgeStatus.confirmed,
                  createdAt: DateTime(2026, 5, 20),
                  updatedAt: DateTime(2026, 5, 20),
                  vectorClock: null,
                )
                as PlannerKnowledgeEntity;
        when(
          () => knowledgeService.activeFor(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => [globalEntry]);

        final result = await execute(
          workflow(knowledgeService: knowledgeService),
        );

        expect(result.success, isTrue);
        final sent = sentPrompt();
        // Hook index always present; the global statement is pulled in.
        expect(
          sent.section('knowledge_index'),
          contains('[deep-work] no deep work before 10 (scope: global)'),
        );
        expect(
          sent.section('knowledge_statements'),
          contains('Never schedule deep work before 10:00.'),
        );
        // Prefix-cache stability: the always-on index leads the prefix, the
        // per-wake scope-filtered statements trail it, and the wall-clock is
        // the last (most volatile) section.
        expect(
          sent.indexOf('knowledge_index'),
          lessThan(sent.indexOf('knowledge_statements')),
        );
        expect(
          sent.indexOf('knowledge_statements'),
          lessThan(sent.indexOf('current_local_time')),
        );
        expect(sent.tagsInOrder.last, 'current_local_time');
      },
    );

    test('omits knowledge blocks when there is no active knowledge', () async {
      final knowledgeService = MockDayAgentKnowledgeService();
      when(
        () => knowledgeService.activeFor(dailyOsPlannerAgentId),
      ).thenAnswer((_) async => []);

      final result = await execute(
        workflow(knowledgeService: knowledgeService),
      );

      expect(result.success, isTrue);
      final sent = sentPrompt();
      expect(sent.has('knowledge_index'), isFalse);
      expect(sent.has('knowledge_statements'), isFalse);
    });

    test('durable knowledge is injected once via knowledgeStatements — never '
        'folded into the day log (ADR 0022 compaction exemption)', () async {
      final knowledgeService = MockDayAgentKnowledgeService();
      const statement = 'Never schedule deep work before 10:00.';
      when(() => knowledgeService.activeFor(dailyOsPlannerAgentId)).thenAnswer(
        (_) async => [
          AgentDomainEntity.plannerKnowledge(
                id: 'k1',
                agentId: agentId,
                key: 'deep-work',
                hook: 'no deep work before 10',
                statementText: statement,
                source: KnowledgeSource.userStated,
                status: KnowledgeStatus.confirmed,
                createdAt: DateTime(2026, 5, 20),
                updatedAt: DateTime(2026, 5, 20),
                vectorClock: null,
              )
              as PlannerKnowledgeEntity,
        ],
      );

      final result = await execute(
        workflow(knowledgeService: knowledgeService),
      );

      expect(result.success, isTrue);
      // Exactly one occurrence: the knowledge is a domain entity surfaced
      // only via knowledgeStatements, never pulled into the compaction fold.
      final raw = conversationRepository.lastUserMessage!;
      expect(statement.allMatches(raw).length, 1);
    });

    test('a category-scoped statement is withheld when the wake touches no '
        'matching category', () async {
      final knowledgeService = MockDayAgentKnowledgeService();
      when(() => knowledgeService.activeFor(dailyOsPlannerAgentId)).thenAnswer(
        (_) async => [
          AgentDomainEntity.plannerKnowledge(
                id: 'k-fitness',
                agentId: agentId,
                key: 'gym',
                hook: 'protect gym blocks',
                statementText: 'Protect gym 3x/week.',
                source: KnowledgeSource.userStated,
                status: KnowledgeStatus.confirmed,
                createdAt: DateTime(2026, 5, 20),
                updatedAt: DateTime(2026, 5, 20),
                vectorClock: null,
                scope: 'category:fitness',
              )
              as PlannerKnowledgeEntity,
        ],
      );

      final result = await execute(
        workflow(knowledgeService: knowledgeService),
      );

      expect(result.success, isTrue);
      final sent = sentPrompt();
      // Hook index always lists the key (discovery)...
      expect(sent.section('knowledge_index'), contains('[gym]'));
      // ...but the full statement is withheld since this wake touches no
      // fitness category.
      expect(sent.has('knowledge_statements'), isFalse);
    });

    test(
      'scope-filtered statements trail the dayLog so a changing statement set '
      'cannot evict the large dayLog prefix (C1)',
      () async {
        // A wake with BOTH durable knowledge and a compacted dayLog: the
        // always-on index must lead the prefix, the dayLog sits in the stable
        // middle, and the per-wake scope-filtered statements trail it.
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
                  id: 'cap-x',
                  agentId: agentId,
                  transcript: 'a folded capture transcript',
                  capturedAt: DateTime.utc(2026, 5, 25, 7),
                  createdAt: DateTime.utc(2026, 5, 25, 7, 1),
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
          () => repository.getEntity('cap-x'),
        ).thenAnswer((_) async => capture);

        final knowledgeService = MockDayAgentKnowledgeService();
        when(
          () => knowledgeService.activeFor(dailyOsPlannerAgentId),
        ).thenAnswer(
          (_) async => [
            AgentDomainEntity.plannerKnowledge(
                  id: 'k-global',
                  agentId: agentId,
                  key: 'deep-work',
                  hook: 'no deep work before 10',
                  statementText: 'Never schedule deep work before 10:00.',
                  source: KnowledgeSource.userStated,
                  status: KnowledgeStatus.confirmed,
                  createdAt: DateTime(2026, 5, 20),
                  updatedAt: DateTime(2026, 5, 20),
                  vectorClock: null,
                )
                as PlannerKnowledgeEntity,
          ],
        );
        when(
          () => repository.getAttentionPlanningInputsForWindow(
            start: any(named: 'start'),
            end: any(named: 'end'),
          ),
        ).thenAnswer(
          (_) async => AttentionPlanningInputs(
            claims: [
              AgentDomainEntity.attentionRequest(
                    id: 'attn-c1',
                    agentId: 'task-agent',
                    kind: AttentionRequestKind.task,
                    title: 'Focus block',
                    categoryId: 'work',
                    requestedMinutes: 45,
                    impact: 3,
                    urgency: 3,
                    energyFit: AttentionEnergyFit.high,
                    evidenceRefs: const [],
                    createdAt: DateTime(2026, 5, 24),
                    vectorClock: null,
                  )
                  as AttentionRequestEntity,
            ],
            standingAgreements: const [],
          ),
        );

        final result = await execute(
          workflow(knowledgeService: knowledgeService),
        );

        expect(result.success, isTrue);
        final sent = sentPrompt();
        // The C1 invariant: index → day_log → statements — and the volatile
        // attention claims must never drift ahead of the (much larger,
        // byte-stable) day log.
        expect(sent.has('knowledge_index'), isTrue);
        expect(sent.has('day_log'), isTrue);
        expect(
          sent.indexOf('knowledge_index'),
          lessThan(sent.indexOf('day_log')),
        );
        expect(
          sent.indexOf('day_log'),
          lessThan(sent.indexOf('attention_planning')),
        );
        expect(
          sent.indexOf('attention_planning'),
          lessThan(sent.indexOf('knowledge_statements')),
        );
        expectCanonicalSectionOrder(sent);
      },
    );

    test('returns a tool error when plan tools are not configured', () async {
      conversationRepository.toolCalls = [
        toolCall(
          name: DayAgentToolNames.draftDayPlan,
          args: {'dayId': dayId, 'blocks': <Object?>[]},
        ),
      ];

      final result = await execute(workflow());

      expect(result.success, isTrue);
      expect(
        conversationRepository.toolResponses.single,
        contains('day-plan tools are not configured'),
      );
    });
  });
}
