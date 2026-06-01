import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/widgets/project_mobile_detail_content.dart';
import 'package:lotti/features/projects/ui/widgets/project_mobile_list_detail_showcase.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
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
      expect(find.text('Project Tasks'), findsOneWidget);
      expect(find.text('One-on-one Reviews'), findsNothing);
    });

    testWidgets(
      'split-view: clears search query via onSearchCleared (lines 53-54)',
      (tester) async {
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

        // Enter a query so the clear (cancel) icon appears.
        final searchField = find.byType(TextField).first;
        await tester.enterText(searchField, 'Device');
        await tester.pump();

        expect(
          container
              .read(projectListDetailShowcaseControllerProvider)
              .searchQuery,
          'Device',
        );

        // Tap the clear icon → invokes onSearchCleared → updateSearchQuery('').
        final clearIcon = find.byIcon(Icons.cancel_rounded).first;
        await tester.ensureVisible(clearIcon);
        await tester.tap(clearIcon);
        await tester.pump();

        expect(
          container
              .read(projectListDetailShowcaseControllerProvider)
              .searchQuery,
          '',
        );
      },
    );

    testWidgets(
      'split-view: opens projects filter modal (lines 56-58)',
      (tester) async {
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

        final filterIcon = find.byIcon(Icons.filter_list_rounded).first;
        await tester.ensureVisible(filterIcon);
        await tester.tap(filterIcon);
        await tester.pumpAndSettle();

        // The shared filter modal uses tasksFilterTitle ("Tasks Filter").
        expect(find.text('Tasks Filter'), findsOneWidget);
      },
    );

    testWidgets(
      'compact: clears search query via onSearchCleared (lines 87-88)',
      (tester) async {
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

        // Enter a query so the clear (cancel) icon appears.
        final searchField = find.byType(TextField).first;
        await tester.enterText(searchField, 'Health');
        await tester.pump();

        expect(
          container
              .read(projectListDetailShowcaseControllerProvider)
              .searchQuery,
          'Health',
        );

        // Tap the clear icon → invokes onSearchCleared → updateSearchQuery('').
        final clearIcon = find.byIcon(Icons.cancel_rounded).first;
        await tester.ensureVisible(clearIcon);
        await tester.tap(clearIcon);
        await tester.pump();

        expect(
          container
              .read(projectListDetailShowcaseControllerProvider)
              .searchQuery,
          '',
        );
      },
    );

    testWidgets(
      'compact: opens projects filter modal (lines 90-92)',
      (tester) async {
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

        final filterIcon = find.byIcon(Icons.filter_list_rounded).first;
        await tester.ensureVisible(filterIcon);
        await tester.tap(filterIcon);
        await tester.pumpAndSettle();

        expect(find.text('Tasks Filter'), findsOneWidget);
      },
    );

    testWidgets(
      'shows NoResultsPane when search matches nothing (line 167)',
      (tester) async {
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

        expect(find.byType(NoResultsPane), findsNothing);

        final searchField = find.byType(TextField).first;
        await tester.enterText(searchField, 'zzznomatch999');
        await tester.pump();

        expect(find.byType(NoResultsPane), findsOneWidget);
        expect(
          container
              .read(projectListDetailShowcaseControllerProvider)
              .visibleGroups
              .isEmpty,
          isTrue,
        );
      },
    );

    testWidgets(
      'tapping FAB in list screen triggers no-op (line 167)',
      (tester) async {
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

        final fab = find.byType(DesignSystemFloatingActionButton).first;
        await tester.ensureVisible(fab);
        await tester.tap(fab);
        await tester.pump();

        // After FAB tap, state is unchanged — no project was opened.
        expect(
          container
              .read(projectListDetailShowcaseControllerProvider)
              .selectedProject,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
