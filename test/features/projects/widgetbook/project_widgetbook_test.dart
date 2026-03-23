import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/widgetbook/project_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildProjectListDetailWidgetbookComponent', () {
    testWidgets('renders the project list and detail showcase', (tester) async {
      final component = buildProjectListDetailWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Project list & detail');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(
              body: SizedBox(
                width: 1440,
                height: 900,
                child: Builder(builder: useCase.builder),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(1600, 1000)),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      expect(find.text('Projects'), findsAtLeastNWidgets(2));
      expect(find.text('Device Sync'), findsAtLeastNWidgets(2));
      expect(find.text('API Migration'), findsOneWidget);
      expect(find.text('3 projects'), findsOneWidget);
      expect(find.text('Health Score'), findsOneWidget);
      expect(find.text('Project Tasks'), findsOneWidget);
      expect(find.text('One-on-one Reviews'), findsOneWidget);
      expect(find.text('11m 38s'), findsOneWidget);
      expect(find.text('Week 11 · Mar 10'), findsOneWidget);
    });
  });
}
