import 'day_agent_workflow_test_harness.dart';

void main() {
  configureDayAgentWorkflowTestSuite();

  // Owns week context, summaries, and dependency-aware planning context.
  group('DayAgentWorkflow', () {
    group('week context', () {
      MockDayAgentWeekContextService weekContextStub({WeekContext? context}) {
        final service = MockDayAgentWeekContextService();
        when(
          () => service.buildForDay(
            planDate: any(named: 'planDate'),
            now: any(named: 'now'),
          ),
        ).thenAnswer((_) async => context);
        return service;
      }

      const sampleContext = WeekContext(
        recentDays:
            'Sun Jun 7 — no plan. Work: 9h recorded. '
            'Total recorded: 9h.',
        weekAhead: 'Fri Jun 12 — draft plan: Work 4h.',
      );

      test('renders recent_days + week_ahead after knowledge statements and '
          'before the mode section', () async {
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
        final planService = MockDayAgentPlanService();
        stubDraftingPlanContext(planService);
        stubSuccessfulDraftToolCall(planService);
        when(
          () => repository.getAttentionPlanningInputsForWindow(
            start: any(named: 'start'),
            end: any(named: 'end'),
          ),
        ).thenAnswer(
          (_) async => AttentionPlanningInputs(
            claims: [
              AgentDomainEntity.attentionRequest(
                    id: 'attn-1',
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
          workflow(
            knowledgeService: knowledgeService,
            planService: planService,
            weekContextService: weekContextStub(context: sampleContext),
          ),
          triggerTokens: {
            dayAgentDraftingToken(dayId),
            dayAgentPlanningDayToken(dayId),
          },
        );

        expect(result.success, isTrue);
        final sent = sentPrompt();
        expect(sent.section('recent_days'), sampleContext.recentDays);
        expect(sent.section('week_ahead'), sampleContext.weekAhead);
        // Volatility ordering (the plan-mandated chain): day-stable
        // attention claims, then per-wake knowledge statements, then the
        // week context (its today-so-far line churns with tracked time),
        // then the per-wake mode section.
        expect(
          sent.indexOf('attention_planning'),
          lessThan(sent.indexOf('knowledge_statements')),
        );
        expect(
          sent.indexOf('knowledge_statements'),
          lessThan(sent.indexOf('recent_days')),
        );
        expect(
          sent.indexOf('recent_days'),
          lessThan(sent.indexOf('week_ahead')),
        );
        expect(sent.indexOf('week_ahead'), lessThan(sent.indexOf('drafting')));
        expectCanonicalSectionOrder(sent);
      });

      test('refine wakes carry week context before the refine section, in '
          'canonical order', () async {
        final planService = MockDayAgentPlanService();
        when(
          () => planService.draftPlanForDay(agentId: agentId, dayId: dayId),
        ).thenAnswer((_) async => null);

        final result = await execute(
          workflow(
            planService: planService,
            weekContextService: weekContextStub(context: sampleContext),
          ),
          triggerTokens: {
            dayAgentRefineToken(dayId),
            dayAgentPlanningDayToken(dayId),
          },
        );

        expect(result.success, isTrue);
        final sent = sentPrompt();
        expect(sent.indexOf('week_ahead'), lessThan(sent.indexOf('refine')));
        expectCanonicalSectionOrder(sent);
      });

      test('omits the sections when the service yields null', () async {
        final result = await execute(
          workflow(weekContextService: weekContextStub()),
        );

        expect(result.success, isTrue);
        final sent = sentPrompt();
        expect(sent.has('recent_days'), isFalse);
        expect(sent.has('week_ahead'), isFalse);
      });

      test('absorbs an unexpected service throw (sections absent, wake '
          'succeeds)', () async {
        final service = MockDayAgentWeekContextService();
        when(
          () => service.buildForDay(
            planDate: any(named: 'planDate'),
            now: any(named: 'now'),
          ),
        ).thenThrow(StateError('service bug'));

        final result = await execute(workflow(weekContextService: service));

        expect(result.success, isTrue);
        final sent = sentPrompt();
        expect(sent.has('recent_days'), isFalse);
        expect(sent.has('week_ahead'), isFalse);
      });

      test('omits each section independently', () async {
        const historyOnly = WeekContext(
          recentDays: 'Sun Jun 7 — no plan. Nothing recorded.',
          weekAhead: null,
        );
        final result = await execute(
          workflow(weekContextService: weekContextStub(context: historyOnly)),
        );

        expect(result.success, isTrue);
        final sent = sentPrompt();
        expect(sent.section('recent_days'), historyOnly.recentDays);
        expect(sent.has('week_ahead'), isFalse);
      });

      test('builds week context for the wake-resolved plan date', () async {
        final service = weekContextStub(context: sampleContext);

        await execute(workflow(weekContextService: service));

        verify(
          () => service.buildForDay(
            planDate: DateTime(2026, 5, 25),
            // The wake's own clock read is passed through so the section's
            // day classification matches current_local_time.
            now: now,
          ),
        ).called(1);
      });

      test('capture-submitted wakes (day from capture fallback) skip the '
          'week-context build entirely', () async {
        currentState = state(activeDayId: '');
        final service = weekContextStub(context: sampleContext);
        final captureService = MockDayAgentCaptureService();
        stubCaptureContext(captureService);
        when(
          () => captureService.parsedItemsForCapture('capture-1'),
        ).thenAnswer((_) async => const []);
        when(
          () => captureService.executeTool(
            agentId: agentId,
            threadId: threadId,
            runKey: runKey,
            toolName: DayAgentToolNames.parseCaptureToItems,
            args: any(named: 'args'),
          ),
        ).thenAnswer(
          (_) async => DayAgentDirectToolResult.success(const {
            'captureId': 'capture-1',
            'items': [
              {'kind': 'newTask', 'title': 'x', 'categoryId': 'home'},
            ],
          }),
        );
        conversationRepository.toolCalls = [
          toolCall(
            name: DayAgentToolNames.parseCaptureToItems,
            args: const {
              'captureId': 'capture-1',
              'items': [
                {
                  'kind': 'newTask',
                  'title': 'x',
                  'categoryId': 'home',
                  'confidenceScore': 0.4,
                },
              ],
            },
          ),
        ];

        final result = await execute(
          workflow(captureService: captureService, weekContextService: service),
          triggerTokens: {dayAgentCaptureSubmittedToken('capture-1')},
        );

        expect(result.success, isTrue);
        verifyNever(
          () => service.buildForDay(
            planDate: any(named: 'planDate'),
            now: any(named: 'now'),
          ),
        );
        expect(sentPrompt().has('recent_days'), isFalse);
      });

      test(
        'write_day_summary dispatches to the service, bypassing the blanket '
        'workspace-day guard (wall-clock window is the service contract)',
        () async {
          final service = weekContextStub(context: sampleContext);
          when(
            () => service.executeTool(
              agentId: agentId,
              toolName: DayAgentToolNames.writeDaySummary,
              args: any(named: 'args'),
            ),
          ).thenAnswer(
            (_) async => DayAgentDirectToolResult.success(const {
              'dayId': 'dayplan-2026-05-24',
              'updated': false,
            }),
          );
          // The summary targets YESTERDAY relative to the wake clock — a
          // different day than the wake workspace. The blanket guard would
          // reject it; the week-context branch must run first.
          conversationRepository.toolCalls = [
            toolCall(
              name: DayAgentToolNames.writeDaySummary,
              args: const {
                'dayId': 'dayplan-2026-05-24',
                'text': 'Calm day; finished early.',
              },
            ),
          ];

          final result = await execute(workflow(weekContextService: service));

          expect(result.success, isTrue);
          expect(
            conversationRepository.toolResponses.single,
            isNot(contains('does not match the wake workspace')),
          );
          expect(
            conversationRepository.toolResponses.single,
            contains('dayplan-2026-05-24'),
          );
          final captured =
              verify(
                    () => service.executeTool(
                      agentId: agentId,
                      toolName: DayAgentToolNames.writeDaySummary,
                      args: captureAny(named: 'args'),
                    ),
                  ).captured.single
                  as Map<String, dynamic>;
          expect(captured['text'], 'Calm day; finished early.');
        },
      );

      test('other day-scoped tools still hit the blanket guard even with the '
          'week-context service configured', () async {
        final service = weekContextStub(context: sampleContext);
        final planService = MockDayAgentPlanService();
        conversationRepository.toolCalls = [
          toolCall(
            name: DayAgentToolNames.draftDayPlan,
            args: const {'dayId': 'dayplan-2026-05-26', 'blocks': <Object?>[]},
          ),
        ];

        final result = await execute(
          workflow(planService: planService, weekContextService: service),
        );

        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          contains('does not match the wake workspace'),
        );
      });

      test('write_day_summary returns a tool error when the service is not '
          'configured', () async {
        conversationRepository.toolCalls = [
          toolCall(
            name: DayAgentToolNames.writeDaySummary,
            args: const {'dayId': 'dayplan-2026-05-25', 'text': 'note'},
          ),
        ];

        final result = await execute(workflow());

        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          contains('week-context tools are not configured'),
        );
      });

      test('offers the write_day_summary tool only when configured', () async {
        await execute(workflow(weekContextService: weekContextStub()));
        expect(
          conversationRepository.lastTools.map((t) => t.function.name),
          contains(DayAgentToolNames.writeDaySummary),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('Week context'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('Sustainability beats'),
        );

        // The gated block keeps exactly one blank line on each seam.
        expect(
          conversationRepository.lastSystemMessage,
          contains('self-evident.\n\nWeek context'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('contradiction.\n\nYour memory'),
        );

        await execute(workflow());
        expect(
          conversationRepository.lastTools.map((t) => t.function.name),
          isNot(contains(DayAgentToolNames.writeDaySummary)),
        );
        expect(
          conversationRepository.lastSystemMessage,
          isNot(contains('Week context')),
        );
        // No double blank line where the gated block collapsed to nothing.
        expect(
          conversationRepository.lastSystemMessage,
          contains('self-evident.\n\nYour memory'),
        );
      });
    });

    test(
      'includes soul sections in the system prompt when one is assigned',
      () async {
        final soulService = MockSoulDocumentService();
        when(
          () => soulService.resolveActiveSoulForTemplate(templateId),
        ).thenAnswer(
          (_) async => makeTestSoulDocumentVersion(
            voiceDirective: 'Use the Shepherd voice.',
            toneBounds: 'Stay candid.',
            coachingStyle: 'Ask for one concrete next action.',
            antiSycophancyPolicy: 'Do not flatter.',
          ),
        );

        final result = await execute(
          workflow(soulDocumentService: soulService),
        );

        expect(result.success, isTrue);
        expect(
          conversationRepository.lastSystemMessage,
          contains('## Personality'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('Use the Shepherd voice.'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('## Tone Bounds'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('Stay candid.'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('## Coaching Style'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('## Anti-Sycophancy Policy'),
        );
      },
    );

    group('dependency-aware planning (ADR 0043)', () {
      test('adds Blocked-work rules to the system prompt only when a '
          'dependencyResolver is configured', () async {
        final resolver = MockTaskDependencyResolver();

        await execute(workflow(dependencyResolver: resolver));
        expect(
          conversationRepository.lastSystemMessage,
          contains('Blocked-work rules (ADR 0043)'),
        );
        // The gated block keeps exactly one blank line on the seam.
        expect(
          conversationRepository.lastSystemMessage,
          contains('self-evident.\n\nBlocked-work rules'),
        );

        await execute(workflow());
        expect(
          conversationRepository.lastSystemMessage,
          isNot(contains('Blocked-work rules')),
        );
      });

      test('the digest gains its blocked-dependency bullet only when both '
          'directiveService and dependencyResolver are configured', () async {
        final directiveService = MockDayAgentDirectiveService();
        when(
          () => directiveService.directiveForDay(any()),
        ).thenAnswer((_) async => null);
        when(
          () => repository.getDayStatusEventsSince(
            any(),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => const []);
        final resolver = MockTaskDependencyResolver();

        Future<WakeResult> executeDigest(DayAgentWorkflow sut) {
          stubCoordinatorReads();
          return withClock(
            Clock.fixed(now),
            () => sut.execute(
              agentIdentity: makeTestIdentity(
                id: dailyOsPlannerAgentId,
                agentId: dailyOsPlannerAgentId,
                kind: AgentKinds.dayAgent,
                displayName: 'Shepherd',
                currentStateId: 'state-$dailyOsPlannerAgentId',
                config: const AgentConfig(
                  profileId: 'profile-day',
                  maxTurnsPerWake: 5,
                ),
                createdAt: now,
                updatedAt: now,
              ),
              runKey: runKey,
              triggerTokens: {dayAgentDigestToken(dayId)},
              threadId: threadId,
            ),
          );
        }

        // directiveService alone: base digest text present, new bullet
        // absent.
        final withoutResolver = await executeDigest(
          workflow(directiveService: directiveService),
        );
        expect(withoutResolver.success, isTrue, reason: withoutResolver.error);
        expect(
          conversationRepository.lastSystemMessage,
          contains('Digest rules'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          isNot(
            contains('A directive commitment on a task blocked for planning'),
          ),
        );

        // Both configured: the new bullet appears, on its own line.
        final withResolver = await executeDigest(
          workflow(
            directiveService: directiveService,
            dependencyResolver: resolver,
          ),
        );
        expect(withResolver.success, isTrue, reason: withResolver.error);
        expect(
          conversationRepository.lastSystemMessage,
          contains(
            'pre-warms.\n'
            '- A directive commitment on a task blocked for planning '
            'should target its\n'
            '  blocker instead',
          ),
        );
      });

      test('passes the exact dependencyResolver instance through to the '
          'capture service on a capture wake', () async {
        final resolver = MockTaskDependencyResolver();
        final capture = makeTestCapture(
          id: 'capture-1',
          agentId: agentId,
          transcript: 'buy milk',
          capturedAt: DateTime(2026, 5, 25, 7),
          createdAt: DateTime(2026, 5, 25, 7),
        );
        final captureService = MockDayAgentCaptureService();
        when(
          () => captureService.getCapture('capture-1'),
        ).thenAnswer((_) async => capture);
        when(
          () => captureService.buildTaskCorpusSnapshot(
            allowedCategoryIds: const <String>{},
            day: DateTime(2026, 5, 25),
            dependencyResolver: resolver,
          ),
        ).thenAnswer((_) async => const []);
        when(
          () => captureService.executeTool(
            agentId: agentId,
            threadId: threadId,
            runKey: runKey,
            toolName: DayAgentToolNames.parseCaptureToItems,
            args: any(named: 'args'),
          ),
        ).thenAnswer(
          (_) async => DayAgentDirectToolResult.success(const {
            'captureId': 'capture-1',
            'items': [
              {'id': 'parsed-1'},
            ],
          }),
        );
        conversationRepository.toolCalls = [
          toolCall(
            name: DayAgentToolNames.parseCaptureToItems,
            args: const {
              'captureId': 'capture-1',
              'items': [
                {
                  'kind': 'newTask',
                  'title': 'Buy milk',
                  'categoryId': 'home',
                  'confidenceScore': 0.4,
                },
              ],
            },
          ),
        ];

        final result = await execute(
          workflow(
            captureService: captureService,
            dependencyResolver: resolver,
          ),
          triggerTokens: {
            dayAgentCaptureSubmittedToken('capture-1'),
            dayAgentPlanningDayToken(dayId),
          },
        );

        expect(result.success, isTrue, reason: result.error);
        // A mismatched (e.g. differently-instantiated) resolver would not
        // satisfy this exact-instance stub, so the mock would have no
        // matching call and this verify would fail — proving the same
        // instance travels from the workflow field through
        // _captureContext to the capture service call.
        verify(
          () => captureService.buildTaskCorpusSnapshot(
            allowedCategoryIds: const <String>{},
            day: DateTime(2026, 5, 25),
            dependencyResolver: resolver,
          ),
        ).called(1);
      });

      test(
        'passes the exact dependencyResolver instance to hydrateDecidedTasks '
        'on a drafting wake with no capture',
        () async {
          final resolver = MockTaskDependencyResolver();
          final planService = MockDayAgentPlanService();
          stubDraftingPlanContext(
            planService,
            decidedTasks: const [
              DecidedTaskRef(
                id: 'task-c-leaf',
                title: 'Ship the integration',
                categoryId: 'work',
                status: 'BLOCKED',
                blockedBy: [
                  ResolvedBlocker(
                    taskId: 'task-b-middle',
                    title: 'Get vendor credentials',
                    status: 'OPEN',
                  ),
                ],
              ),
            ],
          );
          stubSuccessfulDraftToolCall(planService);

          final result = await execute(
            workflow(planService: planService, dependencyResolver: resolver),
            triggerTokens: {
              dayAgentDraftingToken(dayId),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isTrue, reason: result.error);
          // The wake that has no capture is precisely the one the blocked-work
          // rule used to reach empty-handed: `buildTaskCorpusSnapshot` — the
          // only other carrier of status/blockedBy — renders inside
          // `<capture>` alone, so with no capture the model was told to
          // respect blockers while being shown nothing that could be blocked.
          // Same instance as the one gating the rule's emission, so the rule
          // and the data behind it cannot drift apart again.
          verify(
            () => planService.hydrateDecidedTasks(
              allowedCategoryIds: any(named: 'allowedCategoryIds'),
              explicitTaskIds: any(named: 'explicitTaskIds'),
              parsedItems: any(named: 'parsedItems'),
              dependencyResolver: resolver,
            ),
          ).called(1);
          // And it lands in the prompt the model reads, in the shape the rule
          // is phrased against.
          final drafting =
              sentPrompt().json('drafting')! as Map<String, dynamic>;
          final decided =
              (drafting['decidedTasks'] as List<dynamic>).single
                  as Map<String, dynamic>;
          expect(decided['status'], 'BLOCKED');
          expect(
            (decided['blockedBy'] as List<dynamic>).single,
            containsPair('taskId', 'task-b-middle'),
          );
          expect(
            conversationRepository.lastSystemMessage,
            contains('Blocked-work rules (ADR 0043)'),
          );
        },
      );

      test(
        'annotates baseline blocks whose task became blocked since the draft',
        () async {
          // A re-draft replaces the whole block list, so the model re-affirms
          // every baseline block. A task that picked up a blocker after that
          // draft was written is in neither decidedTasks nor (with no capture)
          // the corpus, so without this the rule again arrives with nothing
          // behind it — just for a different set of tasks.
          final resolver = MockTaskDependencyResolver();
          final planService = MockDayAgentPlanService();
          final baselinePlan = makeTestDayPlan(
            agentId: agentId,
            planDate: DateTime(2026, 5, 25),
            data: DayPlanData(
              planDate: DateTime(2026, 5, 25),
              status: const DayPlanStatus.draft(),
              plannedBlocks: [
                PlannedBlock(
                  id: 'block-1',
                  categoryId: 'work',
                  taskId: 'task-since-blocked',
                  startTime: DateTime(2026, 5, 25, 9),
                  endTime: DateTime(2026, 5, 25, 10),
                  title: 'Ship the integration',
                  reason: 'High-energy window.',
                ),
              ],
            ),
            capacityMinutes: 360,
            scheduledMinutes: 60,
            createdAt: DateTime(2026, 5, 25, 8),
            updatedAt: DateTime(2026, 5, 25, 8),
          );
          stubDraftingPlanContext(planService, baselinePlan: baselinePlan);
          stubSuccessfulDraftToolCall(planService);
          when(
            () => planService.resolvePlannedTaskStates(
              taskIds: any(named: 'taskIds'),
              allowedCategoryIds: any(named: 'allowedCategoryIds'),
              dependencyResolver: any(named: 'dependencyResolver'),
            ),
          ).thenAnswer(
            (_) async => {
              'task-since-blocked': const PlannedTaskState(
                status: 'OPEN',
                blockedBy: [
                  ResolvedBlocker(
                    taskId: 'task-b-middle',
                    title: 'Get vendor credentials',
                    status: 'OPEN',
                    categoryId: 'ops',
                  ),
                ],
              ),
            },
          );

          final result = await execute(
            workflow(planService: planService, dependencyResolver: resolver),
            triggerTokens: {
              dayAgentDraftingToken(dayId),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isTrue, reason: result.error);
          final blocks =
              ((sentPrompt().json('drafting')!
                          as Map<String, dynamic>)['baselinePlan']
                      as Map<String, dynamic>)['blocks']
                  as List<dynamic>;
          final blocked = blocks.first as Map<String, dynamic>;
          expect(
            (blocked['blockedBy'] as List<dynamic>).single,
            containsPair('taskId', 'task-b-middle'),
          );
          // Only the ids the baseline actually schedules, and only those not
          // already resolved as decided tasks.
          final asked = verify(
            () => planService.resolvePlannedTaskStates(
              taskIds: captureAny(named: 'taskIds'),
              allowedCategoryIds: any(named: 'allowedCategoryIds'),
              dependencyResolver: any(named: 'dependencyResolver'),
            ),
          ).captured.single;
          expect(asked, {'task-since-blocked'});
        },
      );

      test(
        'leaves an unblocked baseline plan serialised exactly as before',
        () async {
          final resolver = MockTaskDependencyResolver();
          final planService = MockDayAgentPlanService();
          final baselinePlan = makeTestDayPlan(
            agentId: agentId,
            planDate: DateTime(2026, 5, 25),
            data: DayPlanData(
              planDate: DateTime(2026, 5, 25),
              status: const DayPlanStatus.draft(),
              plannedBlocks: [
                PlannedBlock(
                  id: 'block-1',
                  categoryId: 'work',
                  taskId: 'task-fine',
                  startTime: DateTime(2026, 5, 25, 9),
                  endTime: DateTime(2026, 5, 25, 10),
                  title: 'Prep demo',
                  reason: 'High-energy window.',
                ),
              ],
            ),
            capacityMinutes: 360,
            scheduledMinutes: 60,
            createdAt: DateTime(2026, 5, 25, 8),
            updatedAt: DateTime(2026, 5, 25, 8),
          );
          stubDraftingPlanContext(planService, baselinePlan: baselinePlan);
          stubSuccessfulDraftToolCall(planService);
          when(
            () => planService.resolvePlannedTaskStates(
              taskIds: any(named: 'taskIds'),
              allowedCategoryIds: any(named: 'allowedCategoryIds'),
              dependencyResolver: any(named: 'dependencyResolver'),
            ),
          ).thenAnswer((_) async => const {});

          final result = await execute(
            workflow(planService: planService, dependencyResolver: resolver),
            triggerTokens: {
              dayAgentDraftingToken(dayId),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isTrue, reason: result.error);
          final blocks =
              ((sentPrompt().json('drafting')!
                          as Map<String, dynamic>)['baselinePlan']
                      as Map<String, dynamic>)['blocks']
                  as List<dynamic>;
          // Absent, not an empty list: an unblocked plan must not grow a key
          // and cost prompt bytes to say nothing.
          expect(
            (blocks.single as Map<String, dynamic>).containsKey('blockedBy'),
            isFalse,
          );
        },
      );
    });
  });
}
