import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_update_interval_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../../test_helper.dart';

void main() {
  Future<List<int>> pumpRow(
    WidgetTester tester, {
    required int intervalMinutes,
    bool enabled = true,
  }) async {
    final chosen = <int>[];
    await tester.pumpWidget(
      WidgetTestBench(
        child: AgentUpdateIntervalRow(
          intervalMinutes: intervalMinutes,
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

  group('AgentUpdateIntervalRow', () {
    testWidgets('names each offered interval in plain words', (tester) async {
      for (final (minutes, label) in [
        (60, 'Every hour'),
        (120, 'Every 2 hours'),
        (240, 'Every 4 hours'),
        (480, 'Every 8 hours'),
        (1440, 'Once a day'),
      ]) {
        await pumpRow(tester, intervalMinutes: minutes);
        expect(find.text(label), findsOneWidget, reason: '$minutes');
      }
      expect(find.text('Update frequency'), findsOneWidget);
      expect(
        find.text('Out-of-date summaries refresh at most this often'),
        findsOneWidget,
      );
    });

    testWidgets('steps to the neighbouring intervals: decrement is more '
        'often', (tester) async {
      final chosen = await pumpRow(tester, intervalMinutes: 240);

      await tester.tap(
        find.byKey(const ValueKey('agentUpdateIntervalDecrease')),
      );
      await tester.tap(
        find.byKey(const ValueKey('agentUpdateIntervalIncrease')),
      );

      expect(chosen, [120, 480]);
    });

    testWidgets('disables the side that has no further interval', (
      tester,
    ) async {
      await pumpRow(tester, intervalMinutes: 60);
      expect(glyph(tester, 'agentUpdateIntervalDecrease').onTap, isNull);
      expect(glyph(tester, 'agentUpdateIntervalIncrease').onTap, isNotNull);

      await pumpRow(tester, intervalMinutes: 1440);
      expect(glyph(tester, 'agentUpdateIntervalDecrease').onTap, isNotNull);
      expect(glyph(tester, 'agentUpdateIntervalIncrease').onTap, isNull);
    });

    testWidgets('a row without a handler cannot be changed', (tester) async {
      await pumpRow(tester, intervalMinutes: 240, enabled: false);

      expect(glyph(tester, 'agentUpdateIntervalDecrease').onTap, isNull);
      expect(glyph(tester, 'agentUpdateIntervalIncrease').onTap, isNull);
    });
  });
}
