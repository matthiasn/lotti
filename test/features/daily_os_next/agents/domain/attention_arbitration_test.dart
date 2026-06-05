import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/daily_os_next/agents/domain/attention_arbitration.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';

const _plannerAgentId = 'day-agent-001';
const _dayId = 'dayplan-2026-05-25';
final _planDate = DateTime(2026, 5, 25);
final _createdAt = DateTime(2026, 5, 25, 7);

class _GeneratedAttentionScenario {
  const _GeneratedAttentionScenario({
    required this.impactA,
    required this.urgencyA,
    required this.durationA,
    required this.impactB,
    required this.urgencyB,
    required this.durationB,
  });

  final int impactA;
  final int urgencyA;
  final int durationA;
  final int impactB;
  final int urgencyB;
  final int durationB;

  List<AttentionRequestEntity> get requests => [
    _request(
      id: 'request-a',
      title: 'Request A',
      impact: impactA,
      urgency: urgencyA,
      duration: durationA,
    ),
    _request(
      id: 'request-b',
      title: 'Request B',
      impact: impactB,
      urgency: urgencyB,
      duration: durationB,
      createdAt: _createdAt.add(const Duration(minutes: 1)),
    ),
  ];

  @override
  String toString() {
    return '_GeneratedAttentionScenario('
        'impactA: $impactA, urgencyA: $urgencyA, durationA: $durationA, '
        'impactB: $impactB, urgencyB: $urgencyB, durationB: $durationB)';
  }
}

extension _AnyGeneratedAttentionScenario on glados.Any {
  glados.Generator<_GeneratedAttentionScenario> get attentionScenario =>
      glados.CombinableAny(this).combine6(
        glados.IntAnys(this).intInRange(1, 5),
        glados.IntAnys(this).intInRange(1, 5),
        glados.IntAnys(this).intInRange(15, 90),
        glados.IntAnys(this).intInRange(1, 5),
        glados.IntAnys(this).intInRange(1, 5),
        glados.IntAnys(this).intInRange(15, 90),
        (
          int impactA,
          int urgencyA,
          int durationA,
          int impactB,
          int urgencyB,
          int durationB,
        ) => _GeneratedAttentionScenario(
          impactA: impactA,
          urgencyA: urgencyA,
          durationA: durationA,
          impactB: impactB,
          urgencyB: urgencyB,
          durationB: durationB,
        ),
      );
}

