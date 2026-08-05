import 'day_agent_workflow_test_harness.dart';

void main() {
  configureDayAgentWorkflowTestSuite();

  // Owns wake-result persistence, scheduling cleanup, and failure accounting.
  group('DayAgentWorkflow', () {
    test('persists no observation entities when none were recorded', () async {
      // A wake where the model calls no record_observations leaves
      // strategy.extractObservations() empty; _persistObservations must then
      // write nothing while the wake still completes successfully.
      conversationRepository.finalResponse = 'Nothing notable this wake.';

      final result = await execute(workflow());

      expect(result.success, isTrue);
      final observationEntities = upsertedEntities
          .whereType<AgentMessageEntity>()
          .where((m) => m.kind == AgentMessageKind.observation);
      expect(observationEntities, isEmpty);
      // The wake still reached completion (the thought payload is persisted).
      expect(
        upsertedEntities.whereType<AgentMessagePayloadEntity>().map(
          (p) => p.content['text'],
        ),
        contains('Nothing notable this wake.'),
      );
    });

    test('persists no thought when the model returns no final text', () async {
      // The harness defaults finalResponse to null, so the conversation ends
      // with no assistant text. recordFinalResponse(null) leaves the strategy
      // finalResponse null and _persistThought writes nothing — yet the wake
      // still completes successfully.
      expect(conversationRepository.finalResponse, isNull);

      final result = await execute(workflow());

      expect(result.success, isTrue);
      final thoughtMessages = upsertedEntities
          .whereType<AgentMessageEntity>()
          .where((m) => m.kind == AgentMessageKind.thought);
      expect(thoughtMessages, isEmpty);
      // The wake still event-sources its completion.
      expect(
        upsertedEntities.whereType<AgentStateEntity>().last.lastWakeAt,
        now,
      );
    });

    test(
      'includes the newest 20 observations in chronological order',
      () async {
        final payloadsById = <String, AgentMessagePayloadEntity>{};
        final observations = <AgentMessageEntity>[
          for (var index = 0; index < 25; index++)
            AgentDomainEntity.agentMessage(
                  id: 'observation-$index',
                  agentId: agentId,
                  threadId: 'observation-thread',
                  kind: AgentMessageKind.observation,
                  createdAt: now.subtract(Duration(minutes: 25 - index)),
                  vectorClock: null,
                  contentEntryId: 'payload-$index',
                  metadata: AgentMessageMetadata(
                    runKey: 'observation-run-$index',
                  ),
                )
                as AgentMessageEntity,
        ];
        for (var index = 0; index < observations.length; index++) {
          payloadsById['payload-$index'] =
              AgentDomainEntity.agentMessagePayload(
                    id: 'payload-$index',
                    agentId: agentId,
                    createdAt: observations[index].createdAt,
                    vectorClock: null,
                    content: {'text': 'Observation $index'},
                  )
                  as AgentMessagePayloadEntity;
        }
        when(
          () => repository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => observations);
        when(() => repository.getEntitiesByIds(any())).thenAnswer((
          invocation,
        ) async {
          final ids = invocation.positionalArguments.single as Iterable<String>;
          final payloads = <String, AgentDomainEntity>{};
          for (final id in ids) {
            final payload = payloadsById[id];
            if (payload != null) {
              payloads[id] = payload;
            }
          }
          return payloads;
        });

        final result = await execute(workflow());

        expect(result.success, isTrue);
        final recentObservations =
            sentPrompt().json('recent_observations')! as List<dynamic>;
        expect(recentObservations, hasLength(20));
        expect(recentObservations.first, {
          'createdAt': '2026-05-25T07:40:00.000',
          'text': 'Observation 5',
        });
        expect(recentObservations.last, {
          'createdAt': '2026-05-25T07:59:00.000',
          'text': 'Observation 24',
        });
        expect(
          recentObservations,
          isNot(contains(containsPair('text', 'Observation 4'))),
        );
      },
    );

    test('sorts observations with the same timestamp by stable id', () async {
      final createdAt = now.subtract(const Duration(minutes: 30));
      final payloadA =
          AgentDomainEntity.agentMessagePayload(
                id: 'payload-a',
                agentId: agentId,
                createdAt: createdAt,
                vectorClock: null,
                content: const {'text': 'A observation'},
              )
              as AgentMessagePayloadEntity;
      final payloadB =
          AgentDomainEntity.agentMessagePayload(
                id: 'payload-b',
                agentId: agentId,
                createdAt: createdAt,
                vectorClock: null,
                content: const {'text': 'B observation'},
              )
              as AgentMessagePayloadEntity;
      final observationB =
          AgentDomainEntity.agentMessage(
                id: 'observation-b',
                agentId: agentId,
                threadId: 'observation-thread',
                kind: AgentMessageKind.observation,
                createdAt: createdAt,
                vectorClock: null,
                contentEntryId: payloadB.id,
                metadata: const AgentMessageMetadata(runKey: 'old-run'),
              )
              as AgentMessageEntity;
      final observationA =
          AgentDomainEntity.agentMessage(
                id: 'observation-a',
                agentId: agentId,
                threadId: 'observation-thread',
                kind: AgentMessageKind.observation,
                createdAt: createdAt,
                vectorClock: null,
                contentEntryId: payloadA.id,
                metadata: const AgentMessageMetadata(runKey: 'old-run'),
              )
              as AgentMessageEntity;
      when(
        () => repository.getMessagesByKind(
          agentId,
          AgentMessageKind.observation,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [observationB, observationA]);
      when(
        () => repository.getEntitiesByIds({payloadA.id, payloadB.id}),
      ).thenAnswer((_) async => {payloadA.id: payloadA, payloadB.id: payloadB});

      final result = await execute(workflow());

      expect(result.success, isTrue);
      final recentObservations =
          sentPrompt().json('recent_observations')! as List<dynamic>;
      expect(
        recentObservations.map(
          (observation) => (observation as Map<String, dynamic>)['text'],
        ),
        ['A observation', 'B observation'],
      );
    });

    test('clears consumed scheduled wakes after a successful wake', () async {
      currentState = state(
        scheduledWakeAt: now.subtract(const Duration(minutes: 1)),
      );

      final result = await execute(workflow());

      expect(result.success, isTrue);
      final finalState = upsertedEntities.whereType<AgentStateEntity>().last;
      expect(finalState.lastWakeAt, now);
      expect(finalState.scheduledWakeAt, isNull);
    });

    test('preserves future scheduled wakes after a successful wake', () async {
      final futureWakeAt = now.add(const Duration(hours: 1));
      currentState = state(scheduledWakeAt: futureWakeAt);

      final result = await execute(workflow());

      expect(result.success, isTrue);
      final finalState = upsertedEntities.whereType<AgentStateEntity>().last;
      expect(finalState.scheduledWakeAt, futureWakeAt);
    });

    test('clears a scheduled wake landing exactly on now', () async {
      // The remaining-wake gate keeps a wake only when it is STRICTLY after
      // now (`isAfter`), so a wake whose time equals the wake instant is
      // treated as already due and cleared — the boundary between the
      // past-clears and future-preserves cases above.
      currentState = state(scheduledWakeAt: now);

      final result = await execute(workflow());

      expect(result.success, isTrue);
      final finalState = upsertedEntities.whereType<AgentStateEntity>().last;
      expect(finalState.scheduledWakeAt, isNull);
    });

    test('continues when user message persistence fails', () async {
      // Match on the entity being written (the `user`-kind message) rather
      // than a positional write count, so the test keeps targeting the
      // user-message write even if the wake gains an earlier write.
      var threwForUserMessage = false;
      when(() => syncService.upsertEntity(any())).thenAnswer((
        invocation,
      ) async {
        final entity =
            invocation.positionalArguments.single as AgentDomainEntity;
        if (entity is AgentMessageEntity &&
            entity.kind == AgentMessageKind.user) {
          threwForUserMessage = true;
          throw StateError('user message write failed');
        }
        upsertedEntities.add(entity);
        if (entity is AgentStateEntity) {
          currentState = entity;
        }
      });

      final result = await execute(workflow());

      expect(result.success, isTrue);
      // The failure was actually injected on the user-message write.
      expect(threwForUserMessage, isTrue);
      verify(
        () => domainLogger.error(
          any(),
          any(),
          message: 'failed to persist day-agent user message',
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
      expect(
        upsertedEntities.whereType<AgentStateEntity>().last.lastWakeAt,
        now,
      );
    });

    for (final scenario in const [
      ToolValidationScenario(
        name: 'rejects missing at',
        args: {'reason': 'Missing time.'},
        expectedResponse: 'ISO-8601 date-time string',
      ),
      ToolValidationScenario(
        name: 'rejects unparsable at',
        args: {'at': 'not-a-date', 'reason': 'Bad parse.'},
        expectedResponse: 'parseable as an ISO-8601',
      ),
      ToolValidationScenario(
        name: 'rejects empty reason',
        args: {'at': '2026-05-25T08:30:00', 'reason': '   '},
        expectedResponse: 'reason',
      ),
      ToolValidationScenario(
        name: 'rejects short lead time',
        args: {'at': '2026-05-25T08:14:59', 'reason': 'Too soon.'},
        expectedResponse: 'at least 15 minutes',
      ),
    ]) {
      test(scenario.name, () async {
        conversationRepository.toolCalls = [
          toolCall(name: DayAgentToolNames.setNextWake, args: scenario.args),
        ];

        final result = await execute(workflow());

        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          contains(scenario.expectedResponse),
        );
        // A rejected set_next_wake persists no scheduled-wake record.
        expect(upsertedEntities.whereType<ScheduledWakeEntity>(), isEmpty);
      });
    }

    test('rejects scheduled wakes after the daily cap is reached', () async {
      // Cap key is now (dayId, date)-scoped (ADR 0022 Decision 12).
      currentState = state(
        toolCounterByKey: {'day_agent_set_next_wake:$dayId:2026-05-25': 4},
      );
      conversationRepository.toolCalls = [
        toolCall(
          name: DayAgentToolNames.setNextWake,
          args: const {'at': '2026-05-25T08:30:00', 'reason': 'Past the cap.'},
        ),
      ];

      final result = await execute(workflow());

      expect(result.success, isTrue);
      expect(
        conversationRepository.toolResponses.single,
        contains('daily scheduled-wake cap reached'),
      );
      // The cap blocks both the record and any state mutation for the wake.
      expect(upsertedEntities.whereType<ScheduledWakeEntity>(), isEmpty);
    });

    test(
      'returns a tool error when state disappears during scheduling',
      () async {
        var stateReadCount = 0;
        when(() => repository.getAgentState(agentId)).thenAnswer((_) async {
          stateReadCount++;
          if (stateReadCount == 2) return null;
          return currentState;
        });
        conversationRepository.toolCalls = [
          toolCall(
            name: DayAgentToolNames.setNextWake,
            args: const {'at': '2026-05-25T08:30:00', 'reason': 'State race.'},
          ),
        ];

        final result = await execute(workflow());

        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          contains('agent state not found'),
        );
        expect(
          upsertedEntities.whereType<AgentStateEntity>().any(
            (state) => state.scheduledWakeAt != null,
          ),
          isFalse,
        );
      },
    );

    test('bumps failure count when conversation execution throws', () async {
      currentState = state(
        consecutiveFailureCount: 2,
        scheduledWakeAt: now.subtract(const Duration(minutes: 1)),
      );
      conversationRepository.errorToThrow = Exception('model failed');

      final result = await execute(workflow());

      expect(result.success, isFalse);
      expect(result.error, contains('model failed'));
      final failureState = upsertedEntities.whereType<AgentStateEntity>().last;
      expect(failureState.consecutiveFailureCount, 3);
      expect(failureState.scheduledWakeAt, isNull);
      expect(conversationRepository.deletedConversationCount, 1);
      verify(
        () => domainLogger.error(
          any(),
          any(),
          message: 'day-agent wake failed',
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    });

    test('logs when failure-count persistence also fails', () async {
      currentState = state(consecutiveFailureCount: 2);
      conversationRepository.errorToThrow = Exception('model failed');
      when(() => syncService.upsertEntity(any())).thenAnswer((
        invocation,
      ) async {
        final entity =
            invocation.positionalArguments.single as AgentDomainEntity;
        if (entity is AgentStateEntity) {
          throw StateError('state update failed');
        }
        upsertedEntities.add(entity);
      });

      final result = await execute(workflow());

      expect(result.success, isFalse);
      expect(result.error, contains('model failed'));
      verify(
        () => domainLogger.error(
          any(),
          any(),
          message: 'day-agent wake failed',
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
      verify(
        () => domainLogger.error(
          any(),
          any(),
          message: 'failed to update day-agent failure count',
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    });

    test('rejects an unparsable day id from the wake token', () async {
      // A planning_day token whose id is not a parseable dayplan must be
      // rejected before any conversation starts.
      final result = await execute(
        workflow(),
        triggerTokens: {dayAgentPlanningDayToken('not-a-day-plan')},
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Invalid active day ID'));
      expect(conversationRepository.createdConversationCount, 0);
    });
  });
}
