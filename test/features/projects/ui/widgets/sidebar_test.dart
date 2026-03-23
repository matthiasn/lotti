import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/widgets/sidebar.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: SizedBox(
            width: 400,
            height: 900,
            child: child,
          ),
        ),
      ),
    );
  }

  group('Sidebar', () {
    testWidgets('renders navigation items', (tester) async {
      await tester.pumpWidget(wrap(const Sidebar()));
      await tester.pump();

      expect(find.text('My Daily'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
    });

    testWidgets('renders menu icon and brand logo', (tester) async {
      await tester.pumpWidget(wrap(const Sidebar()));
      await tester.pump();

      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    });

    testWidgets('renders AI assistant orb with semantics', (tester) async {
      await tester.pumpWidget(wrap(const Sidebar()));
      await tester.pump();

      expect(
        find.bySemanticsLabel('AI Assistant'),
        findsOneWidget,
      );
    });
  });

  group('MainTopBar', () {
    testWidgets('renders title and notification icon', (tester) async {
      await tester.pumpWidget(wrap(const MainTopBar()));
      await tester.pump();

      expect(find.text('Projects'), findsOneWidget);
      expect(
        find.byIcon(Icons.notifications_none_rounded),
        findsOneWidget,
      );
    });
  });
}
