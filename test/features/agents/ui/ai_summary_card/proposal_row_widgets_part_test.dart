import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/localized_change_summary.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:mocktail/mocktail.dart';

import '../../test_data/change_set_factories.dart';
import 'test_bench.dart';

/// The text the row will actually render for [tool].
///
/// The row rebuilds its body from `toolName` + `args` so a non-English reader
/// sees a translated proposal, falling back to the persisted summary only for
/// tools it cannot reconstruct. These tests are about the inline *kind* prefix
/// rather than the body wording, so the expectation is derived the same way the
/// row derives it instead of hardcoding one or the other.
String _bodyFor(String tool) =>
    localizedChangeSummary(AppLocalizationsEn(), tool, const {}) ??
    'Body for $tool';

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
      (tool: 'link_task', expectedLabel: 'Add'),
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
            find.textContaining('${c.expectedLabel} · ${_bodyFor(c.tool)}'),
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

    testWidgets('proposal prose uses the unmodified bodySmall metrics', (
      tester,
    ) async {
      final bench = AgentTestBench(
        suggestions: UnifiedSuggestionList(
          open: [_pending('set_task_status')],
          activity: const [],
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final text = tester.widget<Text>(
        find.textContaining('Status · ${_bodyFor('set_task_status')}'),
      );
      final context = tester.element(find.byType(Text).first);
      final bodySmall = context.designTokens.typography.styles.body.bodySmall;
      expect(text.style?.fontSize, bodySmall.fontSize);
      expect(text.style?.height, bodySmall.height);
      expect(text.style?.fontWeight, bodySmall.fontWeight);
    });
  });

  group('AiSummaryCard – RowActions hover', () {
    // The visible button is the 32px disc inside a 48×48 hit target. A hover
    // fill over the whole target painted a phantom square around the disc,
    // so the disc answers hover itself: its outline firms in its own hue
    // family, and no Material overlay may paint.
    testWidgets(
      'hovering the confirm target draws the accent outline on the disc, '
      'not an overlay on the hit area',
      (tester) async {
        final bench = AgentTestBench(
          suggestions: UnifiedSuggestionList(
            open: [_pending('set_task_status')],
            activity: const [],
          ),
        );
        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final confirmIcon = find.byIcon(LottiIcons.confirm);
        BoxDecoration discDecoration() {
          final container = tester.widget<Container>(
            find
                .ancestor(of: confirmIcon, matching: find.byType(Container))
                .first,
          );
          return container.decoration! as BoxDecoration;
        }

        expect(discDecoration().border, isNull);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(confirmIcon));
        await tester.pump();

        final ai = tester.element(confirmIcon).designTokens.colors.aiCard;
        expect(discDecoration().border, Border.all(color: ai.accent));

        // No phantom square: every overlay on the 48×48 ink is silenced.
        final inkWell = tester.widget<InkWell>(
          find.ancestor(of: confirmIcon, matching: find.byType(InkWell)).first,
        );
        expect(inkWell.hoverColor, Colors.transparent);
        expect(
          inkWell.overlayColor?.resolve({WidgetState.hovered}),
          Colors.transparent,
        );
      },
    );
  });
}
