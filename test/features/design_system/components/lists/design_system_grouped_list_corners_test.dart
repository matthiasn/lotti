import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list_corners.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemGroupedListCorners', () {
    testWidgets('maybeOf returns the scoped radius to descendants', (
      tester,
    ) async {
      const corners = BorderRadius.vertical(top: Radius.circular(12));

      await tester.pumpWidget(
        makeTestableWidget2(
          const Scaffold(
            body: DesignSystemGroupedListCorners(
              borderRadius: corners,
              child: Text('Scoped'),
            ),
          ),
        ),
      );

      expect(
        DesignSystemGroupedListCorners.maybeOf(
          tester.element(find.text('Scoped')),
        ),
        corners,
      );
    });

    testWidgets('maybeOf returns null without an enclosing scope', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget2(const Scaffold(body: Text('Unscoped'))),
      );

      expect(
        DesignSystemGroupedListCorners.maybeOf(
          tester.element(find.text('Unscoped')),
        ),
        isNull,
      );
    });

    test('updateShouldNotify fires only when the radius changes', () {
      const child = SizedBox.shrink();
      const square = DesignSystemGroupedListCorners(
        borderRadius: BorderRadius.zero,
        child: child,
      );
      final rounded = DesignSystemGroupedListCorners(
        borderRadius: BorderRadius.circular(8),
        child: child,
      );

      expect(rounded.updateShouldNotify(square), isTrue);
      expect(
        square.updateShouldNotify(
          const DesignSystemGroupedListCorners(
            borderRadius: BorderRadius.zero,
            child: child,
          ),
        ),
        isFalse,
      );
    });
  });
}
