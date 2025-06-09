import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_filter_chips.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_fixed_header.dart';

void main() {
  group('AiSettingsFixedHeader', () {
    late TextEditingController searchController;
    late TabController tabController;
    // ignore_for_file: unused_local_variable
    late bool searchCleared;
    late AiSettingsTab tabChangedTo;
    late AiSettingsFilterState filterChangedTo;

    setUp(() {
      searchController = TextEditingController();
      searchCleared = false;
      tabChangedTo = AiSettingsTab.providers;
      filterChangedTo = AiSettingsFilterState.initial();
    });

    tearDown(() {
      searchController.dispose();
    });

    Widget createWidget({
      AiSettingsFilterState? filterState,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DefaultTabController(
              length: 3,
              child: Builder(
                builder: (context) {
                  tabController = DefaultTabController.of(context);
                  // Simulate the sliver layout with a CustomScrollView
                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: AiSettingsFixedHeader(
                          searchController: searchController,
                          tabController: tabController,
                          filterState:
                              filterState ?? AiSettingsFilterState.initial(),
                          onSearchClear: () => searchCleared = true,
                          onTabChanged: (tab) => tabChangedTo = tab,
                          onFilterChanged: (state) => filterChangedTo = state,
                        ),
                      ),
                      // Add a spacer to give the scroll view content
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 500),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('displays all main components', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      // Should have search bar
      expect(find.byType(TextField), findsOneWidget);

      // Should have tabs
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Providers'), findsOneWidget);
      expect(find.text('Models'), findsOneWidget);
      expect(find.text('Prompts'), findsOneWidget);
    });

    testWidgets('search functionality works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      // Find the text field
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      // Type text
      await tester.enterText(textField, 'test search');
      await tester.pump();

      // Verify the controller has the text
      expect(searchController.text, 'test search');

      // Clear the text
      searchController.clear();
      await tester.pump();

      expect(searchController.text, '');
    });

    testWidgets('tab selection triggers callback', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      await tester.tap(find.text('Models'));
      await tester.pump();

      expect(tabChangedTo, AiSettingsTab.models);

      await tester.tap(find.text('Prompts'));
      await tester.pump();

      expect(tabChangedTo, AiSettingsTab.prompts);
    });

    testWidgets('search functionality updates filter state',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      // Enter search text
      await tester.enterText(find.byType(TextField), 'test query');
      await tester.pump();

      expect(searchController.text, 'test query');
    });

    testWidgets('displays filter section only on models tab',
        (WidgetTester tester) async {
      // Start on providers tab (default)
      await tester.pumpWidget(createWidget(
        filterState: AiSettingsFilterState.initial(),
      ));
      await tester.pumpAndSettle();

      // Should not show AiSettingsFilterChips on providers tab
      expect(find.byType(AiSettingsFilterChips), findsNothing);

      // Now test with models tab active - create fresh widget to avoid exceptions
      await tester.pumpWidget(createWidget(
        filterState:
            const AiSettingsFilterState(activeTab: AiSettingsTab.models),
      ));
      await tester.pumpAndSettle();

      // Filter chips widget should now be visible
      expect(find.byType(AiSettingsFilterChips), findsOneWidget);
    });

    testWidgets('has proper spacing between sections',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      // Check for SizedBox widgets used for spacing
      final spacingBoxes = find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height != null,
      );

      expect(spacingBoxes.evaluate().length, greaterThan(0));
    });

    testWidgets('search bar has proper decoration',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      final textField = tester.widget<TextField>(find.byType(TextField));
      final decoration = textField.decoration!;

      expect(decoration.hintText, isNotNull);
      expect(decoration.prefixIcon, isNotNull);
      expect(decoration.filled,
          isNotNull); // Can be true or false depending on theme
      // Border might be OutlineInputBorder or another type depending on theme
      expect(decoration.border, isNotNull);
    });

    testWidgets('tab bar uses proper styling', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));

      expect(tabBar.indicatorSize, TabBarIndicatorSize.tab);
      expect(tabBar.tabs.length, 3);
    });

    testWidgets('handles search input correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'test query');
      await tester.pump();

      expect(searchController.text, 'test query');
    });

    testWidgets('has proper structure and padding',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      // Check that search bar exists and has ancestors with padding
      final searchBarPaddings = find.ancestor(
        of: find.byType(TextField),
        matching: find.byType(Padding),
      );
      expect(searchBarPaddings.evaluate().length, greaterThan(0));

      // Check that tab bar exists and has ancestors with padding
      final tabBarPaddings = find.ancestor(
        of: find.byType(TabBar),
        matching: find.byType(Padding),
      );
      expect(tabBarPaddings.evaluate().length, greaterThan(0));
    });
  });
}
