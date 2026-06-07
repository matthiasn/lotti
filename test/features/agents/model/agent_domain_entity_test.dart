import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/sync/g_counter.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../test_data/soul_factories.dart';

void main() {
  final createdAt = DateTime(2026, 2, 20);
  final updatedAt = DateTime(2026, 2, 20, 12);
  const vectorClock = VectorClock({'host-a': 3, 'host-b': 1});

  AgentDomainEntity roundtrip(AgentDomainEntity original) {
    final json =
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
    return AgentDomainEntity.fromJson(json);
  }

  group('AgentDomainEntity serialization roundtrip', () {
    group('AgentIdentityEntity (agent variant)', () {
      test('roundtrips all fields', () {
        final original = AgentDomainEntity.agent(
          id: 'entity-001',
          agentId: 'agent-001',
          kind: 'journalAssistant',
          displayName: 'Journal Assistant',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: {'cat-001', 'cat-002'},
          currentStateId: 'state-001',
          config: const AgentConfig(),
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<AgentIdentityEntity>());
      });

      test('roundtrips with optional deletedAt and destroyedAt set', () {
        final original = AgentDomainEntity.agent(
          id: 'entity-002',
          agentId: 'agent-002',
          kind: 'taskPlanner',
          displayName: 'Task Planner',
          lifecycle: AgentLifecycle.destroyed,
          mode: AgentInteractionMode.hybrid,
          allowedCategoryIds: {'cat-010'},
          currentStateId: 'state-002',
          config: const AgentConfig(),
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
          deletedAt: DateTime(2026, 2, 20, 18),
          destroyedAt: DateTime(2026, 2, 20, 19),
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final identity = roundtripped as AgentIdentityEntity;
        expect(identity.deletedAt, equals(DateTime(2026, 2, 20, 18)));
        expect(identity.destroyedAt, equals(DateTime(2026, 2, 20, 19)));
      });

      test('runtimeType discriminator key is "agent"', () {
        final entity = AgentDomainEntity.agent(
          id: 'entity-003',
          agentId: 'agent-003',
          kind: 'assistant',
          displayName: 'Assistant',
          lifecycle: AgentLifecycle.created,
          mode: AgentInteractionMode.interactive,
          allowedCategoryIds: const {},
          currentStateId: 'state-003',
          config: const AgentConfig(),
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        );

        final json = entity.toJson();
        expect(json['runtimeType'], equals('agent'));
      });
    });

    group('AgentStateEntity (agentState variant)', () {
      test('roundtrips all fields including optional timestamps', () {
        final original = AgentDomainEntity.agentState(
          id: 'state-001',
          agentId: 'agent-001',
          revision: 7,
          slots: const AgentSlots(activeTaskId: 'task-abc'),
          updatedAt: updatedAt,
          vectorClock: vectorClock,
          lastWakeAt: DateTime(2026, 2, 20, 8),
          nextWakeAt: DateTime(2026, 2, 20, 20),
          sleepUntil: DateTime(2026, 2, 20, 15),
          recentHeadMessageId: 'msg-head-001',
          latestSummaryMessageId: 'msg-summary-001',
          consecutiveFailureCount: 2,
          wakeCounter: const GCounter({'test-host': 14}),
          processedCounterByHost: {'host-a': 5, 'host-b': 9},
          toolCounterByKey: {'day_agent_set_next_wake:2026-02-20': 3},
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<AgentStateEntity>());
      });

      test('roundtrips project agent slots', () {
        final original = AgentDomainEntity.agentState(
          id: 'state-proj-001',
          agentId: 'agent-proj-001',
          revision: 3,
          slots: AgentSlots(
            activeProjectId: 'project-abc',
            lastDailyWakeAt: DateTime(2026, 3, 15, 8),
            lastWeeklyReviewAt: DateTime(2026, 3, 10, 14),
            weeklyReviewCount: const GCounter({'test-host': 5}),
          ),
          updatedAt: updatedAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final state = roundtripped as AgentStateEntity;
        expect(state.slots.activeProjectId, equals('project-abc'));
        expect(
          state.slots.lastDailyWakeAt,
          equals(DateTime(2026, 3, 15, 8)),
        );
        expect(
          state.slots.lastWeeklyReviewAt,
          equals(DateTime(2026, 3, 10, 14)),
        );
        expect(state.slots.weeklyReviewCount.value, equals(5));
      });

      test('roundtrips day agent slots', () {
        final original = AgentDomainEntity.agentState(
          id: 'state-day-001',
          agentId: 'agent-day-001',
          revision: 2,
          slots: const AgentSlots(activeDayId: 'dayplan-2026-05-25'),
          updatedAt: updatedAt,
          vectorClock: vectorClock,
          scheduledWakeAt: DateTime(2026, 5, 25, 6, 30),
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final state = roundtripped as AgentStateEntity;
        expect(state.slots.activeDayId, equals('dayplan-2026-05-25'));
        expect(state.scheduledWakeAt, equals(DateTime(2026, 5, 25, 6, 30)));
      });

      test('roundtrips with defaults for optional int/map fields', () {
        final original = AgentDomainEntity.agentState(
          id: 'state-002',
          agentId: 'agent-001',
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: updatedAt,
          vectorClock: null,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final state = roundtripped as AgentStateEntity;
        expect(state.consecutiveFailureCount, equals(0));
        expect(state.wakeCounter.value, equals(0));
        expect(state.processedCounterByHost, isEmpty);
        expect(state.toolCounterByKey, isEmpty);
      });

      test('runtimeType discriminator key is "agentState"', () {
        final entity = AgentDomainEntity.agentState(
          id: 'state-003',
          agentId: 'agent-001',
          slots: const AgentSlots(),
          updatedAt: updatedAt,
          vectorClock: null,
        );

        final json = entity.toJson();
        expect(json['runtimeType'], equals('agentState'));
      });
    });

    group('AgentMessageEntity (agentMessage variant)', () {
      test('roundtrips all fields', () {
        final original = AgentDomainEntity.agentMessage(
          id: 'msg-001',
          agentId: 'agent-001',
          threadId: 'thread-001',
          kind: AgentMessageKind.action,
          createdAt: createdAt,
          vectorClock: vectorClock,
          prevMessageId: 'msg-000',
          contentEntryId: 'entry-001',
          triggerSourceId: 'trigger-001',
          summaryStartMessageId: 'msg-start-001',
          summaryEndMessageId: 'msg-end-001',
          summaryDepth: 2,
          tokensApprox: 512,
          metadata: const AgentMessageMetadata(
            runKey: 'run-key-001',
            toolName: 'search_journal',
            operationId: 'op-001',
          ),
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<AgentMessageEntity>());
      });

      test('roundtrips with policy denied metadata', () {
        final original = AgentDomainEntity.agentMessage(
          id: 'msg-002',
          agentId: 'agent-001',
          threadId: 'thread-001',
          kind: AgentMessageKind.toolResult,
          createdAt: createdAt,
          vectorClock: null,
          metadata: const AgentMessageMetadata(
            policyDenied: true,
            denialReason: 'Access not permitted for category',
          ),
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final msg = roundtripped as AgentMessageEntity;
        expect(msg.metadata.policyDenied, isTrue);
        expect(
          msg.metadata.denialReason,
          equals('Access not permitted for category'),
        );
      });

      test('roundtrips each AgentMessageKind variant', () {
        for (final kind in AgentMessageKind.values) {
          final original = AgentDomainEntity.agentMessage(
            id: 'msg-kind-${kind.name}',
            agentId: 'agent-001',
            threadId: 'thread-001',
            kind: kind,
            createdAt: createdAt,
            vectorClock: null,
            metadata: const AgentMessageMetadata(),
          );

          final roundtripped = roundtrip(original);

          expect(roundtripped, equals(original), reason: 'kind: $kind');
          expect((roundtripped as AgentMessageEntity).kind, equals(kind));
        }
      });

      test('runtimeType discriminator key is "agentMessage"', () {
        final entity = AgentDomainEntity.agentMessage(
          id: 'msg-003',
          agentId: 'agent-001',
          threadId: 'thread-001',
          kind: AgentMessageKind.user,
          createdAt: createdAt,
          vectorClock: null,
          metadata: const AgentMessageMetadata(),
        );

        final json = entity.toJson();
        expect(json['runtimeType'], equals('agentMessage'));
      });
    });

    group('AgentMessagePayloadEntity (agentMessagePayload variant)', () {
      test('roundtrips all fields with nested content map', () {
        final original = AgentDomainEntity.agentMessagePayload(
          id: 'payload-001',
          agentId: 'agent-001',
          createdAt: createdAt,
          vectorClock: vectorClock,
          content: {
            'role': 'assistant',
            'text': 'Here is my analysis.',
            'tokens': 128,
          },
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<AgentMessagePayloadEntity>());
      });

      test('roundtrips with default contentType', () {
        final original = AgentDomainEntity.agentMessagePayload(
          id: 'payload-002',
          agentId: 'agent-001',
          createdAt: createdAt,
          vectorClock: null,
          content: {'key': 'value'},
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(
          (roundtripped as AgentMessagePayloadEntity).contentType,
          equals('application/json'),
        );
      });

      test('runtimeType discriminator key is "agentMessagePayload"', () {
        final entity = AgentDomainEntity.agentMessagePayload(
          id: 'payload-003',
          agentId: 'agent-001',
          createdAt: createdAt,
          vectorClock: null,
          content: {},
        );

        final json = entity.toJson();
        expect(json['runtimeType'], equals('agentMessagePayload'));
      });
    });

    group('AgentReportEntity (agentReport variant)', () {
      test('roundtrips all fields', () {
        final original = AgentDomainEntity.agentReport(
          id: 'report-001',
          agentId: 'agent-001',
          scope: 'weekly-summary',
          createdAt: createdAt,
          vectorClock: vectorClock,
          content: '# Weekly Summary\n\nCompleted 5 tasks this week.',
          tldr: 'Completed 5 tasks this week.',
          oneLiner: 'Stable week, cleanup and release next',
          confidence: 0.92,
          provenance: {'model': 'gemini-3.1-pro-preview', 'wakeId': 'wake-042'},
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<AgentReportEntity>());
        final report = roundtripped as AgentReportEntity;
        expect(report.tldr, 'Completed 5 tasks this week.');
        expect(report.oneLiner, 'Stable week, cleanup and release next');
      });

      test('roundtrips with null confidence and empty provenance', () {
        final original = AgentDomainEntity.agentReport(
          id: 'report-002',
          agentId: 'agent-001',
          scope: 'daily',
          createdAt: createdAt,
          vectorClock: null,
          content: 'Nothing to report.',
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final report = roundtripped as AgentReportEntity;
        expect(report.confidence, isNull);
        expect(report.provenance, isEmpty);
      });

      test('roundtrips with default empty content', () {
        final original = AgentDomainEntity.agentReport(
          id: 'report-003',
          agentId: 'agent-001',
          scope: 'test',
          createdAt: createdAt,
          vectorClock: null,
        );

        final roundtripped = roundtrip(original);
        expect(roundtripped, equals(original));
        final report = roundtripped as AgentReportEntity;
        expect(report.content, isEmpty);
      });

      test('runtimeType discriminator key is "agentReport"', () {
        final entity = AgentDomainEntity.agentReport(
          id: 'report-004',
          agentId: 'agent-001',
          scope: 'test',
          createdAt: createdAt,
          vectorClock: null,
        );

        final json = entity.toJson();
        expect(json['runtimeType'], equals('agentReport'));
      });
    });

    group('AgentReportHeadEntity (agentReportHead variant)', () {
      test('roundtrips all fields', () {
        final original = AgentDomainEntity.agentReportHead(
          id: 'head-001',
          agentId: 'agent-001',
          scope: 'weekly-summary',
          reportId: 'report-001',
          updatedAt: updatedAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<AgentReportHeadEntity>());
      });

      test('roundtrips with deletedAt set', () {
        final original = AgentDomainEntity.agentReportHead(
          id: 'head-002',
          agentId: 'agent-001',
          scope: 'daily',
          reportId: 'report-010',
          updatedAt: updatedAt,
          vectorClock: null,
          deletedAt: DateTime(2026, 2, 20, 23, 59),
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(
          (roundtripped as AgentReportHeadEntity).deletedAt,
          equals(DateTime(2026, 2, 20, 23, 59)),
        );
      });

      test('runtimeType discriminator key is "agentReportHead"', () {
        final entity = AgentDomainEntity.agentReportHead(
          id: 'head-003',
          agentId: 'agent-001',
          scope: 'test',
          reportId: 'report-000',
          updatedAt: updatedAt,
          vectorClock: null,
        );

        final json = entity.toJson();
        expect(json['runtimeType'], equals('agentReportHead'));
      });
    });

    group('ScheduledWakeEntity (scheduledWake variant)', () {
      test('roundtrips all fields', () {
        final original = AgentDomainEntity.scheduledWake(
          id: 'scheduled_wake:agent-001:day:dayplan-2026-05-25',
          agentId: 'agent-001',
          scheduledAt: DateTime(2026, 5, 25, 8, 30),
          status: ScheduledWakeStatus.pending,
          reason: 'scheduled',
          updatedAt: updatedAt,
          vectorClock: vectorClock,
          triggerTokens: const ['planning_day:dayplan-2026-05-25'],
          workspaceKey: 'day:dayplan-2026-05-25',
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<ScheduledWakeEntity>());
      });

      test('defaults triggerTokens to empty and tolerates null workspace', () {
        final original = AgentDomainEntity.scheduledWake(
          id: 'scheduled_wake:agent-001:global',
          agentId: 'agent-001',
          scheduledAt: DateTime(2026, 5, 25, 9),
          status: ScheduledWakeStatus.consumed,
          reason: 'scheduled',
          updatedAt: updatedAt,
          vectorClock: null,
          consumedAt: DateTime(2026, 5, 25, 9, 1),
        );

        final roundtripped = roundtrip(original) as ScheduledWakeEntity;

        expect(roundtripped.triggerTokens, isEmpty);
        expect(roundtripped.workspaceKey, isNull);
        expect(roundtripped.status, ScheduledWakeStatus.consumed);
        expect(roundtripped.consumedAt, DateTime(2026, 5, 25, 9, 1));
      });

      test('runtimeType discriminator key is "scheduledWake"', () {
        final json = AgentDomainEntity.scheduledWake(
          id: 'scheduled_wake:agent-001:global',
          agentId: 'agent-001',
          scheduledAt: DateTime(2026, 5, 25, 9),
          status: ScheduledWakeStatus.pending,
          reason: 'scheduled',
          updatedAt: updatedAt,
          vectorClock: null,
        ).toJson();
        expect(json['runtimeType'], equals('scheduledWake'));
      });
    });

    group('Daily OS capture variants', () {
      test('CaptureEntity roundtrips all fields incl. dayId', () {
        final original = AgentDomainEntity.capture(
          id: 'capture-001',
          agentId: 'day-agent-001',
          transcript: 'Prep demo and buy milk',
          capturedAt: DateTime(2026, 5, 25, 8, 30),
          createdAt: createdAt,
          vectorClock: vectorClock,
          dayId: 'dayplan-2026-05-25',
          audioRef: 'audio-001',
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<CaptureEntity>());
        expect((roundtripped as CaptureEntity).dayId, 'dayplan-2026-05-25');
        expect(roundtripped.toJson()['runtimeType'], equals('capture'));
      });

      test('CaptureEntity from an older peer (no dayId) deserializes', () {
        // A capture synced from a build predating ADR 0022 carries no dayId;
        // the defaulted field must not throw on fromJson.
        final legacyJson = {
          'runtimeType': 'capture',
          'id': 'capture-legacy',
          'agentId': 'day-agent-001',
          'transcript': 'old capture',
          'capturedAt': DateTime(2026, 5, 25, 8, 30).toIso8601String(),
          'createdAt': createdAt.toIso8601String(),
          'vectorClock': null,
        };

        final decoded = AgentDomainEntity.fromJson(legacyJson) as CaptureEntity;

        expect(decoded.dayId, isEmpty);
        expect(decoded.transcript, 'old capture');
      });

      test('ParsedItemEntity roundtrips optional reconcile fields', () {
        final original = AgentDomainEntity.parsedItem(
          id: 'parsed-001',
          agentId: 'day-agent-001',
          captureId: 'capture-001',
          kind: ParsedItemKind.update,
          title: 'Prep demo',
          categoryId: 'work',
          confidence: ParsedItemConfidence.medium,
          confidenceScore: 0.62,
          createdAt: createdAt,
          vectorClock: vectorClock,
          lowConfidence: true,
          spokenPhrase: 'demo prep',
          matchedTaskId: 'task-001',
          estimateMinutes: 45,
          timeAnchor: 'today afternoon',
          proposedUpdate: 'Move later',
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final item = roundtripped as ParsedItemEntity;
        expect(item.lowConfidence, isTrue);
        expect(item.confidenceScore, 0.62);
        expect(item.toJson()['runtimeType'], equals('parsedItem'));
      });

      test('DayPlanEntity roundtrips drafted plan fields', () {
        final original = AgentDomainEntity.dayPlan(
          id: 'day_agent_plan:dayplan-2026-05-25',
          agentId: 'day-agent-001',
          dayId: 'dayplan-2026-05-25',
          captureId: 'capture-001',
          planDate: DateTime(2026, 5, 25),
          data: DayPlanData(
            planDate: DateTime(2026, 5, 25),
            status: const DayPlanStatus.draft(),
            dayLabel: 'Focused workday',
            plannedBlocks: [
              PlannedBlock(
                id: 'block-001',
                categoryId: 'work',
                startTime: DateTime(2026, 5, 25, 9),
                endTime: DateTime(2026, 5, 25, 10, 30),
                taskId: 'task-001',
                title: 'Prep demo',
                reason: 'High-energy focus window.',
              ),
            ],
            pinnedTasks: const [
              PinnedTaskRef(taskId: 'task-001', categoryId: 'work'),
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
          scheduledMinutes: 90,
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final plan = roundtripped as DayPlanEntity;
        expect(plan.toJson()['runtimeType'], equals('dayPlan'));
        expect(plan.data.plannedBlocks.single.reason, isNotEmpty);
        expect(plan.energyBands.single.level, DayAgentEnergyLevel.high);
      });

      test('AttentionRequestEntity roundtrips bounded bid fields', () {
        final original = AgentDomainEntity.attentionRequest(
          id: 'attention-request-001',
          agentId: 'task-agent-001',
          kind: AttentionRequestKind.task,
          title: 'Prep demo',
          categoryId: 'work',
          requestedMinutes: 45,
          impact: 4,
          urgency: 5,
          energyFit: AttentionEnergyFit.high,
          evidenceRefs: const [
            AttentionEvidenceRef(
              kind: AttentionEvidenceKind.task,
              id: 'task-001',
              label: 'Demo task',
            ),
          ],
          scopeKind: AttentionClaimScopeKind.dateRange,
          rangeStart: DateTime(2026, 5, 25),
          rangeEnd: DateTime(2026, 5, 26),
          earliestStart: DateTime(2026, 5, 25, 9),
          latestEnd: DateTime(2026, 5, 25, 12),
          deadline: DateTime(2026, 5, 25, 11),
          nextReviewAt: DateTime(2026, 5, 24, 18),
          targetId: 'task-001',
          targetKind: 'task',
          rationale: 'Deadline-bound preparation.',
          createdAt: createdAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final request = roundtripped as AttentionRequestEntity;
        expect(request.toJson()['runtimeType'], equals('attentionRequest'));
        expect(request.scopeKind, equals(AttentionClaimScopeKind.dateRange));
        expect(request.status, equals(AttentionRequestStatus.pending));
        expect(request.rangeStart, equals(DateTime(2026, 5, 25)));
        expect(request.rangeEnd, equals(DateTime(2026, 5, 26)));
        expect(request.nextReviewAt, equals(DateTime(2026, 5, 24, 18)));
        expect(request.evidenceRefs.single.kind, AttentionEvidenceKind.task);
      });

      test('AttentionClaimDispositionEntity roundtrips lifecycle fields', () {
        final original = AgentDomainEntity.attentionClaimDisposition(
          id: 'attention-disposition-001',
          agentId: 'planner-agent-001',
          requestId: 'attention-request-001',
          status: AttentionClaimStatus.deferred,
          awardId: 'attention-award-001',
          planId: 'day_agent_plan:dayplan-2026-05-25',
          changeSetId: 'changeset-001',
          reason: 'Needs a clearer window.',
          nextReviewAt: DateTime(2026, 5, 24, 18),
          createdAt: createdAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final disposition = roundtripped as AttentionClaimDispositionEntity;
        expect(
          disposition.toJson()['runtimeType'],
          equals('attentionClaimDisposition'),
        );
        expect(disposition.status, equals(AttentionClaimStatus.deferred));
        expect(disposition.requestId, equals('attention-request-001'));
        expect(disposition.nextReviewAt, equals(DateTime(2026, 5, 24, 18)));
      });

      test('AttentionAwardEntity roundtrips planner award fields', () {
        final original = AgentDomainEntity.attentionAward(
          id: 'attention-award-001',
          agentId: 'day-agent-001',
          requestId: 'attention-request-001',
          dayId: 'dayplan-2026-05-25',
          planId: 'day_agent_plan:dayplan-2026-05-25',
          blockId: 'attention_block:dayplan-2026-05-25:request-001',
          categoryId: 'work',
          title: 'Prep demo',
          startTime: DateTime(2026, 5, 25, 9),
          endTime: DateTime(2026, 5, 25, 9, 45),
          rank: 1,
          utilityScore: 5125,
          taskId: 'task-001',
          rationale: 'Highest utility request.',
          createdAt: createdAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final award = roundtripped as AttentionAwardEntity;
        expect(award.toJson()['runtimeType'], equals('attentionAward'));
        expect(award.status, equals(AttentionAwardStatus.proposed));
        expect(award.utilityScore, greaterThan(0));
      });

      test('StandingAgreementEntity roundtrips durable policy fields', () {
        final original = AgentDomainEntity.standingAgreement(
          id: 'standing-agreement-fitness-weekly',
          agentId: 'fitness-agent-001',
          title: 'Strength training three times per week',
          scope: StandingAgreementScope.fitness,
          cadence: StandingAgreementCadence.weekly,
          enforcement: StandingAgreementEnforcement.nonNegotiable,
          approvalMode: StandingAgreementApprovalMode.autoAccept,
          categoryId: 'health',
          targetId: 'habit-strength',
          targetKind: 'habit',
          minCount: 3,
          minMinutes: 135,
          preferredSessionMinutes: 45,
          canPreempt: true,
          priority: 90,
          preemptibleCategoryIds: const ['admin'],
          protectedCategoryIds: const ['sleep'],
          evidenceRefs: const [
            AttentionEvidenceRef(
              kind: AttentionEvidenceKind.outcome,
              id: 'fitness-outcome-001',
              label: 'Strength target',
            ),
          ],
          activeFrom: DateTime(2026, 5),
          activeUntil: DateTime(2026, 8),
          rationale: 'Protect baseline strength work.',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final agreement = roundtripped as StandingAgreementEntity;
        expect(
          agreement.toJson()['runtimeType'],
          equals('standingAgreement'),
        );
        expect(agreement.scope, equals(StandingAgreementScope.fitness));
        expect(agreement.cadence, equals(StandingAgreementCadence.weekly));
        expect(agreement.minCount, equals(3));
        expect(agreement.minMinutes, equals(135));
        expect(agreement.canPreempt, isTrue);
        expect(
          agreement.evidenceRefs.single.kind,
          equals(AttentionEvidenceKind.outcome),
        );
      });
    });

    group('AgentUnknownEntity fallback (unknown variant)', () {
      test('deserializes unknown runtimeType to AgentUnknownEntity', () {
        final json = <String, dynamic>{
          'runtimeType': 'futureVariantNotYetKnown',
          'id': 'unknown-001',
          'agentId': 'agent-001',
          'createdAt': createdAt.toIso8601String(),
          'vectorClock': null,
          'deletedAt': null,
        };

        final result = AgentDomainEntity.fromJson(json);

        expect(result, isA<AgentUnknownEntity>());
        final unknown = result as AgentUnknownEntity;
        expect(unknown.id, equals('unknown-001'));
        expect(unknown.agentId, equals('agent-001'));
        expect(unknown.createdAt, equals(createdAt));
        expect(unknown.vectorClock, isNull);
        expect(unknown.deletedAt, isNull);
      });

      test('explicit unknown variant roundtrips', () {
        final original = AgentDomainEntity.unknown(
          id: 'unknown-002',
          agentId: 'agent-001',
          createdAt: createdAt,
          vectorClock: vectorClock,
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        expect(roundtripped, isA<AgentUnknownEntity>());
      });

      test('unknown variant with vectorClock and deletedAt roundtrips', () {
        final original = AgentDomainEntity.unknown(
          id: 'unknown-003',
          agentId: 'agent-002',
          createdAt: createdAt,
          vectorClock: const VectorClock({'node-x': 7}),
          deletedAt: DateTime(2026, 2, 20, 16, 30),
        );

        final roundtripped = roundtrip(original);

        expect(roundtripped, equals(original));
        final unknown = roundtripped as AgentUnknownEntity;
        expect(unknown.vectorClock, equals(const VectorClock({'node-x': 7})));
        expect(unknown.deletedAt, equals(DateTime(2026, 2, 20, 16, 30)));
      });
    });

    group('ChangeDecisionEntity (changeDecision variant)', () {
      test(
        'user rejection roundtrips with rejectionReason and default actor',
        () {
          final original =
              AgentDomainEntity.changeDecision(
                    id: 'decision-001',
                    agentId: 'agent-010',
                    changeSetId: 'cs-001',
                    itemIndex: 2,
                    toolName: 'update_task_priority',
                    verdict: ChangeDecisionVerdict.rejected,
                    createdAt: createdAt,
                    vectorClock: vectorClock,
                    taskId: 'task-001',
                    rejectionReason: 'Already P1, unnecessary',
                    humanSummary: 'Set priority to P1',
                    args: const {'priority': 'P1'},
                  )
                  as ChangeDecisionEntity;

          final roundtripped = roundtrip(original) as ChangeDecisionEntity;

          expect(roundtripped, equals(original));
          expect(roundtripped.actor, equals(DecisionActor.user));
          expect(
            roundtripped.rejectionReason,
            equals('Already P1, unnecessary'),
          );
          expect(roundtripped.retractionReason, isNull);
          expect(roundtripped.verdict, equals(ChangeDecisionVerdict.rejected));
        },
      );

      test('agent retraction roundtrips with actor and retractionReason', () {
        final original =
            AgentDomainEntity.changeDecision(
                  id: 'decision-002',
                  agentId: 'agent-010',
                  changeSetId: 'cs-001',
                  itemIndex: 0,
                  toolName: 'update_task_priority',
                  verdict: ChangeDecisionVerdict.retracted,
                  actor: DecisionActor.agent,
                  retractionReason: 'Duplicate of open proposal fp=a7c',
                  humanSummary: 'Set priority to P1',
                  args: const {'priority': 'P1'},
                  createdAt: createdAt,
                  vectorClock: vectorClock,
                  taskId: 'task-001',
                )
                as ChangeDecisionEntity;

        final roundtripped = roundtrip(original) as ChangeDecisionEntity;

        expect(roundtripped, equals(original));
        expect(roundtripped.actor, equals(DecisionActor.agent));
        expect(roundtripped.verdict, equals(ChangeDecisionVerdict.retracted));
        expect(
          roundtripped.retractionReason,
          equals('Duplicate of open proposal fp=a7c'),
        );
        expect(roundtripped.rejectionReason, isNull);
      });

      test(
        'deserializing legacy JSON without actor defaults to DecisionActor.user',
        () {
          // Simulates a row persisted before the actor field existed: no
          // `actor` key present in the JSON blob. The @Default on the factory
          // must backfill `DecisionActor.user` so old decisions are still
          // classified as user verdicts.
          final legacyJson = <String, dynamic>{
            'runtimeType': 'changeDecision',
            'id': 'decision-legacy-001',
            'agentId': 'agent-010',
            'changeSetId': 'cs-legacy',
            'itemIndex': 1,
            'toolName': 'set_task_title',
            'verdict': 'confirmed',
            'createdAt': createdAt.toIso8601String(),
            'vectorClock': const {'host-a': 1},
            'taskId': 'task-legacy',
            'humanSummary': 'Set title to "Fix bug"',
          };

          final decoded =
              AgentDomainEntity.fromJson(legacyJson) as ChangeDecisionEntity;

          expect(decoded.actor, equals(DecisionActor.user));
          expect(decoded.verdict, equals(ChangeDecisionVerdict.confirmed));
          expect(decoded.retractionReason, isNull);
          expect(decoded.rejectionReason, isNull);
        },
      );

      test('runtimeType discriminator key is "changeDecision"', () {
        final original =
            AgentDomainEntity.changeDecision(
                  id: 'decision-003',
                  agentId: 'agent-010',
                  changeSetId: 'cs-001',
                  itemIndex: 0,
                  toolName: 'update_task_due_date',
                  verdict: ChangeDecisionVerdict.confirmed,
                  createdAt: createdAt,
                  vectorClock: vectorClock,
                )
                as ChangeDecisionEntity;

        final json = original.toJson();

        expect(json['runtimeType'], equals('changeDecision'));
      });
    });
  });

  // Merged from soul_document_serialization_test.dart (one test file
  // per source rule).

  group('SoulDocumentEntity serialization', () {
    test('roundtrips through JSON', () {
      final entity = makeTestSoulDocument();
      final json = entity.toJson();
      final decoded = AgentDomainEntity.fromJson(json);
      expect(decoded, equals(entity));
    });

    test('runtimeType is soulDocument', () {
      final entity = makeTestSoulDocument();
      final json = entity.toJson();
      expect(json['runtimeType'], 'soulDocument');
    });

    test('roundtrips through JSON string encoding', () {
      final entity = makeTestSoulDocument(displayName: 'Laura');
      final jsonStr = jsonEncode(entity.toJson());
      final decoded = AgentDomainEntity.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
      expect(decoded, isA<SoulDocumentEntity>());
      expect((decoded as SoulDocumentEntity).displayName, 'Laura');
    });
  });

  group('SoulDocumentVersionEntity serialization', () {
    test('roundtrips through JSON', () {
      final entity = makeTestSoulDocumentVersion(
        voiceDirective: 'Be warm.',
        toneBounds: 'No sarcasm.',
        coachingStyle: 'Gentle nudges.',
        antiSycophancyPolicy: 'Push back on bad ideas.',
      );
      final json = entity.toJson();
      final decoded = AgentDomainEntity.fromJson(json);
      expect(decoded, equals(entity));
    });

    test('runtimeType is soulDocumentVersion', () {
      final entity = makeTestSoulDocumentVersion();
      final json = entity.toJson();
      expect(json['runtimeType'], 'soulDocumentVersion');
    });

    test('preserves all personality fields', () {
      final entity = makeTestSoulDocumentVersion(
        voiceDirective: 'voice',
        toneBounds: 'bounds',
        coachingStyle: 'style',
        antiSycophancyPolicy: 'policy',
        sourceSessionId: 'session-1',
        diffFromVersionId: 'version-0',
      );
      final json = entity.toJson();
      final decoded =
          AgentDomainEntity.fromJson(json) as SoulDocumentVersionEntity;
      expect(decoded.voiceDirective, 'voice');
      expect(decoded.toneBounds, 'bounds');
      expect(decoded.coachingStyle, 'style');
      expect(decoded.antiSycophancyPolicy, 'policy');
      expect(decoded.sourceSessionId, 'session-1');
      expect(decoded.diffFromVersionId, 'version-0');
    });

    test('defaults empty strings for optional personality fields', () {
      final entity = makeTestSoulDocumentVersion();
      expect(entity.toneBounds, '');
      expect(entity.coachingStyle, '');
      expect(entity.antiSycophancyPolicy, '');
    });
  });

  group('SoulDocumentHeadEntity serialization', () {
    test('roundtrips through JSON', () {
      final entity = makeTestSoulDocumentHead();
      final json = entity.toJson();
      final decoded = AgentDomainEntity.fromJson(json);
      expect(decoded, equals(entity));
    });

    test('runtimeType is soulDocumentHead', () {
      final entity = makeTestSoulDocumentHead();
      final json = entity.toJson();
      expect(json['runtimeType'], 'soulDocumentHead');
    });
  });

  group('SoulAssignmentLink serialization', () {
    test('roundtrips through JSON', () {
      final link = makeTestSoulAssignmentLink();
      final json = link.toJson();
      final decoded = AgentLink.fromJson(json);
      expect(decoded, equals(link));
    });

    test('runtimeType is soulAssignment', () {
      final link = makeTestSoulAssignmentLink();
      final json = link.toJson();
      expect(json['runtimeType'], 'soulAssignment');
    });
  });

  group('unknown fallback', () {
    test('unknown runtimeType deserializes to AgentUnknownEntity', () {
      final json = <String, dynamic>{
        'runtimeType': 'futureEntityType',
        'id': 'x',
        'agentId': 'y',
        'createdAt': DateTime(2024, 3, 15).toIso8601String(),
      };
      final decoded = AgentDomainEntity.fromJson(json);
      expect(decoded, isA<AgentUnknownEntity>());
    });
  });
}
