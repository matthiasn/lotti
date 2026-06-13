import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_chip.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

Widget _buildPage({
  required List<LabelDefinition> labels,
  Map<String, int> usageCounts = const {},
}) {
  return ProviderScope(
    overrides: [
      labelsStreamProvider.overrideWith((ref) => Stream.value(labels)),
      labelUsageStatsProvider.overrideWith((ref) => Stream.value(usageCounts)),
    ],
    child: makeTestableWidgetWithScaffold(const LabelsListPage()),
  );
}

void main() {
  group('LabelsListPage Widget Tests', () {
    late MockLabelsRepository mockRepository;

    setUp(() async {
      await setUpTestGetIt();
      mockRepository = MockLabelsRepository();
    });

    tearDown(tearDownTestGetIt);

    Future<void> pumpLabelsListPage(
      WidgetTester tester, {
      bool settle = true,
      Map<String, int> usageCounts = const {},
    }) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            labelsRepositoryProvider.overrideWithValue(mockRepository),
            // Override the stream provider directly so private-label filtering
            // does not interfere with test data.
            labelsStreamProvider.overrideWith((ref) {
              return mockRepository.watchLabels();
            }),
            labelUsageStatsProvider.overrideWith(
              (ref) => Stream.value(usageCounts),
            ),
          ],
          child: const LabelsListPage(),
        ),
      );
      await tester.pump();
      if (settle) {
        await tester.pumpAndSettle();
      }
    }

    group('Loading and Error States', () {
      testWidgets('displays loading state initially', (tester) async {
        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => const Stream.empty(),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              labelsRepositoryProvider.overrideWithValue(mockRepository),
              labelUsageStatsProvider.overrideWith(
                (ref) => const Stream.empty(),
              ),
            ],
            child: const LabelsListPage(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('displays error state when stream errors', (tester) async {
        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.error(Exception('Test error')),
        );

        await pumpLabelsListPage(tester);

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.textContaining('Test error'), findsOneWidget);
      });
    });

    group('Empty State', () {
      testWidgets('displays empty state when no labels', (tester) async {
        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value([]),
        );

        await pumpLabelsListPage(tester);

        expect(find.byIcon(Icons.label_outline), findsOneWidget);
        expect(find.text('No labels yet'), findsOneWidget);
        expect(
          find.text('Tap the + button to create your first label.'),
          findsOneWidget,
        );
      });
    });

    group('Label List Display', () {
      testWidgets('uses DesignSystemListItem for label rows', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Bug'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        expect(find.byType(DesignSystemListItem), findsOneWidget);
        expect(find.text('Bug'), findsOneWidget);
      });

      testWidgets('displays labels in alphabetical order', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Zebra'),
          LabelTestUtils.createTestLabel(name: 'Alpha'),
          LabelTestUtils.createTestLabel(name: 'Beta'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        final items = find.byType(DesignSystemListItem);
        expect(items, findsNWidgets(3));

        final first = tester.widget<DesignSystemListItem>(items.at(0));
        final second = tester.widget<DesignSystemListItem>(items.at(1));
        final third = tester.widget<DesignSystemListItem>(items.at(2));

        expect(first.title, 'Alpha');
        expect(second.title, 'Beta');
        expect(third.title, 'Zebra');
      });

      testWidgets('subtitle is always the usage count, never the description', (
        tester,
      ) async {
        const labelId = 'label-123';
        final labels = [
          LabelTestUtils.createTestLabel(
            id: labelId,
            name: 'Important',
            description: 'High priority items',
          ),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(
          tester,
          usageCounts: {labelId: 5},
        );

        expect(find.text('5 tasks'), findsOneWidget);
        expect(find.text('High priority items'), findsNothing);
      });

      testWidgets('shows zero usage count for unused labels', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Plain'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        expect(find.text('0 tasks'), findsOneWidget);
      });

      testWidgets('leads with a color swatch chip showing the first letter', (
        tester,
      ) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Bug', color: '#000033'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        final chipFinder = find.byType(DefinitionIconChip);
        expect(chipFinder, findsOneWidget);

        // Swatch carries the label color and falls back to the first
        // letter with auto white-on-dark foreground.
        final chip = tester.widget<DefinitionIconChip>(chipFinder);
        expect(chip.background, const Color(0xFF000033));

        final letterFinder = find.descendant(
          of: chipFinder,
          matching: find.text('B'),
        );
        expect(letterFinder, findsOneWidget);
        expect(tester.widget<Text>(letterFinder).style?.color, Colors.white);
      });

      testWidgets('shows chevron trailing icon', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Test'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      });

      testWidgets('shows lock icon for private labels', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Secret', private: true),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      });

      testWidgets('hides lock icon for public labels', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Public'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        expect(find.byIcon(Icons.lock_outline), findsNothing);
      });

      testWidgets('shows dividers between items but not after last', (
        tester,
      ) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'A'),
          LabelTestUtils.createTestLabel(name: 'B'),
          LabelTestUtils.createTestLabel(name: 'C'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        final items = find.byType(DesignSystemListItem);
        final first = tester.widget<DesignSystemListItem>(items.at(0));
        final second = tester.widget<DesignSystemListItem>(items.at(1));
        final third = tester.widget<DesignSystemListItem>(items.at(2));

        expect(first.showDivider, isTrue);
        expect(second.showDivider, isTrue);
        expect(third.showDivider, isFalse);
      });

      testWidgets('renders items inside DesignSystemGroupedList', (
        tester,
      ) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Test'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        expect(find.byType(DesignSystemGroupedList), findsOneWidget);
      });

      testWidgets('DesignSystemListItem is tappable', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Clickable'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        final item = tester.widget<DesignSystemListItem>(
          find.byType(DesignSystemListItem),
        );
        expect(item.onTap, isNotNull);
      });
    });

    group('Search and Filter', () {
      testWidgets('filters labels by name', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Bug'),
          LabelTestUtils.createTestLabel(name: 'Feature'),
          LabelTestUtils.createTestLabel(name: 'Bugfix'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        expect(find.byType(DesignSystemListItem), findsNWidgets(3));

        await tester.enterText(find.byType(TextField), 'Bug');
        await tester.pumpAndSettle();

        expect(find.byType(DesignSystemListItem), findsNWidgets(2));

        final items = find.byType(DesignSystemListItem);
        final first = tester.widget<DesignSystemListItem>(items.at(0));
        final second = tester.widget<DesignSystemListItem>(items.at(1));
        expect(first.title, 'Bug');
        expect(second.title, 'Bugfix');
      });

      testWidgets('filters labels by description', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(
            name: 'Alpha',
            description: 'Tracks regressions',
          ),
          LabelTestUtils.createTestLabel(
            name: 'Beta',
            description: 'General tasks',
          ),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        await tester.enterText(find.byType(TextField), 'regression');
        await tester.pumpAndSettle();

        expect(find.byType(DesignSystemListItem), findsOneWidget);
        expect(find.text('Alpha'), findsOneWidget);
      });

      testWidgets('shows no-match state with create button', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Bug'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pumpAndSettle();

        expect(find.byType(DesignSystemListItem), findsNothing);
        expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
        expect(find.text('No labels match "zzz"'), findsOneWidget);
        expect(find.byType(DesignSystemButton), findsOneWidget);
        expect(find.text('Create "zzz" label'), findsOneWidget);
      });

      testWidgets('search is case insensitive', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Important'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        await tester.enterText(find.byType(TextField), 'IMPORT');
        await tester.pumpAndSettle();

        expect(find.byType(DesignSystemListItem), findsOneWidget);
      });
    });

    group('Layout', () {
      testWidgets('uses CustomScrollView', (tester) async {
        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value([]),
        );

        await pumpLabelsListPage(tester);

        expect(find.byType(CustomScrollView), findsOneWidget);
      });

      testWidgets('shows FAB for creating labels once labels exist', (
        tester,
      ) async {
        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value([LabelTestUtils.createTestLabel(name: 'Bug')]),
        );

        await pumpLabelsListPage(tester);

        expect(find.byType(DesignSystemFloatingActionButton), findsOneWidget);
      });

      testWidgets(
        'hides the corner FAB on an empty list — the empty state carries '
        'its own inline create button instead',
        (tester) async {
          when(() => mockRepository.watchLabels()).thenAnswer(
            (_) => Stream.value([]),
          );

          await pumpLabelsListPage(tester);

          expect(find.byType(DesignSystemFloatingActionButton), findsNothing);
        },
      );
    });
  });
  group('LabelsListPage — navigation, search, and badges', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .views
          .first
          .physicalSize = const Size(
        1024,
        1400,
      );
      TestWidgetsFlutterBinding
              .instance
              .platformDispatcher
              .views
              .first
              .devicePixelRatio =
          1.0;

      ensureThemingServicesRegistered();

      if (!getIt.isRegistered<NavService>()) {
        getIt.registerSingleton<NavService>(MockNavService());
      }
    });

    tearDown(() async {
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .views
          .first
          .physicalSize = const Size(
        800,
        600,
      );
      TestWidgetsFlutterBinding
              .instance
              .platformDispatcher
              .views
              .first
              .devicePixelRatio =
          1.0;
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
    });

    testWidgets('renders labels with usage stats', (tester) async {
      // The subtitle is always the usage count — descriptions never leak
      // into the second line, so its meaning is stable across rows.
      await tester.pumpWidget(
        _buildPage(
          labels: [testLabelDefinition1, testLabelDefinition2],
          usageCounts: {'label-1': 3, 'label-2': 1},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Urgent'), findsWidgets);
      expect(find.text('Backlog'), findsWidgets);
      expect(find.text('3 tasks'), findsOneWidget);
      expect(find.text('1 task'), findsOneWidget);
      // Label 1 has a description, but it is never the subtitle.
      expect(find.text('Requires immediate attention'), findsNothing);
    });

    testWidgets('filters list based on search query', (tester) async {
      await tester.pumpWidget(
        _buildPage(labels: [testLabelDefinition1, testLabelDefinition2]),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField, skipOffstage: false).first,
        'backlog',
      );
      await tester.pump();

      expect(find.text('Backlog'), findsWidgets);
      expect(find.text('Urgent'), findsNothing);
    });

    testWidgets('search filters labels case-insensitively', (tester) async {
      await tester.pumpWidget(
        _buildPage(labels: [testLabelDefinition1, testLabelDefinition2]),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField, skipOffstage: false).first,
        'BACK',
      );
      await tester.pump();

      expect(find.text('Backlog'), findsWidgets);
      expect(find.text('Urgent'), findsNothing);
    });

    testWidgets('empty state shows when no labels exist', (tester) async {
      await tester.pumpWidget(_buildPage(labels: const []));
      await tester.pumpAndSettle();

      expect(find.text('No labels yet'), findsOneWidget);
    });

    testWidgets('error state displays error message and details', (
      tester,
    ) async {
      final widget = ProviderScope(
        overrides: [
          labelsStreamProvider.overrideWith(
            (ref) => Stream<List<LabelDefinition>>.error('boom'),
          ),
        ],
        child: makeTestableWidgetWithScaffold(const LabelsListPage()),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Failed to load labels'), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets('list item uses chevron and no popup menu', (tester) async {
      await tester.pumpWidget(
        _buildPage(labels: [testLabelDefinition1]),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('FAB navigates to create label page', (tester) async {
      final mockNav = getIt<NavService>() as MockNavService;
      await tester.pumpWidget(
        _buildPage(labels: [testLabelDefinition1]),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(DesignSystemBottomNavigationFabPadding),
        findsOneWidget,
      );
      final fab = find.byType(DesignSystemFloatingActionButton);
      await tester.ensureVisible(fab);
      await tester.tap(fab, warnIfMissed: false);
      await tester.pump();

      verify(() => mockNav.beamToNamed('/settings/labels/create')).called(1);
    });

    testWidgets('Create CTA navigates with encoded name', (tester) async {
      final mockNav = getIt<NavService>() as MockNavService;
      await tester.pumpWidget(_buildPage(labels: [testLabelDefinition1]));
      await tester.pumpAndSettle();

      const query = 'My Label';
      await tester.enterText(
        find.byType(TextField, skipOffstage: false).first,
        query,
      );
      await tester.pump();

      final ctaText = find.text('Create "$query" label');
      expect(ctaText, findsOneWidget);
      await tester.ensureVisible(ctaText);
      await tester.tap(ctaText, warnIfMissed: false);
      await tester.pump();

      verify(
        () => mockNav.beamToNamed('/settings/labels/create?name=My%20Label'),
      ).called(1);
    });

    testWidgets('tapping label navigates to details', (tester) async {
      final mockNav = getIt<NavService>() as MockNavService;
      await tester.pumpWidget(_buildPage(labels: [testLabelDefinition1]));
      await tester.pumpAndSettle();

      // Tap the DesignSystemListItem
      final item = find.byType(DesignSystemListItem).first;
      await tester.ensureVisible(item);
      await tester.tap(item, warnIfMissed: false);
      await tester.pump();

      verify(
        () =>
            mockNav.beamToNamed('/settings/labels/${testLabelDefinition1.id}'),
      ).called(1);
    });

    testWidgets('private badge renders lock icon for private labels', (
      tester,
    ) async {
      final privateLabel = testLabelDefinition1.copyWith(private: true);
      await tester.pumpWidget(
        _buildPage(labels: [privateLabel]),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('shows create-from-search CTA with typed query', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            labelsStreamProvider.overrideWith(
              (ref) => Stream.value([
                testLabelDefinition1,
                testLabelDefinition2,
              ]),
            ),
            labelUsageStatsProvider.overrideWith(
              (ref) => Stream.value(const <String, int>{}),
            ),
          ],
          child: makeTestableWidgetWithScaffold(const LabelsListPage()),
        ),
      );
      await tester.pumpAndSettle();

      const query = 'NewLabelX';
      await tester.enterText(
        find.byType(TextField, skipOffstage: false).first,
        query,
      );
      await tester.pump();

      expect(find.text('Create "$query" label'), findsOneWidget);
    });

    group('SettingsPageHeader Integration', () {
      testWidgets('displays SettingsPageHeader with correct title', (
        tester,
      ) async {
        await tester.pumpWidget(_buildPage(labels: []));
        await tester.pumpAndSettle();

        expect(find.byType(SettingsPageHeader), findsOneWidget);
        expect(find.byType(SliverAppBar), findsOneWidget);
      });

      testWidgets('uses CustomScrollView with slivers', (tester) async {
        // A non-empty list: the search sliver only renders when there is
        // something to search.
        await tester.pumpWidget(_buildPage(labels: [testLabelDefinition1]));
        await tester.pumpAndSettle();

        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.byType(SettingsPageHeader), findsOneWidget);
        expect(find.byType(SliverToBoxAdapter), findsWidgets);
      });
    });
  });
}
