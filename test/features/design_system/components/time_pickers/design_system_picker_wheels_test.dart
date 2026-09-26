import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoTimerPicker;
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

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
      final minuteWheel = tester.widget<ListWheelScrollView>(
        find.byType(ListWheelScrollView).at(1),
      );
      expect(wheel.physics, isA<FixedExtentScrollPhysics>());
      expect(wheel.physics!.maxFlingVelocity, 320);
      expect(minuteWheel.physics!.maxFlingVelocity, 800);
      expect(wheel.dragStartBehavior, DragStartBehavior.down);
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

  testWidgets('time changes preserve a UTC initial value', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    DateTime? changed;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DesignSystemTimeWheel(
          initialDateTime: DateTime.utc(2024, 6, 15, 14, 30),
          use24hFormat: true,
          onDateTimeChanged: (value) => changed = value,
        ),
      ),
    );

    final hour = tester.getSemantics(find.bySemanticsLabel('Hour'));
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        type: SemanticsAction.increase,
        nodeId: hour.id,
        viewId: tester.view.viewId,
      ),
    );
    await tester.pump();

    expect(changed, DateTime.utc(2024, 6, 15, 15, 30));
    expect(changed!.isUtc, isTrue);
    semanticsHandle.dispose();
  });

  testWidgets('looping hour wheel can move backwards from midnight', (
    tester,
  ) async {
    DateTime? changed;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DesignSystemTimeWheel(
          initialDateTime: DateTime(2024, 6, 15),
          use24hFormat: true,
          onDateTimeChanged: (value) => changed = value,
        ),
      ),
    );

    final hourWheel = find.byType(ListWheelScrollView).first;
    final controller =
        tester.widget<ListWheelScrollView>(hourWheel).controller!
            as FixedExtentScrollController;
    expect(controller.selectedItem, greaterThan(24));

    await tester.drag(hourWheel, const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 800));

    expect(changed, DateTime(2024, 6, 15, 23));
  });

  testWidgets('looping columns defensively normalize absolute indices', (
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

    final hourWheel = tester.widget<ListWheelScrollView>(
      find.byType(ListWheelScrollView).first,
    );
    hourWheel.onSelectedItemChanged!(12005);
    await tester.pump();

    final hour = tester.getSemantics(find.bySemanticsLabel('Hour'));
    expect(hour.value, '05');
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        type: SemanticsAction.increase,
        nodeId: hour.id,
        viewId: tester.view.viewId,
      ),
    );
    await tester.pump();

    expect(changed, DateTime(2024, 6, 15, 6, 30));
    semanticsHandle.dispose();
  });

  testWidgets(
    'Linux pointer scroll accumulates fine deltas and keeps accepting '
    'large events',
    (
      tester,
    ) async {
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

      final hourWheel = find.byType(ListWheelScrollView).first;
      Future<void> scrollBy(double delta, Duration timeStamp) =>
          tester.sendEventToBinding(
            PointerScrollEvent(
              position: tester.getCenter(hourWheel),
              scrollDelta: Offset(0, delta),
              timeStamp: timeStamp,
            ),
          );

      await scrollBy(10, Duration.zero);
      await tester.pump();
      expect(changed, isNull);

      await scrollBy(10, const Duration(milliseconds: 10));
      await tester.pump();
      expect(changed, DateTime(2024, 6, 15, 15, 30));

      for (var i = 0; i < 2; i++) {
        await scrollBy(400, Duration(milliseconds: 20 + i * 10));
        await tester.pump();
      }
      expect(changed, DateTime(2024, 6, 15, 17, 30));

      for (var i = 0; i < 8; i++) {
        await scrollBy(400, Duration(milliseconds: 40 + i * 10));
        await tester.pump();
      }
      expect(changed, DateTime(2024, 6, 15, 1, 30));
    },
  );

  testWidgets('fast hour drag accelerates without an unbounded fling', (
    tester,
  ) async {
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

    await tester.fling(
      find.byType(ListWheelScrollView).first,
      const Offset(0, -80),
      10000,
    );
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    final advancedHours = (changed!.hour - 14 + 24) % 24;
    expect(advancedHours, inInclusiveRange(2, 4));
  });

  testWidgets('keyboard arrows adjust focused columns one row at a time', (
    tester,
  ) async {
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

    final wheels = find.byType(ListWheelScrollView);
    await tester.tap(wheels.first);
    await tester.pump();

    final tokens = tester.element(wheels.first).designTokens;
    expect(
      tester.widget<Text>(find.text('14').first).style!.color,
      tokens.colors.interactive.enabled,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(changed, DateTime(2024, 6, 15, 15, 30));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(changed, DateTime(2024, 6, 15, 17, 30));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(changed, DateTime(2024, 6, 15, 17, 29));
  });

  testWidgets('settled selection does not rebuild the wheel delegate', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DesignSystemTimeWheel(
          initialDateTime: DateTime(2024, 6, 15, 14, 30),
          use24hFormat: true,
          onDateTimeChanged: (_) {},
        ),
      ),
    );

    final hourWheel = find.byType(ListWheelScrollView).first;
    final initialDelegate = tester
        .widget<ListWheelScrollView>(hourWheel)
        .childDelegate;

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(hourWheel),
        scrollDelta: const Offset(0, 40),
      ),
    );
    await tester.pump();

    final updatedDelegate = tester
        .widget<ListWheelScrollView>(hourWheel)
        .childDelegate;
    expect(updatedDelegate.shouldRebuild(initialDelegate), isFalse);
  });

  testWidgets('theme change refreshes cached wheel children', (tester) async {
    Widget buildWheel(Brightness brightness) => makeTestableWidgetWithScaffold(
      DesignSystemTimeWheel(
        initialDateTime: DateTime(2024, 6, 15, 14, 30),
        use24hFormat: true,
        onDateTimeChanged: (_) {},
      ),
      theme: ThemeData(brightness: brightness),
    );

    await tester.pumpWidget(buildWheel(Brightness.light));
    final hourWheel = find.byType(ListWheelScrollView).first;
    final initialDelegate = tester
        .widget<ListWheelScrollView>(hourWheel)
        .childDelegate;

    await tester.pumpWidget(buildWheel(Brightness.dark));
    await tester.pump(kThemeAnimationDuration);
    final updatedDelegate = tester
        .widget<ListWheelScrollView>(hourWheel)
        .childDelegate;

    expect(updatedDelegate.shouldRebuild(initialDelegate), isTrue);
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

  group('minute drum carries into the hour drum', () {
    Future<List<DateTime>> pumpWheel(
      WidgetTester tester,
      DateTime initial, {
      bool use24hFormat = true,
      MediaQueryData? mediaQueryData,
    }) async {
      final changes = <DateTime>[];
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemTimeWheel(
            initialDateTime: initial,
            use24hFormat: use24hFormat,
            onDateTimeChanged: changes.add,
          ),
          mediaQueryData: mediaQueryData,
        ),
      );
      return changes;
    }

    Finder wheelAt(int index) => find.byType(ListWheelScrollView).at(index);

    int shownRow(WidgetTester tester, int wheel, int itemCount) =>
        (tester.widget<ListWheelScrollView>(wheelAt(wheel)).controller!
                as FixedExtentScrollController)
            .selectedItem %
        itemCount;

    /// Runs every scroll animation to rest. The first frame starts their
    /// tickers; a single long pump would render only that starting frame.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
    }

    Future<void> focusMinutes(WidgetTester tester) async {
      await tester.tap(wheelAt(1));
      await tester.pump();
    }

    testWidgets(
      'dragging minutes back past :00 animates to the previous hour',
      (
        tester,
      ) async {
        final changes = await pumpWheel(tester, DateTime(2024, 6, 15, 14, 1));

        // Two rows down: :01 → :00 → :59.
        await tester.drag(wheelAt(1), const Offset(0, 80));
        await settle(tester);

        expect(changes.last, DateTime(2024, 6, 15, 13, 59));
        expect(shownRow(tester, 0, 24), 13);
        expect(shownRow(tester, 1, 60), 59);
      },
    );

    testWidgets('the hour animates rather than jumping', (tester) async {
      final changes = await pumpWheel(tester, DateTime(2024, 6, 15, 14));
      final hourController =
          tester.widget<ListWheelScrollView>(wheelAt(0)).controller!
              as FixedExtentScrollController;
      final startOffset = hourController.offset;

      await focusMinutes(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      // The new hour is reported at once, while the drum is still moving.
      expect(changes.last, DateTime(2024, 6, 15, 13, 59));
      await tester.pump(const Duration(milliseconds: 100));
      final midOffset = hourController.offset;
      expect(midOffset, lessThan(startOffset));
      expect(midOffset, greaterThan(startOffset - 40));

      await tester.pump(const Duration(milliseconds: 400));
      expect(hourController.offset, startOffset - 40);
      expect(shownRow(tester, 0, 24), 13);
      expect(changes.last, DateTime(2024, 6, 15, 13, 59));
    });

    testWidgets('reduced motion moves the hour without animating', (
      tester,
    ) async {
      final changes = await pumpWheel(
        tester,
        DateTime(2024, 6, 15, 14),
        mediaQueryData: const MediaQueryData(disableAnimations: true),
      );

      await focusMinutes(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(shownRow(tester, 0, 24), 13);
      expect(changes.last, DateTime(2024, 6, 15, 13, 59));
    });

    testWidgets('rolling minutes forward past :59 advances the hour', (
      tester,
    ) async {
      final changes = await pumpWheel(tester, DateTime(2024, 6, 15, 13, 59));

      await focusMinutes(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);

      expect(changes.last, DateTime(2024, 6, 15, 14));
      expect(shownRow(tester, 0, 24), 14);
    });

    testWidgets('crossings in quick succession roll back one hour each', (
      tester,
    ) async {
      final changes = await pumpWheel(tester, DateTime(2024, 6, 15, 14));
      final minuteWheel = tester.widget<ListWheelScrollView>(wheelAt(1));

      // Two backward crossings reported before the first hour animation has
      // had a frame to run: :00 → :59 → :30 → :01 → :00 → :59.
      minuteWheel.onSelectedItemChanged!(59);
      minuteWheel.onSelectedItemChanged!(30);
      minuteWheel.onSelectedItemChanged!(1);
      minuteWheel.onSelectedItemChanged!(0);
      minuteWheel.onSelectedItemChanged!(59);
      await settle(tester);

      expect(shownRow(tester, 0, 24), 12);
      expect(changes.last, DateTime(2024, 6, 15, 12, 59));
    });

    testWidgets(
      'an interrupted hour animation does not overwrite a newer one',
      (
        tester,
      ) async {
        final changes = await pumpWheel(tester, DateTime(2024, 6, 15, 14));
        final minuteWheel = tester.widget<ListWheelScrollView>(wheelAt(1));

        // Back, forward and back again: the third hour animation aims at the
        // same row as the first, which it interrupted along with the second.
        minuteWheel.onSelectedItemChanged!(59);
        minuteWheel.onSelectedItemChanged!(0);
        minuteWheel.onSelectedItemChanged!(59);
        await tester.pump();
        // One more forward crossing must build on 13:59, not on the 14 the
        // drum still shows mid-animation.
        minuteWheel.onSelectedItemChanged!(0);
        await settle(tester);

        expect(shownRow(tester, 0, 24), 14);
        expect(changes.last, DateTime(2024, 6, 15, 14));
        // No report ever pairs the rolled hour with the pre-wrap minute.
        expect(changes, isNot(contains(DateTime(2024, 6, 15, 14, 59))));
      },
    );

    testWidgets(
      'rolling back past midnight wraps the hour but keeps the date',
      (
        tester,
      ) async {
        final changes = await pumpWheel(tester, DateTime(2024, 6, 15));

        await focusMinutes(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await settle(tester);

        expect(changes.last, DateTime(2024, 6, 15, 23, 59));
      },
    );

    testWidgets('a 12-hour wheel crosses from 12 PM back into the morning', (
      tester,
    ) async {
      final changes = await pumpWheel(
        tester,
        DateTime(2024, 6, 15, 12),
        use24hFormat: false,
      );

      await focusMinutes(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settle(tester);

      expect(changes.last, DateTime(2024, 6, 15, 11, 59));
      // Hour row 10 is the "11" label; period row 0 is AM.
      expect(shownRow(tester, 0, 12), 10);
      expect(shownRow(tester, 2, 2), 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);

      expect(changes.last, DateTime(2024, 6, 15, 12));
      expect(shownRow(tester, 2, 2), 1);
    });

    testWidgets('grabbing the hour drum mid-animation keeps where it lands', (
      tester,
    ) async {
      final changes = await pumpWheel(tester, DateTime(2024, 6, 15, 14));

      await focusMinutes(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump(const Duration(milliseconds: 50));

      // The user takes over the hour drum and drags it three rows up.
      await tester.drag(wheelAt(0), const Offset(0, -120));
      await settle(tester);

      final shownHour = shownRow(tester, 0, 24);
      expect(shownHour, isNot(13));
      expect(changes.last, DateTime(2024, 6, 15, shownHour, 59));
    });
  });
}
