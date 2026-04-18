import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_button.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  testWidgets(
    'FloatingAddActionButton renders the design-system FAB '
    '(rounded-24, no Material default circle)',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const FloatingAddActionButton(),
          theme: DesignSystemTheme.dark(),
        ),
      );
      await tester.pump();

      expect(find.byType(DesignSystemFloatingActionButton), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      final size = tester.getSize(
        find.byType(DesignSystemFloatingActionButton),
      );
      expect(size, const Size(56, 56));
    },
  );
}
