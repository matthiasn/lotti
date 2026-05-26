import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_card.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/why_chip.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child) => makeTestableWidget2(
  child,
  mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
);

const _category = DayAgentCategory(
  id: 'cat_work',
  name: 'Work',
  colorHex: '5ED4B7',
);

void main() {
  group('AgendaCard', () {
    testWidgets('renders title, outcome and an estimate chip', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Material(
            child: AgendaCard(
              index: 1,
              item: AgendaItem(
                id: 'a1',
                title: 'Send the leadership deck to Sarah',
                category: _category,
                linkedBlockIds: ['b1'],
                outcome: 'Deck reviewed by Sarah, sent to leadership.',
                totalEstimateMinutes: 120,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Send the leadership deck to Sarah'), findsOneWidget);
      expect(
        find.text('Deck reviewed by Sarah, sent to leadership.'),
        findsOneWidget,
      );
      expect(find.text('120m'), findsOneWidget);
    });

    testWidgets('shows WhyChip when a whyReason is provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Material(
            child: AgendaCard(
              index: 1,
              item: AgendaItem(
                id: 'a1',
                title: 'Deep work',
                category: _category,
                linkedBlockIds: ['b1'],
              ),
              whyReason: 'High-energy window 8–10:30.',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(WhyChip), findsOneWidget);
    });

    testWidgets('omits WhyChip when no reason is provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Material(
            child: AgendaCard(
              index: 1,
              item: AgendaItem(
                id: 'a1',
                title: 'Plain item',
                category: _category,
                linkedBlockIds: ['b1'],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(WhyChip), findsNothing);
    });

    testWidgets('invokes onTap when the card is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          Material(
            child: AgendaCard(
              index: 1,
              item: const AgendaItem(
                id: 'a1',
                title: 'Open task',
                category: _category,
                linkedBlockIds: ['b1'],
                taskId: 'task-1',
              ),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open task'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