void main() {
  const arbitrator = AttentionPlannerArbitrator();

  group('AttentionPlannerArbitrator', () {
    test(
      'awards highest utility request into a preferred high-energy band',
      () {
        final plan = _plan(
          energyBands: [
            DayAgentEnergyBand(
              start: DateTime(2026, 5, 25, 9),
              end: DateTime(2026, 5, 25, 12),
              level: DayAgentEnergyLevel.high,
              label: 'HIGH ENERGY',
            ),
          ],
        );
        final high = _request(
          id: 'request-high',
          title: 'Prep investor demo',
          impact: 5,
          urgency: 5,
          duration: 60,
          energyFit: AttentionEnergyFit.high,
        );
        final low = _request(
          id: 'request-low',
          title: 'Triage inbox',
          impact: 2,
          urgency: 2,
        );

        final result = arbitrator.arbitrate(
          plannerAgentId: _plannerAgentId,
          plan: plan,
          requests: [low, high],
          createdAt: _createdAt,
        );

        expect(result.awards, hasLength(2));
        expect(result.awards.first.request.id, 'request-high');
        expect(result.awards.first.award.rank, 1);
        expect(
          result.awards.first.plannedBlock.startTime,
          DateTime(2026, 5, 25, 9),
        );
        expect(
          result.awards.first.plannedBlock.endTime,
          DateTime(2026, 5, 25, 10),
        );
        expect(
          result.awards.first.award.utilityScore,
          greaterThan(result.awards.last.award.utilityScore),
        );
      },
    );

    test('skips lower-ranked requests when capacity is exhausted', () {
      final plan = _plan(capacityMinutes: 60);
      final first = _request(
        id: 'request-first',
        title: 'Write proposal',
        impact: 5,
        urgency: 5,
        duration: 45,
      );
      final second = _request(
        id: 'request-second',
        title: 'Review notes',
        impact: 4,
        urgency: 4,
      );

      final result = arbitrator.arbitrate(
        plannerAgentId: _plannerAgentId,
        plan: plan,
        requests: [second, first],
        createdAt: _createdAt,
      );

      expect(result.awards.single.request.id, 'request-first');
      expect(result.skipped.single.request.id, 'request-second');
      expect(result.skipped.single.reason, AttentionSkipReason.capacity);
    });

    test('requires evidence-backed requests', () {
      final request = _request(
        id: 'request-without-evidence',
        title: 'Unbacked ask',
        evidenceRefs: const [],
      );

      final result = arbitrator.arbitrate(
        plannerAgentId: _plannerAgentId,
        plan: _plan(),
        requests: [request],
        createdAt: _createdAt,
      );

      expect(result.awards, isEmpty);
      expect(result.skipped.single.reason, AttentionSkipReason.missingEvidence);
    });

    test('places awards after existing non-dropped blocks', () {
      final existing = PlannedBlock(
        id: 'existing-block',
        categoryId: 'work',
        startTime: DateTime(2026, 5, 25, 9),
        endTime: DateTime(2026, 5, 25, 10),
        title: 'Existing focus',
        reason: 'Already planned.',
      );
      final request = _request(
        id: 'request-after-existing',
        title: 'Follow-up',
      );

      final result = arbitrator.arbitrate(
        plannerAgentId: _plannerAgentId,
        plan: _plan(plannedBlocks: [existing]),
        requests: [request],
        createdAt: _createdAt,
      );

      expect(
        result.awards.single.plannedBlock.startTime,
        DateTime(2026, 5, 25, 10),
      );
      expect(
        result.awards.single.plannedBlock.endTime,
        DateTime(2026, 5, 25, 10, 30),
      );
      expect(result.addBlockChanges.single['action'], 'added');
    });

    glados.Glados(
      glados.any.attentionScenario,
      glados.ExploreConfig(),
    ).test('is independent of input request order', (scenario) {
      final plan = _plan();
      final forward = arbitrator.arbitrate(
        plannerAgentId: _plannerAgentId,
        plan: plan,
        requests: scenario.requests,
        createdAt: _createdAt,
      );
      final reversed = arbitrator.arbitrate(
        plannerAgentId: _plannerAgentId,
        plan: plan,
        requests: scenario.requests.reversed.toList(),
        createdAt: _createdAt,
      );

      expect(
        forward.awards.map((proposal) => proposal.award.id),
        equals(reversed.awards.map((proposal) => proposal.award.id)),
        reason: '$scenario',
      );
      expect(
        forward.rankedRequests.map((ranking) => ranking.request.id),
        equals(reversed.rankedRequests.map((ranking) => ranking.request.id)),
        reason: '$scenario',
      );
    }, tags: 'glados');
  });
}

DayPlanEntity _plan({
  int capacityMinutes = 480,
  List<PlannedBlock> plannedBlocks = const [],
  List<DayAgentEnergyBand> energyBands = const [],
}) {
  final scheduledMinutes = plannedBlocks
      .where((block) => block.state != PlannedBlockState.dropped)
      .fold<int>(0, (sum, block) => sum + block.duration.inMinutes);
  return AgentDomainEntity.dayPlan(
        id: dayAgentPlanEntityId(_dayId),
        agentId: _plannerAgentId,
        dayId: _dayId,
        planDate: _planDate,
        data: DayPlanData(
          planDate: _planDate,
          status: const DayPlanStatus.draft(),
          plannedBlocks: plannedBlocks,
        ),
        energyBands: energyBands,
        capacityMinutes: capacityMinutes,
        scheduledMinutes: scheduledMinutes,
        createdAt: _createdAt,
        updatedAt: _createdAt,
        vectorClock: null,
      )
      as DayPlanEntity;
}

AttentionRequestEntity _request({
  required String id,
  required String title,
  int impact = 3,
  int urgency = 3,
  int duration = 30,
  AttentionEnergyFit energyFit = AttentionEnergyFit.neutral,
  List<AttentionEvidenceRef> evidenceRefs = const [
    AttentionEvidenceRef(kind: AttentionEvidenceKind.task, id: 'task-001'),
  ],
  DateTime? createdAt,
}) {
  return AgentDomainEntity.attentionRequest(
        id: id,
        agentId: 'task-agent-$id',
        dayId: _dayId,
        kind: AttentionRequestKind.task,
        title: title,
        categoryId: 'work',
        requestedMinutes: duration,
        impact: impact,
        urgency: urgency,
        energyFit: energyFit,
        evidenceRefs: evidenceRefs,
        earliestStart: DateTime(2026, 5, 25, 9),
        latestEnd: DateTime(2026, 5, 25, 17),
        targetId: 'task-$id',
        targetKind: 'task',
        createdAt: createdAt ?? _createdAt,
        vectorClock: null,
      )
      as AttentionRequestEntity;
}
