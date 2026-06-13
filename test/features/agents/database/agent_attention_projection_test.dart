import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_attention_projection.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repo_core.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Mirror tests for [AgentAttentionProjection]. They construct the collaborator
/// wired to a real [AgentRepoCore] over an in-memory [AgentDatabase]. Because
/// the projection is the planner read path, the tests seed the source rows
/// through `core.upsertEntity` (which refreshes the index), then assert the
/// window/target reads return what the index implies — and that a rebuild
/// re-derives the index from the source tables.
void main() {
  late AgentDatabase db;
  late AgentRepoCore core;
  late AgentAttentionProjection projection;

  final testDate = DateTime(2026, 3, 15);

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    core = AgentRepoCore(db);
    projection = AgentAttentionProjection(db, core);
    core.projection = projection;
  });

  tearDown(() async {
    await db.close();
  });

  AttentionRequestEntity makeClaim({
    required String id,
    String agentId = 'planner-1',
    AttentionRequestStatus status = AttentionRequestStatus.pending,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    String? targetId = 'task-1',
    String? targetKind = 'task',
  }) {
    return AgentDomainEntity.attentionRequest(
          id: id,
          agentId: agentId,
          kind: AttentionRequestKind.task,
          title: 'Focus block',
          categoryId: 'work',
          requestedMinutes: 45,
          impact: 4,
          urgency: 3,
          energyFit: AttentionEnergyFit.high,
          evidenceRefs: const [],
          scopeKind: AttentionClaimScopeKind.dateRange,
          status: status,
          rangeStart: rangeStart ?? DateTime(2026, 3, 15, 9),
          rangeEnd: rangeEnd ?? DateTime(2026, 3, 15, 12),
          targetId: targetId,
          targetKind: targetKind,
          createdAt: testDate,
          vectorClock: const VectorClock({'node-1': 1}),
        )
        as AttentionRequestEntity;
  }

  StandingAgreementEntity makeAgreement({
    required String id,
    StandingAgreementStatus status = StandingAgreementStatus.active,
    DateTime? activeFrom,
    DateTime? activeUntil,
  }) {
    return AgentDomainEntity.standingAgreement(
          id: id,
          agentId: 'fitness-1',
          title: 'Exercise weekly',
          scope: StandingAgreementScope.fitness,
          cadence: StandingAgreementCadence.weekly,
          status: status,
          priority: 10,
          activeFrom: activeFrom ?? DateTime(2026, 3),
          activeUntil: activeUntil ?? DateTime(2026, 4),
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: const VectorClock({'node-1': 2}),
        )
        as StandingAgreementEntity;
  }

  group('getAttentionClaimsForWindow', () {
    test('returns claims overlapping the window via the index', () async {
      await core.upsertEntity(makeClaim(id: 'claim-in'));
      await core.upsertEntity(
        makeClaim(
          id: 'claim-out',
          rangeStart: DateTime(2026, 3, 20, 9),
          rangeEnd: DateTime(2026, 3, 20, 12),
        ),
      );

      final claims = await projection.getAttentionClaimsForWindow(
        start: DateTime(2026, 3, 15, 8),
        end: DateTime(2026, 3, 15, 13),
      );
      expect(claims.map((c) => c.id), ['claim-in']);
    });

    test('returns empty for an inverted window without a query', () async {
      await core.upsertEntity(makeClaim(id: 'claim-x'));
      final claims = await projection.getAttentionClaimsForWindow(
        start: DateTime(2026, 3, 16),
        end: DateTime(2026, 3, 15),
      );
      expect(claims, isEmpty);
    });
  });

  group('getAttentionClaimsForTarget', () {
    test('returns claims matching target kind + id', () async {
      await core.upsertEntity(
        makeClaim(id: 'claim-t', targetId: 'task-7'),
      );

      final claims = await projection.getAttentionClaimsForTarget(
        targetKind: 'task',
        targetId: 'task-7',
      );
      expect(claims.map((c) => c.id), ['claim-t']);
    });
  });

  group('getStandingAgreementsForWindow / planning inputs', () {
    test('returns active agreements overlapping the window', () async {
      await core.upsertEntity(makeAgreement(id: 'agr-1'));

      final agreements = await projection.getStandingAgreementsForWindow(
        start: DateTime(2026, 3, 14),
        end: DateTime(2026, 3, 16),
      );
      expect(agreements.map((a) => a.id), ['agr-1']);
    });

    test('getAttentionPlanningInputsForWindow combines both reads', () async {
      await core.upsertEntity(makeClaim(id: 'claim-p'));
      await core.upsertEntity(makeAgreement(id: 'agr-p'));

      final inputs = await projection.getAttentionPlanningInputsForWindow(
        start: DateTime(2026, 3, 14),
        end: DateTime(2026, 3, 16),
      );
      expect(inputs.claims.map((c) => c.id), ['claim-p']);
      expect(inputs.standingAgreements.map((a) => a.id), ['agr-p']);
      expect(inputs.isEmpty, isFalse);
    });
  });

  group('rebuildAttentionClaimProjection', () {
    test('re-derives the index from the source rows', () async {
      await core.upsertEntity(makeClaim(id: 'claim-r'));

      // Wipe the index out-of-band, then prove the rebuild restores it.
      await db.customStatement('DELETE FROM attention_claim_index');
      expect(
        await projection.getAttentionClaimsForWindow(
          start: DateTime(2026, 3, 15, 8),
          end: DateTime(2026, 3, 15, 13),
        ),
        isEmpty,
      );

      await projection.rebuildAttentionClaimProjection();

      final claims = await projection.getAttentionClaimsForWindow(
        start: DateTime(2026, 3, 15, 8),
        end: DateTime(2026, 3, 15, 13),
      );
      expect(claims.map((c) => c.id), ['claim-r']);
    });
  });
}
