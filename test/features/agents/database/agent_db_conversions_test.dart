import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_db_conversions.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/sync/g_counter.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../test_utils.dart';

enum _GeneratedReportContentShape {
  string,
  markdownString,
  markdownNumber,
  firstString,
  firstNumber,
  emptyMap,
}

class _GeneratedReportContentScenario {
  const _GeneratedReportContentScenario({
    required this.shape,
    required this.seed,
  });

  final _GeneratedReportContentShape shape;
  final int seed;

  Object get content {
    return switch (shape) {
      _GeneratedReportContentShape.string => 'report body $seed',
      _GeneratedReportContentShape.markdownString => {
        'markdown': '# Report $seed',
        'html': '<h1>ignored $seed</h1>',
      },
      _GeneratedReportContentShape.markdownNumber => {
        'markdown': seed,
        'html': '<h1>ignored $seed</h1>',
      },
      _GeneratedReportContentShape.firstString => {
        'html': '<h1>Report $seed</h1>',
        'plain': 'ignored $seed',
      },
      _GeneratedReportContentShape.firstNumber => {
        'count': seed,
        'plain': 'ignored $seed',
      },
      _GeneratedReportContentShape.emptyMap => <String, dynamic>{},
    };
  }

  String get expectedContent {
    return switch (shape) {
      _GeneratedReportContentShape.string => 'report body $seed',
      _GeneratedReportContentShape.markdownString => '# Report $seed',
      _GeneratedReportContentShape.markdownNumber => '$seed',
      _GeneratedReportContentShape.firstString => '<h1>Report $seed</h1>',
      _GeneratedReportContentShape.firstNumber => '$seed',
      _GeneratedReportContentShape.emptyMap => '',
    };
  }

  @override
  String toString() {
    return '_GeneratedReportContentScenario('
        'shape: $shape, seed: $seed)';
  }
}

extension _AnyGeneratedReportContent on glados.Any {
  glados.Generator<_GeneratedReportContentShape> get reportContentShape =>
      glados.AnyUtils(this).choose(_GeneratedReportContentShape.values);

  glados.Generator<_GeneratedReportContentScenario> get reportContentScenario =>
      glados.CombinableAny(this).combine2(
        reportContentShape,
        glados.IntAnys(this).intInRange(0, 10000),
        (_GeneratedReportContentShape shape, int seed) =>
            _GeneratedReportContentScenario(shape: shape, seed: seed),
      );
}

