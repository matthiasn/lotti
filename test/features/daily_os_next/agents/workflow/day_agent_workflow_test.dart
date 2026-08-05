import 'day_agent_workflow_test_harness.dart';

void main() {
  configureDayAgentWorkflowTestSuite();

  // Owns workflow preconditions, inference setup, and shell-level wake execution.
  group('DayAgentWorkflow', () {
    test('fails the wake when no reconciled agent state exists', () async {
      when(
        () => syncService.reconciledAgentState(agentId),
      ).thenAnswer((_) async => null);

      final result = await execute(workflow());

      expect(result.success, isFalse);
      expect(result.error, 'No agent state found');
      // Nothing ran: no conversation, no persisted entities.
      expect(conversationRepository.lastUserMessage, isNull);
      expect(upsertedEntities, isEmpty);
    });

    test('fails the wake when no day can be resolved from tokens', () async {
      // Post-cutover the planner has no activeDayId slot: a wake with no day
      // token and no capture cannot resolve a workspace and must fail fast
      // (ADR 0022 Decision 3).
      final result = await execute(workflow(), triggerTokens: const {});

      expect(result.success, isFalse);
      expect(result.error, 'No active day ID');
      expect(conversationRepository.lastUserMessage, isNull);
      expect(upsertedEntities, isEmpty);
    });

    test('fails the wake when no inference provider is configured', () async {
      // The profile resolves but its thinking model has no matching provider
      // model, so ProfileResolver.resolve() returns null and the wake aborts
      // before any conversation is started.
      when(
        () => aiConfigRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => const []);

      final result = await execute(workflow());

      expect(result.success, isFalse);
      expect(result.error, 'No inference provider configured');
      expect(conversationRepository.createdConversationCount, 0);
      expect(conversationRepository.lastUserMessage, isNull);
      expect(upsertedEntities, isEmpty);
    });

    // A null template context (no template, or no active version) forces the
    // profile to null, so the wake aborts at the inference-provider guard
    // BEFORE any conversation is created. The scaffold-only system prompt and
    // the `templateCtx != null` guard around updateWakeRunTemplate are
    // therefore unreachable while the profile guard fires first.
    for (final (name, stub) in [
      (
        'no template is assigned',
        () => when(
          () => templateService.getTemplateForAgent(agentId),
        ).thenAnswer((_) async => null),
      ),
      (
        'the active template version is missing',
        () => when(
          () => templateService.getActiveVersion(templateId),
        ).thenAnswer((_) async => null),
      ),
    ]) {
      test('aborts the wake when $name', () async {
        stub();

        final result = await execute(workflow());

        expect(result.success, isFalse);
        expect(result.error, 'No inference provider configured');
        expect(conversationRepository.createdConversationCount, 0);
        expect(upsertedEntities, isEmpty);
        verifyNever(
          () => repository.updateWakeRunTemplate(
            any(),
            any(),
            any(),
            resolvedModelId: any(named: 'resolvedModelId'),
            soulId: any(named: 'soulId'),
            soulVersionId: any(named: 'soulVersionId'),
          ),
        );
      });
    }

    test(
      'resolves the day from a planning_day token without the legacy slot',
      () async {
        // Empty slot proves the wake derives its day from trigger tokens
        // (ADR 0022), not from state.slots.activeDayId.
        currentState = state(activeDayId: '');

        final result = await execute(
          workflow(),
          triggerTokens: {dayAgentPlanningDayToken(dayId)},
        );

        expect(result.success, isTrue);
        expect(sentPrompt().section('day_id'), dayId);
      },
    );

    test(
      'fails fast when trigger tokens claim conflicting day workspaces',
      () async {
        final result = await execute(
          workflow(),
          triggerTokens: {
            dayAgentDraftingToken('dayplan-2026-05-25'),
            dayAgentRefineToken('dayplan-2026-05-26'),
          },
        );

        expect(result.success, isFalse);
        expect(result.error, contains('Ambiguous day workspace'));
        // Nothing ran: no conversation, no persisted entities.
        expect(conversationRepository.lastUserMessage, isNull);
        expect(upsertedEntities, isEmpty);
      },
    );

    test(
      'a capture-only wake resolves its day from the capture, not the slot',
      () async {
        // Empty slot + only a capture token: the day must come from the
        // capture's own dayId scope (ADR 0022), not state.slots.activeDayId.
        currentState = state(activeDayId: '');
        final captureService = MockDayAgentCaptureService();
        when(() => captureService.getCapture('capture-1')).thenAnswer(
          (_) async => makeTestCapture(
            id: 'capture-1',
            agentId: agentId,
            transcript: 'buy milk',
            capturedAt: DateTime(2026, 5, 25, 7),
            createdAt: DateTime(2026, 5, 25, 7),
            dayId: dayId,
          ),
        );
        when(
          () => captureService.buildTaskCorpusSnapshot(
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            day: any(named: 'day'),
            dependencyResolver: any(named: 'dependencyResolver'),
          ),
        ).thenAnswer((_) async => const []);
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
              {
                'kind': 'newTask',
                'title': 'buy milk',
                'categoryId': 'home',
                'confidenceScore': 0.4,
              },
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
                  'title': 'buy milk',
                  'categoryId': 'home',
                  'confidenceScore': 0.4,
                },
              ],
            },
          ),
        ];

        final result = await execute(
          workflow(captureService: captureService),
          triggerTokens: {dayAgentCaptureSubmittedToken('capture-1')},
        );

        expect(result.success, isTrue);
        expect(sentPrompt().section('day_id'), dayId);
      },
    );

    test(
      'a capture-only wake is ambiguous when its captures span two days',
      () async {
        currentState = state(activeDayId: '');
        final captureService = MockDayAgentCaptureService();
        when(() => captureService.getCapture('cap-a')).thenAnswer(
          (_) async => makeTestCapture(
            id: 'cap-a',
            agentId: agentId,
            dayId: 'dayplan-2026-05-25',
          ),
        );
        when(() => captureService.getCapture('cap-b')).thenAnswer(
          (_) async => makeTestCapture(
            id: 'cap-b',
            agentId: agentId,
            dayId: 'dayplan-2026-05-26',
          ),
        );

        final result = await execute(
          workflow(captureService: captureService),
          triggerTokens: {
            dayAgentCaptureSubmittedToken('cap-a'),
            dayAgentCaptureSubmittedToken('cap-b'),
          },
        );

        expect(result.success, isFalse);
        expect(
          result.error,
          contains('Ambiguous day workspace across captures'),
        );
        expect(conversationRepository.lastUserMessage, isNull);
      },
    );

    test('record_observations is handled by the strategy and never routed to '
        'the capture or plan services', () async {
      // The workflow handler only routes capture/plan/set_next_wake names;
      // record_observations is intercepted by the strategy beforehand.
      expect(
        DayAgentToolNames.workflowHandlerTools,
        isNot(contains(DayAgentToolNames.recordObservations)),
      );

      final captureService = MockDayAgentCaptureService();
      final planService = MockDayAgentPlanService();
      conversationRepository.toolCalls = [
        toolCall(
          name: DayAgentToolNames.recordObservations,
          args: {
            'observations': ['Morning wake was useful.'],
          },
        ),
      ];

      final result = await execute(
        workflow(captureService: captureService, planService: planService),
      );

      expect(result.success, isTrue);
      expect(
        conversationRepository.toolResponses.single,
        'Recorded 1 observation(s).',
      );
      verifyNever(
        () => captureService.executeTool(
          agentId: any(named: 'agentId'),
          threadId: any(named: 'threadId'),
          runKey: any(named: 'runKey'),
          toolName: any(named: 'toolName'),
          args: any(named: 'args'),
        ),
      );
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
  });
}
