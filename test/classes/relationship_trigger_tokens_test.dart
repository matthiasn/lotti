import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';

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
}
