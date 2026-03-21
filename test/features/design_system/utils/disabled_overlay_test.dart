import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('DesignSystemDisabledOverlay', () {
    testWidgets('does not wrap enabled widgets in opacity', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const Text('Enabled').withDisabledOpacity(
            enabled: true,
            disabledOpacity: 0.32,
          ),
        ),
      );

      expect(find.text('Enabled'), findsOneWidget);
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('wraps disabled widgets in opacity', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const Text('Disabled').withDisabledOpacity(
            enabled: false,
            disabledOpacity: 0.32,
          ),
        ),
      );

      final opacity = tester.widget<Opacity>(find.byType(Opacity));

      expect(find.text('Disabled'), findsOneWidget);
      expect(opacity.opacity, 0.32);
    });
  });
}
