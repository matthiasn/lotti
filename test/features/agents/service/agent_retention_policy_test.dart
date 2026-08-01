import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/service/agent_retention_policy.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../test_data/entity_factories.dart';

void main() {
  const policy = AgentRetentionPolicy();
  final now = DateTime(2026, 8);

  group('what is never eligible', () {
    test("the user's own material has no horizon, however old", () {
      final authored = <AgentDomainEntity>[
        makeTestCapture(createdAt: DateTime(2015)),
        makeTestDayPlan(createdAt: DateTime(2015)),
        makeTestDaySummary(createdAt: DateTime(2015)),
        makeTestDayDirective(createdAt: DateTime(2015)),
        makeTestReport(createdAt: DateTime(2015)),
      ];

      for (final entity in authored) {
        expect(
          policy.classify(entity),
          AgentRetentionClass.userAuthored,
          reason: "${entity.runtimeType} is the user's own material.",
        );
        expect(
          policy.isBeyondHorizon(
            entity: entity,
            createdAt: DateTime(2015),
            now: now,
          ),
          isFalse,
        );
      }
    });

    test('the deliberate keeps stay keeps', () {
      // These were decided against on the record, not overlooked. A horizon
      // appearing on any of them is a regression, not a new feature.
      final kept = <AgentDomainEntity>[
        makeTestWeekRollup(),
        makeTestIdentity(),
        makeTestState(),
        makeTestMessagePayload(),
      ];

      for (final entity in kept) {
        expect(policy.classify(entity), AgentRetentionClass.keptDerived);
        expect(policy.horizonFor(entity), isNull);
      }
    });

    test('a non-observation message is durable memory, not residue', () {
      final summary = makeTestMessage(
        kind: AgentMessageKind.summary,
        createdAt: DateTime(2015),
      );

      expect(policy.classify(summary), AgentRetentionClass.keptDerived);
      expect(
        policy.isBeyondHorizon(
          entity: summary,
          createdAt: DateTime(2015),
          now: now,
        ),
        isFalse,
        reason:
            'Compaction summaries are what the agent remembers after its raw '
            'log is folded away; ageing them out would erase that memory.',
      );
    });
  });

  group('what is bounded', () {
    test('an observation is classified but not yet swept', () {
      final observation = makeTestMessage(kind: AgentMessageKind.observation);

      expect(policy.classify(observation), AgentRetentionClass.observation);
      expect(
        policy.horizonFor(observation),
        isNull,
        reason:
            'Observations sit inside the message DAG — message_prev edges, '
            'agent-state heads, and content-addressed payloads shared by '
            'link. Until the sweep answers for all of those, dropping them '
            'on ingest would delete rows this device never prunes locally.',
      );
    });

    test('a day-status event past the horizon is dropped', () {
      final event = makeTestDayStatusEvent();

      expect(
        policy.isBeyondHorizon(
          entity: event,
          createdAt: now.subtract(const Duration(days: 91)),
          now: now,
        ),
        isTrue,
      );
      expect(
        policy.isBeyondHorizon(
          entity: event,
          createdAt: now.subtract(const Duration(days: 89)),
          now: now,
        ),
        isFalse,
      );
    });

    test('the boundary itself is kept, not dropped', () {
      expect(
        policy.isBeyondHorizon(
          entity: makeTestDayStatusEvent(),
          createdAt: now.subtract(policy.dayStatusEvents),
          now: now,
        ),
        isFalse,
        reason: 'Strictly-before, so the horizon is inclusive of its edge.',
      );
    });
  });

  test('every entity variant is classified, and none by accident', () {
    // One instance of every AgentDomainEntity variant. `classify` is a freezed
    // map with no fallback, so a new variant fails to compile there — this
    // pins what each existing one was decided to be, which is the part a
    // compiler cannot check.
    final t = DateTime(2026, 6);
    const VectorClock? vc = null;
    final expected = <AgentDomainEntity, AgentRetentionClass>{
      // Identity and live state.
      makeTestIdentity(): AgentRetentionClass.keptDerived,
      makeTestState(): AgentRetentionClass.keptDerived,
      AgentDomainEntity.scheduledWake(
        id: 'w',
        agentId: 'a',
        scheduledAt: t,
        status: ScheduledWakeStatus.pending,
        reason: 'r',
        updatedAt: t,
        vectorClock: vc,
      ): AgentRetentionClass.keptDerived,
      AgentDomainEntity.unknown(id: 'u', agentId: 'a', createdAt: t):
          AgentRetentionClass.keptDerived,

      // The user's own material.
      makeTestCapture(): AgentRetentionClass.userAuthored,
      makeTestParsedItem(): AgentRetentionClass.userAuthored,
      makeTestDayPlan(): AgentRetentionClass.userAuthored,
      makeTestDaySummary(): AgentRetentionClass.userAuthored,
      makeTestDayDirective(): AgentRetentionClass.userAuthored,
      makeTestReport(): AgentRetentionClass.userAuthored,
      makeTestReportHead(): AgentRetentionClass.userAuthored,
      AgentDomainEntity.plannerKnowledge(
        id: 'k',
        agentId: 'a',
        key: 'k',
        hook: 'h',
        statementText: 's',
        source: KnowledgeSource.userStated,
        status: KnowledgeStatus.confirmed,
        createdAt: t,
        updatedAt: t,
        vectorClock: vc,
      ): AgentRetentionClass.userAuthored,
      AgentDomainEntity.agentTemplate(
        id: 't',
        agentId: 'a',
        displayName: 'n',
        kind: AgentTemplateKind.dayAgent,
        modelId: 'm',
        categoryIds: const {},
        createdAt: t,
        updatedAt: t,
        vectorClock: vc,
      ): AgentRetentionClass.userAuthored,
      AgentDomainEntity.agentTemplateVersion(
        id: 'tv',
        agentId: 'a',
        version: 1,
        status: AgentTemplateVersionStatus.active,
        directives: 'd',
        authoredBy: 'u',
        createdAt: t,
        vectorClock: vc,
      ): AgentRetentionClass.userAuthored,
      AgentDomainEntity.agentTemplateHead(
        id: 'th',
        agentId: 'a',
        versionId: 'tv',
        updatedAt: t,
        vectorClock: vc,
      ): AgentRetentionClass.userAuthored,
      AgentDomainEntity.evolutionSession(
        id: 'es',
        agentId: 'a',
        templateId: 't',
        sessionNumber: 1,
        status: EvolutionSessionStatus.active,
        createdAt: t,
        updatedAt: t,
        vectorClock: vc,
      ): AgentRetentionClass.userAuthored,
      AgentDomainEntity.evolutionSessionRecap(
        id: 'esr',
        agentId: 'a',
        sessionId: 'es',
        createdAt: t,
        vectorClock: vc,
        tldr: 'x',
        recapMarkdown: 'y',
      ): AgentRetentionClass.userAuthored,
      AgentDomainEntity.evolutionNote(
        id: 'en',
        agentId: 'a',
        sessionId: 'es',
        kind: EvolutionNoteKind.decision,
        createdAt: t,
        vectorClock: vc,
        content: 'c',
      ): AgentRetentionClass.userAuthored,
      AgentDomainEntity.soulDocument(
        id: 'sd',
        agentId: 'a',
        displayName: 'n',
        createdAt: t,
        updatedAt: t,
        vectorClock: vc,
      ): AgentRetentionClass.userAuthored,
      AgentDomainEntity.soulDocumentVersion(
        id: 'sdv',
        agentId: 'a',
        version: 1,
        status: SoulDocumentVersionStatus.active,
        authoredBy: 'u',
        createdAt: t,
        vectorClock: vc,
        voiceDirective: 'v',
      ): AgentRetentionClass.userAuthored,
      AgentDomainEntity.soulDocumentHead(
        id: 'sdh',
        agentId: 'a',
        versionId: 'sdv',
        updatedAt: t,
        vectorClock: vc,
      ): AgentRetentionClass.userAuthored,

      // Derived, kept deliberately.
      makeTestWeekRollup(): AgentRetentionClass.keptDerived,
      makeTestMessagePayload(): AgentRetentionClass.keptDerived,
      AgentDomainEntity.wakeTokenUsage(
        id: 'tu',
        agentId: 'a',
        runKey: 'r',
        threadId: 'th',
        modelId: 'm',
        createdAt: t,
        vectorClock: vc,
      ): AgentRetentionClass.keptDerived,
      AgentDomainEntity.changeSet(
        id: 'cs',
        agentId: 'a',
        taskId: 'task',
        threadId: 'th',
        runKey: 'r',
        status: ChangeSetStatus.pending,
        items: const [],
        createdAt: t,
        vectorClock: vc,
      ): AgentRetentionClass.keptDerived,
      AgentDomainEntity.changeDecision(
        id: 'cd',
        agentId: 'a',
        changeSetId: 'cs',
        itemIndex: 0,
        toolName: 'tool',
        verdict: ChangeDecisionVerdict.confirmed,
        createdAt: t,
        vectorClock: vc,
      ): AgentRetentionClass.keptDerived,
      AgentDomainEntity.attentionRequest(
        id: 'ar',
        agentId: 'a',
        kind: AttentionRequestKind.task,
        title: 'x',
        categoryId: 'c',
        requestedMinutes: 30,
        impact: 1,
        urgency: 1,
        energyFit: AttentionEnergyFit.high,
        evidenceRefs: const [],
        createdAt: t,
        vectorClock: vc,
      ): AgentRetentionClass.keptDerived,
      AgentDomainEntity.attentionClaimDisposition(
        id: 'acd',
        agentId: 'a',
        requestId: 'ar',
        status: AttentionClaimStatus.declined,
        createdAt: t,
        vectorClock: vc,
      ): AgentRetentionClass.keptDerived,
      AgentDomainEntity.attentionAward(
        id: 'aa',
        agentId: 'a',
        requestId: 'ar',
        dayId: 'd',
        planId: 'p',
        blockId: 'b',
        categoryId: 'c',
        title: 'x',
        startTime: t,
        endTime: t,
        rank: 1,
        utilityScore: 1,
        createdAt: t,
        vectorClock: vc,
      ): AgentRetentionClass.keptDerived,
      AgentDomainEntity.standingAgreement(
        id: 'sa',
        agentId: 'a',
        title: 'x',
        scope: StandingAgreementScope.custom,
        cadence: StandingAgreementCadence.daily,
        createdAt: t,
        updatedAt: t,
        vectorClock: vc,
      ): AgentRetentionClass.keptDerived,
      AgentDomainEntity.projectRecommendation(
        id: 'pr',
        agentId: 'a',
        projectId: 'p',
        title: 'x',
        position: 0,
        status: ProjectRecommendationStatus.active,
        createdAt: t,
        updatedAt: t,
        vectorClock: vc,
      ): AgentRetentionClass.keptDerived,
      makeTestMessage(kind: AgentMessageKind.summary):
          AgentRetentionClass.keptDerived,

      // Derived and bounded.
      makeTestDayStatusEvent(): AgentRetentionClass.ageBounded,
      makeTestMessage(kind: AgentMessageKind.observation):
          AgentRetentionClass.observation,
    };

    for (final entry in expected.entries) {
      expect(
        policy.classify(entry.key),
        entry.value,
        reason: '${entry.key.runtimeType} is classified ${entry.value.name}',
      );
    }
  });

  test('every read window a horizon protects fits inside it', () {
    // The digest reads status events from its watermark with 12h of sync-lag
    // slack. If a horizon ever drops below the read window it protects, the
    // read silently starts returning less than it asks for.
    expect(policy.dayStatusEvents, greaterThan(const Duration(days: 3)));
  });
}
