import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/widgets/projects_header.dart';
import 'package:lotti/features/projects/ui/widgets/projects_overview_content.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets(
    'projects header sits outside the CustomScrollView so scroll gestures '
    'do not drag the title',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(
              body: ProjectsOverviewContent(
                title: 'Projects',
                groups: const [],
                onProjectTap: (_) {},
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(402, 874)),
        ),
      );
      await tester.pumpAndSettle();

      final headerFinder = find.byType(ProjectsHeader);
      final scrollFinder = find.byType(CustomScrollView);

      expect(headerFinder, findsOneWidget);
      expect(scrollFinder, findsOneWidget);

      // Header must not be inside the scroll view — otherwise the title
      // would scroll with the list (regression for the Figma static header).
      expect(
        find.descendant(of: scrollFinder, matching: headerFinder),
        findsNothing,
      );
    },
  );
}
