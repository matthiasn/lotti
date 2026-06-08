import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:mocktail/mocktail.dart';

import '../../test_data/change_set_factories.dart';
import 'test_bench.dart';

PendingSuggestion _pending(String tool) {
  return makePending(
    id: tool,
    toolName: tool,
    humanSummary: 'Body for $tool',
  );
} // Per-kind token selectors. Each generated `DsColorsProposalKind<Kind>` is a

// distinct type with no shared interface, so we project each onto a common
// `(color, surface)` record for the parameterized chip test below.
({Color color, Color surface}) _selectAdd(DsColorsProposalKind p) =>
    (color: p.add.color, surface: p.add.surface);
({Color color, Color surface}) _selectUpdate(DsColorsProposalKind p) =>
    (color: p.update.color, surface: p.update.surface);
({Color color, Color surface}) _selectRemove(DsColorsProposalKind p) =>
    (color: p.remove.color, surface: p.remove.surface);
({Color color, Color surface}) _selectPriority(DsColorsProposalKind p) =>
    (color: p.priority.color, surface: p.priority.surface);
({Color color, Color surface}) _selectEstimate(DsColorsProposalKind p) =>
    (color: p.estimate.color, surface: p.estimate.surface);
({Color color, Color surface}) _selectStatus(DsColorsProposalKind p) =>
    (color: p.status.color, surface: p.status.surface);
({Color color, Color surface}) _selectLabel(DsColorsProposalKind p) =>
    (color: p.label.color, surface: p.label.surface);
({Color color, Color surface}) _selectDue(DsColorsProposalKind p) =>
    (color: p.due.color, surface: p.due.surface);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(makeTestChangeSet());
    registerFallbackValue(<String>{});
  });
  group('AiSummaryCard – Proposal kind chips', () {
    // Each tool name resolves (via `_resolveKind`) to a proposal kind, and
    // each kind resolves (via `_kindMeta`) to a chip whose label text, text
    // color and surface color come from the `proposalKind` design tokens.
    // We drive every (tool → kind) arm and assert all three observable
    // properties against the live production tokens rather than re-deriving
    // them in the test.
    const cases =
        <
          ({
            String tool,
            String expectedLabel,
            ({Color color, Color surface}) Function(DsColorsProposalKind p)
            select,
          })
        >[
          (
            tool: 'add_multiple_checklist_items',
            expectedLabel: 'Add',
            select: _selectAdd,
          ),
          (
            tool: 'update_checklist_items',
            expectedLabel: 'Update',
            select: _selectUpdate,
          ),
          (
            tool: 'retract_suggestions',
            expectedLabel: 'Remove',
            select: _selectRemove,
          ),
          (
            tool: 'update_task_priority',
            expectedLabel: 'Priority',
            select: _selectPriority,
          ),
          (
            tool: 'update_task_estimate',
            expectedLabel: 'Estimate',
            select: _selectEstimate,
          ),
          (
            tool: 'set_task_status',
            expectedLabel: 'Status',
            select: _selectStatus,
          ),
          (
            tool: 'assign_task_labels',
            expectedLabel: 'Label',
            select: _selectLabel,
          ),
          (
            tool: 'update_task_due_date',
            expectedLabel: 'Due',
            select: _selectDue,
          ),
        ];

    for (final c in cases) {
      testWidgets(
        'renders ${c.expectedLabel} chip with token color/surface '
        'for ${c.tool}',
        (tester) async {
          final bench = AgentTestBench(
            suggestions: UnifiedSuggestionList(
              open: [_pending(c.tool)],
              activity: const [],
            ),
          );

          await tester.pumpWidget(bench.build());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          final labelFinder = find.text(c.expectedLabel);
          expect(labelFinder, findsOneWidget);

          // Resolve the production tokens from the live render context so the
          // expected colors are never hard-coded or re-derived in the test.
          final tokens = tester
              .element(labelFinder)
              .designTokens
              .colors
              .proposalKind;
          final entry = c.select(tokens);

          final labelText = tester.widget<Text>(labelFinder);
          expect(labelText.style?.color, entry.color);

          // Each kind is a distinct token; sanity-check that the chip color
          // is the kind's own foreground, not a different kind's.
          expect(entry.color, isNot(entry.surface));

          // The chip surface lives on the nearest enclosing decorated
          // Container ancestor of the label text.
          final chip = tester.widget<Container>(
            find
                .ancestor(of: labelFinder, matching: find.byType(Container))
                .first,
          );
          final decoration = chip.decoration! as BoxDecoration;
          expect(decoration.color, entry.surface);
        },
      );
    }

    testWidgets(
      'an unrecognised tool name falls through to the Update kind chip',
      (tester) async {
        // `_resolveKind` has a `default → _ProposalKind.update` arm for any
        // tool name not in its dispatch table. A made-up tool name exercises
        // exactly that fallback, which is otherwise unreached by the known
        // tool-name cases above.
        final bench = AgentTestBench(
          suggestions: UnifiedSuggestionList(
            open: [_pending('totally_unknown_future_tool')],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The fallback resolves to the Update kind, so the chip reads
        // "Update" and carries the Update token colors — identical to the
        // explicit `update_checklist_items` case, proving the default arm
        // routes through the same `_kindMeta(_ProposalKind.update)` path.
        final labelFinder = find.text('Update');
        expect(labelFinder, findsOneWidget);

        final updateTokens = _selectUpdate(
          tester.element(labelFinder).designTokens.colors.proposalKind,
        );
        final labelText = tester.widget<Text>(labelFinder);
        expect(labelText.style?.color, updateTokens.color);

        final chip = tester.widget<Container>(
          find
              .ancestor(of: labelFinder, matching: find.byType(Container))
              .first,
        );
        expect(
          (chip.decoration! as BoxDecoration).color,
          updateTokens.surface,
        );
      },
    );
  });
}
