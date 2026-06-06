// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/sync/agent_lww_timestamp.dart';

import '../test_data/change_set_factories.dart';
import '../test_data/entity_factories.dart';
import '../test_data/evolution_factories.dart';
import '../test_data/soul_factories.dart';
import '../test_data/template_factories.dart';
import '../test_data/wake_factories.dart';

/// Distinct timestamps so a variant that has *both* fields fails the test if it
/// returns `createdAt` where it should return `updatedAt` (or vice versa).
final _created = DateTime(2024, 1, 1);
final _updated = DateTime(2024, 6, 1);

/// One row per `AgentDomainEntity` variant: the entity and the timestamp
/// `effectiveUpdatedAt` must return. Together these exercise every arm of the
/// exhaustive `map` — a wrong field mapping is caught by the distinct dates,
/// and a *missing* variant is caught by the compiler (freezed `map`).
final _cases = <({String label, AgentDomainEntity entity, DateTime expected})>[
  (
    label: 'agent',
    entity: makeTestIdentity(createdAt: _created, updatedAt: _updated),
    expected: _updated,
  ),
  (
    label: 'agentState',
    entity: makeTestState(updatedAt: _updated),
    expected: _updated,
  ),
  (
    label: 'agentMessage',
    entity: makeTestMessage(createdAt: _created),
    expected: _created,
  ),
  (
    label: 'agentMessagePayload',
    entity: makeTestMessagePayload(createdAt: _created),
    expected: _created,
  ),
  (
    label: 'agentReport',
    entity: makeTestReport(createdAt: _created),
    expected: _created,
  ),
  (
    label: 'agentReportHead',
    entity: makeTestReportHead(updatedAt: _updated),
    expected: _updated,
  ),
  (
    label: 'capture',
    entity: AgentDomainEntity.capture(
      id: 'capture-1',
      agentId: 'agent-1',
      transcript: 't',
      capturedAt: _created,
      createdAt: _created,
      vectorClock: null,
    ),
    expected: _created,
  ),
  (
    label: 'parsedItem',
    entity: AgentDomainEntity.parsedItem(
      id: 'parsed-1',
      agentId: 'agent-1',
      captureId: 'capture-1',
      kind: ParsedItemKind.newTask,
      title: 'title',
      categoryId: 'cat-1',
      confidence: ParsedItemConfidence.high,
      confidenceScore: 0.9,
      createdAt: _created,
      vectorClock: null,
    ),
    expected: _created,
  ),
  (
    label: 'dayPlan',
    entity: AgentDomainEntity.dayPlan(
      id: 'plan-1',
      agentId: 'agent-1',
      dayId: '2024-06-01',
      planDate: _updated,
      data: DayPlanData(
        planDate: _updated,
        status: const DayPlanStatus.draft(),
      ),
      createdAt: _created,
      updatedAt: _updated,
      vectorClock: null,
    ),
    expected: _updated,
  ),
  (
    label: 'attentionRequest',
    entity: AgentDomainEntity.attentionRequest(
      id: 'attention-request-1',
      agentId: 'agent-1',
      kind: AttentionRequestKind.task,
      title: 'Focus block',
      categoryId: 'work',
      requestedMinutes: 45,
      impact: 4,
      urgency: 3,
      energyFit: AttentionEnergyFit.high,
      evidenceRefs: const [
        AttentionEvidenceRef(kind: AttentionEvidenceKind.task, id: 'task-1'),
      ],
      createdAt: _created,
      vectorClock: null,
    ),
    expected: _created,
  ),
  (
    label: 'attentionClaimDisposition',
    entity: AgentDomainEntity.attentionClaimDisposition(
      id: 'attention-disposition-1',
      agentId: 'day-agent-1',
      requestId: 'attention-request-1',
      status: AttentionClaimStatus.deferred,
      createdAt: _created,
      vectorClock: null,
    ),
    expected: _created,
  ),
  (
    label: 'attentionAward',
    entity: AgentDomainEntity.attentionAward(
      id: 'attention-award-1',
      agentId: 'day-agent-1',
      requestId: 'attention-request-1',
      dayId: 'dayplan-2024-06-01',
      planId: 'day_agent_plan:dayplan-2024-06-01',
      blockId: 'attention_block:dayplan-2024-06-01:attention-request-1',
      categoryId: 'work',
      title: 'Focus block',
      startTime: _updated,
      endTime: _updated.add(const Duration(minutes: 45)),
      rank: 1,
      utilityScore: 4000,
      createdAt: _created,
      vectorClock: null,
    ),
    expected: _created,
  ),
  (
    label: 'standingAgreement',
    entity: AgentDomainEntity.standingAgreement(
      id: 'standing-agreement-1',
      agentId: 'fitness-agent-1',
      title: 'Exercise three times per week',
      scope: StandingAgreementScope.fitness,
      cadence: StandingAgreementCadence.weekly,
      createdAt: _created,
      updatedAt: _updated,
      vectorClock: null,
    ),
    expected: _updated,
  ),
  (
    label: 'agentTemplate',
    entity: makeTestTemplate(createdAt: _created, updatedAt: _updated),
    expected: _updated,
  ),
  (
    label: 'agentTemplateVersion',
    entity: makeTestTemplateVersion(createdAt: _created),
    expected: _created,
  ),
  (
    label: 'agentTemplateHead',
    entity: makeTestTemplateHead(updatedAt: _updated),
    expected: _updated,
  ),
  (
    label: 'evolutionSession',
    entity: makeTestEvolutionSession(createdAt: _created, updatedAt: _updated),
    expected: _updated,
  ),
  (
    label: 'evolutionSessionRecap',
    entity: makeTestEvolutionSessionRecap(createdAt: _created),
    expected: _created,
  ),
  (
    label: 'evolutionNote',
    entity: makeTestEvolutionNote(createdAt: _created),
    expected: _created,
  ),
  (
    label: 'changeSet',
    entity: makeTestChangeSet(createdAt: _created),
    expected: _created,
  ),
  (
    label: 'changeDecision',
    entity: makeTestChangeDecision(createdAt: _created),
    expected: _created,
  ),
  (
    label: 'projectRecommendation',
    entity: makeTestProjectRecommendation(
      createdAt: _created,
      updatedAt: _updated,
    ),
    expected: _updated,
  ),
  (
    label: 'wakeTokenUsage',
    entity: makeTestWakeTokenUsage(createdAt: _created),
    expected: _created,
  ),
  (
    label: 'soulDocument',
    entity: makeTestSoulDocument(createdAt: _created, updatedAt: _updated),
    expected: _updated,
  ),
  (
    label: 'soulDocumentVersion',
    entity: makeTestSoulDocumentVersion(createdAt: _created),
    expected: _created,
  ),
  (
    label: 'soulDocumentHead',
    entity: makeTestSoulDocumentHead(updatedAt: _updated),
    expected: _updated,
  ),
  (
    label: 'unknown',
    entity: AgentDomainEntity.unknown(
      id: 'unknown-1',
      agentId: 'agent-1',
      createdAt: _created,
      vectorClock: null,
    ),
    expected: _created,
  ),
];

void main() {
  group('AgentDomainEntity.effectiveUpdatedAt', () {
    for (final c in _cases) {
      test('${c.label} resolves to its LWW timestamp', () {
        expect(
          c.entity.effectiveUpdatedAt.isAtSameMomentAs(c.expected),
          isTrue,
          reason: c.label,
        );
      });
    }

    test('covers every AgentDomainEntity variant', () {
      // Guards the data table above: if a variant is added (and classified in
      // the exhaustive `map`), this count must be bumped with a new case.
      expect(_cases.length, 27);
    });
  });
}
