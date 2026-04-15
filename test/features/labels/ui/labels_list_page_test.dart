import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

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
    // testLabelDefinition1 has a description so subtitle shows description.
    // testLabelDefinition2 has no description so subtitle shows usage count.
    await tester.pumpWidget(
      _buildPage(
        labels: [testLabelDefinition1, testLabelDefinition2],
        usageCounts: {'label-1': 3, 'label-2': 1},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Urgent'), findsWidgets);
    expect(find.text('Backlog'), findsWidgets);
    // Label 1 has description → subtitle is description, not usage count
    expect(
      find.text('Requires immediate attention'),
      findsOneWidget,
    );
    // Label 2 has no description → subtitle is usage count
    expect(find.textContaining('Used on 1 task'), findsOneWidget);
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

  testWidgets('error state displays error message and details', (tester) async {
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

    expect(find.byType(DesignSystemBottomNavigationFabPadding), findsOneWidget);
    final fab = find.byType(FloatingActionButton);
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
      () => mockNav.beamToNamed('/settings/labels/${testLabelDefinition1.id}'),
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

  testWidgets('shows create-from-search CTA with typed query', (tester) async {
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

  testWidgets('settings search field capitalizes words', (tester) async {
    await tester.pumpWidget(
      _buildPage(labels: [testLabelDefinition1, testLabelDefinition2]),
    );
    await tester.pumpAndSettle();

    final searchFieldFinder = find.byType(TextField, skipOffstage: false).first;
    final tf = tester.widget<TextField>(searchFieldFinder);
    expect(tf.textCapitalization, TextCapitalization.words);
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
      await tester.pumpWidget(_buildPage(labels: []));
      await tester.pumpAndSettle();

      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(SettingsPageHeader), findsOneWidget);
      expect(find.byType(SliverToBoxAdapter), findsWidgets);
    });
  });
}
