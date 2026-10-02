import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_wake_budget_row.dart';
import 'package:lotti/features/design_system/theme/icon_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../test_helper.dart';

void main() {
  Future<List<int>> pumpRow(
    WidgetTester tester, {
    required int used,
    required int maxPerDay,
    bool enabled = true,
  }) async {
    final chosen = <int>[];
    await tester.pumpWidget(
      WidgetTestBench(
        child: AgentWakeBudgetRow(
          used: used,
          maxPerDay: maxPerDay,
          onChanged: enabled ? chosen.add : null,
        ),
      ),
    );
    await tester.pump();
    return chosen;
  }

  InkWell glyph(WidgetTester tester, String key) => tester.widget(
    find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(InkWell),
    ),
  );

  group('AgentWakeBudgetRow', () {
    testWidgets('shows the limit and how much of it today used', (
      tester,
    ) async {
      await pumpRow(tester, used: 3, maxPerDay: 10);

      expect(find.text('Daily wake limit'), findsOneWidget);
      expect(find.text('3 of 10 used today'), findsOneWidget);
      expect(find.text('10 per day'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agentWakeBudgetExhaustedGlyph')),
        findsNothing,
      );
    });

    testWidgets('says automatic updates resume tomorrow once the limit is '
        'used, with the warning glyph', (tester) async {
      await pumpRow(tester, used: 10, maxPerDay: 10);

      expect(
        find.text('Limit reached — automatic updates resume tomorrow'),
        findsOneWidget,
      );
      final glyph = tester.widget<Icon>(
        find.byKey(const ValueKey('agentWakeBudgetExhaustedGlyph')),
      );
      expect(glyph.icon, LottiIcons.warning);
    });

    testWidgets('steps to the neighbouring choices', (tester) async {
      final chosen = await pumpRow(tester, used: 0, maxPerDay: 10);

      await tester.tap(find.byKey(const ValueKey('agentWakeBudgetDecrease')));
      await tester.tap(find.byKey(const ValueKey('agentWakeBudgetIncrease')));

      expect(chosen, [5, 15]);
    });

    testWidgets('a value between two choices steps to the nearest on either '
        'side', (tester) async {
      final chosen = await pumpRow(tester, used: 0, maxPerDay: 7);

      await tester.tap(find.byKey(const ValueKey('agentWakeBudgetDecrease')));
      await tester.tap(find.byKey(const ValueKey('agentWakeBudgetIncrease')));

      expect(chosen, [5, 10]);
    });

    testWidgets('disables the side that has no further choice', (
      tester,
    ) async {
      await pumpRow(tester, used: 0, maxPerDay: 1);
      expect(glyph(tester, 'agentWakeBudgetDecrease').onTap, isNull);
      expect(glyph(tester, 'agentWakeBudgetIncrease').onTap, isNotNull);

      await pumpRow(tester, used: 0, maxPerDay: 24);
      expect(glyph(tester, 'agentWakeBudgetDecrease').onTap, isNotNull);
      expect(glyph(tester, 'agentWakeBudgetIncrease').onTap, isNull);
    });

    testWidgets('a row without a handler cannot be changed', (tester) async {
      await pumpRow(tester, used: 0, maxPerDay: 10, enabled: false);

      expect(glyph(tester, 'agentWakeBudgetDecrease').onTap, isNull);
      expect(glyph(tester, 'agentWakeBudgetIncrease').onTap, isNull);
    });
  });
}
