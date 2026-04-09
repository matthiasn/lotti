import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

import '../../../../widget_test_utils.dart';

Future<void> pumpFab(
  WidgetTester tester, {
  VoidCallback? onPressed,
}) {
  return tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      DesignSystemFloatingActionButton(
        semanticLabel: 'Create',
        onPressed: onPressed,
      ),
      theme: DesignSystemTheme.light(),
    ),
  );
}

void main() {
  group('DesignSystemFloatingActionButton', () {
    testWidgets('renders the primary jumbo icon-only button', (tester) async {
      await pumpFab(tester);

      expect(find.byType(DesignSystemFloatingActionButton), findsOneWidget);
      expect(find.bySemanticsLabel('Create'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      final size = tester.getSize(
        find.byType(DesignSystemFloatingActionButton),
      );
      expect(size, const Size(56, 56));
    });

    testWidgets('invokes onPressed when tapped', (tester) async {
      var tapped = false;

      await pumpFab(tester, onPressed: () => tapped = true);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('centers the icon horizontally inside the button', (
      tester,
    ) async {
      await pumpFab(tester);

      final buttonCenter = tester.getCenter(
        find.byType(DesignSystemFloatingActionButton),
      );
      final iconCenter = tester.getCenter(find.byIcon(Icons.add_rounded));

      expect(iconCenter.dx, closeTo(buttonCenter.dx, 0.01));
    });
  });
}
