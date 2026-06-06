import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/today_button.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('TodayButton', () {
    testWidgets('renders the localized label with the calendar icon and '
        'invokes onPressed', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Center(child: TodayButton(onPressed: () => pressed++)),
        ),
      );

      expect(find.text('Today'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(MdiIcons.calendarToday));
      expect(icon.size, 16);

      // Icon and label share the primary color.
      final context = tester.element(find.byType(TodayButton));
      final primary = Theme.of(context).colorScheme.primary;
      expect(icon.color, primary);
      expect(
        tester.widget<Text>(find.text('Today')).style?.color,
        primary,
      );

      await tester.tap(find.byType(TodayButton));
      await tester.pump();
      expect(pressed, 1);
    });

    testWidgets('uses a compact hit area (no minimum size inflation)', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Center(child: TodayButton(onPressed: () {})),
        ),
      );

      final button = tester.widget<TextButton>(find.byType(TextButton));
      expect(button.style?.minimumSize?.resolve(const {}), Size.zero);
      expect(
        button.style?.tapTargetSize,
        MaterialTapTargetSize.shrinkWrap,
      );
    });
  });
}
