import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/relationship_trigger_tokens.dart';

import '../test_utils/glados_generators.dart';

/// Wake tokens that are NOT in the relationship-escalation family: entity
/// ids, bare numeric ids, the goal family's escalation keys (which must
/// never match the relationship lease predicate), and arbitrary prefixed
/// noise. The shrinker converges to the bare-number shape.
extension _AnyTriggerTokens on glados.Any {
  glados.Generator<String> get nonEscalationToken => combine2(
    choose(const ['', 'relationship-', 'goal-escalation:', 'x:']),
    intInRange(0, 1000),
    (String prefix, int n) => '$prefix$n',
  );
}

void main() {
  test('escalation workspace keys round-trip through the trigger-token '
      'parser', () {
    final key = relationshipEscalationWorkspaceKey('2026-08-16');
    expect(key, 'relationship-escalation:2026-08-16');
    expect(isRelationshipEscalationWorkspace(key), isTrue);
    expect(
      relationshipEscalationDueDayFromTriggerTokens({'relationship-123', key}),
      '2026-08-16',
    );
  });

  test('report-refresh episodes live INSIDE the escalation family — the '
      'lease predicate and the LLM-tier router cover them unchanged', () {
    final key = relationshipReportRefreshEscalationWorkspaceKey('2026-08-14');
    expect(key, 'relationship-escalation:refresh-2026-08-14');
    expect(isRelationshipEscalationWorkspace(key), isTrue);
    expect(
      relationshipEscalationDueDayFromTriggerTokens({key}),
      'refresh-2026-08-14',
    );
    // Disjoint from the lapse episode of any due day: the refresh must
    // never consume the lapse episode's record.
    expect(key, isNot(relationshipEscalationWorkspaceKey('2026-08-14')));
  });

  test('non-escalation wakes yield null — they must stay on the €0 tier', () {
    expect(
      relationshipEscalationDueDayFromTriggerTokens({
        relationshipCadenceWorkspaceKey,
        'relationship-123',
      }),
      isNull,
    );
    expect(relationshipEscalationDueDayFromTriggerTokens(const {}), isNull);
    expect(isRelationshipEscalationWorkspace(null), isFalse);
    expect(
      isRelationshipEscalationWorkspace(relationshipCadenceWorkspaceKey),
      isFalse,
    );
  });

  test('the goal family never matches the relationship lease predicate — '
      'the two escalation namespaces stay disjoint', () {
    expect(
      isRelationshipEscalationWorkspace('goal-escalation:2026-08-16'),
      isFalse,
    );
  });

  test('baseline tokens preserve the pre-transition status exactly', () {
    final token = relationshipEscalationBaselineToken(
      RelationshipCadenceStatus.ok.name,
    );
    expect(token, 'relationship-baseline:ok');
    expect(
      relationshipEscalationBaselineFromTriggerTokens({
        relationshipEscalationWorkspaceKey('2026-08-16'),
        token,
      }),
      'ok',
    );
    expect(
      relationshipEscalationBaselineFromTriggerTokens(const {'unrelated'}),
      isNull,
      reason: 'a first-ever evaluation carries no baseline',
    );
  });

  test('report refresh is an explicit opt-in trigger', () {
    expect(
      relationshipReportRefreshRequested(
        const {relationshipReportRefreshTriggerToken},
      ),
      isTrue,
    );
    expect(
      relationshipReportRefreshRequested(const {'relationship-123'}),
      isFalse,
    );
  });

  test('the cadence status enum keeps its serialized names — baseline '
      'tokens on synced wake records depend on them', () {
    expect(RelationshipCadenceStatus.values.map((s) => s.name), [
      'ok',
      'due',
    ]);
  });

  group('token-contract properties', () {
    glados.Glados2(
      glados.any.isoDate,
      glados.any.nonEscalationToken,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'lapse-episode keys round-trip for any due day; without one the wake '
      'stays on the €0 tier however noisy the token set',
      (date, noise) {
        final tokens = {relationshipCadenceWorkspaceKey, noise};
        expect(
          relationshipEscalationDueDayFromTriggerTokens(tokens),
          isNull,
          reason: 'noise "$noise" must not enter the LLM tier',
        );
        expect(relationshipEscalationBaselineFromTriggerTokens(tokens), isNull);
        expect(relationshipReportRefreshRequested(tokens), isFalse);

        final key = relationshipEscalationWorkspaceKey(date.text);
        expect(isRelationshipEscalationWorkspace(key), isTrue);
        expect(
          relationshipEscalationDueDayFromTriggerTokens({...tokens, key}),
          date.text,
          reason: 'noise "$noise" must not clobber the due day',
        );
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.isoDate,
      glados.any.isoDate,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'refresh episodes stay inside the escalation family yet never '
      'collide with any lapse episode',
      (checkInDay, dueDay) {
        final refreshKey = relationshipReportRefreshEscalationWorkspaceKey(
          checkInDay.text,
        );
        expect(isRelationshipEscalationWorkspace(refreshKey), isTrue);
        expect(
          relationshipEscalationDueDayFromTriggerTokens({refreshKey}),
          'refresh-${checkInDay.text}',
        );
        // For EVERY pair of days — the same day included — the refresh
        // episode must keep its own record identity, or per-episode
        // idempotence would suppress the real cadence-lapse escalation.
        expect(
          refreshKey,
          isNot(relationshipEscalationWorkspaceKey(dueDay.text)),
        );
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.choose(RelationshipCadenceStatus.values),
      glados.any.isoDate,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'baseline and workspace tokens ride one token set without clobbering '
      'each other',
      (status, date) {
        final tokens = {
          relationshipCadenceWorkspaceKey,
          relationshipEscalationWorkspaceKey(date.text),
          relationshipEscalationBaselineToken(status.name),
        };
        expect(
          relationshipEscalationBaselineFromTriggerTokens(tokens),
          status.name,
        );
        expect(relationshipEscalationDueDayFromTriggerTokens(tokens), date.text);
      },
      tags: 'glados',
    );
  });
}
