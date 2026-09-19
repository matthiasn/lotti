import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_layout_widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('TaskShowcaseHeroBanner', () {
    testWidgets('draws its bridge art once: the painter never asks to '
        'repaint', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(width: 480, child: TaskShowcaseHeroBanner()),
        ),
      );

      final bridge = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(TaskShowcaseHeroBanner),
          matching: find.byWidgetPredicate(
            (widget) => widget is CustomPaint && widget.painter != null,
          ),
        ),
      );
      final painter = bridge.painter!;

      expect(painter.shouldRepaint(painter), isFalse);
      // The art keeps the bridge's wide aspect.
      final size = tester.getSize(find.byWidget(bridge));
      expect(size.width / size.height, closeTo(2.7, 0.01));
    });
  });

  group('TaskShowcaseDesktopActionBar', () {
    testWidgets('the showcase FAB is the real design-system button and a tap '
        'on it changes nothing', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const TaskShowcaseDesktopActionBar()),
      );
      final fab = find.byType(DesignSystemFloatingActionButton);
      expect(
        tester.widget<DesignSystemFloatingActionButton>(fab).onPressed,
        isNotNull,
      );

      await tester.tap(fab);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(fab, findsOneWidget);
    });
  });
}
