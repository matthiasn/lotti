import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/projection/decision_events.dart';

LedgerEntry _entry({
  String changeSetId = 'cs-1',
  int itemIndex = 0,
  String toolName = 'set_task_title',
  String humanSummary = 'Set title to "X"',
  String fingerprint = 'set_task_title:123',
  ChangeItemStatus status = ChangeItemStatus.confirmed,
  DateTime? createdAt,
  DateTime? resolvedAt,
  DecisionActor? resolvedBy = DecisionActor.user,
  ChangeDecisionVerdict? verdict = ChangeDecisionVerdict.confirmed,
  String? reason,
}) => LedgerEntry(
  changeSetId: changeSetId,
  itemIndex: itemIndex,
  toolName: toolName,
  args: const {},
  humanSummary: humanSummary,
  fingerprint: fingerprint,
  status: status,
  createdAt: createdAt ?? DateTime.utc(2024, 3, 10),
  resolvedAt: resolvedAt,
  resolvedBy: resolvedBy,
  verdict: verdict,
  reason: reason,
);

void main() {
  group('formatResolvedLedgerLine', () {
    // ── generative property ──────────────────────────────────────────────────

    glados.Glados3(
      glados.AnyUtils(glados.any).choose(ChangeDecisionVerdict.values),
      glados.AnyUtils(
        glados.any,
      ).choose(<DecisionActor?>[DecisionActor.user, DecisionActor.agent, null]),
      glados.AnyUtils(
        glados.any,
      ).choose(<String?>[null, '', '  ', 'too vague', 'cited evidence']),
      glados.ExploreConfig(numRuns: 120),
    ).test('always carries fingerprint, tool, summary and verdict', (
      verdict,
      actor,
      reason,
    ) {
      final line = formatResolvedLedgerLine(
        _entry(verdict: verdict, resolvedBy: actor, reason: reason),
      );
      expect(line, contains('[fp=set_task_title:123]'));
      expect(line, contains('`set_task_title`'));
      expect(line, contains('Set title to "X"'));
      expect(line, contains(verdict.name));
      // The reason renders exactly when it carries information.
      final hasReason = reason != null && reason.trim().isNotEmpty;
      expect(line.contains('(reason: "'), hasReason);
      expect(
        line.contains('by user'),
        actor == DecisionActor.user,
      );
    }, tags: 'glados');

    // ── examples ─────────────────────────────────────────────────────────────

    test('renders a user confirmation', () {
      expect(
        formatResolvedLedgerLine(_entry()),
        '[fp=set_task_title:123] ✓ `set_task_title`: Set title to "X" '
        '— confirmed by user',
      );
    });

    test('renders an agent retraction with its reason', () {
      expect(
        formatResolvedLedgerLine(
          _entry(
            verdict: ChangeDecisionVerdict.retracted,
            resolvedBy: DecisionActor.agent,
            reason: 'duplicates an open proposal',
          ),
        ),
        '[fp=set_task_title:123] ↺ `set_task_title`: Set title to "X" '
        '— retracted by agent (reason: "duplicates an open proposal")',
      );
    });

    test('falls back to the item status when no verdict exists', () {
      expect(
        formatResolvedLedgerLine(
          _entry(
            verdict: null,
            resolvedBy: null,
            status: ChangeItemStatus.rejected,
          ),
        ),
        contains('○ `set_task_title`: Set title to "X" — rejected'),
      );
    });
  });

  group('decisionEventsFromLedger', () {
    test('positions each verdict at its resolution time with a unique '
        'deterministic key', () {
      final events = decisionEventsFromLedger([
        _entry(resolvedAt: DateTime.utc(2024, 3, 12)),
        _entry(
          itemIndex: 1,
          fingerprint: 'other:1',
          resolvedAt: DateTime.utc(2024, 3, 14),
        ),
      ]);

      expect(events, hasLength(2));
      expect(events[0].position.at, DateTime.utc(2024, 3, 12));
      expect(events[0].position.key, 'decision|cs-1:0');
      expect(events[1].position.key, 'decision|cs-1:1');
      expect(events[0].contentDigest, isNull);
      expect(events[0].inlineContent!['entryType'], 'decision');
      expect(
        events[0].inlineContent!['text'],
        formatResolvedLedgerLine(_entry()),
      );
    });

    test('falls back to the proposal creation time when resolvedAt is '
        'missing', () {
      final events = decisionEventsFromLedger([
        _entry(createdAt: DateTime.utc(2024, 3, 11)),
      ]);
      expect(events.single.position.at, DateTime.utc(2024, 3, 11));
      expect(events.single.sourceCreatedAt, DateTime.utc(2024, 3, 11));
    });
  });
}
