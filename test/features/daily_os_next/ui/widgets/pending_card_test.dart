import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/pending_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

const _category = DayAgentCategory(
  id: 'work',
  name: 'Work',
  colorHex: '5ED4B7',
);

Widget _wrap(Widget child) => makeTestableWidget2(
  Material(child: child),
  mediaQueryData: const MediaQueryData(size: Size(500, 400)),
);

void main() {
  group('PendingCard', () {
    testWidgets('labels due items against the selected plan date', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PendingCard(
            item: PendingItem(
              taskId: 'task-1',
              title: 'Submit report',
              category: _category,
              reason: PendingItemReason.dueToday,
              referenceDate: DateTime(2026, 5, 30),
            ),
            onTriage: (_) {},
          ),
        ),
      );

      final messages = tester.element(find.byType(PendingCard)).messages;
      expect(
        find.text(messages.dailyOsNextStateDueOnDate('May 30')),
        findsOneWidget,
      );
      expect(find.text('Submit report'), findsOneWidget);
    });

    testWidgets('labels overdue items against the selected plan date', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PendingCard(
            item: PendingItem(
              taskId: 'task-1',
              title: 'Pay invoice',
              category: _category,
              reason: PendingItemReason.overdue,
              overdueByDays: 5,
              referenceDate: DateTime(2026, 5, 30),
            ),
            onTriage: (_) {},
          ),
        ),
      );

      final messages = tester.element(find.byType(PendingCard)).messages;
      expect(
        find.text(messages.dailyOsNextStateOverdueOnDate(5, 'May 30')),
        findsOneWidget,
      );
      expect(find.text('Pay invoice'), findsOneWidget);
    });
  });
}
