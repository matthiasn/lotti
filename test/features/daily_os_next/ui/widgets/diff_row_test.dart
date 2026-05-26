import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/diff_row.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

const _category = DayAgentCategory(
  id: 'cat-work',
  name: 'Work',
  colorHex: '3366CC',
);

final _change = PlanDiffChange(
  id: 'diff_0',
  kind: PlanDiffChangeKind.added,
  title: 'Gym session',
  category: _category,
  reason: 'User requested a gym session.',
  affectedBlockId: 'block-1',
  toStart: DateTime(2026, 5, 25, 20),
  toEnd: DateTime(2026, 5, 25, 21, 45),
);

Widget _wrap(Widget child) => makeTestableWidget2(
  Material(child: child),
  mediaQueryData: const MediaQueryData(size: Size(420, 500)),
);

void main() {
  group('DiffRow', () {
    testWidgets('shows per-change accept and reject actions', (tester) async {
      var accepted = 0;
      var rejected = 0;
      await tester.pumpWidget(
        _wrap(
          DiffRow(
            change: _change,
            decision: PlanDiffChangeDecision.pending,
            onAccept: () => accepted++,
            onReject: () => rejected++,
          ),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(DiffRow));
      final messages = context.messages;
      expect(find.text(messages.dailyOsNextRefineAccept), findsOneWidget);
      expect(find.text(messages.changeSetSwipeReject), findsOneWidget);

      await tester.tap(find.text(messages.dailyOsNextRefineAccept));
      await tester.tap(find.text(messages.changeSetSwipeReject));

      expect(accepted, 1);
      expect(rejected, 1);
    });

    testWidgets('collapses accepted rows into a confirmation pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DiffRow(
            change: _change,
            decision: PlanDiffChangeDecision.accepted,
            onAccept: () {},
            onReject: () {},
          ),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(DiffRow));
      final messages = context.messages;
      expect(find.text(messages.changeSetItemConfirmed), findsOneWidget);
      expect(find.text(messages.dailyOsNextRefineAccept), findsNothing);
      expect(find.text(messages.changeSetSwipeReject), findsNothing);
    });
  });
}
