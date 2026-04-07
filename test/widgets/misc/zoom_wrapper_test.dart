import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/misc/zoom_wrapper.dart';

import '../../widget_test_utils.dart';

Future<void> _pumpZoomWrapper(
  WidgetTester tester, {
  required double scale,
  Key childKey = const Key('child'),
}) {
  return tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      ZoomWrapper(
        scale: scale,
        child: Text('Hello', key: childKey),
      ),
    ),
  );
}

void main() {
  group('ZoomWrapper', () {
    testWidgets('returns child directly when scale is 1.0', (tester) async {
      const childKey = Key('child');
      await _pumpZoomWrapper(tester, scale: 1);

      expect(find.text('Hello'), findsOneWidget);
      final element = tester.element(find.byKey(childKey));
      final mediaQuery = MediaQuery.of(element);
      expect(mediaQuery.textScaler.scale(14), 14);
    });

    testWidgets('applies TextScaler when scale is greater than 1.0', (
      tester,
    ) async {
      const childKey = Key('child');
      await _pumpZoomWrapper(tester, scale: 1.5);

      expect(find.text('Hello'), findsOneWidget);
      final element = tester.element(find.byKey(childKey));
      final mediaQuery = MediaQuery.of(element);
      expect(mediaQuery.textScaler.scale(10), 15);
    });

    testWidgets('applies TextScaler when scale is less than 1.0', (
      tester,
    ) async {
      const childKey = Key('child');
      await _pumpZoomWrapper(tester, scale: 0.5);

      final element = tester.element(find.byKey(childKey));
      final mediaQuery = MediaQuery.of(element);
      expect(mediaQuery.textScaler.scale(10), 5);
    });
  });
}
