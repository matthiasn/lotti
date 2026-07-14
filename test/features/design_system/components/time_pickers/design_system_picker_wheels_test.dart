import 'package:flutter/cupertino.dart' show CupertinoTimerPicker;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets(
    'time wheel uses the requested clock format and forwards changes',
    (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();
      DateTime? changed;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemTimeWheel(
            initialDateTime: DateTime(2024, 6, 15, 14, 30),
            use24hFormat: true,
            onDateTimeChanged: (value) => changed = value,
          ),
        ),
      );

      final picker = tester.widget<DesignSystemTimeWheel>(
        find.byType(DesignSystemTimeWheel),
      );
      expect(picker.use24hFormat, isTrue);
      expect(find.byType(ListWheelScrollView), findsNWidgets(2));
      expect(find.text(':'), findsOneWidget);

      final wheel = tester.widget<ListWheelScrollView>(
        find.byType(ListWheelScrollView).first,
      );
      expect(wheel.physics, isA<FixedExtentScrollPhysics>());
      expect(wheel.itemExtent, 40);
      expect(wheel.diameterRatio, 1.07);
      expect(wheel.squeeze, 1.45);
      expect(wheel.overAndUnderCenterOpacity, 0.447);

      final hour = tester.getSemantics(find.bySemanticsLabel('Hour'));
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.increase,
          nodeId: hour.id,
          viewId: tester.view.viewId,
        ),
      );
      await tester.pump();
      expect(changed, DateTime(2024, 6, 15, 15, 30));

      final minute = tester.getSemantics(find.bySemanticsLabel('Minute'));
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.increase,
          nodeId: minute.id,
          viewId: tester.view.viewId,
        ),
      );
      await tester.pump();
      expect(changed, DateTime(2024, 6, 15, 15, 31));

      final updatedMinute = tester.getSemantics(
        find.bySemanticsLabel('Minute'),
      );
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.decrease,
          nodeId: updatedMinute.id,
          viewId: tester.view.viewId,
        ),
      );
      await tester.pump();
      expect(changed, DateTime(2024, 6, 15, 15, 30));
      semanticsHandle.dispose();
    },
  );

  testWidgets('12-hour wheel includes a fixed AM/PM column', (tester) async {
    DateTime? changed;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DesignSystemTimeWheel(
          initialDateTime: DateTime(2024, 6, 15, 14, 30),
          onDateTimeChanged: (value) => changed = value,
        ),
      ),
    );

    expect(find.byType(ListWheelScrollView), findsNWidgets(3));
    expect(find.text('PM'), findsWidgets);

    await tester.drag(
      find.byType(ListWheelScrollView).at(2),
      const Offset(0, 48),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(changed, DateTime(2024, 6, 15, 2, 30));
  });

  testWidgets('time columns expose localized adjustable semantics', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    DateTime? changed;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DesignSystemTimeWheel(
          initialDateTime: DateTime(2024, 6, 15, 14, 30),
          onDateTimeChanged: (value) => changed = value,
        ),
      ),
    );

    final hour = tester.getSemantics(find.bySemanticsLabel('Hour'));
    final minute = tester.getSemantics(find.bySemanticsLabel('Minute'));
    final period = tester.getSemantics(find.bySemanticsLabel('AM / PM'));
    expect(hour.value, '2');
    expect(hour.increasedValue, '3');
    expect(minute.value, '30');
    expect(period.value, 'PM');

    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        type: SemanticsAction.increase,
        nodeId: hour.id,
        viewId: tester.view.viewId,
      ),
    );
    await tester.pump();
    expect(changed, DateTime(2024, 6, 15, 15, 30));
    semanticsHandle.dispose();
  });

  testWidgets('duration wheel exposes composed live semantics', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DesignSystemDurationWheel(
          initialDuration: const Duration(minutes: 30),
          semanticsLabel: 'Estimate: 0h 30m',
          semanticsLiveRegion: true,
          onDurationChanged: (_) {},
        ),
      ),
    );

    final semantics = tester.getSemantics(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
    );
    expect(semantics.label, 'Estimate: 0h 30m');
    expect(find.byType(CupertinoTimerPicker), findsOneWidget);
  });
}
