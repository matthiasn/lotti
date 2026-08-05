import 'day_agent_workflow_test_harness.dart';

void main() {
  configureDayAgentWorkflowTestSuite();

  // Owns capture, drafting context, prompt ordering, and planning-window behavior.
  group('DayAgentWorkflow', () {
    test(
      'records observations, schedules wake, and persists wake output',
      () async {
        final observationPayload = makeTestMessagePayload(
          id: 'payload-old-observation',
          agentId: agentId,
          createdAt: now.subtract(const Duration(hours: 2)),
          content: const {'text': 'Earlier wake was too late.'},
        );
        final observationMessage = makeTestMessage(
          id: 'old-observation',
          agentId: agentId,
          threadId: 'old-thread',
          kind: AgentMessageKind.observation,
          createdAt: now.subtract(const Duration(hours: 2)),
          contentEntryId: observationPayload.id,
          metadata: const AgentMessageMetadata(runKey: 'old-run'),
        );
        currentState = state(
          toolCounterByKey: const {
            'day_agent_set_next_wake:2026-05-24': 4,
            'unrelated_tool:host-a': 9,
          },
        );
        conversationRepository
          ..toolCalls = [
            toolCall(
              name: DayAgentToolNames.recordObservations,
              args: {
                'observations': [
                  {
                    'text': 'Morning planning wake was useful.',
                    'priority': 'notable',
                    'category': 'operational',
                  },
                ],
              },
            ),
            toolCall(
              id: 'call-set-wake',
              name: DayAgentToolNames.setNextWake,
              args: {
                'at': '2026-05-25T08:30:00',
                'reason': 'Check whether capture has started.',
              },
            ),
          ]
          ..finalResponse = 'Captured the morning planning state.'
          ..usage = const InferenceUsage(inputTokens: 11, outputTokens: 7);
        when(
          () => repository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [observationMessage]);
        when(
          () => repository.getEntitiesByIds({observationPayload.id}),
        ).thenAnswer((_) async => {observationPayload.id: observationPayload});

        final result = await execute(workflow());

        expect(result.success, isTrue);
        expect(conversationRepository.deletedConversationCount, 1);
        expect(
          conversationRepository.lastTools.map((tool) => tool.function.name),
          containsAll([
            DayAgentToolNames.recordObservations,
            DayAgentToolNames.setNextWake,
          ]),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('General day-agent directive.'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('Report day-agent directive.'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('current_local_time'),
        );

        final userPayload = sentPrompt();
        expect(userPayload.section('day_id'), dayId);
        expect(userPayload.section('plan_date'), '2026-05-25T00:00:00.000');
        expect(
          userPayload.section('current_local_time'),
          '2026-05-25T08:00:00.000',
        );
        // Volatile wall-clock must be the trailing section so the rest of the
        // payload stays a stable prefix across wakes (prefix/KV-cache reuse).
        expect(userPayload.tagsInOrder.last, 'current_local_time');
        expect(userPayload.json('trigger_tokens'), [
          dayAgentPlanningDayToken(dayId),
        ]);
        expect(userPayload.json('recent_observations'), [
          {
            'createdAt': '2026-05-25T06:00:00.000',
            'text': 'Earlier wake was too late.',
          },
        ]);

        // set_next_wake persists a day-scoped ScheduledWakeEntity record
        // (ADR 0022 Decision 12) rather than the clobberable state slot.
        final scheduledRecord = upsertedEntities
            .whereType<ScheduledWakeEntity>()
            .single;
        expect(scheduledRecord.scheduledAt, DateTime(2026, 5, 25, 8, 30));
        expect(scheduledRecord.status, ScheduledWakeStatus.pending);
        expect(scheduledRecord.workspaceKey, dayAgentWorkspaceKey(dayId));
        expect(
          scheduledRecord.triggerTokens,
          contains(dayAgentPlanningDayToken(dayId)),
        );
        expect(
          scheduledRecord.id,
          scheduledWakeRecordId(
            agentId,
            workspaceKey: dayAgentWorkspaceKey(dayId),
          ),
        );
        // No state carries scheduledWakeAt anymore; the cap counter is
        // re-keyed by (dayId, date) and the stale prior-date entry is GC'd.
        final scheduledState = upsertedEntities
            .whereType<AgentStateEntity>()
            .firstWhere(
              (state) => state.toolCounterByKey.keys.any(
                (k) => k.startsWith('day_agent_set_next_wake:'),
              ),
            );
        expect(scheduledState.scheduledWakeAt, isNull);
        expect(scheduledState.toolCounterByKey, {
          'unrelated_tool:host-a': 9,
          'day_agent_set_next_wake:$dayId:2026-05-25': 1,
        });
        expect(scheduledState.processedCounterByHost, isEmpty);

        final finalState = upsertedEntities.whereType<AgentStateEntity>().last;
        expect(finalState.lastWakeAt, now);
        expect(finalState.consecutiveFailureCount, 0);
        expect(finalState.wakeCounter.value, 1);
        // The completed wake event-sources lastWakeAt (PR 4, B2).
        expect(capturedMilestones(syncService), [AgentMilestone.wakeCompleted]);

        final payloads = upsertedEntities
            .whereType<AgentMessagePayloadEntity>();
        expect(
          payloads.map((payload) => payload.content['text']),
          containsAll([
            contains('Morning planning wake was useful.'),
            'Captured the morning planning state.',
          ]),
        );
        expect(
          upsertedEntities.whereType<WakeTokenUsageEntity>().single.modelId,
          'models/day',
        );
        expect(changedTokens, [agentId, agentId, dayId]);
      },
    );

    test('set_next_wake normalizes a Z-suffixed time to naive-local so the due '
        'query orders it consistently against a local now', () async {
      currentState = state();
      conversationRepository
        ..toolCalls = [
          toolCall(
            id: 'call-set-wake-utc',
            name: DayAgentToolNames.setNextWake,
            args: {
              // A UTC-suffixed instant, two days out so it clears the minimum
              // lead time regardless of the test machine's timezone.
              'at': '2026-05-27T12:00:00Z',
              'reason': 'Pre-warm the next morning.',
            },
          ),
        ]
        ..finalResponse = 'Scheduled.'
        ..usage = const InferenceUsage(inputTokens: 5, outputTokens: 3);

      final result = await execute(workflow());

      expect(result.success, isTrue);
      final rec = upsertedEntities.whereType<ScheduledWakeEntity>().single;
      // Persisted naive-local (no `Z`), so getDueScheduledWakeRecords'
      // lexicographic compare against a naive-local `now` stays correct —
      // and identical across devices in different timezones.
      expect(rec.scheduledAt.isUtc, isFalse);
      expect(rec.scheduledAt, DateTime.parse('2026-05-27T12:00:00Z').toLocal());
    });

    test(
      'propagates the resolved model geminiThinkingMode to the wrapper',
      () async {
        when(
          () => aiConfigRepository.getConfigById('profile-day'),
        ).thenAnswer((_) async => testInferenceProfile(id: 'profile-day'));
        when(
          () => aiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => [
            testAiModel(
              id: 'gemini-flash',
              inferenceProviderId: 'provider-day',
            ),
          ],
        );
        conversationRepository.finalResponse = 'Day-agent wake completed.';

        final result = await execute(workflow());

        expect(result.success, isTrue);
        expect(
          conversationRepository.sendMessageCalls.single.model,
          'models/gemini-3-flash-preview',
        );
        final inferenceRepo =
            conversationRepository.sendMessageCalls.single.inferenceRepo;
        expect(inferenceRepo, isA<DayAgentTimeoutInferenceRepository>());
        final bounded = inferenceRepo as DayAgentTimeoutInferenceRepository;
        expect(bounded.wakeKind, DayAgentWakeKind.general);
        expect(bounded.timeout, const Duration(seconds: 60));
        expect(
          bounded.delegate,
          isA<DayAgentOutputBudgetInferenceRepository>(),
        );
        final outputBudget =
            bounded.delegate as DayAgentOutputBudgetInferenceRepository;
        expect(outputBudget.wakeKind, DayAgentWakeKind.general);
        expect(outputBudget.maxCompletionTokens, 4096);
        expect(outputBudget.delegate, isA<CloudInferenceWrapper>());
        final wrapper = outputBudget.delegate as CloudInferenceWrapper;
        // testAiModel defaults to AiConfigModel.geminiThinkingMode == low.
        expect(wrapper.geminiThinkingMode, GeminiThinkingMode.low);

        // No AiInteractionCapture is registered, so the consumption gate
        // stays closed and no owner ids are forwarded to sendMessage.
        final call = conversationRepository.sendMessageCalls.single;
        expect(call.consumptionAgentId, isNull);
        expect(call.consumptionWakeRunKey, isNull);
        expect(call.consumptionThreadId, isNull);
      },
    );

    test('passes consumption owner ids to sendMessage when an '
        'AiInteractionCapture is registered', () async {
      getIt.registerSingleton<AiInteractionCapture>(MockAiInteractionCapture());
      addTearDown(() {
        if (getIt.isRegistered<AiInteractionCapture>()) {
          getIt.unregister<AiInteractionCapture>();
        }
      });
      conversationRepository.finalResponse = 'Day-agent wake completed.';

      final result = await execute(workflow());

      expect(result.success, isTrue);
      // Day agents are day-level: only agent/run/thread ownership is
      // attributed (no per-task or per-category owner).
      final call = conversationRepository.sendMessageCalls.single;
      expect(call.consumptionAgentId, agentId);
      expect(call.consumptionWakeRunKey, runKey);
      expect(call.consumptionThreadId, threadId);
    });

    test('includes capture context for capture-submitted wakes', () async {
      final capture = makeTestCapture(
        id: 'capture-1',
        agentId: agentId,
        transcript: 'Prep demo and buy milk',
        capturedAt: DateTime(2026, 5, 25, 7, 45),
        createdAt: DateTime(2026, 5, 25, 7, 45),
        audioRef: 'audio-1',
      );
      final captureService = MockDayAgentCaptureService();
      when(
        () => captureService.getCapture('capture-1'),
      ).thenAnswer((_) async => capture);
      when(
        () => captureService.buildTaskCorpusSnapshot(
          allowedCategoryIds: const <String>{},
          day: DateTime(2026, 5, 25),
          dependencyResolver: any(named: 'dependencyResolver'),
        ),
      ).thenAnswer(
        (_) async => const [
          {
            'taskId': 'task-1',
            'title': 'Prep demo',
            'status': 'OPEN',
            'categoryId': 'work',
            'due': null,
            'estimateMinutes': 45,
            'priority': 'P2',
          },
        ],
      );
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
                'title': 'Prep demo',
                'categoryId': 'work',
                'confidenceScore': 0.4,
              },
            ],
          },
        ),
      ];

      final result = await execute(
        workflow(captureService: captureService),
        triggerTokens: {
          dayAgentCaptureSubmittedToken('capture-1'),
          dayAgentPlanningDayToken(dayId),
        },
      );

      expect(result.success, isTrue);
      expectCanonicalSectionOrder(sentPrompt());
      final capturePayload =
          sentPrompt().json('capture')! as Map<String, dynamic>;
      expect(capturePayload['captureId'], 'capture-1');
      expect(capturePayload['transcript'], 'Prep demo and buy milk');
      expect(capturePayload['audioRef'], 'audio-1');
      expect(capturePayload['taskCorpus'], [
        {
          'taskId': 'task-1',
          'title': 'Prep demo',
          'status': 'OPEN',
          'categoryId': 'work',
          'due': null,
          'estimateMinutes': 45,
          'priority': 'P2',
        },
      ]);
      final systemPrompt = conversationRepository.lastSystemMessage!;
      expect(systemPrompt, contains('Capture matching rules:'));
      expect(systemPrompt, contains('`parse_capture_to_items`'));
      expect(systemPrompt, isNot(contains('Drafting rules:')));
      expect(systemPrompt, isNot(contains('`draft_day_plan`')));
      expect(systemPrompt, isNot(contains('Refine rules:')));
      expect(systemPrompt, isNot(contains('Your memory (append-only')));
    });

    group('capture wake parse enforcement', () {
      test('forces parse_capture_to_items when a capture wake stops without '
          'parsing', () async {
        final captureService = MockDayAgentCaptureService();
        stubCaptureContext(captureService);
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
        conversationRepository
          ..toolCallsByInvocation = [
            const <ChatCompletionMessageToolCall>[],
            [
              toolCall(
                id: 'parse-call',
                name: DayAgentToolNames.parseCaptureToItems,
                args: const {
                  'captureId': 'capture-1',
                  'items': [
                    {
                      'kind': 'newTask',
                      'title': 'Prep demo',
                      'categoryId': 'work',
                      'confidenceScore': 0.4,
                    },
                  ],
                },
              ),
            ],
          ]
          ..usageByInvocation = const [
            InferenceUsage(inputTokens: 10, outputTokens: 5),
            InferenceUsage(inputTokens: 3, outputTokens: 2),
          ];

        final result = await execute(
          workflow(captureService: captureService),
          triggerTokens: {
            dayAgentCaptureSubmittedToken('capture-1'),
            dayAgentPlanningDayToken(dayId),
          },
        );

        expect(result.success, isTrue);
        expect(conversationRepository.sendMessageCalls, hasLength(2));
        final systemPrompt = conversationRepository.lastSystemMessage!;
        expect(systemPrompt, contains('Capture matching rules:'));
        expect(systemPrompt, contains('`parse_capture_to_items`'));
        expect(systemPrompt, isNot(contains('Drafting rules:')));
        expect(systemPrompt, isNot(contains('`draft_day_plan`')));
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
          contains('You did not call `parse_capture_to_items`'),
        );
        expect(retryCall.message, contains('capture `capture-1`'));
        expect(retryCall.tools.map((tool) => tool.function.name), [
          DayAgentToolNames.parseCaptureToItems,
        ]);
        retryCall.toolChoice!.map(
          mode: (_) => fail('Expected named tool choice, got mode.'),
          tool: (named) {
            expect(
              named.value.function.name,
              DayAgentToolNames.parseCaptureToItems,
            );
          },
        );

        final args =
            verify(
                  () => captureService.executeTool(
                    agentId: agentId,
                    threadId: threadId,
                    runKey: runKey,
                    toolName: DayAgentToolNames.parseCaptureToItems,
                    args: captureAny(named: 'args'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(args['captureId'], 'capture-1');
        expect(args['items'], isA<List<Object?>>());

        final usage = upsertedEntities.whereType<WakeTokenUsageEntity>().single;
        expect(usage.inputTokens, 13);
        expect(usage.outputTokens, 7);
      });

      test(
        'fails the wake when the forced retry still omits parsing',
        () async {
          final captureService = MockDayAgentCaptureService();
          stubCaptureContext(captureService);
          conversationRepository.toolCallsByInvocation = [
            const <ChatCompletionMessageToolCall>[],
            const <ChatCompletionMessageToolCall>[],
          ];

          final result = await execute(
            workflow(captureService: captureService),
            triggerTokens: {
              dayAgentCaptureSubmittedToken('capture-1'),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isFalse);
          expect(result.error, contains('parse_capture_to_items'));
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
            () => captureService.executeTool(
              agentId: any(named: 'agentId'),
              threadId: any(named: 'threadId'),
              runKey: any(named: 'runKey'),
              toolName: DayAgentToolNames.parseCaptureToItems,
              args: any(named: 'args'),
            ),
          );
        },
      );

      test(
        'does not force parsing when the submitted capture is unavailable',
        () async {
          final captureService = MockDayAgentCaptureService();
          when(
            () => captureService.getCapture('capture-1'),
          ).thenAnswer((_) async => null);

          final result = await execute(
            workflow(captureService: captureService),
            triggerTokens: {
              dayAgentCaptureSubmittedToken('capture-1'),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isTrue);
          expect(conversationRepository.sendMessageCalls, hasLength(1));
          expect(sentPrompt().has('capture'), isFalse);
          verify(() => captureService.getCapture('capture-1')).called(1);
          verifyNever(
            () => captureService.executeTool(
              agentId: any(named: 'agentId'),
              threadId: any(named: 'threadId'),
              runKey: any(named: 'runKey'),
              toolName: DayAgentToolNames.parseCaptureToItems,
              args: any(named: 'args'),
            ),
          );
        },
      );

      test('accepts an explicit empty parse without forcing a retry', () async {
        final captureService = MockDayAgentCaptureService();
        stubCaptureContext(captureService);
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
            'items': <Object?>[],
          }),
        );
        conversationRepository.toolCallsByInvocation = [
          [
            toolCall(
              id: 'parse-call',
              name: DayAgentToolNames.parseCaptureToItems,
              args: const {'captureId': 'capture-1', 'items': <Object?>[]},
            ),
          ],
        ];

        final result = await execute(
          workflow(captureService: captureService),
          triggerTokens: {
            dayAgentCaptureSubmittedToken('capture-1'),
            dayAgentPlanningDayToken(dayId),
          },
        );

        expect(result.success, isTrue);
        expect(conversationRepository.sendMessageCalls, hasLength(1));
        verify(
          () => captureService.executeTool(
            agentId: agentId,
            threadId: threadId,
            runKey: runKey,
            toolName: DayAgentToolNames.parseCaptureToItems,
            args: any(named: 'args'),
          ),
        ).called(1);
      });
    });

    test('states a planning floor the model can build on for today', () async {
      final planService = MockDayAgentPlanService();
      stubDraftingPlanContext(planService);
      stubSuccessfulDraftToolCall(planService);

      final result = await withClock(
        // Mid-afternoon on the plan day, a few milliseconds past the minute —
        // the shape that had every sampled model start at 15:00 and be
        // rejected for it.
        Clock.fixed(DateTime(2026, 5, 25, 15, 0, 0, 5, 877)),
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
      final window =
          sentPrompt().json('planning_window')! as Map<String, dynamic>;
      expect(window['earliestStart'], '2026-05-25T15:05:00.000');
      expect(window.containsKey('closed'), isFalse);
    });

    test(
      'captures the planning snapshot after pre-prompt context awaits',
      () async {
        final planService = MockDayAgentPlanService();
        final knowledgeService = MockDayAgentKnowledgeService();
        final weekContextService = MockDayAgentWeekContextService();
        var currentTime = DateTime(2026, 5, 25, 16, 50);
        when(
          () => planService.draftPlanForDay(agentId: agentId, dayId: dayId),
        ).thenAnswer((_) async {
          // Simulate a slow context read crossing the final usable slot before
          // the prompt is rendered.
          currentTime = DateTime(2026, 5, 25, 16, 58);
          return null;
        });
        when(
          () => planService.hydrateDecidedTasks(
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            explicitTaskIds: any(named: 'explicitTaskIds'),
            parsedItems: any(named: 'parsedItems'),
            dependencyResolver: any(named: 'dependencyResolver'),
          ),
        ).thenAnswer((_) async => const []);
        when(
          () => knowledgeService.activeFor(dailyOsPlannerAgentId),
        ).thenAnswer(
          (_) async => [
            AgentDomainEntity.plannerKnowledge(
                  id: 'knowledge-crossed-boundary',
                  agentId: dailyOsPlannerAgentId,
                  key: 'late-day-check',
                  hook: 're-check late-day assumptions',
                  statementText: 'Confirm this still applies before planning.',
                  source: KnowledgeSource.userStated,
                  status: KnowledgeStatus.confirmed,
                  createdAt: DateTime(2026, 5, 20),
                  updatedAt: DateTime(2026, 5, 20),
                  reviewAfter: DateTime(2026, 5, 25, 16, 55),
                  vectorClock: null,
                )
                as PlannerKnowledgeEntity,
          ],
        );
        when(
          () => weekContextService.buildForDay(
            planDate: any(named: 'planDate'),
            now: any(named: 'now'),
          ),
        ).thenAnswer((_) async => null);
        stubSuccessfulDraftToolCall(planService);

        final result = await withClock(
          Clock(() => currentTime),
          () =>
              workflow(
                planService: planService,
                knowledgeService: knowledgeService,
                weekContextService: weekContextService,
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
        final window =
            sentPrompt().json('planning_window')! as Map<String, dynamic>;
        expect(window, {'closed': true});
        expect(
          sentPrompt().section('current_local_time'),
          '2026-05-25T16:58:00.000',
        );
        expect(
          sentPrompt().section('knowledge_statements'),
          contains('please re-confirm'),
        );
        verify(
          () => weekContextService.buildForDay(
            planDate: DateTime(2026, 5, 25),
            now: currentTime,
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
            planningSnapshotAt: currentTime,
            // The slow read returned no baseline.
            // ignore: avoid_redundant_argument_values
            planningBaselinePlan: null,
          ),
        ).called(1);
      },
    );

    test('rebuilds time-sensitive context when its own await crosses the '
        'planning boundary', () async {
      final planService = MockDayAgentPlanService();
      final weekContextService = MockDayAgentWeekContextService();
      var currentTime = DateTime(2026, 5, 25, 16, 50);
      var weekContextCalls = 0;
      stubDraftingPlanContext(planService);
      when(
        () => weekContextService.buildForDay(
          planDate: any(named: 'planDate'),
          now: any(named: 'now'),
        ),
      ).thenAnswer((_) async {
        weekContextCalls++;
        if (weekContextCalls == 1) {
          currentTime = DateTime(2026, 5, 25, 17, 1);
        }
        return null;
      });
      stubSuccessfulDraftToolCall(planService);

      final result = await withClock(
        Clock(() => currentTime),
        () =>
            workflow(
              planService: planService,
              weekContextService: weekContextService,
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
      expect(sentPrompt().json('planning_window'), {'closed': true});
      expect(
        sentPrompt().section('current_local_time'),
        '2026-05-25T17:01:00.000',
      );
      final contextSnapshots = verify(
        () => weekContextService.buildForDay(
          planDate: DateTime(2026, 5, 25),
          now: captureAny(named: 'now'),
        ),
      ).captured.cast<DateTime>();
      expect(contextSnapshots, [
        DateTime(2026, 5, 25, 16, 50),
        DateTime(2026, 5, 25, 17, 1),
      ]);
      verify(
        () => planService.executeTool(
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          toolName: DayAgentToolNames.draftDayPlan,
          args: any(named: 'args'),
          planningConfig: any(named: 'planningConfig'),
          planningSnapshotAt: currentTime,
          // ignore: avoid_redundant_argument_values
          planningBaselinePlan: null,
        ),
      ).called(1);
    });

    test('rebuilds and replaces the durable prompt when a pre-inference await '
        'crosses the planning boundary', () async {
      final planService = MockDayAgentPlanService();
      final weekContextService = MockDayAgentWeekContextService();
      var currentTime = DateTime(2026, 5, 25, 16, 50);
      stubDraftingPlanContext(planService);
      when(
        () => weekContextService.buildForDay(
          planDate: any(named: 'planDate'),
          now: any(named: 'now'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => repository.updateWakeRunTemplate(
          any(),
          any(),
          any(),
          resolvedModelId: any(named: 'resolvedModelId'),
          soulId: any(named: 'soulId'),
          soulVersionId: any(named: 'soulVersionId'),
        ),
      ).thenAnswer((_) async {
        currentTime = DateTime(2026, 5, 25, 17, 1);
      });
      stubSuccessfulDraftToolCall(planService);

      final result = await withClock(
        Clock(() => currentTime),
        () =>
            workflow(
              planService: planService,
              weekContextService: weekContextService,
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
      expect(sentPrompt().json('planning_window'), {'closed': true});
      expect(
        sentPrompt().section('current_local_time'),
        '2026-05-25T17:01:00.000',
      );
      final contextSnapshots = verify(
        () => weekContextService.buildForDay(
          planDate: DateTime(2026, 5, 25),
          now: captureAny(named: 'now'),
        ),
      ).captured.cast<DateTime>();
      expect(contextSnapshots, [
        DateTime(2026, 5, 25, 16, 50),
        DateTime(2026, 5, 25, 17, 1),
      ]);
      final userMessages = upsertedEntities
          .whereType<AgentMessageEntity>()
          .where((entity) => entity.kind == AgentMessageKind.user)
          .toList();
      final userPayloads = upsertedEntities
          .whereType<AgentMessagePayloadEntity>()
          .where(
            (entity) =>
                entity.content.containsKey('text') ||
                entity.content.containsKey('promptRecordVersion'),
          )
          .toList();
      expect(userMessages, hasLength(2));
      expect(userMessages.map((entity) => entity.id).toSet(), hasLength(1));
      expect(userPayloads, hasLength(2));
      expect(userPayloads.map((entity) => entity.id).toSet(), hasLength(1));
      verify(
        () => planService.executeTool(
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          toolName: DayAgentToolNames.draftDayPlan,
          args: any(named: 'args'),
          planningConfig: any(named: 'planningConfig'),
          planningSnapshotAt: currentTime,
          // ignore: avoid_redundant_argument_values
          planningBaselinePlan: null,
        ),
      ).called(1);
    });

    test('states the floor on a wake that builds no mode context', () async {
      // A scheduled planning_day wake builds neither drafting nor refine
      // context, yet draft_day_plan stays exposed and the writer still guards
      // it. Keying this on the mode sections left those wakes deriving the
      // threshold from the raw instant — the original bug.
      final result = await withClock(
        Clock.fixed(DateTime(2026, 5, 25, 15, 0, 0, 5, 877)),
        () => workflow().execute(
          agentIdentity: identity(),
          runKey: runKey,
          triggerTokens: {dayAgentPlanningDayToken(dayId)},
          threadId: threadId,
        ),
      );

      expect(result.success, isTrue, reason: result.error);
      final window =
          sentPrompt().json('planning_window')! as Map<String, dynamic>;
      expect(window['earliestStart'], '2026-05-25T15:05:00.000');
    });

    test('states the working minutes the day actually has left', () async {
      final result = await withClock(
        Clock.fixed(DateTime(2026, 5, 25, 15)),
        () => workflow().execute(
          agentIdentity: identity(),
          runKey: runKey,
          triggerTokens: {dayAgentPlanningDayToken(dayId)},
          threadId: threadId,
        ),
      );

      expect(result.success, isTrue, reason: result.error);
      final window =
          sentPrompt().json('planning_window')! as Map<String, dynamic>;
      // 15:05 to 17:00, not the 480 of capacity the planning defaults carry.
      // Deriving that gap is what models were getting wrong.
      expect(window['availableMinutes'], 115);
      expect(window['earliestStart'], '2026-05-25T15:05:00.000');
      expect(
        conversationRepository.lastSystemMessage,
        contains('availableMinutes'),
      );
      expect(
        conversationRepository.lastSystemMessage,
        contains('unsized, not free'),
      );
    });

    test('a refine wake budgets against the plan it is editing', () async {
      // propose_plan_diff applies changes on top of an existing plan, so its
      // budget is what that plan has left. Advertising a fresh day here told
      // the model another 300 minutes would fit into a 360-minute plan that
      // already held 300.
      final planService = MockDayAgentPlanService();
      when(
        () => planService.draftPlanForDay(agentId: agentId, dayId: dayId),
      ).thenAnswer(
        (_) async => makeTestDayPlan(
          agentId: agentId,
          planDate: DateTime(2026, 5, 25),
          data: DayPlanData(
            planDate: DateTime(2026, 5, 25),
            status: const DayPlanStatus.draft(),
            plannedBlocks: [
              PlannedBlock(
                id: 'block-1',
                categoryId: 'work',
                startTime: DateTime(2026, 5, 25, 9),
                endTime: DateTime(2026, 5, 25, 11),
                title: 'Deep work',
                reason: 'morning',
              ),
            ],
          ),
          capacityMinutes: 360,
          scheduledMinutes: 120,
          createdAt: DateTime(2026, 5, 24, 20),
          updatedAt: DateTime(2026, 5, 24, 20),
        ),
      );

      final result = await withClock(
        Clock.fixed(DateTime(2026, 5, 24, 20)),
        () => workflow(planService: planService).execute(
          agentIdentity: identity(),
          runKey: runKey,
          triggerTokens: {
            dayAgentRefineToken(dayId),
            dayAgentPlanningDayToken(dayId),
          },
          threadId: threadId,
        ),
      );

      expect(result.success, isTrue, reason: result.error);
      final window =
          sentPrompt().json('planning_window')! as Map<String, dynamic>;
      // The two facts a diff needs, not a single "available" number: dropping
      // a 180-minute block to add another is net zero, and reading that
      // against the unused remainder alone would report a conflict that does
      // not exist.
      expect(window['capacityMinutes'], 360);
      expect(window['scheduledMinutes'], 120);
      // Drafted the evening before, so no clock floor applies and the full
      // working day is still ahead. The refine fields sit *beside* the
      // temporal ones rather than replacing them.
      expect(window.containsKey('earliestStart'), isFalse);
      expect(window['availableMinutes'], 480);
    });

    test(
      'a same-day refine keeps the clock bounds beside its capacity',
      () async {
        // proposePlanDiff enforces the same past-start guard as drafting, so
        // dropping the temporal fields let a 480-minute baseline advertise room
        // for a 240-minute addition at 15:00 with 115 working minutes left.
        final planService = MockDayAgentPlanService();
        when(
          () => planService.draftPlanForDay(agentId: agentId, dayId: dayId),
        ).thenAnswer(
          (_) async => makeTestDayPlan(
            agentId: agentId,
            planDate: DateTime(2026, 5, 25),
            data: DayPlanData(
              planDate: DateTime(2026, 5, 25),
              status: const DayPlanStatus.draft(),
              plannedBlocks: [
                PlannedBlock(
                  id: 'block-1',
                  categoryId: 'work',
                  startTime: DateTime(2026, 5, 25, 9),
                  endTime: DateTime(2026, 5, 25, 11),
                  title: 'Deep work',
                  reason: 'morning',
                ),
              ],
            ),
            // Matches the config default, and stated so the test reads as a
            // whole-day baseline rather than an accident.
            // ignore: avoid_redundant_argument_values
            capacityMinutes: 480,
            scheduledMinutes: 120,
            createdAt: DateTime(2026, 5, 25, 8),
            updatedAt: DateTime(2026, 5, 25, 8),
          ),
        );

        final result = await withClock(
          Clock.fixed(DateTime(2026, 5, 25, 15)),
          () => workflow(planService: planService).execute(
            agentIdentity: identity(),
            runKey: runKey,
            triggerTokens: {
              dayAgentRefineToken(dayId),
              dayAgentPlanningDayToken(dayId),
            },
            threadId: threadId,
          ),
        );

        expect(result.success, isTrue, reason: result.error);
        final window =
            sentPrompt().json('planning_window')! as Map<String, dynamic>;
        expect(window['capacityMinutes'], 480);
        expect(window['scheduledMinutes'], 120);
        expect(window['earliestStart'], '2026-05-25T15:05:00.000');
        expect(window['availableMinutes'], 115);
      },
    );

    test(
      'refine occupancy is recomputed from blocks, not the stored total',
      () async {
        // The denormalized `scheduledMinutes` can drift; the projection and the
        // agenda view both recompute for that reason. A stale zero would expose
        // the full capacity and let a diff double-book the day.
        final planService = MockDayAgentPlanService();
        when(
          () => planService.draftPlanForDay(agentId: agentId, dayId: dayId),
        ).thenAnswer(
          (_) async => makeTestDayPlan(
            agentId: agentId,
            planDate: DateTime(2026, 5, 25),
            data: DayPlanData(
              planDate: DateTime(2026, 5, 25),
              status: const DayPlanStatus.draft(),
              plannedBlocks: [
                PlannedBlock(
                  id: 'block-1',
                  categoryId: 'work',
                  startTime: DateTime(2026, 5, 25, 9),
                  endTime: DateTime(2026, 5, 25, 11),
                  title: 'Deep work',
                  reason: 'morning',
                ),
              ],
            ),
            capacityMinutes: 360,
            // The stale value is the subject of the test, not an oversight.
            // ignore: avoid_redundant_argument_values
            scheduledMinutes: 0,
            createdAt: DateTime(2026, 5, 24, 20),
            updatedAt: DateTime(2026, 5, 24, 20),
          ),
        );

        final result = await withClock(
          Clock.fixed(DateTime(2026, 5, 24, 20)),
          () => workflow(planService: planService).execute(
            agentIdentity: identity(),
            runKey: runKey,
            triggerTokens: {
              dayAgentRefineToken(dayId),
              dayAgentPlanningDayToken(dayId),
            },
            threadId: threadId,
          ),
        );

        expect(result.success, isTrue, reason: result.error);
        final window =
            sentPrompt().json('planning_window')! as Map<String, dynamic>;
        expect(window['scheduledMinutes'], 120);
      },
    );

    test(
      'a working day already over reads as closed, not zero minutes',
      () async {
        // Pairing earliestStart 18:05 with availableMinutes 0 left a fresh draft
        // no coherent move: the rules forbid running past working hours, and
        // there is no time left inside them.
        final result = await withClock(
          Clock.fixed(DateTime(2026, 5, 25, 18)),
          () => workflow().execute(
            agentIdentity: identity(),
            runKey: runKey,
            triggerTokens: {dayAgentPlanningDayToken(dayId)},
            threadId: threadId,
          ),
        );

        expect(result.success, isTrue, reason: result.error);
        final window =
            sentPrompt().json('planning_window')! as Map<String, dynamic>;
        expect(window['closed'], isTrue);
        expect(window.containsKey('earliestStart'), isFalse);
        expect(window.containsKey('availableMinutes'), isFalse);
      },
    );

    test('a closed window states no budget beside it', () async {
      final result = await withClock(
        Clock.fixed(DateTime(2026, 5, 25, 23, 58)),
        () => workflow().execute(
          agentIdentity: identity(),
          runKey: runKey,
          triggerTokens: {dayAgentPlanningDayToken(dayId)},
          threadId: threadId,
        ),
      );

      expect(result.success, isTrue, reason: result.error);
      final window =
          sentPrompt().json('planning_window')! as Map<String, dynamic>;
      expect(window['closed'], isTrue);
      expect(window.containsKey('availableMinutes'), isFalse);
    });

    test('reports a closed window late in the day', () async {
      final result = await withClock(
        Clock.fixed(DateTime(2026, 5, 25, 23, 58)),
        () => workflow().execute(
          agentIdentity: identity(),
          runKey: runKey,
          triggerTokens: {dayAgentPlanningDayToken(dayId)},
          threadId: threadId,
        ),
      );

      expect(result.success, isTrue, reason: result.error);
      final window =
          sentPrompt().json('planning_window')! as Map<String, dynamic>;
      // Closed, never a next-day earliestStart, and never silently empty —
      // empty would read as "the day has not begun, plan anywhere".
      expect(window['closed'], isTrue);
      expect(window.containsKey('earliestStart'), isFalse);
    });

    test('reports a past target day as closed after midnight', () async {
      final result = await withClock(
        Clock.fixed(DateTime(2026, 5, 26, 0, 1)),
        () => workflow().execute(
          agentIdentity: identity(),
          runKey: runKey,
          triggerTokens: {dayAgentPlanningDayToken(dayId)},
          threadId: threadId,
        ),
      );

      expect(result.success, isTrue, reason: result.error);
      expect(sentPrompt().json('planning_window'), {'closed': true});
    });

    test('leaves the window empty for a day that has not begun', () async {
      final result = await withClock(
        Clock.fixed(DateTime(2026, 5, 24, 20)),
        () => workflow().execute(
          agentIdentity: identity(),
          runKey: runKey,
          triggerTokens: {dayAgentPlanningDayToken(dayId)},
          threadId: threadId,
        ),
      );

      expect(result.success, isTrue, reason: result.error);
      final window =
          sentPrompt().json('planning_window')! as Map<String, dynamic>;
      // No floor — none of tomorrow is in the past — but it still has a
      // budget, and the whole working day is available.
      expect(window.containsKey('earliestStart'), isFalse);
      expect(window.containsKey('closed'), isFalse);
      expect(window['availableMinutes'], 480);
    });

    test(
      'includes a null-baseline drafting context for drafting-token wakes',
      () async {
        final planService = MockDayAgentPlanService();
        stubDraftingPlanContext(planService);
        stubSuccessfulDraftToolCall(planService);

        final result = await execute(
          workflow(planService: planService),
          triggerTokens: {
            dayAgentDraftingToken(dayId),
            dayAgentPlanningDayToken(dayId),
          },
        );

        expect(result.success, isTrue);
        final draftingPayload =
            sentPrompt().json('drafting')! as Map<String, dynamic>;
        expect(draftingPayload['requested'], isTrue);
        expect(draftingPayload['baselinePlan'], isNull);
        expect(draftingPayload['decidedTasks'], isEmpty);
        verify(
          () => planService.draftPlanForDay(agentId: agentId, dayId: dayId),
        ).called(1);
      },
    );

    test(
      'surfaces the existing draft as the baseline for drafting wakes',
      () async {
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
                startTime: DateTime(2026, 5, 25, 9),
                endTime: DateTime(2026, 5, 25, 10),
                title: 'Prep demo',
                reason: 'High-energy window.',
              ),
            ],
          ),
          energyBands: [
            DayAgentEnergyBand(
              start: DateTime(2026, 5, 25, 9),
              end: DateTime(2026, 5, 25, 12),
              level: DayAgentEnergyLevel.high,
              label: 'HIGH ENERGY',
            ),
          ],
          capacityMinutes: 360,
          scheduledMinutes: 60,
          createdAt: DateTime(2026, 5, 25, 8),
          updatedAt: DateTime(2026, 5, 25, 8),
        );
        stubDraftingPlanContext(planService, baselinePlan: baselinePlan);
        stubSuccessfulDraftToolCall(planService);

        final result = await execute(
          workflow(planService: planService),
          triggerTokens: {
            dayAgentDraftingToken(dayId),
            dayAgentPlanningDayToken(dayId),
          },
        );

        expect(result.success, isTrue);
        final draftingPayload =
            sentPrompt().json('drafting')! as Map<String, dynamic>;
        final plan = draftingPayload['baselinePlan'] as Map<String, dynamic>;
        expect(plan['planId'], 'day_agent_plan:$dayId');
        expect(plan['capacityMinutes'], 360);
        expect(plan['scheduledMinutes'], 60);
        final blocks = plan['blocks'] as List<dynamic>;
        expect(blocks, hasLength(1));
        expect((blocks.single as Map<String, dynamic>)['title'], 'Prep demo');
        final bands = plan['energyBands'] as List<dynamic>;
        expect(bands, hasLength(1));
        expect((bands.single as Map<String, dynamic>)['level'], 'high');
        verify(
          () => planService.executeTool(
            agentId: agentId,
            threadId: threadId,
            runKey: runKey,
            toolName: DayAgentToolNames.draftDayPlan,
            args: any(named: 'args'),
            planningConfig: any(named: 'planningConfig'),
            planningSnapshotAt: now,
            planningBaselinePlan: baselinePlan,
          ),
        ).called(1);
      },
    );

    test(
      'omits the drafting context when no drafting token is present',
      () async {
        final planService = MockDayAgentPlanService();

        final result = await execute(
          workflow(planService: planService),
          triggerTokens: {dayAgentPlanningDayToken(dayId)},
        );

        expect(result.success, isTrue);
        expect(sentPrompt().has('drafting'), isFalse);
        verifyNever(
          () => planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        );
      },
    );

    test(
      'surfaces decided tasks and unlinked capture items for drafting',
      () async {
        final planService = MockDayAgentPlanService();
        final captureService = MockDayAgentCaptureService();
        final capture =
            AgentDomainEntity.capture(
                  id: 'capture-1',
                  agentId: agentId,
                  transcript: 'prep demo + buy milk',
                  capturedAt: DateTime(2026, 5, 25, 7, 45),
                  createdAt: DateTime(2026, 5, 25, 7, 45),
                  vectorClock: null,
                )
                as CaptureEntity;
        final parsedItem = makeTestParsedItem(
          id: 'parsed-1',
          agentId: agentId,
          captureId: 'capture-1',
          kind: ParsedItemKind.matched,
          title: 'Buy milk',
          categoryId: 'life',
          matchedTaskId: 'task-milk',
          createdAt: DateTime(2026, 5, 25, 7, 50),
        );
        final newParsedItem = makeTestParsedItem(
          id: 'parsed-new',
          agentId: agentId,
          captureId: 'capture-1',
          title: 'Prep demo follow-up',
          categoryId: 'work',
          confidence: ParsedItemConfidence.medium,
          confidenceScore: 0.6,
          spokenPhrase: 'prep the follow-up',
          estimateMinutes: 25,
          createdAt: DateTime(2026, 5, 25, 7, 51),
        );
        when(
          () => captureService.getCapture('capture-1'),
        ).thenAnswer((_) async => capture);
        when(
          () => captureService.buildTaskCorpusSnapshot(
            allowedCategoryIds: const <String>{},
            day: DateTime(2026, 5, 25),
            dependencyResolver: any(named: 'dependencyResolver'),
          ),
        ).thenAnswer((_) async => const []);
        when(
          () => captureService.parsedItemsForCapture('capture-1'),
        ).thenAnswer((_) async => [parsedItem, newParsedItem]);
        when(
          () => planService.draftPlanForDay(agentId: agentId, dayId: dayId),
        ).thenAnswer((_) async => null);
        when(
          () => planService.hydrateDecidedTasks(
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            explicitTaskIds: any(named: 'explicitTaskIds'),
            parsedItems: any(named: 'parsedItems'),
          ),
        ).thenAnswer(
          (_) async => const [
            DecidedTaskRef(
              id: 'task-1',
              title: 'Prep demo',
              categoryId: 'work',
            ),
            DecidedTaskRef(
              id: 'task-milk',
              title: 'Buy milk',
              categoryId: 'life',
            ),
          ],
        );
        stubSuccessfulDraftToolCall(planService);

        final result = await execute(
          workflow(planService: planService, captureService: captureService),
          triggerTokens: {
            dayAgentDraftingToken(dayId),
            dayAgentCaptureSubmittedToken('capture-1'),
            dayAgentDecidedTaskToken('task-1'),
            dayAgentDecidedCaptureItemToken('parsed-new'),
            dayId,
          },
        );

        expect(result.success, isTrue);
        final draftingPayload =
            sentPrompt().json('drafting')! as Map<String, dynamic>;
        final decidedTasks = draftingPayload['decidedTasks'] as List<dynamic>;
        expect(decidedTasks, hasLength(2));
        expect((decidedTasks[0] as Map<String, dynamic>)['id'], 'task-1');
        expect((decidedTasks[1] as Map<String, dynamic>)['title'], 'Buy milk');
        final decidedCaptureItems =
            draftingPayload['decidedCaptureItems'] as List<dynamic>;
        expect(decidedCaptureItems, hasLength(1));
        expect(
          (decidedCaptureItems.single as Map<String, dynamic>)['id'],
          'parsed-new',
        );
        expect(
          (decidedCaptureItems.single as Map<String, dynamic>)['title'],
          'Prep demo follow-up',
        );

        final hydrateCall = verify(
          () => planService.hydrateDecidedTasks(
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            explicitTaskIds: captureAny(named: 'explicitTaskIds'),
            parsedItems: captureAny(named: 'parsedItems'),
          ),
        ).captured;
        expect(hydrateCall.first, ['task-1']);
        final passedParsedItems = hydrateCall.last as List<ParsedItemEntity>;
        expect(passedParsedItems, hasLength(2));
        expect(passedParsedItems.first.matchedTaskId, 'task-milk');
      },
    );
  });
}
