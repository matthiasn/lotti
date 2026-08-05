import 'day_agent_workflow_test_harness.dart';

void main() {
  configureDayAgentWorkflowTestSuite();

  // Owns drafting-wake terminal plan enforcement.
  group('DayAgentWorkflow', () {
    group('drafting wake final plan enforcement', () {
      test(
        'rejects an empty closed draft that silently omits selected work',
        () async {
          final planService = MockDayAgentPlanService();
          stubDraftingPlanContext(
            planService,
            decidedTasks: const [
              DecidedTaskRef(
                id: 'task-selected',
                title: 'Selected task',
                categoryId: 'work',
              ),
            ],
          );
          stubSuccessfulDraftToolCall(planService);

          final result = await withClock(
            Clock.fixed(DateTime(2026, 5, 25, 18)),
            () => workflow(planService: planService).execute(
              agentIdentity: identity(),
              runKey: runKey,
              triggerTokens: {
                dayAgentDraftingToken(dayId),
                dayAgentPlanningDayToken(dayId),
              },
              threadId: threadId,
            ),
          );

          expect(result.success, isFalse);
          expect(result.error, contains('draft_day_plan'));
          expect(conversationRepository.sendMessageCalls, hasLength(2));
          expect(
            conversationRepository.toolResponses.last,
            contains('attentionNeeded'),
          );
          verifyNever(
            () => planService.executeTool(
              agentId: any(named: 'agentId'),
              threadId: any(named: 'threadId'),
              runKey: any(named: 'runKey'),
              toolName: DayAgentToolNames.draftDayPlan,
              args: any(named: 'args'),
              planningConfig: any(named: 'planningConfig'),
              planningSnapshotAt: any(named: 'planningSnapshotAt'),
              planningBaselinePlan: any(named: 'planningBaselinePlan'),
            ),
          );
        },
      );

      test('rejects an exact non-empty baseline echo that omits newly selected '
          'work', () async {
        final planService = MockDayAgentPlanService();
        final baselineBlock = closedBaselineBlock();
        final baselinePlan = closedBaselinePlan(baselineBlock);
        stubDraftingPlanContext(
          planService,
          baselinePlan: baselinePlan,
          decidedTasks: const [
            DecidedTaskRef(
              id: 'task-new',
              title: 'Newly selected task',
              categoryId: 'work',
            ),
          ],
        );
        stubSuccessfulDraftToolCall(planService);
        conversationRepository.toolCalls = [
          toolCall(
            id: 'draft-call',
            name: DayAgentToolNames.draftDayPlan,
            args: {
              'dayId': dayId,
              'blocks': [closedBaselineBlockArgs(baselineBlock)],
            },
          ),
        ];

        final result = await withClock(
          Clock.fixed(DateTime(2026, 5, 25, 18)),
          () => workflow(planService: planService).execute(
            agentIdentity: identity(),
            runKey: runKey,
            triggerTokens: {
              dayAgentDraftingToken(dayId),
              dayAgentPlanningDayToken(dayId),
            },
            threadId: threadId,
          ),
        );

        expect(result.success, isFalse);
        expect(
          conversationRepository.toolResponses.last,
          contains('attentionNeeded'),
        );
        verifyNever(
          () => planService.executeTool(
            agentId: any(named: 'agentId'),
            threadId: any(named: 'threadId'),
            runKey: any(named: 'runKey'),
            toolName: DayAgentToolNames.draftDayPlan,
            args: any(named: 'args'),
            planningConfig: any(named: 'planningConfig'),
            planningSnapshotAt: any(named: 'planningSnapshotAt'),
            planningBaselinePlan: any(named: 'planningBaselinePlan'),
          ),
        );
      });

      test('accepts an exact non-empty baseline echo when selected work is '
          'already represented', () async {
        final planService = MockDayAgentPlanService();
        final baselineBlock = closedBaselineBlock(taskId: 'task-selected');
        final baselinePlan = closedBaselinePlan(baselineBlock);
        stubDraftingPlanContext(
          planService,
          baselinePlan: baselinePlan,
          decidedTasks: const [
            DecidedTaskRef(
              id: 'task-selected',
              title: 'Represented task',
              categoryId: 'work',
            ),
          ],
        );
        stubSuccessfulDraftToolCall(planService);
        conversationRepository.toolCalls = [
          toolCall(
            id: 'draft-call',
            name: DayAgentToolNames.draftDayPlan,
            args: {
              'dayId': dayId,
              'blocks': [closedBaselineBlockArgs(baselineBlock)],
            },
          ),
        ];

        final result = await withClock(
          Clock.fixed(DateTime(2026, 5, 25, 18)),
          () => workflow(planService: planService).execute(
            agentIdentity: identity(),
            runKey: runKey,
            triggerTokens: {
              dayAgentDraftingToken(dayId),
              dayAgentPlanningDayToken(dayId),
            },
            threadId: threadId,
          ),
        );

        expect(result.success, isTrue, reason: result.error);
        verify(
          () => planService.executeTool(
            agentId: agentId,
            threadId: threadId,
            runKey: runKey,
            toolName: DayAgentToolNames.draftDayPlan,
            args: any(named: 'args'),
            planningConfig: any(named: 'planningConfig'),
            planningSnapshotAt: any(named: 'planningSnapshotAt'),
            planningBaselinePlan: baselinePlan,
          ),
        ).called(1);
      });

      test('rejects an exact non-empty baseline echo that omits a decided '
          'capture item', () async {
        final planService = MockDayAgentPlanService();
        final captureService = MockDayAgentCaptureService();
        final baselineBlock = closedBaselineBlock();
        final baselinePlan = closedBaselinePlan(baselineBlock);
        final decidedItem = makeTestParsedItem(
          id: 'parsed-new',
          agentId: agentId,
          captureId: 'capture-1',
          kind: ParsedItemKind.matched,
          title: 'New capture decision',
          categoryId: 'work',
          matchedTaskId: 'task-new',
          createdAt: DateTime(2026, 5, 25, 8),
        );
        stubCaptureContext(captureService);
        when(
          () => captureService.parsedItemsForCapture('capture-1'),
        ).thenAnswer((_) async => [decidedItem]);
        stubDraftingPlanContext(planService, baselinePlan: baselinePlan);
        stubSuccessfulDraftToolCall(planService);
        conversationRepository.toolCalls = [
          toolCall(
            id: 'draft-call',
            name: DayAgentToolNames.draftDayPlan,
            args: {
              'dayId': dayId,
              'blocks': [closedBaselineBlockArgs(baselineBlock)],
            },
          ),
        ];

        final result = await withClock(
          Clock.fixed(DateTime(2026, 5, 25, 18)),
          () =>
              workflow(
                planService: planService,
                captureService: captureService,
              ).execute(
                agentIdentity: identity(),
                runKey: runKey,
                triggerTokens: {
                  dayAgentDraftingToken(dayId),
                  dayAgentPlanningDayToken(dayId),
                  dayAgentCaptureSubmittedToken('capture-1'),
                  dayAgentDecidedCaptureItemToken('parsed-new'),
                },
                threadId: threadId,
              ),
        );

        expect(result.success, isFalse);
        expect(
          conversationRepository.toolResponses.last,
          contains('attentionNeeded'),
        );
        verifyNever(
          () => planService.executeTool(
            agentId: any(named: 'agentId'),
            threadId: any(named: 'threadId'),
            runKey: any(named: 'runKey'),
            toolName: DayAgentToolNames.draftDayPlan,
            args: any(named: 'args'),
            planningConfig: any(named: 'planningConfig'),
            planningSnapshotAt: any(named: 'planningSnapshotAt'),
            planningBaselinePlan: any(named: 'planningBaselinePlan'),
          ),
        );
      });

      test('rejects an empty closed draft that silently omits a binding '
          'commitment', () async {
        final planService = MockDayAgentPlanService();
        final directiveService = MockDayAgentDirectiveService();
        stubDraftingPlanContext(planService);
        stubSuccessfulDraftToolCall(planService);
        when(() => directiveService.directiveForDay(dayId)).thenAnswer(
          (_) async => makeTestDayDirective(
            commitments: const [
              DayDirectiveCommitment(
                id: 'commitment-1',
                source: DayCommitmentSource.userCommitment,
                title: 'Finish release notes',
                minutes: 45,
              ),
            ],
          ),
        );

        final result = await withClock(
          Clock.fixed(DateTime(2026, 5, 25, 18)),
          () =>
              workflow(
                planService: planService,
                directiveService: directiveService,
              ).execute(
                agentIdentity: identity(),
                runKey: runKey,
                triggerTokens: {
                  dayAgentDraftingToken(dayId),
                  dayAgentPlanningDayToken(dayId),
                },
                threadId: threadId,
              ),
        );

        expect(result.success, isFalse);
        expect(
          conversationRepository.toolResponses.last,
          contains('attentionNeeded'),
        );
        verifyNever(
          () => planService.executeTool(
            agentId: any(named: 'agentId'),
            threadId: any(named: 'threadId'),
            runKey: any(named: 'runKey'),
            toolName: DayAgentToolNames.draftDayPlan,
            args: any(named: 'args'),
            planningConfig: any(named: 'planningConfig'),
            planningSnapshotAt: any(named: 'planningSnapshotAt'),
            planningBaselinePlan: any(named: 'planningBaselinePlan'),
          ),
        );
      });

      test('does not treat a commitment title as represented inside a longer '
          'baseline word', () async {
        final planService = MockDayAgentPlanService();
        final directiveService = MockDayAgentDirectiveService();
        final baselineBlock = closedBaselineBlock().copyWith(
          title: 'Planning review',
          reason: 'Review the planning backlog.',
        );
        final baselinePlan = closedBaselinePlan(baselineBlock);
        stubDraftingPlanContext(planService, baselinePlan: baselinePlan);
        stubSuccessfulDraftToolCall(planService);
        when(() => directiveService.directiveForDay(dayId)).thenAnswer(
          (_) async => makeTestDayDirective(
            commitments: const [
              DayDirectiveCommitment(
                id: 'commitment-short-title',
                source: DayCommitmentSource.userCommitment,
                title: 'Plan',
                minutes: 30,
              ),
            ],
          ),
        );
        conversationRepository.toolCalls = [
          toolCall(
            id: 'draft-call',
            name: DayAgentToolNames.draftDayPlan,
            args: {
              'dayId': dayId,
              'blocks': [closedBaselineBlockArgs(baselineBlock)],
            },
          ),
        ];

        final result = await withClock(
          Clock.fixed(DateTime(2026, 5, 25, 18)),
          () =>
              workflow(
                planService: planService,
                directiveService: directiveService,
              ).execute(
                agentIdentity: identity(),
                runKey: runKey,
                triggerTokens: {
                  dayAgentDraftingToken(dayId),
                  dayAgentPlanningDayToken(dayId),
                },
                threadId: threadId,
              ),
        );

        expect(result.success, isFalse);
        expect(
          conversationRepository.toolResponses.last,
          contains('attentionNeeded'),
        );
        verifyNever(
          () => planService.executeTool(
            agentId: any(named: 'agentId'),
            threadId: any(named: 'threadId'),
            runKey: any(named: 'runKey'),
            toolName: DayAgentToolNames.draftDayPlan,
            args: any(named: 'args'),
            planningConfig: any(named: 'planningConfig'),
            planningSnapshotAt: any(named: 'planningSnapshotAt'),
            planningBaselinePlan: any(named: 'planningBaselinePlan'),
          ),
        );
      });

      test('accepts an empty closed draft with a binding commitment after a '
          'successful attention status', () async {
        final planService = MockDayAgentPlanService();
        final directiveService = MockDayAgentDirectiveService();
        stubDraftingPlanContext(planService);
        stubSuccessfulDraftToolCall(planService);
        when(() => directiveService.directiveForDay(dayId)).thenAnswer(
          (_) async => makeTestDayDirective(
            commitments: const [
              DayDirectiveCommitment(
                id: 'commitment-1',
                source: DayCommitmentSource.userCommitment,
                title: 'Finish release notes',
                minutes: 45,
              ),
            ],
          ),
        );
        when(
          () => directiveService.executeTool(
            agentId: agentId,
            toolName: DayAgentToolNames.raiseDayStatus,
            args: any(named: 'args'),
            wakeDayId: dayId,
            runKey: runKey,
            processingJobId: any(named: 'processingJobId'),
            planningConfig: any(named: 'planningConfig'),
          ),
        ).thenAnswer(
          (_) async => DayAgentDirectToolResult.success(const {
            'id': 'day_status:$dayId:event-1',
          }),
        );
        conversationRepository.toolCalls = [
          toolCall(
            id: 'status-call',
            name: DayAgentToolNames.raiseDayStatus,
            args: {
              'dayId': dayId,
              'status': 'attentionNeeded',
              'reasons': ['overCommitted'],
              'note': 'The binding commitment no longer fits.',
            },
          ),
          toolCall(
            id: 'draft-call',
            name: DayAgentToolNames.draftDayPlan,
            args: {'dayId': dayId, 'blocks': <Object?>[]},
          ),
        ];

        final result = await withClock(
          Clock.fixed(DateTime(2026, 5, 25, 18)),
          () =>
              workflow(
                planService: planService,
                directiveService: directiveService,
              ).execute(
                agentIdentity: identity(),
                runKey: runKey,
                triggerTokens: {
                  dayAgentDraftingToken(dayId),
                  dayAgentPlanningDayToken(dayId),
                },
                threadId: threadId,
              ),
        );

        expect(result.success, isTrue, reason: result.error);
        verify(
          () => directiveService.executeTool(
            agentId: agentId,
            toolName: DayAgentToolNames.raiseDayStatus,
            args: any(named: 'args'),
            wakeDayId: dayId,
            runKey: runKey,
            processingJobId: any(named: 'processingJobId'),
            planningConfig: any(named: 'planningConfig'),
          ),
        ).called(1);
        verify(
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
        ).called(1);
      });

      test(
        'forces draft_day_plan when a drafting wake stops without drafting',
        () async {
          final planService = MockDayAgentPlanService();
          stubDraftingPlanContext(planService);
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
          conversationRepository
            ..toolCallsByInvocation = [
              const <ChatCompletionMessageToolCall>[],
              [
                toolCall(
                  id: 'draft-call',
                  name: DayAgentToolNames.draftDayPlan,
                  args: {'dayId': dayId, 'blocks': <Object?>[]},
                ),
              ],
            ]
            ..usageByInvocation = const [
              InferenceUsage(inputTokens: 10, outputTokens: 5),
              InferenceUsage(inputTokens: 3, outputTokens: 2),
            ];

          final result = await execute(
            workflow(planService: planService),
            triggerTokens: {
              dayAgentDraftingToken(dayId),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isTrue);
          expect(conversationRepository.sendMessageCalls, hasLength(2));
          final systemPrompt = conversationRepository.lastSystemMessage!;
          expect(systemPrompt, contains('Drafting rules:'));
          expect(systemPrompt, contains('`draft_day_plan`'));
          expect(systemPrompt, isNot(contains('Capture matching rules:')));
          expect(systemPrompt, isNot(contains('`parse_capture_to_items`')));
          expect(systemPrompt, isNot(contains('Refine rules:')));
          expect(systemPrompt, isNot(contains('`summarize_recent_patterns`')));
          expect(systemPrompt, isNot(contains('Your memory (append-only')));
          expect(
            conversationRepository.sendMessageCalls.first.toolChoice,
            isNull,
          );

          final retryCall = conversationRepository.sendMessageCalls[1];
          expect(
            retryCall.message,
            contains('You did not call `draft_day_plan`'),
          );
          expect(retryCall.tools.map((tool) => tool.function.name), [
            DayAgentToolNames.draftDayPlan,
          ]);
          retryCall.toolChoice!.map(
            mode: (_) => fail('Expected named tool choice, got mode.'),
            tool: (named) {
              expect(named.value.function.name, DayAgentToolNames.draftDayPlan);
            },
          );
          verify(
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
          ).called(1);

          final usage = upsertedEntities
              .whereType<WakeTokenUsageEntity>()
              .single;
          expect(usage.inputTokens, 13);
          expect(usage.outputTokens, 7);
        },
      );

      test(
        'adopts the forced-retry usage when the first call returns none',
        () async {
          // Covers the null-left branch of the usage merge: when the initial
          // sendMessage reports no usage, the forced draft_day_plan retry's
          // usage is adopted verbatim (no merge against a null left operand).
          final planService = MockDayAgentPlanService();
          stubDraftingPlanContext(planService);
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
          conversationRepository
            ..toolCallsByInvocation = [
              const <ChatCompletionMessageToolCall>[],
              [
                toolCall(
                  id: 'draft-call',
                  name: DayAgentToolNames.draftDayPlan,
                  args: {'dayId': dayId, 'blocks': <Object?>[]},
                ),
              ],
            ]
            ..usageByInvocation = const [
              null,
              InferenceUsage(inputTokens: 3, outputTokens: 2),
            ];

          final result = await execute(
            workflow(planService: planService),
            triggerTokens: {dayAgentDraftingToken(dayId), dayId},
          );

          expect(result.success, isTrue);
          expect(conversationRepository.sendMessageCalls, hasLength(2));
          final usage = upsertedEntities
              .whereType<WakeTokenUsageEntity>()
              .single;
          expect(usage.inputTokens, 3);
          expect(usage.outputTokens, 2);
        },
      );

      test(
        'does not force draft_day_plan on reconcile-only capture wakes',
        () async {
          final planService = MockDayAgentPlanService();
          conversationRepository.toolCallsByInvocation = [
            const <ChatCompletionMessageToolCall>[],
          ];

          final result = await execute(
            workflow(planService: planService),
            triggerTokens: {
              dayAgentCaptureSubmittedToken('capture-1'),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isTrue);
          expect(conversationRepository.sendMessageCalls, hasLength(1));
          expect(
            conversationRepository.sendMessageCalls.single.toolChoice,
            isNull,
          );
          verifyNever(
            () => planService.draftPlanForDay(
              agentId: any(named: 'agentId'),
              dayId: any(named: 'dayId'),
            ),
          );
        },
      );

      test(
        'fails the wake when the forced draft_day_plan call is rejected',
        () async {
          final planService = MockDayAgentPlanService();
          stubDraftingPlanContext(planService);
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
            (_) async => DayAgentDirectToolResult.failure(
              'draft_day_plan requires at least one block',
            ),
          );
          conversationRepository.toolCallsByInvocation = [
            const <ChatCompletionMessageToolCall>[],
            [
              toolCall(
                id: 'draft-call',
                name: DayAgentToolNames.draftDayPlan,
                args: {'dayId': dayId, 'blocks': <Object?>[]},
              ),
            ],
          ];

          final result = await execute(
            workflow(planService: planService),
            triggerTokens: {
              dayAgentDraftingToken(dayId),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isFalse);
          expect(result.error, contains('draft_day_plan'));
          verify(
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
          ).called(1);
        },
      );

      test(
        'fails the wake when the forced retry still omits draft_day_plan',
        () async {
          final planService = MockDayAgentPlanService();
          stubDraftingPlanContext(planService);
          conversationRepository.toolCallsByInvocation = [
            const <ChatCompletionMessageToolCall>[],
            const <ChatCompletionMessageToolCall>[],
          ];

          final result = await execute(
            workflow(planService: planService),
            triggerTokens: {
              dayAgentDraftingToken(dayId),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isFalse);
          expect(result.error, contains('draft_day_plan'));
          expect(conversationRepository.sendMessageCalls, hasLength(2));
          expect(
            conversationRepository.sendMessageCalls[1].toolChoice,
            isNotNull,
          );
          final failureState = upsertedEntities
              .whereType<AgentStateEntity>()
              .last;
          expect(failureState.consecutiveFailureCount, 1);
          verifyNever(
            () => planService.executeTool(
              agentId: any(named: 'agentId'),
              threadId: any(named: 'threadId'),
              runKey: any(named: 'runKey'),
              toolName: DayAgentToolNames.draftDayPlan,
              args: any(named: 'args'),
              planningConfig: any(named: 'planningConfig'),
              planningSnapshotAt: any(named: 'planningSnapshotAt'),
              planningBaselinePlan: any(named: 'planningBaselinePlan'),
            ),
          );
        },
      );
    });
  });
}
