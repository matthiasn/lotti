import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/grouped_card_row_surface.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const backgroundKey = Key('row-background');
  const hoverColor = Color(0xFF112233);
  const selectedColor = Color(0xFF445566);

  Future<void> pumpSurface(
    WidgetTester tester, {
    bool selected = false,
    VoidCallback? onTap,
    ValueChanged<bool>? onHoverChanged,
    double topOverlap = 0,
    double bottomOverlap = 0,
  }) {
    return tester.pumpWidget(
      makeTestableWidget2(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: GroupedCardRowSurface(
                selected: selected,
                hoverColor: hoverColor,
                selectedColor: selectedColor,
                padding: const EdgeInsets.all(8),
                onTap: onTap ?? () {},
                onHoverChanged: onHoverChanged,
                topOverlap: topOverlap,
                bottomOverlap: bottomOverlap,
                backgroundKey: backgroundKey,
                child: const Text('Row'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color backgroundColor(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(find.byKey(backgroundKey));
    return (box.decoration as BoxDecoration).color!;
  }

  group('GroupedCardRowSurface', () {
    testWidgets('idle unselected row paints no background layer', (
      tester,
    ) async {
      await pumpSurface(tester);

      expect(find.byKey(backgroundKey), findsNothing);
    });

    testWidgets('selected row paints the selected color', (tester) async {
      await pumpSurface(tester, selected: true);

      expect(backgroundColor(tester), selectedColor);
    });

    testWidgets('hover paints hoverColor and reports onHoverChanged', (
      tester,
    ) async {
      final hoverChanges = <bool>[];
      await pumpSurface(tester, onHoverChanged: hoverChanges.add);

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(find.text('Row')));
      await tester.pump();

      expect(hoverChanges, [true]);
      expect(backgroundColor(tester), hoverColor);

      await gesture.moveTo(Offset.zero);
      await tester.pump();

      expect(hoverChanges, [true, false]);
      expect(find.byKey(backgroundKey), findsNothing);
    });

    testWidgets('selection wins over hover for the background color', (
      tester,
    ) async {
      await pumpSurface(tester, selected: true);

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('Row')));
      await tester.pump();

      expect(backgroundColor(tester), selectedColor);
    });

    testWidgets('overlaps extend the background beyond the row bounds', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        selected: true,
        topOverlap: 4,
        bottomOverlap: 6,
      );

      final rowRect = tester.getRect(find.byType(GroupedCardRowSurface));
      final backgroundRect = tester.getRect(find.byKey(backgroundKey));

      expect(backgroundRect.top, rowRect.top - 4);
      expect(backgroundRect.bottom, rowRect.bottom + 6);
      expect(backgroundRect.left, rowRect.left);
      expect(backgroundRect.right, rowRect.right);
    });

    testWidgets('forwards taps', (tester) async {
      var taps = 0;
      await pumpSurface(tester, onTap: () => taps++);

      await tester.tap(find.text('Row'));
      expect(taps, 1);
    });
  });
}
