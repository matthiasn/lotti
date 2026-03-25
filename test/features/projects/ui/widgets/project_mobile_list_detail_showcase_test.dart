import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/widgets/project_mobile_list_detail_showcase.dart';
import 'package:lotti/features/projects/widgetbook/project_list_detail_mock_controller.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Widget wrap(
    ProviderContainer container, {
    required ThemeData theme,
    required Size viewportSize,
  }) {
    return makeTestableWidget2(
      UncontrolledProviderScope(
        container: container,
        child: Theme(
          data: theme,
          child: Scaffold(
            body: SizedBox(
              width: viewportSize.width,
              height: viewportSize.height,
              child: const ProjectMobileListDetailShowcase(),
            ),
          ),
        ),
      ),
      mediaQueryData: MediaQueryData(
        size: viewportSize,
        padding: phoneMediaQueryData.padding,
      ),
    );
  }

  group('ProjectMobileListDetailShowcase', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('renders split list/detail layout and syncs selection', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(920, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.dark(),
          viewportSize: const Size(920, 900),
        ),
      );
      await tester.pump();

      expect(find.text('Health Score'), findsOneWidget);
      expect(
        container
            .read(projectListDetailShowcaseControllerProvider)
            .selectedProject
            ?.project
            .data
            .title,
        'Device Sync',
      );

      await tester.tap(find.text('API Migration').first);
      await tester.pump();

      expect(
        container
            .read(projectListDetailShowcaseControllerProvider)
            .selectedProject
            ?.project
            .data
            .title,
        'API Migration',
      );
      expect(find.text('API Migration'), findsAtLeastNWidgets(2));
      expect(
        find.textContaining('legacy webhook bridge'),
        findsOneWidget,
      );
    });

    testWidgets('keeps selection when compact layout navigates back', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.dark(),
          viewportSize: const Size(430, 900),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Weekly Meal Prep'));
      await tester.pump();

      expect(find.text('Back'), findsOneWidget);
      expect(
        container
            .read(projectListDetailShowcaseControllerProvider)
            .selectedProject
            ?.project
            .data
            .title,
        'Weekly Meal Prep',
      );

      await tester.tap(find.text('Back'));
      await tester.pump();

      expect(find.text('Projects'), findsAtLeastNWidgets(2));
      expect(
        container
            .read(projectListDetailShowcaseControllerProvider)
            .selectedProject
            ?.project
            .data
            .title,
        'Weekly Meal Prep',
      );
    });

    testWidgets('renders without exceptions in light mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(920, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.light(),
          viewportSize: const Size(920, 900),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Projects'), findsAtLeastNWidgets(2));
      expect(find.text('Project Tasks'), findsOneWidget);
      expect(find.text('One-on-one Reviews'), findsOneWidget);
    });
  });
}
