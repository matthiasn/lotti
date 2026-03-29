import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/widgets/project_mobile_detail_content.dart';
import 'package:lotti/features/projects/widgetbook/project_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildProjectListDetailWidgetbookComponent', () {
    testWidgets('renders the desktop project list and detail showcase', (
      tester,
    ) async {
      final component = buildProjectListDetailWidgetbookComponent();
      final useCase = component.useCases.firstWhere(
        (useCase) => useCase.name == 'Desktop',
      );

      expect(component.name, 'Project list & detail');
      expect(
        component.useCases.map((useCase) => useCase.name),
        ['Desktop', 'Mobile'],
      );

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
      expect(find.text('11m 38s'), findsOneWidget);
      expect(find.text('One-on-one Reviews'), findsNothing);
    });

    testWidgets('renders the mobile showcase in light mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final component = buildProjectListDetailWidgetbookComponent();
      final useCase = component.useCases.firstWhere(
        (useCase) => useCase.name == 'Mobile',
      );

      await tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.light(),
            child: Scaffold(
              body: SizedBox(
                width: 920,
                height: 920,
                child: Builder(builder: useCase.builder),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(1100, 1000)),
        ),
      );
      await tester.pump();

      final detailScrollView = find.descendant(
        of: find.byType(ProjectMobileDetailContent),
        matching: find.byType(Scrollable),
      );

      await tester.scrollUntilVisible(
        find.text('Project Tasks'),
        300,
        scrollable: detailScrollView,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Projects'), findsAtLeastNWidgets(2));
      expect(find.text('Health Score'), findsOneWidget);
      expect(find.text('Project Tasks'), findsOneWidget);
    });

    testWidgets('does not throw when hovering widgetbook scrollbars', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final component = buildProjectListDetailWidgetbookComponent();
      final useCase = component.useCases.firstWhere(
        (useCase) => useCase.name == 'Mobile',
      );

      await tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.light(),
            child: Scaffold(
              body: SizedBox(
                width: 920,
                height: 920,
                child: Builder(builder: useCase.builder),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(1100, 1000)),
        ),
      );
      await tester.pump();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);

      await gesture.addPointer(location: Offset.zero);
      await tester.pump();

      final scrollbars = find.byType(Scrollbar);
      expect(scrollbars, findsAtLeastNWidgets(1));

      for (var index = 0; index < scrollbars.evaluate().length; index++) {
        await gesture.moveTo(tester.getCenter(scrollbars.at(index)));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
