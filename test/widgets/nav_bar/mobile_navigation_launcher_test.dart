import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_launcher.dart';
import 'package:material_ui/material_ui.dart';

import '../../widget_test_utils.dart';

void main() {
  void onNavigate() {}

  group('MobileNavigationLauncher', () {
    testWidgets('centers one labeled launcher and dispatches its action', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MobileNavigationLauncher(onNavigate: () => taps++),
          theme: DesignSystemTheme.light(),
        ),
      );
      final button = tester.getRect(find.byType(DesignSystemButton));
      final container = tester.getRect(
        find.byType(MobileNavigationLauncher),
      );
      expect(button.width, lessThan(container.width));
      expect(button.center.dx, container.center.dx);
      expect(button.height, greaterThanOrEqualTo(TapTargets.minimum));
      await tester.tap(find.text('Navigate'));
      expect(taps, 1);
    });

    for (final scaler in const [
      TextScaler.linear(1.3),
      TextScaler.linear(2),
      TextScaler.linear(3),
      _NonlinearTextScaler(),
    ]) {
      testWidgets('launcher clearance matches large text at $scaler', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            MobileNavigationLauncher(onNavigate: onNavigate),
            theme: DesignSystemTheme.light(),
            mediaQueryData: MediaQueryData(
              size: const Size(390, 844),
              textScaler: scaler,
              padding: const EdgeInsets.only(bottom: 34),
            ),
          ),
        );
        final finder = find.byType(MobileNavigationLauncher);
        expect(
          tester.getSize(finder).height,
          MobileNavigationLauncher.barHeight(
            tester.element(finder),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// Smaller fonts grow proportionally more, as in accessibility text scaling.
class _NonlinearTextScaler extends TextScaler {
  const _NonlinearTextScaler();

  @override
  double scale(double fontSize) =>
      fontSize <= 16 ? fontSize * 2 : fontSize * 1.5 + 8;

  @override
  double get textScaleFactor => 2;
}
