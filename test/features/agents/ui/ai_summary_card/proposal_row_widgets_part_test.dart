import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../test_data/change_set_factories.dart';
import 'test_bench.dart';

PendingSuggestion _pending(String tool) {
  return makePending(
    id: tool,
    toolName: tool,
    humanSummary: 'Body for $tool',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(makeTestChangeSet());
    registerFallbackValue(<String>{});
  });
  group('AiSummaryCard – Proposal kind labels', () {
    // Each tool name resolves (via `_resolveKind`) to a proposal kind, and
    // each kind resolves (via `_kindMeta`) to a label that renders as a
    // quiet inline prefix of the row text ("Update · …") — the accent
    // family is reserved for actions, so the kind never gets its own
    // colored chip.
    const cases = <({String tool, String expectedLabel})>[
      (tool: 'add_multiple_checklist_items', expectedLabel: 'Add'),
      (tool: 'update_checklist_items', expectedLabel: 'Update'),
      (tool: 'retract_suggestions', expectedLabel: 'Remove'),
      (tool: 'update_task_priority', expectedLabel: 'Priority'),
      (tool: 'update_task_estimate', expectedLabel: 'Estimate'),
      (tool: 'set_task_status', expectedLabel: 'Status'),
      (tool: 'assign_task_labels', expectedLabel: 'Label'),
      (tool: 'update_task_due_date', expectedLabel: 'Due'),
    ];

    for (final c in cases) {
      testWidgets(
        'renders the ${c.expectedLabel} inline prefix for ${c.tool}',
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

          expect(
            find.textContaining('${c.expectedLabel} · '),
            findsOneWidget,
          );
          // The label leads the row's own text — one rich text per row.
          expect(
            find.textContaining('${c.expectedLabel} · Body for ${c.tool}'),
            findsOneWidget,
          );
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

        // The fallback resolves to the Update kind, so the prefix reads
        // "Update · " — identical to the explicit `update_checklist_items`
        // case, proving the default arm routes through the same
        // `_kindMeta(_ProposalKind.update)` path.
        expect(find.textContaining('Update · '), findsOneWidget);
      },
    );
  });
}