void main() {
  const id = 'report-id-1';
  const agentId = 'agent-id-1';
  final createdAt = DateTime(2026, 2, 21);
  final updatedAt = DateTime(2026, 2, 21);

  AgentEntity makeRow(Map<String, dynamic> serializedJson) {
    return AgentEntity(
      id: id,
      agentId: agentId,
      type: 'agentReport',
      createdAt: createdAt,
      updatedAt: updatedAt,
      serialized: jsonEncode(serializedJson),
      schemaVersion: 1,
    );
  }

  Map<String, dynamic> baseReportJson({required Object content}) {
    return {
      'runtimeType': 'agentReport',
      'id': id,
      'agentId': agentId,
      'scope': 'test-scope',
      'createdAt': createdAt.toIso8601String(),
      'vectorClock': null,
      'content': content,
    };
  }

  group('AgentDbConversions.fromEntityRow — _migrateReportContent', () {
    test(
      'old-format Map content with "markdown" key is migrated to String value',
      () {
        final row = makeRow(
          baseReportJson(content: {'markdown': '# Report'}),
        );

        final entity = AgentDbConversions.fromEntityRow(row);

        expect(entity, isA<AgentReportEntity>());
        final report = entity as AgentReportEntity;
        expect(report.content, '# Report');
      },
    );

    test('new-format String content passes through unchanged', () {
      const markdownString = '# Already a String';
      final row = makeRow(
        baseReportJson(content: markdownString),
      );

      final entity = AgentDbConversions.fromEntityRow(row);

      expect(entity, isA<AgentReportEntity>());
      final report = entity as AgentReportEntity;
      expect(report.content, markdownString);
    });

    test(
      'old-format Map content with no "markdown" key falls back to first value',
      () {
        final row = makeRow(
          baseReportJson(content: {'html': '<h1>Report</h1>'}),
        );

        final entity = AgentDbConversions.fromEntityRow(row);

        expect(entity, isA<AgentReportEntity>());
        final report = entity as AgentReportEntity;
        expect(report.content, '<h1>Report</h1>');
      },
    );

    test('old-format Map content with empty map returns empty string', () {
      final row = makeRow(
        baseReportJson(content: <String, dynamic>{}),
      );

      final entity = AgentDbConversions.fromEntityRow(row);

      expect(entity, isA<AgentReportEntity>());
      final report = entity as AgentReportEntity;
      expect(report.content, '');
    });

    glados.Glados(
      glados.any.reportContentScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test('migrates generated report content shapes', (scenario) {
      final row = makeRow(baseReportJson(content: scenario.content));

      final entity = AgentDbConversions.fromEntityRow(row);

      expect(entity, isA<AgentReportEntity>(), reason: '$scenario');
      final report = entity as AgentReportEntity;
      expect(report.content, scenario.expectedContent, reason: '$scenario');
    }, tags: 'glados');
  });

  group('AgentDbConversions — G-counter migration + dual-write', () {
    const sentinel = AgentDbConversions.preGCounterSentinelHost;

    AgentEntity makeStateRow(Map<String, dynamic> serializedJson) {
      return AgentEntity(
        id: 'state-1',
        agentId: agentId,
        type: AgentEntityTypes.agentState,
        createdAt: createdAt,
        updatedAt: updatedAt,
        serialized: jsonEncode(serializedJson),
        schemaVersion: 1,
      );
    }

    Map<String, dynamic> stateJson({
      Map<String, dynamic> extra = const {},
      Map<String, dynamic> slots = const {},
    }) {
      return {
        'runtimeType': 'agentState',
        'id': 'state-1',
        'agentId': agentId,
        'revision': 1,
        'slots': slots,
        'updatedAt': updatedAt.toIso8601String(),
        'vectorClock': null,
        ...extra,
      };
    }

    AgentStateEntity readState(Map<String, dynamic> serializedJson) =>
        AgentDbConversions.fromEntityRow(makeStateRow(serializedJson))
            as AgentStateEntity;

    test('seeds a legacy scalar counter under the shared sentinel host', () {
      final state = readState(
        stateJson(
          extra: {'wakeCounter': 42},
          slots: {'totalSessionsCompleted': 7, 'weeklyReviewCount': 3},
        ),
      );

      expect(state.wakeCounter.byHost, {sentinel: 42});
      expect(state.wakeCounter.value, 42);
      expect(state.slots.totalSessionsCompleted.value, 7);
      expect(state.slots.weeklyReviewCount.value, 3);
    });

    test('absent counters default to an empty G-counter (value 0)', () {
      final state = readState(stateJson());

      expect(state.wakeCounter.value, 0);
      expect(state.slots.totalSessionsCompleted.value, 0);
      expect(state.slots.weeklyReviewCount.value, 0);
    });

    test('a present per-host map wins; the stale legacy mirror is ignored', () {
      // A new-client write carries both; the map is authoritative.
      final state = readState(
        stateJson(
          extra: {
            'wakeCounterByHost': {'h1': 2, 'h2': 3},
            'wakeCounter': 999, // stale mirror — must be ignored
          },
        ),
      );

      expect(state.wakeCounter.byHost, {'h1': 2, 'h2': 3});
      expect(state.wakeCounter.value, 5);
    });

    test(
      'toEntityCompanion dual-writes the per-host map and the int mirror',
      () {
        final entity = AgentDomainEntity.agentState(
          id: 'state-1',
          agentId: agentId,
          revision: 1,
          slots: const AgentSlots(totalSessionsCompleted: GCounter({'h1': 4})),
          updatedAt: updatedAt,
          vectorClock: null,
          wakeCounter: const GCounter({'h1': 2, 'h2': 3}),
        );

        final companion = AgentDbConversions.toEntityCompanion(entity);
        final json =
            jsonDecode(companion.serialized.value) as Map<String, dynamic>;

        // Per-host map (authoritative) ...
        expect(json['wakeCounterByHost'], {'h1': 2, 'h2': 3});
        // ... plus the legacy scalar mirror (= value) for old clients.
        expect(json['wakeCounter'], 5);
        final slots = json['slots'] as Map<String, dynamic>;
        expect(slots['totalSessionsCompletedByHost'], {'h1': 4});
        expect(slots['totalSessionsCompleted'], 4);
      },
    );

    test('round-trips a multi-host G-counter through write then read', () {
      final entity = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: agentId,
        revision: 1,
        slots: const AgentSlots(
          weeklyReviewCount: GCounter({'h1': 1, 'h2': 1}),
        ),
        updatedAt: updatedAt,
        vectorClock: null,
        wakeCounter: const GCounter({'h1': 5, 'h2': 9}),
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);
      final roundtripped = readState(
        jsonDecode(companion.serialized.value) as Map<String, dynamic>,
      );

      expect(roundtripped.wakeCounter, const GCounter({'h1': 5, 'h2': 9}));
      expect(
        roundtripped.slots.weeklyReviewCount,
        const GCounter({'h1': 1, 'h2': 1}),
      );
    });

    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(1, 1000), // legacy value n
      glados.IntAnys(glados.any).intInRange(1, 6), // number of devices
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'N devices migrating the same legacy scalar converge to n, not N·n '
      '(the overcount trap)',
      (n, deviceCount) {
        // Every device independently migrates a legacy row carrying the same n
        // (they had LWW-converged to it). Merging must preserve n, not sum it.
        final migrated = [
          for (var i = 0; i < deviceCount; i++)
            readState(stateJson(extra: {'wakeCounter': n})).wakeCounter,
        ];
        final merged = migrated.fold(
          const GCounter.empty(),
          (acc, c) => acc.merge(c),
        );

        expect(merged.value, n, reason: 'n=$n devices=$deviceCount');
      },
      tags: 'glados',
    );
  });

  group('AgentDbConversions — unknown entity variant', () {
    test('toEntityCompanion handles unknown variant correctly', () {
      final entity = AgentDomainEntity.unknown(
        id: 'unknown-001',
        agentId: agentId,
        createdAt: createdAt,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.id, const Value('unknown-001'));
      expect(companion.agentId, const Value(agentId));
      expect(companion.type, const Value('unknown'));
      expect(companion.createdAt, Value(createdAt));
      expect(companion.updatedAt, Value(createdAt));
      expect(companion.deletedAt, const Value<DateTime?>(null));
    });

    test('fromEntityRow roundtrips unknown variant', () {
      final entity = AgentDomainEntity.unknown(
        id: 'unknown-002',
        agentId: agentId,
        createdAt: createdAt,
      );
      final companion = AgentDbConversions.toEntityCompanion(entity);

      final row = AgentEntity(
        id: companion.id.value,
        agentId: agentId,
        type: 'unknown',
        createdAt: createdAt,
        updatedAt: createdAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromEntityRow(row);
      expect(result, isA<AgentUnknownEntity>());
      expect(result.id, 'unknown-002');
      expect(result.agentId, agentId);
    });
  });

  group('AgentDbConversions — messagePayload link variant', () {
    test('toLinkCompanion handles messagePayload link correctly', () {
      final link = model.AgentLink.messagePayload(
        id: 'link-mp-001',
        fromId: 'msg-001',
        toId: 'payload-001',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toLinkCompanion(link);

      expect(companion.id, const Value('link-mp-001'));
      expect(companion.fromId, const Value('msg-001'));
      expect(companion.toId, const Value('payload-001'));
      expect(companion.type, const Value('message_payload'));
    });
  });

  group('AgentDbConversions — Daily OS capture reconcile variants', () {
    test('toEntityCompanion writes capture type and timestamps', () {
      final entity = AgentDomainEntity.capture(
        id: 'capture-001',
        agentId: agentId,
        transcript: 'Prep demo',
        capturedAt: DateTime(2026, 2, 21, 8, 15),
        createdAt: createdAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.id, const Value('capture-001'));
      expect(companion.type, const Value(AgentEntityTypes.capture));
      expect(companion.subtype, const Value('capture-001'));
      expect(companion.createdAt, Value(createdAt));
      expect(companion.updatedAt, Value(createdAt));
    });

    test('fromEntityRow roundtrips parsedItem variant', () {
      final entity = AgentDomainEntity.parsedItem(
        id: 'parsed-001',
        agentId: agentId,
        captureId: 'capture-001',
        kind: ParsedItemKind.matched,
        title: 'Prep demo',
        categoryId: 'work',
        confidence: ParsedItemConfidence.high,
        confidenceScore: 0.91,
        createdAt: createdAt,
        vectorClock: const VectorClock({'node-a': 1}),
        matchedTaskId: 'task-001',
      );
      final companion = AgentDbConversions.toEntityCompanion(entity);

      final row = AgentEntity(
        id: 'parsed-001',
        agentId: agentId,
        type: AgentEntityTypes.parsedItem,
        subtype: ParsedItemKind.matched.name,
        createdAt: createdAt,
        updatedAt: createdAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromEntityRow(row);

      expect(result, isA<ParsedItemEntity>());
      final parsed = result as ParsedItemEntity;
      expect(parsed.captureId, 'capture-001');
      expect(parsed.kind, ParsedItemKind.matched);
      expect(parsed.matchedTaskId, 'task-001');
    });

    test('scheduledWake writes type/subtype and roundtrips through a row', () {
      final entity = AgentDomainEntity.scheduledWake(
        id: 'scheduled_wake:$agentId:day:dayplan-2026-05-25',
        agentId: agentId,
        scheduledAt: DateTime(2026, 5, 25, 8, 30),
        status: ScheduledWakeStatus.pending,
        reason: 'scheduled',
        updatedAt: updatedAt,
        vectorClock: const VectorClock({'node-a': 2}),
        triggerTokens: const ['planning_day:dayplan-2026-05-25'],
        workspaceKey: 'day:dayplan-2026-05-25',
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);
      expect(companion.type, const Value(AgentEntityTypes.scheduledWake));
      expect(companion.subtype, const Value('pending'));
      expect(companion.updatedAt, Value(updatedAt));

      final row = AgentEntity(
        id: entity.id,
        agentId: agentId,
        type: AgentEntityTypes.scheduledWake,
        subtype: 'pending',
        createdAt: updatedAt,
        updatedAt: updatedAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromEntityRow(row);
      expect(result, isA<ScheduledWakeEntity>());
      final wake = result as ScheduledWakeEntity;
      expect(wake.scheduledAt, DateTime(2026, 5, 25, 8, 30));
      expect(wake.workspaceKey, 'day:dayplan-2026-05-25');
      expect(wake.triggerTokens, ['planning_day:dayplan-2026-05-25']);
      expect(wake.status, ScheduledWakeStatus.pending);
    });

    test('toEntityCompanion writes dayPlan type, subtype, and timestamps', () {
      final entity = AgentDomainEntity.dayPlan(
        id: 'day_agent_plan:dayplan-2026-05-25',
        agentId: agentId,
        dayId: 'dayplan-2026-05-25',
        planDate: DateTime(2026, 5, 25),
        data: DayPlanData(
          planDate: DateTime(2026, 5, 25),
          status: const DayPlanStatus.draft(),
          plannedBlocks: [
            PlannedBlock(
              id: 'block-001',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'High-energy focus window.',
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
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.id, const Value('day_agent_plan:dayplan-2026-05-25'));
      expect(companion.type, const Value(AgentEntityTypes.dayPlan));
      expect(companion.subtype, const Value('dayplan-2026-05-25'));
      expect(companion.createdAt, Value(createdAt));
      expect(companion.updatedAt, Value(updatedAt));
    });

    test(
      'toEntityCompanion writes attention request type and scope subtype',
      () {
        final entity = AgentDomainEntity.attentionRequest(
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
            ),
          ],
          scopeKind: AttentionClaimScopeKind.deadline,
          createdAt: createdAt,
          vectorClock: null,
        );

        final companion = AgentDbConversions.toEntityCompanion(entity);

        expect(companion.id, const Value('attention-request-001'));
        expect(companion.type, const Value(AgentEntityTypes.attentionRequest));
        expect(companion.subtype, const Value('deadline'));
        expect(companion.createdAt, Value(createdAt));
        expect(companion.updatedAt, Value(createdAt));
      },
    );

    test(
      'toEntityCompanion writes claim disposition type and request subtype',
      () {
        final entity = AgentDomainEntity.attentionClaimDisposition(
          id: 'attention-disposition-001',
          agentId: 'planner-agent-001',
          requestId: 'attention-request-001',
          status: AttentionClaimStatus.deferred,
          planId: 'day_agent_plan:dayplan-2026-05-25',
          changeSetId: 'changeset-001',
          reason: 'Revisit tomorrow.',
          nextReviewAt: DateTime(2026, 5, 24, 18),
          createdAt: createdAt,
          vectorClock: null,
        );

        final companion = AgentDbConversions.toEntityCompanion(entity);

        expect(companion.id, const Value('attention-disposition-001'));
        expect(
          companion.type,
          const Value(AgentEntityTypes.attentionClaimDisposition),
        );
        expect(companion.subtype, const Value('attention-request-001'));
        expect(companion.createdAt, Value(createdAt));
        expect(companion.updatedAt, Value(createdAt));
      },
    );

    test('toEntityCompanion writes attention award type and day subtype', () {
      final entity = AgentDomainEntity.attentionAward(
        id: 'attention-award-001',
        agentId: 'day-agent-001',
        requestId: 'attention-request-001',
        dayId: 'dayplan-2026-05-25',
        planId: 'day_agent_plan:dayplan-2026-05-25',
        blockId: 'attention_block:dayplan-2026-05-25:attention-request-001',
        categoryId: 'work',
        title: 'Prep demo',
        startTime: DateTime(2026, 5, 25, 9),
        endTime: DateTime(2026, 5, 25, 9, 45),
        rank: 1,
        utilityScore: 5125,
        createdAt: createdAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.id, const Value('attention-award-001'));
      expect(companion.type, const Value(AgentEntityTypes.attentionAward));
      expect(companion.subtype, const Value('dayplan-2026-05-25'));
      expect(companion.createdAt, Value(createdAt));
      expect(companion.updatedAt, Value(createdAt));
    });

    test(
      'toEntityCompanion writes standing agreement type and scope subtype',
      () {
        final entity = AgentDomainEntity.standingAgreement(
          id: 'standing-agreement-001',
          agentId: 'fitness-agent-001',
          title: 'Exercise three times per week',
          scope: StandingAgreementScope.fitness,
          cadence: StandingAgreementCadence.weekly,
          enforcement: StandingAgreementEnforcement.nonNegotiable,
          approvalMode: StandingAgreementApprovalMode.autoAccept,
          minCount: 3,
          minMinutes: 135,
          preferredSessionMinutes: 45,
          priority: 80,
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        );

        final companion = AgentDbConversions.toEntityCompanion(entity);

        expect(companion.id, const Value('standing-agreement-001'));
        expect(
          companion.type,
          const Value(AgentEntityTypes.standingAgreement),
        );
        expect(companion.subtype, const Value('fitness'));
        expect(companion.createdAt, Value(createdAt));
        expect(companion.updatedAt, Value(updatedAt));
      },
    );

    test('toLinkCompanion writes capture reconcile link types', () {
      final captureLink = model.AgentLink.captureToParsedItem(
        id: 'link-capture-item',
        fromId: 'capture-001',
        toId: 'parsed-001',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );
      final taskLink = model.AgentLink.parsedItemToTask(
        id: 'link-item-task',
        fromId: 'parsed-001',
        toId: 'task-001',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );
      final planLink = model.AgentLink.captureToPlan(
        id: 'link-capture-plan',
        fromId: 'capture-001',
        toId: 'day_agent_plan:dayplan-2026-05-25',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final captureCompanion = AgentDbConversions.toLinkCompanion(captureLink);
      final taskCompanion = AgentDbConversions.toLinkCompanion(taskLink);
      final planCompanion = AgentDbConversions.toLinkCompanion(planLink);

      expect(
        captureCompanion.type,
        const Value(AgentLinkTypes.captureToParsedItem),
      );
      expect(
        taskCompanion.type,
        const Value(AgentLinkTypes.parsedItemToTask),
      );
      expect(
        planCompanion.type,
        const Value(AgentLinkTypes.captureToPlan),
      );
    });

    test('toLinkCompanion writes attention negotiation link types', () {
      final evidenceLink = model.AgentLink.attentionRequestEvidence(
        id: 'link-attention-evidence',
        fromId: 'attention-request-001',
        toId: 'task-001',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );
      final requestLink = model.AgentLink.attentionAwardRequest(
        id: 'link-attention-award-request',
        fromId: 'attention-award-001',
        toId: 'attention-request-001',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );
      final planLink = model.AgentLink.attentionAwardPlan(
        id: 'link-attention-award-plan',
        fromId: 'attention-award-001',
        toId: 'day_agent_plan:dayplan-2026-05-25',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final evidenceCompanion = AgentDbConversions.toLinkCompanion(
        evidenceLink,
      );
      final requestCompanion = AgentDbConversions.toLinkCompanion(requestLink);
      final planCompanion = AgentDbConversions.toLinkCompanion(planLink);

      expect(
        evidenceCompanion.type,
        const Value(AgentLinkTypes.attentionRequestEvidence),
      );
      expect(
        requestCompanion.type,
        const Value(AgentLinkTypes.attentionAwardRequest),
      );
      expect(
        planCompanion.type,
        const Value(AgentLinkTypes.attentionAwardPlan),
      );
    });

    test('fromLinkRow roundtrips capture reconcile links', () {
      final link = model.AgentLink.parsedItemToTask(
        id: 'link-item-task',
        fromId: 'parsed-001',
        toId: 'task-001',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );
      final companion = AgentDbConversions.toLinkCompanion(link);

      final row = AgentLink(
        id: 'link-item-task',
        fromId: 'parsed-001',
        toId: 'task-001',
        type: AgentLinkTypes.parsedItemToTask,
        createdAt: createdAt,
        updatedAt: updatedAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromLinkRow(row);

      expect(result, isA<model.ParsedItemToTaskLink>());
      expect(result.fromId, 'parsed-001');
      expect(result.toId, 'task-001');
    });

    test('fromLinkRow roundtrips captureToPlan link', () {
      final link = model.AgentLink.captureToPlan(
        id: 'link-capture-plan',
        fromId: 'capture-001',
        toId: 'day_agent_plan:dayplan-2026-05-25',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );
      final companion = AgentDbConversions.toLinkCompanion(link);

      final row = AgentLink(
        id: 'link-capture-plan',
        fromId: 'capture-001',
        toId: 'day_agent_plan:dayplan-2026-05-25',
        type: AgentLinkTypes.captureToPlan,
        createdAt: createdAt,
        updatedAt: updatedAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromLinkRow(row);

      expect(result, isA<model.CaptureToPlanLink>());
      expect(result.fromId, 'capture-001');
      expect(result.toId, 'day_agent_plan:dayplan-2026-05-25');
    });
  });

  group('AgentDbConversions.toEntityCompanion — subtype population', () {
    test('populates subtype with kind for agent entities', () {
      final entity = AgentDomainEntity.agent(
        id: 'agent-1',
        agentId: agentId,
        kind: 'task_agent',
        displayName: 'Test',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.subtype, const Value('task_agent'));
    });

    test('populates subtype with kind name for agentMessage entities', () {
      final entity = AgentDomainEntity.agentMessage(
        id: 'msg-1',
        agentId: agentId,
        threadId: 'thread-1',
        kind: AgentMessageKind.observation,
        createdAt: createdAt,
        metadata: const AgentMessageMetadata(runKey: 'rk-1'),
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.subtype, const Value('observation'));
    });

    test('populates subtype with scope for agentReport entities', () {
      final entity = AgentDomainEntity.agentReport(
        id: 'report-1',
        agentId: agentId,
        scope: 'weekly',
        createdAt: createdAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.subtype, const Value('weekly'));
    });

    test('populates subtype with scope for agentReportHead entities', () {
      final entity = AgentDomainEntity.agentReportHead(
        id: 'head-1',
        agentId: agentId,
        scope: 'daily',
        reportId: 'report-1',
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.subtype, const Value('daily'));
    });

    test('leaves subtype absent for agentState entities', () {
      final entity = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: agentId,
        revision: 1,
        slots: const AgentSlots(),
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.subtype, const Value<String?>.absent());
    });

    test(
      'populates subtype and timestamps for projectRecommendation entities',
      () {
        final entity = AgentDomainEntity.projectRecommendation(
          id: 'project-rec-001',
          agentId: agentId,
          projectId: 'project-001',
          title: 'Close the loop with George',
          position: 0,
          status: ProjectRecommendationStatus.active,
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: const VectorClock({}),
          rationale: 'The main delivery work is already complete',
          priority: 'MEDIUM',
        );

        final companion = AgentDbConversions.toEntityCompanion(entity);

        expect(companion.type, const Value('projectRecommendation'));
        expect(companion.subtype, const Value('active'));
        expect(companion.createdAt, Value(createdAt));
        expect(companion.updatedAt, Value(updatedAt));
      },
    );
  });

  group('AgentDbConversions — projectRecommendation entity roundtrip', () {
    test('fromEntityRow roundtrips projectRecommendation variant', () {
      final entity = AgentDomainEntity.projectRecommendation(
        id: 'project-rec-002',
        agentId: agentId,
        projectId: 'project-001',
        title: 'Archive the project',
        position: 1,
        status: ProjectRecommendationStatus.dismissed,
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: const VectorClock({}),
        rationale: 'No additional follow-up work is expected',
        priority: 'LOW',
        dismissedAt: updatedAt,
      );
      final companion = AgentDbConversions.toEntityCompanion(entity);

      final row = AgentEntity(
        id: 'project-rec-002',
        agentId: agentId,
        type: 'projectRecommendation',
        subtype: 'dismissed',
        createdAt: createdAt,
        updatedAt: updatedAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromEntityRow(row);

      expect(result, isA<ProjectRecommendationEntity>());
      final recommendation = result as ProjectRecommendationEntity;
      expect(recommendation.projectId, 'project-001');
      expect(recommendation.title, 'Archive the project');
      expect(recommendation.status, ProjectRecommendationStatus.dismissed);
      expect(recommendation.priority, 'LOW');
      expect(recommendation.dismissedAt, updatedAt);
    });
  });

  group('AgentDbConversions — agentTemplate entity roundtrip', () {
    test('toEntityCompanion produces correct companion', () {
      final entity = AgentDomainEntity.agentTemplate(
        id: 'tpl-001',
        agentId: 'tpl-001',
        displayName: 'Laura',
        kind: AgentTemplateKind.taskAgent,
        modelId: 'models/gemini-3.1-pro-preview',
        categoryIds: const {'cat-1'},
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.id, const Value('tpl-001'));
      expect(companion.type, const Value('agentTemplate'));
      expect(companion.subtype, const Value('taskAgent'));
      expect(companion.createdAt, Value(createdAt));
      expect(companion.updatedAt, Value(updatedAt));
    });

    test('fromEntityRow roundtrips agentTemplate variant', () {
      final entity = AgentDomainEntity.agentTemplate(
        id: 'tpl-002',
        agentId: 'tpl-002',
        displayName: 'Tom',
        kind: AgentTemplateKind.taskAgent,
        modelId: 'models/test',
        categoryIds: const {'cat-a', 'cat-b'},
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );
      final companion = AgentDbConversions.toEntityCompanion(entity);

      final row = AgentEntity(
        id: 'tpl-002',
        agentId: 'tpl-002',
        type: 'agentTemplate',
        subtype: 'taskAgent',
        createdAt: createdAt,
        updatedAt: updatedAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromEntityRow(row);
      expect(result, isA<AgentTemplateEntity>());
      final tpl = result as AgentTemplateEntity;
      expect(tpl.displayName, 'Tom');
      expect(tpl.kind, AgentTemplateKind.taskAgent);
      expect(tpl.categoryIds, containsAll(['cat-a', 'cat-b']));
    });
  });

  group('AgentDbConversions — agentTemplateVersion entity roundtrip', () {
    test('toEntityCompanion produces correct companion', () {
      final entity = AgentDomainEntity.agentTemplateVersion(
        id: 'ver-001',
        agentId: 'tpl-001',
        version: 1,
        status: AgentTemplateVersionStatus.active,
        directives: 'Be helpful.',
        authoredBy: 'user',
        createdAt: createdAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.id, const Value('ver-001'));
      expect(companion.type, const Value('agentTemplateVersion'));
      expect(companion.subtype, const Value('active'));
      expect(companion.createdAt, Value(createdAt));
      // Immutable — updatedAt = createdAt.
      expect(companion.updatedAt, Value(createdAt));
    });

    test('fromEntityRow roundtrips agentTemplateVersion variant', () {
      final entity = AgentDomainEntity.agentTemplateVersion(
        id: 'ver-002',
        agentId: 'tpl-001',
        version: 2,
        status: AgentTemplateVersionStatus.archived,
        directives: 'Updated directives.',
        authoredBy: 'admin',
        createdAt: createdAt,
        vectorClock: null,
      );
      final companion = AgentDbConversions.toEntityCompanion(entity);

      final row = AgentEntity(
        id: 'ver-002',
        agentId: 'tpl-001',
        type: 'agentTemplateVersion',
        subtype: 'archived',
        createdAt: createdAt,
        updatedAt: createdAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromEntityRow(row);
      expect(result, isA<AgentTemplateVersionEntity>());
      final ver = result as AgentTemplateVersionEntity;
      expect(ver.version, 2);
      expect(ver.status, AgentTemplateVersionStatus.archived);
      expect(ver.directives, 'Updated directives.');
      expect(ver.authoredBy, 'admin');
    });
  });

  group('AgentDbConversions — agentTemplateHead entity roundtrip', () {
    test('toEntityCompanion produces correct companion', () {
      final entity = AgentDomainEntity.agentTemplateHead(
        id: 'head-001',
        agentId: 'tpl-001',
        versionId: 'ver-001',
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.id, const Value('head-001'));
      expect(companion.type, const Value('agentTemplateHead'));
      // No subtype for head.
      expect(companion.subtype, const Value<String?>.absent());
      // Head has no createdAt — falls back to updatedAt.
      expect(companion.createdAt, Value(updatedAt));
      expect(companion.updatedAt, Value(updatedAt));
    });

    test('fromEntityRow roundtrips agentTemplateHead variant', () {
      final entity = AgentDomainEntity.agentTemplateHead(
        id: 'head-002',
        agentId: 'tpl-001',
        versionId: 'ver-003',
        updatedAt: updatedAt,
        vectorClock: null,
      );
      final companion = AgentDbConversions.toEntityCompanion(entity);

      final row = AgentEntity(
        id: 'head-002',
        agentId: 'tpl-001',
        type: 'agentTemplateHead',
        createdAt: updatedAt,
        updatedAt: updatedAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromEntityRow(row);
      expect(result, isA<AgentTemplateHeadEntity>());
      // Assert the full field set, not just versionId/agentId — id, updatedAt
      // and the (here-absent) deletedAt must all survive the round-trip.
      expect(result, equals(entity));
      final head = result as AgentTemplateHeadEntity;
      expect(head.id, 'head-002');
      expect(head.versionId, 'ver-003');
      expect(head.agentId, 'tpl-001');
      expect(head.updatedAt, updatedAt);
      expect(head.deletedAt, isNull);
    });

    test('fromEntityRow roundtrips a soft-deleted agentTemplateHead', () {
      // deletedAt lives inside the serialized JSON blob (not the row column),
      // so a head tombstone must survive companion serialisation + decode.
      final deletedAt = updatedAt.add(const Duration(hours: 2));
      final entity = AgentDomainEntity.agentTemplateHead(
        id: 'head-003',
        agentId: 'tpl-001',
        versionId: 'ver-004',
        updatedAt: updatedAt,
        vectorClock: null,
        deletedAt: deletedAt,
      );
      final companion = AgentDbConversions.toEntityCompanion(entity);

      final row = AgentEntity(
        id: 'head-003',
        agentId: 'tpl-001',
        type: 'agentTemplateHead',
        createdAt: updatedAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromEntityRow(row);
      expect(result, equals(entity));
      expect((result as AgentTemplateHeadEntity).deletedAt, deletedAt);
    });
  });

  group('AgentDbConversions — templateAssignment link', () {
    test('toLinkCompanion handles templateAssignment link correctly', () {
      final link = model.AgentLink.templateAssignment(
        id: 'link-ta-001',
        fromId: 'tpl-001',
        toId: 'agent-001',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toLinkCompanion(link);

      expect(companion.id, const Value('link-ta-001'));
      expect(companion.fromId, const Value('tpl-001'));
      expect(companion.toId, const Value('agent-001'));
      expect(companion.type, const Value('template_assignment'));
    });

    test('fromLinkRow roundtrips templateAssignment link', () {
      final link = model.AgentLink.templateAssignment(
        id: 'link-ta-002',
        fromId: 'tpl-001',
        toId: 'agent-002',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );
      final companion = AgentDbConversions.toLinkCompanion(link);

      final row = AgentLink(
        id: 'link-ta-002',
        fromId: 'tpl-001',
        toId: 'agent-002',
        type: 'template_assignment',
        createdAt: createdAt,
        updatedAt: updatedAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromLinkRow(row);
      expect(result, isA<model.TemplateAssignmentLink>());
      expect(result.fromId, 'tpl-001');
      expect(result.toId, 'agent-002');
    });
  });

  group('AgentDbConversions — agentDay link', () {
    test('toLinkCompanion handles agentDay link correctly', () {
      final link = model.AgentLink.agentDay(
        id: 'link-day-001',
        fromId: 'agent-001',
        toId: 'day-2026-06-01',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toLinkCompanion(link);

      expect(companion.id, const Value('link-day-001'));
      expect(companion.fromId, const Value('agent-001'));
      expect(companion.toId, const Value('day-2026-06-01'));
      expect(companion.type, const Value('agent_day'));
    });

    test('fromLinkRow roundtrips agentDay link', () {
      final link = model.AgentLink.agentDay(
        id: 'link-day-002',
        fromId: 'agent-001',
        toId: 'day-2026-06-01',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );
      final companion = AgentDbConversions.toLinkCompanion(link);

      final row = AgentLink(
        id: 'link-day-002',
        fromId: 'agent-001',
        toId: 'day-2026-06-01',
        type: 'agent_day',
        createdAt: createdAt,
        updatedAt: updatedAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromLinkRow(row);
      expect(result, isA<model.AgentDayLink>());
      expect(result.fromId, 'agent-001');
      expect(result.toId, 'day-2026-06-01');
    });

    test('preserves deletedAt for agentDay through to/from conversion', () {
      final deletedAt = DateTime(2026, 6, 2, 12);
      final link = model.AgentLink.agentDay(
        id: 'link-day-003',
        fromId: 'agent-001',
        toId: 'day-2026-06-01',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
        deletedAt: deletedAt,
      );

      final companion = AgentDbConversions.toLinkCompanion(link);
      expect(companion.deletedAt, Value(deletedAt));

      final row = AgentLink(
        id: 'link-day-003',
        fromId: 'agent-001',
        toId: 'day-2026-06-01',
        type: 'agent_day',
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromLinkRow(row);
      expect(result, isA<model.AgentDayLink>());
      expect(result.deletedAt, deletedAt);
    });
  });

  group('AgentDbConversions — improverTarget link', () {
    test('toLinkCompanion handles improverTarget link correctly', () {
      final link = model.AgentLink.improverTarget(
        id: 'link-it-001',
        fromId: 'improver-agent-001',
        toId: 'tpl-target-001',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toLinkCompanion(link);

      expect(companion.id, const Value('link-it-001'));
      expect(companion.fromId, const Value('improver-agent-001'));
      expect(companion.toId, const Value('tpl-target-001'));
      expect(companion.type, const Value('improver_target'));
    });

    test('fromLinkRow roundtrips improverTarget link', () {
      final link = model.AgentLink.improverTarget(
        id: 'link-it-002',
        fromId: 'improver-agent-001',
        toId: 'tpl-target-001',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );
      final companion = AgentDbConversions.toLinkCompanion(link);

      final row = AgentLink(
        id: 'link-it-002',
        fromId: 'improver-agent-001',
        toId: 'tpl-target-001',
        type: 'improver_target',
        createdAt: createdAt,
        updatedAt: updatedAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromLinkRow(row);
      expect(result, isA<model.ImproverTargetLink>());
      expect(result.fromId, 'improver-agent-001');
      expect(result.toId, 'tpl-target-001');
    });
  });

  group('AgentDbConversions — wakeTokenUsage entity roundtrip', () {
    test('toEntityCompanion produces correct companion', () {
      final entity = AgentDomainEntity.wakeTokenUsage(
        id: 'usage-001',
        agentId: agentId,
        runKey: 'run-001',
        threadId: 'thread-001',
        modelId: 'models/gemini-3.1-pro',
        templateId: 'tpl-001',
        templateVersionId: 'ver-001',
        inputTokens: 1000,
        outputTokens: 500,
        thoughtsTokens: 200,
        cachedInputTokens: 300,
        createdAt: createdAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.id, const Value('usage-001'));
      expect(companion.agentId, const Value(agentId));
      expect(companion.type, const Value('wakeTokenUsage'));
      // No subtype for wakeTokenUsage.
      expect(companion.subtype, const Value<String?>.absent());
      expect(companion.threadId, const Value('thread-001'));
      expect(companion.createdAt, Value(createdAt));
      // Immutable — updatedAt = createdAt.
      expect(companion.updatedAt, Value(createdAt));
    });

    test('fromEntityRow roundtrips wakeTokenUsage variant', () {
      final entity = AgentDomainEntity.wakeTokenUsage(
        id: 'usage-002',
        agentId: agentId,
        runKey: 'run-002',
        threadId: 'thread-002',
        modelId: 'models/gemini-3.1-flash',
        templateId: 'tpl-002',
        templateVersionId: 'ver-003',
        inputTokens: 2000,
        outputTokens: 800,
        thoughtsTokens: 150,
        cachedInputTokens: 500,
        createdAt: createdAt,
        vectorClock: null,
      );
      final companion = AgentDbConversions.toEntityCompanion(entity);

      final row = AgentEntity(
        id: 'usage-002',
        agentId: agentId,
        type: 'wakeTokenUsage',
        threadId: 'thread-002',
        createdAt: createdAt,
        updatedAt: createdAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromEntityRow(row);
      expect(result, isA<WakeTokenUsageEntity>());
      final usage = result as WakeTokenUsageEntity;
      expect(usage.runKey, 'run-002');
      expect(usage.modelId, 'models/gemini-3.1-flash');
      expect(usage.templateId, 'tpl-002');
      expect(usage.templateVersionId, 'ver-003');
      expect(usage.inputTokens, 2000);
      expect(usage.outputTokens, 800);
      expect(usage.thoughtsTokens, 150);
      expect(usage.cachedInputTokens, 500);
    });

    test('roundtrips with null optional fields', () {
      final entity = AgentDomainEntity.wakeTokenUsage(
        id: 'usage-003',
        agentId: agentId,
        runKey: 'run-003',
        threadId: 'thread-003',
        modelId: 'models/gemini-3.1-pro',
        createdAt: createdAt,
        vectorClock: null,
      );
      final companion = AgentDbConversions.toEntityCompanion(entity);

      final row = AgentEntity(
        id: 'usage-003',
        agentId: agentId,
        type: 'wakeTokenUsage',
        threadId: 'thread-003',
        createdAt: createdAt,
        updatedAt: createdAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromEntityRow(row);
      expect(result, isA<WakeTokenUsageEntity>());
      final usage = result as WakeTokenUsageEntity;
      expect(usage.templateId, equals(null));
      expect(usage.inputTokens, equals(null));
      expect(usage.outputTokens, equals(null));
      expect(usage.thoughtsTokens, equals(null));
      expect(usage.cachedInputTokens, equals(null));
    });
  });

  group('AgentDbConversions.toEntityCompanion — thread_id population', () {
    test('populates threadId for agentMessage entities', () {
      final message = AgentDomainEntity.agentMessage(
        id: 'msg-1',
        agentId: agentId,
        threadId: 'thread-abc',
        kind: AgentMessageKind.thought,
        createdAt: createdAt,
        metadata: const AgentMessageMetadata(runKey: 'rk-1'),
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(message);

      expect(companion.threadId, const Value('thread-abc'));
    });

    test('leaves threadId absent for non-message entities', () {
      final report = AgentDomainEntity.agentReport(
        id: id,
        agentId: agentId,
        scope: 'test-scope',
        content: '# Report',
        createdAt: createdAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(report);

      expect(companion.threadId, const Value<String?>.absent());
    });
  });

  // ── Soul document conversions ───────────────────────────────────────────

  group('AgentDbConversions — soulDocument entity roundtrip', () {
    test('toEntityCompanion produces correct companion', () {
      final entity = AgentDomainEntity.soulDocument(
        id: 'soul-001',
        agentId: 'soul-001',
        displayName: 'Laura',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.id, const Value('soul-001'));
      expect(companion.type, const Value('soulDocument'));
      expect(companion.subtype, const Value<String?>.absent());
      expect(companion.createdAt, Value(createdAt));
      expect(companion.updatedAt, Value(updatedAt));
    });

    test('fromEntityRow roundtrips soulDocument variant', () {
      final entity = AgentDomainEntity.soulDocument(
        id: 'soul-002',
        agentId: 'soul-002',
        displayName: 'Max',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );
      final companion = AgentDbConversions.toEntityCompanion(entity);

      final row = AgentEntity(
        id: 'soul-002',
        agentId: 'soul-002',
        type: 'soulDocument',
        createdAt: createdAt,
        updatedAt: updatedAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromEntityRow(row);
      expect(result, isA<SoulDocumentEntity>());
      final soul = result as SoulDocumentEntity;
      expect(soul.displayName, 'Max');
      expect(soul.agentId, 'soul-002');
    });
  });

  group('AgentDbConversions — soulDocumentVersion entity roundtrip', () {
    test('toEntityCompanion produces correct companion', () {
      final entity = AgentDomainEntity.soulDocumentVersion(
        id: 'sv-001',
        agentId: 'soul-001',
        version: 1,
        status: SoulDocumentVersionStatus.active,
        authoredBy: 'system',
        createdAt: createdAt,
        vectorClock: null,
        voiceDirective: 'Be warm.',
        toneBounds: 'No sarcasm.',
        coachingStyle: 'Gentle.',
        antiSycophancyPolicy: 'Push back.',
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.id, const Value('sv-001'));
      expect(companion.type, const Value('soulDocumentVersion'));
      expect(companion.subtype, const Value('active'));
      expect(companion.createdAt, Value(createdAt));
      // Immutable — updatedAt = createdAt.
      expect(companion.updatedAt, Value(createdAt));
    });

    test('fromEntityRow roundtrips soulDocumentVersion variant', () {
      final entity = AgentDomainEntity.soulDocumentVersion(
        id: 'sv-002',
        agentId: 'soul-001',
        version: 2,
        status: SoulDocumentVersionStatus.archived,
        authoredBy: 'evolution_agent',
        createdAt: createdAt,
        vectorClock: null,
        voiceDirective: 'Be terse.',
        toneBounds: 'No fluff.',
        coachingStyle: 'Direct.',
        antiSycophancyPolicy: 'Be blunt.',
        sourceSessionId: 'session-1',
        diffFromVersionId: 'sv-001',
      );
      final companion = AgentDbConversions.toEntityCompanion(entity);

      final row = AgentEntity(
        id: 'sv-002',
        agentId: 'soul-001',
        type: 'soulDocumentVersion',
        subtype: 'archived',
        createdAt: createdAt,
        updatedAt: createdAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromEntityRow(row);
      expect(result, isA<SoulDocumentVersionEntity>());
      final ver = result as SoulDocumentVersionEntity;
      expect(ver.version, 2);
      expect(ver.status, SoulDocumentVersionStatus.archived);
      expect(ver.voiceDirective, 'Be terse.');
      expect(ver.toneBounds, 'No fluff.');
      expect(ver.coachingStyle, 'Direct.');
      expect(ver.antiSycophancyPolicy, 'Be blunt.');
      expect(ver.sourceSessionId, 'session-1');
      expect(ver.diffFromVersionId, 'sv-001');
    });
  });

  group('AgentDbConversions — soulDocumentHead entity roundtrip', () {
    test('toEntityCompanion produces correct companion', () {
      final entity = AgentDomainEntity.soulDocumentHead(
        id: 'sh-001',
        agentId: 'soul-001',
        versionId: 'sv-001',
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toEntityCompanion(entity);

      expect(companion.id, const Value('sh-001'));
      expect(companion.type, const Value('soulDocumentHead'));
      expect(companion.subtype, const Value<String?>.absent());
      // Head has no createdAt — falls back to updatedAt.
      expect(companion.createdAt, Value(updatedAt));
      expect(companion.updatedAt, Value(updatedAt));
    });

    test('fromEntityRow roundtrips soulDocumentHead variant', () {
      final entity = AgentDomainEntity.soulDocumentHead(
        id: 'sh-002',
        agentId: 'soul-001',
        versionId: 'sv-003',
        updatedAt: updatedAt,
        vectorClock: null,
      );
      final companion = AgentDbConversions.toEntityCompanion(entity);

      final row = AgentEntity(
        id: 'sh-002',
        agentId: 'soul-001',
        type: 'soulDocumentHead',
        createdAt: updatedAt,
        updatedAt: updatedAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromEntityRow(row);
      expect(result, isA<SoulDocumentHeadEntity>());
      // Full field set, not just versionId/agentId.
      expect(result, equals(entity));
      final head = result as SoulDocumentHeadEntity;
      expect(head.id, 'sh-002');
      expect(head.versionId, 'sv-003');
      expect(head.agentId, 'soul-001');
      expect(head.updatedAt, updatedAt);
      expect(head.deletedAt, isNull);
    });

    test('fromEntityRow roundtrips a soft-deleted soulDocumentHead', () {
      final deletedAt = updatedAt.add(const Duration(hours: 2));
      final entity = AgentDomainEntity.soulDocumentHead(
        id: 'sh-003',
        agentId: 'soul-001',
        versionId: 'sv-004',
        updatedAt: updatedAt,
        vectorClock: null,
        deletedAt: deletedAt,
      );
      final companion = AgentDbConversions.toEntityCompanion(entity);

      final row = AgentEntity(
        id: 'sh-003',
        agentId: 'soul-001',
        type: 'soulDocumentHead',
        createdAt: updatedAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromEntityRow(row);
      expect(result, equals(entity));
      expect((result as SoulDocumentHeadEntity).deletedAt, deletedAt);
    });
  });

  group('AgentDbConversions — soulAssignment link', () {
    test('toLinkCompanion handles soulAssignment link correctly', () {
      final link = model.AgentLink.soulAssignment(
        id: 'link-sa-001',
        fromId: 'tpl-001',
        toId: 'soul-001',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );

      final companion = AgentDbConversions.toLinkCompanion(link);

      expect(companion.id, const Value('link-sa-001'));
      expect(companion.fromId, const Value('tpl-001'));
      expect(companion.toId, const Value('soul-001'));
      expect(companion.type, const Value('soul_assignment'));
    });

    test('fromLinkRow roundtrips soulAssignment link', () {
      final link = model.AgentLink.soulAssignment(
        id: 'link-sa-002',
        fromId: 'tpl-001',
        toId: 'soul-002',
        createdAt: createdAt,
        updatedAt: updatedAt,
        vectorClock: null,
      );
      final companion = AgentDbConversions.toLinkCompanion(link);

      final row = AgentLink(
        id: 'link-sa-002',
        fromId: 'tpl-001',
        toId: 'soul-002',
        type: 'soul_assignment',
        createdAt: createdAt,
        updatedAt: updatedAt,
        serialized: companion.serialized.value,
        schemaVersion: 1,
      );

      final result = AgentDbConversions.fromLinkRow(row);
      expect(result, isA<model.SoulAssignmentLink>());
      expect(result.fromId, 'tpl-001');
      expect(result.toId, 'soul-002');
    });
  });

  group('AgentDbConversions — parametric entity round-trip', () {
    AgentEntity rowFor(AgentEntitiesCompanion companion) => AgentEntity(
      id: companion.id.value,
      agentId: companion.agentId.value,
      type: companion.type.value,
      subtype: companion.subtype.present ? companion.subtype.value : null,
      threadId: companion.threadId.present ? companion.threadId.value : null,
      createdAt: companion.createdAt.value,
      updatedAt: companion.updatedAt.value,
      deletedAt: companion.deletedAt.value,
      serialized: companion.serialized.value,
      schemaVersion: 1,
    );

    test(
      'fromEntityRow(toEntityCompanion(e)) reconstructs every union variant',
      () {
        final representatives = <AgentDomainEntity>[
          makeTestIdentity(),
          makeTestState(),
          makeTestMessage(),
          makeTestMessagePayload(),
          makeTestReport(),
          makeTestReportHead(),
          makeTestTemplate(),
          makeTestTemplateVersion(),
          makeTestTemplateHead(),
          makeTestCapture(),
          makeTestParsedItem(),
          makeTestDayPlan(),
          makeTestChangeSet(),
          makeTestChangeDecision(),
          makeTestEvolutionSession(),
          makeTestEvolutionNote(),
          makeTestEvolutionSessionRecap(),
          makeTestSoulDocument(),
          makeTestSoulDocumentVersion(),
          makeTestSoulDocumentHead(),
          makeTestWakeTokenUsage(),
          makeTestProjectRecommendation(),
          AgentDomainEntity.attentionRequest(
            id: 'rt-attention-request',
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
              ),
            ],
            scopeKind: AttentionClaimScopeKind.deadline,
            createdAt: createdAt,
            vectorClock: null,
          ),
          AgentDomainEntity.attentionClaimDisposition(
            id: 'rt-attention-disposition',
            agentId: 'planner-agent-001',
            requestId: 'rt-attention-request',
            status: AttentionClaimStatus.deferred,
            planId: 'day_agent_plan:dayplan-2026-05-25',
            changeSetId: 'changeset-001',
            reason: 'Revisit tomorrow.',
            nextReviewAt: DateTime(2026, 5, 24, 18),
            createdAt: createdAt,
            vectorClock: null,
          ),
          AgentDomainEntity.attentionAward(
            id: 'rt-attention-award',
            agentId: 'day-agent-001',
            requestId: 'rt-attention-request',
            dayId: 'dayplan-2026-05-25',
            planId: 'day_agent_plan:dayplan-2026-05-25',
            blockId: 'attention_block:dayplan-2026-05-25:rt-attention-request',
            categoryId: 'work',
            title: 'Prep demo',
            startTime: DateTime(2026, 5, 25, 9),
            endTime: DateTime(2026, 5, 25, 9, 45),
            rank: 1,
            utilityScore: 5125,
            createdAt: createdAt,
            vectorClock: null,
          ),
          AgentDomainEntity.standingAgreement(
            id: 'rt-standing-agreement',
            agentId: 'fitness-agent-001',
            title: 'Exercise three times per week',
            scope: StandingAgreementScope.fitness,
            cadence: StandingAgreementCadence.weekly,
            enforcement: StandingAgreementEnforcement.nonNegotiable,
            approvalMode: StandingAgreementApprovalMode.autoAccept,
            minCount: 3,
            minMinutes: 135,
            preferredSessionMinutes: 45,
            priority: 80,
            createdAt: createdAt,
            updatedAt: updatedAt,
            vectorClock: null,
          ),
        ];

        // One representative per serialisable union variant (everything but
        // `unknown`, which has its own dedicated group). A new variant added
        // without extending this list fails the distinct-type guard below
        // only if someone remembers — the per-entity equality is the real
        // assertion.
        final distinctTypes = representatives
            .map(AgentDbConversions.entityType)
            .toSet();
        expect(distinctTypes, hasLength(representatives.length));

        for (final entity in representatives) {
          final companion = AgentDbConversions.toEntityCompanion(entity);
          final restored = AgentDbConversions.fromEntityRow(rowFor(companion));
          expect(
            restored,
            equals(entity),
            reason:
                'variant ${AgentDbConversions.entityType(entity)} '
                'must survive the companion/row round-trip',
          );
        }
      },
    );
  });
}
