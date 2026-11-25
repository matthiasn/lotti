import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/ui/front_chat_day_label.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  test('the same local day, whatever the hour', () {
    expect(
      frontChatSameDay(
        DateTime(2026, 11, 24, 0, 5),
        DateTime(2026, 11, 24, 23),
      ),
      isTrue,
    );
    expect(
      frontChatSameDay(
        DateTime(2026, 11, 24, 23),
        DateTime(2026, 11, 25, 0, 5),
      ),
      isFalse,
    );
  });

  testWidgets('today and yesterday by name, every other day by date', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    withClock(Clock.fixed(DateTime(2026, 11, 24, 9)), () {
      expect(
        frontChatDayLabel(context, DateTime(2026, 11, 24, 8), 'en'),
        'Today',
      );
      expect(
        frontChatDayLabel(context, DateTime(2026, 11, 23, 22), 'en'),
        'Yesterday',
      );
      expect(
        frontChatDayLabel(context, DateTime(2026, 11, 20, 9), 'en'),
        'Friday, November 20, 2026',
      );
    });
    // Just after midnight, yesterday's late evening is still yesterday —
    // counted by the calendar, not by 24 hours.
    withClock(Clock.fixed(DateTime(2026, 3, 30, 0, 30)), () {
      expect(
        frontChatDayLabel(context, DateTime(2026, 3, 29, 23, 45), 'en'),
        'Yesterday',
      );
      expect(
        frontChatDayLabel(context, DateTime(2026, 3, 28, 23, 45), 'en'),
        'Saturday, March 28, 2026',
      );
    });
    // Across the start of a month.
    withClock(Clock.fixed(DateTime(2026, 12, 1, 8)), () {
      expect(
        frontChatDayLabel(context, DateTime(2026, 11, 30, 20), 'en'),
        'Yesterday',
      );
    });
  });
}
