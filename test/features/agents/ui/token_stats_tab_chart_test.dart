import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/ui/token_stats_tab_chart.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('exposes each day as one selected token-usage button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SizedBox(
          height: 180,
          child: InteractiveWeeklyChart(
            days: [
              DailyTokenUsage(
                date: DateTime(2024, 3, 15),
                totalTokens: 1000,
                tokensByTimeOfDay: 1000,
                isToday: true,
              ),
            ],
            selectedIndex: 0,
            onBarTap: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Mar 15, 2024, 1K tokens')),
      matchesSemantics(
        label: 'Mar 15, 2024, 1K tokens',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });
}
