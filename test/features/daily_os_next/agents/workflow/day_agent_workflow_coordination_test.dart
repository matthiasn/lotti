import 'day_agent_workflow_test_harness.dart';

void main() {
  configureDayAgentWorkflowTestSuite();

  // Owns attention context, directives, and coordinator digest behavior.
  group('DayAgentWorkflow', () {
    test(
      'surfaces completed persisted recordings before CaptureEntity creation',
      () async {
        final journalDb = MockJournalDb();
        when(() => journalDb.getDayAudioEntries(dayId)).thenAnswer(
          (_) async => [
            JournalAudio(
              meta: Metadata(
                id: 'audio-offline',
                createdAt: now,
                updatedAt: now,
                dateFrom: now,
                dateTo: now,
              ),
              data: AudioData(
                dateFrom: now,
                dateTo: now,
                audioFile: 'offline.wav',
                audioDirectory: '/audio/',
                duration: const Duration(minutes: 1),
                dayContext: DayAudioContext(
                  dayId: dayId,
                  planDate: now,
                  recordingSessionId: 'session-offline',
                  activityEntryId: 'activity-offline',
                  processingJobId: 'transcribe_session-offline',
                  capturedAt: now,
                  intent: 'dayPlan',
                ),
                transcripts: [
                  AudioTranscript(
                    created: now,
                    library: 'daily-os-outbox',
                    model: 'configured-audio-model',
                    detectedLanguage: 'en',
                    transcript: 'Keep the afternoon free for recovery.',
                    processingJobId: 'transcribe_session-offline',
                  ),
                ],
              ),
            ),
          ],
        );

        final result = await execute(
          workflow(
            dayAudioEntryContextService: DayAudioEntryContextService(
              journalDb: journalDb,
            ),
          ),
        );

        expect(result.success, isTrue);
        final entries =
            sentPrompt().json(DayAgentPromptTags.dayEntries)! as List;
        expect(entries, hasLength(1));
        expect(entries.single, containsPair('audioId', 'audio-offline'));
        expect(
          entries.single,
          containsPair('transcript', 'Keep the afternoon free for recovery.'),
        );
      },
    );

    test('caps <day_entries> to the newest 32 recordings with an explicit '
        'truncation marker (ADR 0032 §4 provenance-index sizing)', () async {
      final journalDb = MockJournalDb();
      JournalAudio audioAt(int minute) => JournalAudio(
        meta: Metadata(
          id: 'audio-$minute',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: AudioData(
          dateFrom: now,
          dateTo: now,
          audioFile: 'clip-$minute.wav',
          audioDirectory: '/audio/',
          duration: const Duration(minutes: 1),
          dayContext: DayAudioContext(
            dayId: dayId,
            planDate: now,
            recordingSessionId: 'session-$minute',
            activityEntryId: 'activity-$minute',
            processingJobId: 'transcribe_session-$minute',
            capturedAt: now.add(Duration(minutes: minute)),
            intent: 'dayPlan',
          ),
        ),
      );
      when(
        () => journalDb.getDayAudioEntries(dayId),
      ).thenAnswer((_) async => [for (var i = 0; i < 40; i++) audioAt(i)]);

      final result = await execute(
        workflow(
          dayAudioEntryContextService: DayAudioEntryContextService(
            journalDb: journalDb,
          ),
        ),
      );

      expect(result.success, isTrue);
      final entries = sentPrompt().json(DayAgentPromptTags.dayEntries)! as List;
      // The newest 32 entries plus the truncation marker.
      expect(entries, hasLength(33));
      expect(
        (entries.first as Map)['audioId'],
        'audio-8',
        reason: 'The cap keeps the NEWEST entries — oldest 8 drop.',
      );
      expect((entries[31] as Map)['audioId'], 'audio-39');
      final marker = entries.last as Map;
      expect(marker, containsPair('truncated', true));
      expect(marker, containsPair('omittedOlderEntries', 8));
    });

    test(
      'keeps planning available when durable recording lookup fails',
      () async {
        final journalDb = MockJournalDb();
        when(
          () => journalDb.getJournalEntities(
            types: const ['JournalAudio'],
            starredStatuses: const [true, false],
            privateStatuses: const [true, false],
            flaggedStatuses: const [1, 0],
            ids: null,
            limit: 64,
            // ignore: avoid_redundant_argument_values
            offset: 0,
          ),
        ).thenThrow(StateError('local audio index unavailable'));

        final result = await execute(
          workflow(
            dayAudioEntryContextService: DayAudioEntryContextService(
              journalDb: journalDb,
            ),
          ),
        );

        expect(result.success, isTrue);
        expect(sentPrompt().json(DayAgentPromptTags.dayEntries), isNull);
      },
    );

    test('read-flips to a dayLog of capture transcripts and observations, '
        'dropping the recentObservations listing', () async {
      when(() => syncService.repository).thenReturn(repository);
      when(
        () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
      ).thenAnswer((_) async => []);
      when(
        () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
      ).thenAnswer((_) async => []);
      when(() => repository.getLinksFrom(agentId)).thenAnswer((_) async => []);
      final capture =
          AgentDomainEntity.capture(
                id: 'cap-1',
                agentId: agentId,
                transcript: 'morning planning capture',
                capturedAt: DateTime.utc(2026, 5, 24, 23),
                createdAt: DateTime.utc(2026, 5, 25, 7, 1),
                vectorClock: null,
                dayId: dayId,
              )
              as CaptureEntity;
      // The substrate loads only lightweight metadata; the transcript is
      // resolved lazily (tail only) via getEntity.
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
      final obs = AgentDomainEntity.agentMessage(
        id: 'obs-1',
        agentId: agentId,
        threadId: 'old-thread',
        kind: AgentMessageKind.observation,
        createdAt: DateTime.utc(2026, 5, 25, 8),
        vectorClock: null,
        contentEntryId: 'obs-payload-1',
        metadata: const AgentMessageMetadata(),
      );
      when(
        () =>
            repository.getMessagesByKind(agentId, AgentMessageKind.observation),
      ).thenAnswer((_) async => [obs as AgentMessageEntity]);
      stubEntitiesByIds({
        'obs-payload-1': AgentDomainEntity.agentMessagePayload(
          id: 'obs-payload-1',
          agentId: agentId,
          createdAt: DateTime.utc(2026, 5, 25, 8),
          vectorClock: null,
          content: const {'text': 'a day observation'},
        ),
      });

      final sut = DayAgentWorkflow(
        agentRepository: repository,
        conversationRepository: conversationRepository,
        aiConfigRepository: aiConfigRepository,
        cloudInferenceRepository: cloudInferenceRepository,
        syncService: syncService,
        templateService: templateService,
        domainLogger: domainLogger,
        onPersistedStateChanged: changedTokens.add,
      );
      final result = await execute(
        sut,
        triggerTokens: {dayAgentPlanningDayToken(dayId)},
      );
      expect(result.success, isTrue);

      // The SENT prompt carries the dayLog with capture transcripts and
      // observations interleaved in event order (capture 07:01 before
      // observation 08:00), superseding the recentObservations listing.
      final sent = conversationRepository.lastUserMessage!;
      expect(sent, contains('<day_log>'));
      expect(sent, contains('(id: cap-1, capture) morning planning capture'));
      expect(sent, contains('(id: obs-1, observation) a day observation'));
      expect(sent, isNot(contains('<recent_observations>')));
      expect(
        sent.indexOf('morning planning capture'),
        lessThan(sent.indexOf('a day observation')),
      );

      // The PERSISTED payload is a v2 record with the derivable line
      // stripped and the marker stored.
      final record = upsertedEntities
          .whereType<AgentMessagePayloadEntity>()
          .map((p) => p.content)
          .firstWhere((c) => c['promptFormat'] == 'v2');
      final head = record['head']! as String;
      final tail = record['tail']! as String;
      expect(record['wrap'], 'day-log-section');
      expect(head, contains('<day_id>'));
      // The whole derivable `<day_log>…</day_log>` section is stripped from
      // storage; head ends before it and tail begins after it.
      expect(head, isNot(contains('<day_log>')));
      expect(tail, isNot(contains('</day_log>')));
      expect(tail, contains('<trigger_tokens>'));
      // The derivable log content is gone from storage…
      expect(head + tail, isNot(contains('morning planning capture')));
      // …and the substrate supersedes the separate listing.
      expect(head + tail, isNot(contains('<recent_observations>')));
      final marker = record['log']! as Map<String, Object?>;
      expect(marker['until'], isNotNull);

      // End-to-end: the persisted record must reconstruct byte-identically
      // to the prompt the wake actually sent — the head/tail boundaries and
      // the re-rendered <day_log> section have to line up exactly (ADR 0020).
      when(
        () => repository.getEntitiesByAgentId(
          agentId,
          type: AgentEntityTypes.capture,
        ),
      ).thenAnswer((_) async => [capture]);
      // The day wrap renderers are Daily OS's contribution to the shared
      // reconstructor (see buildProviderOverrides); without them the
      // `<day_log>` section would splice in verbatim.
      final reconstructed = await WakePromptReconstructor(
        syncService: syncService,
        wrapRenderers: dayPromptLogWrapRenderers,
      ).reconstruct(agentId: agentId, content: record);
      expect(reconstructed, conversationRepository.lastUserMessage);
    });

    test('falls back to the legacy prompt when the capture-entity load '
        'throws', () async {
      // The substrate is an optimization: a failed capture load is absorbed,
      // the read-flip gate stays closed, and the wake proceeds legacy-shaped.
      when(() => syncService.repository).thenReturn(repository);
      when(
        () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
      ).thenAnswer((_) async => []);
      when(
        () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
      ).thenAnswer((_) async => []);
      when(() => repository.getLinksFrom(agentId)).thenAnswer((_) async => []);
      when(
        () => repository.getCaptureEventMetaForDay(
          agentId: agentId,
          dayId: dayId,
        ),
      ).thenThrow(StateError('capture table unavailable'));

      final sut = DayAgentWorkflow(
        agentRepository: repository,
        conversationRepository: conversationRepository,
        aiConfigRepository: aiConfigRepository,
        cloudInferenceRepository: cloudInferenceRepository,
        syncService: syncService,
        templateService: templateService,
        domainLogger: domainLogger,
        onPersistedStateChanged: changedTokens.add,
      );
      final result = await execute(
        sut,
        triggerTokens: {dayAgentPlanningDayToken(dayId)},
      );
      expect(result.success, isTrue);

      // No day_log in the sent prompt, and the persisted payload stays a
      // legacy full blob (no v2 record without a usable compacted log).
      expect(
        conversationRepository.lastUserMessage,
        isNot(contains('<day_log>')),
      );
      final v2Records = upsertedEntities
          .whereType<AgentMessagePayloadEntity>()
          .map((p) => p.content)
          .where((c) => c['promptFormat'] == 'v2');
      expect(v2Records, isEmpty);
    });

    test('renders attention-planning claims and standing agreements into the '
        'sent prompt', () async {
      when(() => syncService.repository).thenReturn(repository);
      when(
        () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
      ).thenAnswer((_) async => []);
      when(
        () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
      ).thenAnswer((_) async => []);
      when(() => repository.getLinksFrom(agentId)).thenAnswer((_) async => []);

      final claim =
          AgentDomainEntity.attentionRequest(
                id: 'attn-claim-1',
                agentId: 'task-agent-7',
                kind: AttentionRequestKind.task,
                title: 'Finish tax packet',
                categoryId: 'work',
                requestedMinutes: 90,
                impact: 5,
                urgency: 4,
                energyFit: AttentionEnergyFit.high,
                evidenceRefs: const [
                  AttentionEvidenceRef(
                    kind: AttentionEvidenceKind.task,
                    id: 'task-9',
                    label: 'Tax packet',
                  ),
                ],
                scopeKind: AttentionClaimScopeKind.dateRange,
                earliestStart: DateTime.utc(2026, 5, 25, 9),
                latestEnd: DateTime.utc(2026, 5, 25, 17),
                deadline: DateTime.utc(2026, 5, 26, 12),
                targetId: 'task-9',
                targetKind: 'task',
                rationale: 'Due soon and still needs a focused block.',
                createdAt: DateTime.utc(2026, 5, 24, 8),
                vectorClock: null,
              )
              as AttentionRequestEntity;
      final agreement =
          AgentDomainEntity.standingAgreement(
                id: 'agreement-1',
                agentId: 'soul-agent-2',
                title: 'Exercise three times a week',
                scope: StandingAgreementScope.fitness,
                cadence: StandingAgreementCadence.weekly,
                categoryId: 'health',
                minCount: 3,
                priority: 2,
                rationale: 'Keep weekly movement consistent.',
                createdAt: DateTime.utc(2026, 5, 1, 8),
                updatedAt: DateTime.utc(2026, 5, 1, 8),
                vectorClock: null,
              )
              as StandingAgreementEntity;
      when(
        () => repository.getAttentionPlanningInputsForWindow(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenAnswer(
        (_) async => AttentionPlanningInputs(
          claims: [claim],
          standingAgreements: [agreement],
        ),
      );

      final result = await execute(
        workflow(),
        triggerTokens: {dayAgentPlanningDayToken(dayId)},
      );
      expect(result.success, isTrue);

      final attentionPlanning = sentPrompt().json('attention_planning')! as Map;
      final claims = attentionPlanning['claims'] as List;
      expect(claims, hasLength(1));
      final renderedClaim = claims.single as Map;
      expect(renderedClaim['id'], 'attn-claim-1');
      expect(renderedClaim['kind'], 'task');
      expect(renderedClaim['requestedMinutes'], 90);
      expect(renderedClaim['energyFit'], 'high');
      expect(renderedClaim['scopeKind'], 'dateRange');
      expect(renderedClaim['earliestStart'], '2026-05-25T09:00:00.000Z');
      expect(renderedClaim['deadline'], '2026-05-26T12:00:00.000Z');
      expect((renderedClaim['evidenceRefs'] as List).single, {
        'kind': 'task',
        'id': 'task-9',
        'label': 'Tax packet',
      });

      final agreements = attentionPlanning['standingAgreements'] as List;
      expect(agreements, hasLength(1));
      final renderedAgreement = agreements.single as Map;
      expect(renderedAgreement['id'], 'agreement-1');
      expect(renderedAgreement['scope'], 'fitness');
      expect(renderedAgreement['cadence'], 'weekly');
      expect(renderedAgreement['enforcement'], 'target');
      expect(renderedAgreement['approvalMode'], 'ask');
      expect(renderedAgreement['minCount'], 3);
      expect(renderedAgreement['priority'], 2);
      expect(
        renderedAgreement['rationale'],
        'Keep weekly movement consistent.',
      );
    });

    test('absorbs a failure loading attention-planning inputs', () async {
      when(() => syncService.repository).thenReturn(repository);
      when(
        () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
      ).thenAnswer((_) async => []);
      when(
        () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
      ).thenAnswer((_) async => []);
      when(() => repository.getLinksFrom(agentId)).thenAnswer((_) async => []);
      when(
        () => repository.getAttentionPlanningInputsForWindow(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenThrow(StateError('attention window unavailable'));

      final result = await execute(
        workflow(),
        triggerTokens: {dayAgentPlanningDayToken(dayId)},
      );

      // The throwing load path is actually exercised: if the workflow stopped
      // calling getAttentionPlanningInputsForWindow, this test would no longer
      // be proving the failure is absorbed.
      verify(
        () => repository.getAttentionPlanningInputsForWindow(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).called(1);

      // The load failure degrades to empty inputs, so the section is omitted
      // entirely (it is only rendered when non-empty) and the wake still
      // succeeds rather than propagating the error.
      expect(result.success, isTrue);
      expect(sentPrompt().has('attention_planning'), isFalse);
    });

    group('day directive (ADR 0032 phase 3)', () {
      late MockDayAgentDirectiveService directiveService;

      setUp(() {
        directiveService = MockDayAgentDirectiveService();
      });

      test(
        'renders <day_directive> ahead of the volatile tail when one exists',
        () async {
          when(() => directiveService.directiveForDay(dayId)).thenAnswer(
            (_) async => makeTestDayDirective(
              directiveRevisionId: 'rev-7',
              commitments: const [
                DayDirectiveCommitment(
                  id: 'award-1',
                  source: DayCommitmentSource.attentionAward,
                  title: 'Ship release notes',
                  minutes: 90,
                ),
              ],
              capacityBudget: const DayCapacityBudget(
                availableMinutes: 420,
                alreadyScheduledMinutes: 60,
              ),
              carryOver: const [
                DayCarryOverItem(
                  title: 'Expense report',
                  reason: 'Dropped yesterday.',
                  taskId: 'task-42',
                ),
              ],
              constraints: const ['Protect 12:00-13:00.'],
              attentionNotes: const ['Third heavy commitment this week.'],
            ),
          );

          final result = await execute(
            workflow(directiveService: directiveService),
            triggerTokens: {dayAgentPlanningDayToken(dayId)},
          );

          expect(result.success, isTrue);
          final section = sentPrompt().json('day_directive')! as Map;
          expect(section['directiveRevisionId'], 'rev-7');
          final commitments = section['commitments'] as List;
          expect((commitments.single as Map)['title'], 'Ship release notes');
          expect((section['capacityBudget'] as Map)['availableMinutes'], 420);
          expect(
            ((section['carryOver'] as List).single as Map)['taskId'],
            'task-42',
          );
          expect(
            (section['constraints'] as List).single,
            'Protect 12:00-13:00.',
          );
          expect(
            (section['attentionNotes'] as List).single,
            'Third heavy commitment this week.',
          );
          // Stable-prefix placement: the directive precedes the volatile
          // trigger-token tail.
          final sent = conversationRepository.lastUserMessage!;
          expect(
            sent.indexOf('<day_directive>'),
            lessThan(sent.indexOf('<trigger_tokens>')),
          );
        },
      );

      test('omits the section when no directive exists', () async {
        when(
          () => directiveService.directiveForDay(dayId),
        ).thenAnswer((_) async => null);

        final result = await execute(
          workflow(directiveService: directiveService),
          triggerTokens: {dayAgentPlanningDayToken(dayId)},
        );

        expect(result.success, isTrue);
        expect(sentPrompt().has('day_directive'), isFalse);
      });

      test(
        'absorbs a directive read failure without killing the wake',
        () async {
          when(
            () => directiveService.directiveForDay(dayId),
          ).thenThrow(StateError('directive store unavailable'));

          final result = await execute(
            workflow(directiveService: directiveService),
            triggerTokens: {dayAgentPlanningDayToken(dayId)},
          );

          verify(() => directiveService.directiveForDay(dayId)).called(1);
          expect(result.success, isTrue);
          expect(sentPrompt().has('day_directive'), isFalse);
        },
      );

      test('offers issue_day_directive to the coordinator but not to a per-day '
          'agent', () async {
        when(
          () => directiveService.directiveForDay(dayId),
        ).thenAnswer((_) async => null);

        await execute(
          workflow(directiveService: directiveService),
          triggerTokens: {dayAgentPlanningDayToken(dayId)},
        );
        expect(
          [
            for (final tool in conversationRepository.lastTools)
              tool.function.name,
          ],
          isNot(contains(DayAgentToolNames.issueDayDirective)),
          reason: 'A per-day agent must not even see the tool.',
        );
        expect(
          [
            for (final tool in conversationRepository.lastTools)
              tool.function.name,
          ],
          contains(DayAgentToolNames.raiseDayStatus),
          reason: 'Every day owner may raise status upward.',
        );

        await executeAsCoordinator(
          workflow(directiveService: directiveService),
        );
        expect([
          for (final tool in conversationRepository.lastTools)
            tool.function.name,
        ], contains(DayAgentToolNames.issueDayDirective));
        expect(
          conversationRepository.lastSystemMessage,
          contains('`issue_day_directive`'),
        );
      });

      test('dispatches issue_day_directive to the service with the waking '
          'agent id', () async {
        when(
          () => directiveService.directiveForDay(dayId),
        ).thenAnswer((_) async => null);
        when(
          () => directiveService.executeTool(
            agentId: dailyOsPlannerAgentId,
            toolName: DayAgentToolNames.issueDayDirective,
            args: any(named: 'args'),
            wakeDayId: any(named: 'wakeDayId'),
            runKey: any(named: 'runKey'),
            processingJobId: any(named: 'processingJobId'),
            planningConfig: any(named: 'planningConfig'),
          ),
        ).thenAnswer(
          (_) async => DayAgentDirectToolResult.success(const {
            'id': 'day_directive:$dayId',
          }),
        );
        conversationRepository.toolCalls = [
          toolCall(
            id: 'directive-call',
            name: DayAgentToolNames.issueDayDirective,
            // A directive for ANOTHER day than the wake workspace must
            // pass: digest wakes issue tomorrow's directive, so the tool
            // is exempt from the workspace-day guard.
            args: {'dayId': 'dayplan-2026-05-26'},
          ),
        ];

        final result = await executeAsCoordinator(
          workflow(directiveService: directiveService),
        );

        expect(result.success, isTrue);
        verify(
          () => directiveService.executeTool(
            agentId: dailyOsPlannerAgentId,
            toolName: DayAgentToolNames.issueDayDirective,
            args: {'dayId': 'dayplan-2026-05-26'},
            // The wake's workspace day and run key travel with the call so
            // the service can enforce raise_day_status's own-day rule and
            // the per-wake status cap.
            wakeDayId: dayId,
            runKey: runKey,
            planningConfig: any(named: 'planningConfig'),
          ),
        ).called(1);
      });

      test('dispatches raise_day_status with the wake day for own-day '
          'enforcement', () async {
        when(
          () => directiveService.directiveForDay(dayId),
        ).thenAnswer((_) async => null);
        when(
          () => directiveService.executeTool(
            agentId: agentId,
            toolName: DayAgentToolNames.raiseDayStatus,
            args: any(named: 'args'),
            wakeDayId: any(named: 'wakeDayId'),
            runKey: any(named: 'runKey'),
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
            args: {'dayId': dayId, 'status': 'dayClosed'},
          ),
        ];

        final result = await execute(
          workflow(directiveService: directiveService),
          triggerTokens: {
            dayAgentPlanningDayToken(dayId),
            dayAgentProcessingJobToken(
              'job-1',
              requestedAt: DateTime.utc(2026, 7, 22),
            ),
          },
        );

        expect(result.success, isTrue);
        expect(sentPrompt().json('trigger_tokens'), [
          dayAgentPlanningDayToken(dayId),
        ]);
        verify(
          () => directiveService.executeTool(
            agentId: agentId,
            toolName: DayAgentToolNames.raiseDayStatus,
            args: {'dayId': dayId, 'status': 'dayClosed'},
            wakeDayId: dayId,
            runKey: runKey,
            processingJobId: dayAgentProcessingIntentId(
              'job-1',
              requestedAt: DateTime.utc(2026, 7, 22),
            ),
            planningConfig: any(named: 'planningConfig'),
          ),
        ).called(1);
      });

      test(
        'issue_day_directive without a configured service fails cleanly',
        () async {
          conversationRepository.toolCalls = [
            toolCall(
              id: 'directive-call',
              name: DayAgentToolNames.issueDayDirective,
              args: {'dayId': dayId},
            ),
          ];

          final result = await execute(workflow());

          expect(result.success, isTrue);
          expect(
            conversationRepository.toolResponses.single,
            contains('directive tools are not configured'),
          );
        },
      );
    });

    group('coordinator digest wake (ADR 0032 phase 3)', () {
      late MockDayAgentDirectiveService directiveService;

      setUp(() {
        directiveService = MockDayAgentDirectiveService();
        when(
          () => directiveService.directiveForDay(any()),
        ).thenAnswer((_) async => null);
        when(
          () => repository.getDayStatusEventsSince(
            any(),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => const []);
      });

      Future<WakeResult> executeDigest(DayAgentWorkflow sut) {
        return executeAsCoordinator(
          sut,
          triggerTokens: {dayAgentDigestToken(dayId)},
        );
      }

      group('a digest wake that fires late re-anchors to the day it runs on', () {
        setUp(() {
          // The `<digest>` section only renders when its context loads; these
          // are the reads the shared coordinator stubs do not cover.
          when(
            () => repository.getMessagesByKind(
              dailyOsPlannerAgentId,
              AgentMessageKind.system,
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => []);
          when(
            () => repository.getAttentionPlanningInputsForWindow(
              start: any(named: 'start'),
              end: any(named: 'end'),
            ),
          ).thenAnswer(
            (_) async => const AttentionPlanningInputs(
              claims: [],
              standingAgreements: [],
            ),
          );
        });

        test('reasons about today, not the day it was scheduled for', () async {
          // Pending since the 20th — device asleep/offline through four slots.
          final result = await executeAsCoordinator(
            workflow(directiveService: directiveService),
            triggerTokens: {dayAgentDigestToken('dayplan-2026-05-20')},
          );

          expect(result.success, isTrue, reason: result.error);
          final digest = sentPrompt().json('digest')! as Map;
          expect(
            digest['todayDayId'],
            dayId,
            reason:
                'The digest plans the day it runs on. Anchoring to 05-20 '
                'would issue directives for a day that is already over.',
          );
          expect(digest['tomorrowDayId'], 'dayplan-2026-05-26');
          expect(sentPrompt().json('trigger_tokens'), [
            dayAgentDigestToken(dayId),
          ]);
          expect(
            upsertedEntities
                .whereType<ScheduledWakeEntity>()
                .single
                .scheduledAt,
            DateTime(2026, 5, 26, 6),
            reason: 'Missed slots collapse into this run; cadence resumes.',
          );
        });

        test(
          'a re-anchored wake before the digest hour does not re-arm a second '
          'digest for the same day',
          () async {
            final result = await executeAsCoordinator(
              workflow(directiveService: directiveService),
              triggerTokens: {dayAgentDigestToken('dayplan-2026-05-20')},
              at: DateTime(2026, 5, 25, 3),
            );

            expect(result.success, isTrue, reason: result.error);
            expect((sentPrompt().json('digest')! as Map)['todayDayId'], dayId);
            final rearmed = upsertedEntities
                .whereType<ScheduledWakeEntity>()
                .single;
            expect(
              rearmed.scheduledAt,
              DateTime(2026, 5, 26, 6),
              reason:
                  'Today 06:00 is still ahead of 03:00, but this run already '
                  'digested today — re-arming it would digest today twice.',
            );
            expect(rearmed.triggerTokens, [
              dayAgentDigestToken('dayplan-2026-05-26'),
            ]);
          },
        );

        test('an on-time wake keeps its scheduled anchor', () async {
          final result = await executeAsCoordinator(
            workflow(directiveService: directiveService),
            triggerTokens: {dayAgentDigestToken(dayId)},
            at: DateTime(2026, 5, 25, 6, 4),
          );

          expect(result.success, isTrue, reason: result.error);
          expect((sentPrompt().json('digest')! as Map)['todayDayId'], dayId);
          expect(
            upsertedEntities
                .whereType<ScheduledWakeEntity>()
                .single
                .scheduledAt,
            DateTime(2026, 5, 26, 6),
          );
        });

        test('a digest that committed before failing keeps the bound', () async {
          // AgentSyncService rethrows a buffered outbox failure only AFTER its
          // transaction commits, so the milestone can be durable while the
          // wake still reports failure. Re-arming unbounded there would
          // overwrite the committed next-day record and digest today twice.
          when(
            () => repository.getMessagesByKind(
              dailyOsPlannerAgentId,
              AgentMessageKind.system,
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              makeTestMessage(
                id: 'committed-digest',
                agentId: dailyOsPlannerAgentId,
                kind: AgentMessageKind.system,
                createdAt: DateTime(2026, 5, 25, 3),
                metadata: const AgentMessageMetadata(
                  milestone: AgentMilestone.dailyWakeCompleted,
                  runKey: runKey,
                ),
              ),
            ],
          );
          conversationRepository.errorToThrow = Exception('outbox enqueue');

          final result = await executeAsCoordinator(
            workflow(directiveService: directiveService),
            triggerTokens: {dayAgentDigestToken('dayplan-2026-05-20')},
            at: DateTime(2026, 5, 25, 3),
          );

          expect(result.success, isFalse);
          expect(
            upsertedEntities
                .whereType<ScheduledWakeEntity>()
                .single
                .scheduledAt,
            DateTime(2026, 5, 26, 6),
            reason:
                "The log says today was digested, so today's slot is skipped "
                'even though the wake reported failure.',
          );
        });

        test("a failed catch-up keeps today's retry", () async {
          conversationRepository.errorToThrow = Exception('model failed');

          final result = await executeAsCoordinator(
            workflow(directiveService: directiveService),
            triggerTokens: {dayAgentDigestToken('dayplan-2026-05-20')},
            at: DateTime(2026, 5, 25, 3),
          );

          expect(result.success, isFalse);
          final rearmed = upsertedEntities
              .whereType<ScheduledWakeEntity>()
              .single;
          expect(
            rearmed.scheduledAt,
            DateTime(2026, 5, 25, 6),
            reason:
                'A failed run digested nothing and wrote no watermark, so the '
                'day-bounded guard must not apply — skipping to tomorrow '
                "would cost the user today's briefing over a transient "
                'error.',
          );
          expect(rearmed.triggerTokens, [
            dayAgentDigestToken('dayplan-2026-05-25'),
          ]);
        });
      });

      test('uses the configured digest output ceiling', () async {
        final result = await executeDigest(
          workflow(
            directiveService: directiveService,
            outputTokenBudgets: const DayAgentOutputTokenBudgetPolicy(
              digest: 2304,
            ),
          ),
        );

        expect(result.success, isTrue, reason: result.error);
        final inferenceRepo =
            conversationRepository.sendMessageCalls.single.inferenceRepo;
        expect(inferenceRepo, isA<DayAgentTimeoutInferenceRepository>());
        final timeoutRepo = inferenceRepo as DayAgentTimeoutInferenceRepository;
        expect(timeoutRepo.wakeKind, DayAgentWakeKind.digest);
        expect(timeoutRepo.timeout, const Duration(seconds: 60));
        expect(
          timeoutRepo.delegate,
          isA<DayAgentOutputBudgetInferenceRepository>(),
        );
        final outputBudget =
            timeoutRepo.delegate as DayAgentOutputBudgetInferenceRepository;
        expect(outputBudget.wakeKind, DayAgentWakeKind.digest);
        expect(outputBudget.maxCompletionTokens, 2304);
      });

      test('re-arms the next digest when provider execution fails', () async {
        conversationRepository.errorToThrow = Exception('model failed');

        final result = await executeDigest(
          workflow(directiveService: directiveService),
        );

        expect(result.success, isFalse);
        final rearmed = upsertedEntities
            .whereType<ScheduledWakeEntity>()
            .single;
        expect(rearmed.workspaceKey, coordinatorDigestWorkspaceKey);
        expect(rearmed.status, ScheduledWakeStatus.pending);
        expect(rearmed.scheduledAt, DateTime(2026, 5, 26, 6));
        expect(rearmed.triggerTokens, [
          dayAgentDigestToken('dayplan-2026-05-26'),
        ]);
      });

      test(
        're-arms the next digest when provider resolution fails early',
        () async {
          when(
            () => aiConfigRepository.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => const []);

          final result = await executeDigest(
            workflow(directiveService: directiveService),
          );

          expect(result.success, isFalse);
          expect(result.error, 'No inference provider configured');
          final rearmed = upsertedEntities
              .whereType<ScheduledWakeEntity>()
              .single;
          expect(rearmed.workspaceKey, coordinatorDigestWorkspaceKey);
          expect(rearmed.status, ScheduledWakeStatus.pending);
          expect(rearmed.scheduledAt, DateTime(2026, 5, 26, 6));
          expect(rearmed.triggerTokens, [
            dayAgentDigestToken('dayplan-2026-05-26'),
          ]);
        },
      );

      test('re-arms the next digest when setup throws early', () async {
        when(
          () => syncService.reconciledAgentState(dailyOsPlannerAgentId),
        ).thenThrow(StateError('state read failed'));

        await expectLater(
          executeDigest(workflow(directiveService: directiveService)),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'state read failed',
            ),
          ),
        );

        final rearmed = upsertedEntities
            .whereType<ScheduledWakeEntity>()
            .single;
        expect(rearmed.workspaceKey, coordinatorDigestWorkspaceKey);
        expect(rearmed.status, ScheduledWakeStatus.pending);
        expect(rearmed.scheduledAt, DateTime(2026, 5, 26, 6));
      });

      test('logs when re-arming a failed digest also fails', () async {
        conversationRepository.errorToThrow = Exception('model failed');
        when(() => syncService.upsertEntity(any())).thenAnswer((
          invocation,
        ) async {
          final entity =
              invocation.positionalArguments.single as AgentDomainEntity;
          if (entity is ScheduledWakeEntity) {
            throw StateError('wake write failed');
          }
          upsertedEntities.add(entity);
        });

        final result = await executeDigest(
          workflow(directiveService: directiveService),
        );

        expect(result.success, isFalse);
        verify(
          () => domainLogger.error(
            any(),
            any(),
            message: 'failed to re-arm coordinator digest wake',
            stackTrace: any(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);
      });

      test('renders <digest> with status events, directives, and the digest '
          'rules, then re-arms the next digest', () async {
        // Watermark: the newest dailyWakeCompleted milestone, overlapped
        // by the 12h sync-lag slack so a peer's late-synced escalation
        // (origin timestamp older than the local milestone) still ranks.
        final lastDigestAt = now.subtract(const Duration(hours: 24));
        final sinceWithSlack = lastDigestAt.subtract(const Duration(hours: 12));
        when(
          () => repository.getMessagesByKind(
            dailyOsPlannerAgentId,
            AgentMessageKind.system,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => [
            makeTestMessage(
              id: 'digest-marker',
              agentId: dailyOsPlannerAgentId,
              kind: AgentMessageKind.system,
              createdAt: lastDigestAt,
              metadata: const AgentMessageMetadata(
                milestone: AgentMilestone.dailyWakeCompleted,
              ),
            ),
          ],
        );
        when(
          () => repository.getDayStatusEventsSince(
            sinceWithSlack,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => [
            makeTestDayStatusEvent(
              id: 'day_status:$dayId:event-1',
              raisedAt: now.subtract(const Duration(hours: 2)),
              createdAt: now.subtract(const Duration(hours: 2)),
            ),
          ],
        );
        when(() => directiveService.directiveForDay(dayId)).thenAnswer(
          (_) async => makeTestDayDirective(directiveRevisionId: 'rev-t'),
        );
        when(
          () => directiveService.directiveForDay('dayplan-2026-05-26'),
        ).thenAnswer(
          (_) async => makeTestDayDirective(
            dayId: 'dayplan-2026-05-26',
            id: 'day_directive:dayplan-2026-05-26',
            directiveRevisionId: 'rev-tomorrow',
          ),
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
                    id: 'claim-digest',
                    agentId: 'task-agent',
                    kind: AttentionRequestKind.task,
                    title: 'Tax packet',
                    categoryId: 'work',
                    requestedMinutes: 45,
                    impact: 3,
                    urgency: 3,
                    energyFit: AttentionEnergyFit.high,
                    evidenceRefs: const [],
                    createdAt: DateTime.utc(2026, 5, 24),
                    vectorClock: null,
                  )
                  as AttentionRequestEntity,
            ],
            standingAgreements: const [],
          ),
        );

        final result = await executeDigest(
          workflow(directiveService: directiveService),
        );

        expect(result.success, isTrue, reason: result.error);
        final digest = sentPrompt().json('digest')! as Map;
        expect(digest['todayDayId'], dayId);
        expect(digest['tomorrowDayId'], 'dayplan-2026-05-26');
        expect(digest['since'], sinceWithSlack.toIso8601String());
        final events = digest['statusEvents'] as List;
        expect((events.single as Map)['status'], 'attentionNeeded');
        expect((events.single as Map)['reasons'], ['overCommitted']);
        final directives = digest['directives'] as Map;
        expect((directives['today'] as Map)['directiveRevisionId'], 'rev-t');
        expect(
          (directives['tomorrow'] as Map)['directiveRevisionId'],
          'rev-tomorrow',
        );
        final attentionWindow = digest['attentionWindow'] as Map;
        expect(
          ((attentionWindow['claims'] as List).single as Map)['id'],
          'claim-digest',
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('Digest rules'),
        );

        // Completion: the digest watermark milestone plus the
        // deterministic re-arm of tomorrow's digest record.
        verify(
          () => syncService.appendMilestone(
            agentId: dailyOsPlannerAgentId,
            milestone: AgentMilestone.dailyWakeCompleted,
            createdAt: any(named: 'createdAt'),
            threadId: threadId,
            runKey: runKey,
          ),
        ).called(1);
        final rearmed = upsertedEntities
            .whereType<ScheduledWakeEntity>()
            .single;
        expect(rearmed.workspaceKey, coordinatorDigestWorkspaceKey);
        expect(rearmed.status, ScheduledWakeStatus.pending);
        // now = 08:00, past the 06:00 digest hour, so the next digest is
        // tomorrow morning.
        expect(rearmed.scheduledAt, DateTime(2026, 5, 26, 6));
        expect(rearmed.triggerTokens, [
          dayAgentDigestToken('dayplan-2026-05-26'),
        ]);
      });

      test('digest wakes grow the coordinator log distilled-only '
          '(ADR 0032 phase 6)', () async {
        when(
          () => repository.getMessagesByKind(
            dailyOsPlannerAgentId,
            AgentMessageKind.system,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => []);

        final result = await executeDigest(
          workflow(directiveService: directiveService),
        );

        expect(result.success, isTrue, reason: result.error);
        // The structural fix ADR 0032 promises: the coordinator's log
        // grows at distilled-event rate only. A digest may persist its
        // own dialogue (messages + payloads), updated state, and the
        // deterministic next-digest record — never transcript-rate
        // artifacts (captures), plan mutations, or change sets under the
        // coordinator's id.
        for (final entity in upsertedEntities) {
          expect(
            entity,
            anyOf(
              isA<AgentMessageEntity>(),
              isA<AgentMessagePayloadEntity>(),
              isA<AgentStateEntity>(),
              isA<ScheduledWakeEntity>(),
            ),
            reason:
                'Digest persisted a non-distilled entity: '
                '${entity.runtimeType}',
          );
        }
        expect(upsertedEntities.whereType<CaptureEntity>(), isEmpty);
        expect(upsertedEntities.whereType<DayPlanEntity>(), isEmpty);
        expect(upsertedEntities.whereType<ChangeSetEntity>(), isEmpty);
        // The dialogue itself is bounded: one user message, one thought.
        expect(
          upsertedEntities.whereType<AgentMessageEntity>().length,
          lessThanOrEqualTo(4),
        );
      });

      test('flags truncation when the status-event page fills up', () async {
        when(
          () => repository.getMessagesByKind(
            dailyOsPlannerAgentId,
            AgentMessageKind.system,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getDayStatusEventsSince(
            any(),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => [
            // 51 routine closes, newest-skewed, plus one OLD escalation:
            // ranked selection must keep the escalation and drop a
            // routine close, not truncate by age.
            makeTestDayStatusEvent(
              id: 'day_status:$dayId:escalation',
              raisedAt: now.subtract(const Duration(hours: 20)),
              createdAt: now.subtract(const Duration(hours: 20)),
            ),
            for (var i = 0; i < 51; i++)
              makeTestDayStatusEvent(
                id: 'day_status:$dayId:close-$i',
                status: DayStatusKind.dayClosed,
                reasons: const [],
                raisedAt: now.subtract(Duration(minutes: 51 - i)),
                createdAt: now.subtract(Duration(minutes: 51 - i)),
              ),
          ],
        );

        final result = await executeDigest(
          workflow(directiveService: directiveService),
        );

        expect(result.success, isTrue, reason: result.error);
        final digest = sentPrompt().json('digest')! as Map;
        expect(digest['statusEventsTruncated'], isTrue);
        final events = digest['statusEvents'] as List;
        expect(events, hasLength(50));
        expect(
          (events.first as Map)['status'],
          'attentionNeeded',
          reason:
              'The 20-hour-old escalation survives ranked truncation and '
              'renders first chronologically.',
        );
      });

      test('a full status-event page refetches wider so ranking sees the '
          'newest events before the watermark advances past them', () async {
        when(
          () => repository.getMessagesByKind(
            dailyOsPlannerAgentId,
            AgentMessageKind.system,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => []);
        // 200 oldest routine closes fill the first page exactly; the one
        // escalation is NEWER than all of them, so a fixed 200-row fetch
        // would never rank it — and the completion watermark would then
        // skip it forever.
        final all = <DayStatusEventEntity>[
          for (var i = 0; i < 200; i++)
            makeTestDayStatusEvent(
              id: 'day_status:$dayId:close-$i',
              status: DayStatusKind.dayClosed,
              reasons: const [],
              raisedAt: now.subtract(Duration(hours: 40, minutes: 200 - i)),
              createdAt: now.subtract(Duration(hours: 40, minutes: 200 - i)),
            ),
          makeTestDayStatusEvent(
            id: 'day_status:$dayId:newest-escalation',
            raisedAt: now.subtract(const Duration(hours: 1)),
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
        ];
        when(
          () => repository.getDayStatusEventsSince(any(), limit: 200),
        ).thenAnswer((_) async => all.take(200).toList());
        when(
          () => repository.getDayStatusEventsSince(any(), limit: 400),
        ).thenAnswer((_) async => all);

        final result = await executeDigest(
          workflow(directiveService: directiveService),
        );

        expect(result.success, isTrue, reason: result.error);
        verify(
          () => repository.getDayStatusEventsSince(any(), limit: 400),
        ).called(1);
        final digest = sentPrompt().json('digest')! as Map;
        expect(digest['statusEventsTruncated'], isTrue);
        final events = digest['statusEvents'] as List;
        expect(
          (events.last as Map)['status'],
          'attentionNeeded',
          reason:
              'The newest escalation sits beyond the first page and must '
              'still be ranked in (rendering last, chronologically).',
        );
      });

      test('the doubling refetch stops at the hard ceiling and forces the '
          'truncation marker', () async {
        when(
          () => repository.getMessagesByKind(
            dailyOsPlannerAgentId,
            AgentMessageKind.system,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => []);
        final all = <DayStatusEventEntity>[
          for (var i = 0; i < 2000; i++)
            makeTestDayStatusEvent(
              id: 'day_status:$dayId:flood-$i',
              status: DayStatusKind.dayClosed,
              reasons: const [],
              raisedAt: now.subtract(Duration(minutes: 2100 - i)),
              createdAt: now.subtract(Duration(minutes: 2100 - i)),
            ),
          // Beyond the ceiling: the oldest-first fetch can never return
          // this escalation, and the watermark would skip it forever.
          makeTestDayStatusEvent(
            id: 'day_status:$dayId:beyond-ceiling-escalation',
            raisedAt: now.subtract(const Duration(minutes: 1)),
            createdAt: now.subtract(const Duration(minutes: 1)),
          ),
        ];
        when(
          () => repository.getDayStatusEventsSince(
            any(),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((invocation) async {
          final limit = invocation.namedArguments[#limit] as int?;
          return all.take(limit ?? all.length).toList();
        });
        when(
          () => repository.getDayStatusEventsSinceNewestFirst(
            any(),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((invocation) async {
          final limit = invocation.namedArguments[#limit]! as int;
          return all.reversed.take(limit).toList();
        });

        final result = await executeDigest(
          workflow(directiveService: directiveService),
        );

        expect(result.success, isTrue, reason: result.error);
        // 200 → 400 → 800 → 1600 → 2000, then STOP: the ceiling bounds
        // memory even against a pathological flood.
        for (final limit in [200, 400, 800, 1600, 2000]) {
          verify(
            () => repository.getDayStatusEventsSince(any(), limit: limit),
          ).called(1);
        }
        verifyNever(
          () => repository.getDayStatusEventsSince(any(), limit: 3200),
        );
        // At the ceiling one newest-first page merges into the pool so
        // the live end of the backlog still gets ranked.
        verify(
          () =>
              repository.getDayStatusEventsSinceNewestFirst(any(), limit: 200),
        ).called(1);
        final digest = sentPrompt().json('digest')! as Map;
        expect(digest['statusEventsTruncated'], isTrue);
        final events = digest['statusEvents'] as List;
        expect(events, hasLength(50));
        expect(
          (events.last as Map)['status'],
          'attentionNeeded',
          reason:
              'The escalation beyond the ceiling must be ranked in via '
              'the newest-first merge (rendering last, chronologically).',
        );
      });

      test('falls back to a 48h watermark (plus the sync-lag slack) for the '
          'first digest', () async {
        when(
          () => repository.getMessagesByKind(
            dailyOsPlannerAgentId,
            AgentMessageKind.system,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => []);

        final result = await executeDigest(
          workflow(directiveService: directiveService),
        );

        expect(result.success, isTrue, reason: result.error);
        final digest = sentPrompt().json('digest')! as Map;
        expect(
          digest['since'],
          now.subtract(const Duration(hours: 60)).toIso8601String(),
        );
        verify(
          () => repository.getDayStatusEventsSince(
            now.subtract(const Duration(hours: 60)),
            limit: any(named: 'limit'),
          ),
        ).called(1);
      });

      test('a digest token on a per-day agent renders no digest section and '
          'writes no digest milestone', () async {
        final result = await execute(
          workflow(directiveService: directiveService),
          triggerTokens: {dayAgentDigestToken(dayId)},
        );

        expect(result.success, isTrue, reason: result.error);
        expect(sentPrompt().has('digest'), isFalse);
        expect(
          conversationRepository.lastSystemMessage,
          isNot(contains('Digest rules')),
        );
        verifyNever(
          () => syncService.appendMilestone(
            agentId: any(named: 'agentId'),
            milestone: AgentMilestone.dailyWakeCompleted,
            createdAt: any(named: 'createdAt'),
            threadId: any(named: 'threadId'),
            runKey: any(named: 'runKey'),
          ),
        );
        expect(upsertedEntities.whereType<ScheduledWakeEntity>(), isEmpty);
      });

      test('absorbs a digest context load failure', () async {
        when(
          () => repository.getMessagesByKind(
            dailyOsPlannerAgentId,
            AgentMessageKind.system,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getDayStatusEventsSince(
            any(),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(StateError('status scan unavailable'));

        final result = await executeDigest(
          workflow(directiveService: directiveService),
        );

        expect(result.success, isTrue, reason: result.error);
        expect(sentPrompt().has('digest'), isFalse);
      });

      MockDayAgentWeekContextService rollupStub({
        List<Map<String, Object?>>? weeks,
      }) {
        final service = MockDayAgentWeekContextService();
        when(
          () => service.buildForDay(
            planDate: any(named: 'planDate'),
            now: any(named: 'now'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => service.ensureWeekRollups(now: any(named: 'now')),
        ).thenAnswer((_) async {});
        when(
          () => service.recentWeeksJson(now: any(named: 'now')),
        ).thenAnswer((_) async => weeks);
        return service;
      }

      test('a digest wake refreshes rollups and renders <recent_weeks> plus '
          'its digest rule', () async {
        final weekContextService = rollupStub(
          weeks: [
            {
              'weekStart': '2026-05-18',
              'daysWithPlans': 5,
              'plannedMinutes': {'Work': 480},
              'recordedMinutes': {'Work': 300},
            },
          ],
        );

        final result = await executeDigest(
          workflow(
            directiveService: directiveService,
            weekContextService: weekContextService,
          ),
        );

        expect(result.success, isTrue, reason: result.error);
        verify(
          () => weekContextService.ensureWeekRollups(now: any(named: 'now')),
        ).called(1);
        final weeks = sentPrompt().json('recent_weeks')! as List;
        final week = weeks.single as Map;
        expect(week['weekStart'], '2026-05-18');
        expect(week['daysWithPlans'], 5);
        expect((week['plannedMinutes'] as Map)['Work'], 480);
        expect((week['recordedMinutes'] as Map)['Work'], 300);
        expect(
          conversationRepository.lastSystemMessage,
          contains('<recent_weeks>'),
          reason: 'The digest rules must teach the section.',
        );
      });

      test('a per-day agent digest token never refreshes rollups and renders '
          'no <recent_weeks>', () async {
        final weekContextService = rollupStub();

        final result = await execute(
          workflow(
            directiveService: directiveService,
            weekContextService: weekContextService,
          ),
          triggerTokens: {dayAgentDigestToken(dayId)},
        );

        expect(result.success, isTrue, reason: result.error);
        verifyNever(
          () => weekContextService.ensureWeekRollups(now: any(named: 'now')),
        );
        expect(sentPrompt().has('recent_weeks'), isFalse);
      });

      test('absorbs a rollup refresh failure', () async {
        final weekContextService = rollupStub();
        when(
          () => weekContextService.ensureWeekRollups(now: any(named: 'now')),
        ).thenThrow(StateError('rollup storage offline'));

        final result = await executeDigest(
          workflow(
            directiveService: directiveService,
            weekContextService: weekContextService,
          ),
        );

        expect(result.success, isTrue, reason: result.error);
        expect(sentPrompt().has('recent_weeks'), isFalse);
      });
    });
  });
}
