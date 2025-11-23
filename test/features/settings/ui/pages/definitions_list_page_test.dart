import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/ui/pages/definitions_list_page.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';

import '../../../../widget_test_utils.dart';

// Test data class
class TestItem {
  TestItem(this.name);
  final String name;
}

void main() {
  group('DefinitionsListPage', () {
    late StreamController<List<TestItem>> streamController;

    setUp(() {
      streamController = StreamController<List<TestItem>>();
    });

    tearDown(() {
      streamController.close();
    });

    Widget createTestWidget({
      required List<TestItem> items,
      String? initialSearchTerm,
      void Function(String)? searchCallback,
    }) {
      streamController.add(items);

      return makeTestableWidgetWithScaffold(
        DefinitionsListPage<TestItem>(
          stream: streamController.stream,
          title: 'Test Items',
          getName: (item) => item.name,
          definitionCard: (index, item) => Card(
            key: ValueKey('item_$index'),
            child: ListTile(title: Text(item.name)),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
          initialSearchTerm: initialSearchTerm,
          searchCallback: searchCallback,
        ),
      );
    }

    group('Basic Rendering', () {
      testWidgets('displays SettingsPageHeader with correct title',
          (tester) async {
        await tester.pumpWidget(createTestWidget(items: []));
        await tester.pumpAndSettle();

        // Should have SettingsPageHeader
        expect(find.byType(SettingsPageHeader), findsOneWidget);

        // Should display correct title
        expect(find.text('Test Items'), findsOneWidget);
      });

      testWidgets('shows back button in SettingsPageHeader', (tester) async {
        await tester.pumpWidget(createTestWidget(items: []));
        await tester.pumpAndSettle();

        // Should have back button (chevron_left icon)
        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      });

      testWidgets('uses CustomScrollView with slivers', (tester) async {
        await tester.pumpWidget(createTestWidget(items: []));
        await tester.pumpAndSettle();

        // Should use CustomScrollView for sliver structure
        expect(find.byType(CustomScrollView), findsOneWidget);

        // Should have SettingsPageHeader as a sliver
        expect(find.byType(SettingsPageHeader), findsOneWidget);

        // Should have SliverToBoxAdapter for search widget
        expect(find.byType(SliverToBoxAdapter), findsWidgets);
      });

      testWidgets('displays search widget', (tester) async {
        await tester.pumpWidget(createTestWidget(items: []));
        await tester.pumpAndSettle();

        // Should have search field
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('displays floating action button', (tester) async {
        await tester.pumpWidget(createTestWidget(items: []));
        await tester.pumpAndSettle();

        // Should have FAB
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });
    });

    group('Items Display', () {
      testWidgets('displays items when stream emits data', (tester) async {
        final items = [
          TestItem('Alpha'),
          TestItem('Beta'),
          TestItem('Gamma'),
        ];

        await tester.pumpWidget(createTestWidget(items: items));
        await tester.pumpAndSettle();

        // Should display all items
        expect(find.text('Alpha'), findsOneWidget);
        expect(find.text('Beta'), findsOneWidget);
        expect(find.text('Gamma'), findsOneWidget);
      });

      testWidgets('sorts items alphabetically', (tester) async {
        final items = [
          TestItem('Zulu'),
          TestItem('Alpha'),
          TestItem('Mike'),
          TestItem('Bravo'),
        ];

        await tester.pumpWidget(createTestWidget(items: items));
        await tester.pumpAndSettle();

        // Find all list tiles
        final tileFinder = find.byType(ListTile);
        final tiles = tester.widgetList<ListTile>(tileFinder).toList();

        // Should be sorted alphabetically
        expect((tiles[0].title! as Text).data, 'Alpha');
        expect((tiles[1].title! as Text).data, 'Bravo');
        expect((tiles[2].title! as Text).data, 'Mike');
        expect((tiles[3].title! as Text).data, 'Zulu');
      });

      testWidgets('displays empty list when no items', (tester) async {
        await tester.pumpWidget(createTestWidget(items: []));
        await tester.pumpAndSettle();

        // Should not display any items
        expect(find.byKey(const ValueKey('item_0')), findsNothing);
      });
    });

    group('Search Functionality', () {
      testWidgets('filters items based on search query', (tester) async {
        final items = [
          TestItem('Apple'),
          TestItem('Banana'),
          TestItem('Cherry'),
          TestItem('Apricot'),
        ];

        await tester.pumpWidget(createTestWidget(items: items));
        await tester.pumpAndSettle();

        // All items visible initially
        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Banana'), findsOneWidget);
        expect(find.text('Cherry'), findsOneWidget);
        expect(find.text('Apricot'), findsOneWidget);

        // Search for "ap"
        await tester.enterText(find.byType(TextField), 'ap');
        await tester.pumpAndSettle();

        // Should only show items containing "ap"
        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Apricot'), findsOneWidget);
        expect(find.text('Banana'), findsNothing);
        expect(find.text('Cherry'), findsNothing);
      });

      testWidgets('search is case insensitive', (tester) async {
        final items = [
          TestItem('Apple'),
          TestItem('banana'),
          TestItem('CHERRY'),
        ];

        await tester.pumpWidget(createTestWidget(items: items));
        await tester.pumpAndSettle();

        // Search with lowercase
        await tester.enterText(find.byType(TextField), 'apple');
        await tester.pumpAndSettle();

        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('banana'), findsNothing);

        // Search with uppercase
        await tester.enterText(find.byType(TextField), 'BANANA');
        await tester.pumpAndSettle();

        expect(find.text('banana'), findsOneWidget);
        expect(find.text('Apple'), findsNothing);
      });

      testWidgets('calls searchCallback when provided', (tester) async {
        String? capturedQuery;

        final items = [TestItem('Test')];

        await tester.pumpWidget(
          createTestWidget(
            items: items,
            searchCallback: (query) {
              capturedQuery = query;
            },
          ),
        );
        await tester.pumpAndSettle();

        // Enter search query
        await tester.enterText(find.byType(TextField), 'test query');
        await tester.pumpAndSettle();

        // Callback should be called with query
        expect(capturedQuery, 'test query');
      });

      testWidgets('uses initialSearchTerm if provided', (tester) async {
        final items = [
          TestItem('Apple'),
          TestItem('Banana'),
          TestItem('Apricot'),
        ];

        await tester.pumpWidget(
          createTestWidget(
            items: items,
            initialSearchTerm: 'ap',
          ),
        );
        await tester.pumpAndSettle();

        // Should start with filtered results
        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Apricot'), findsOneWidget);
        expect(find.text('Banana'), findsNothing);
      });

      testWidgets('clears search when clear icon tapped', (tester) async {
        final items = [
          TestItem('Apple'),
          TestItem('Banana'),
        ];

        await tester.pumpWidget(createTestWidget(items: items));
        await tester.pumpAndSettle();

        // Enter search query
        await tester.enterText(find.byType(TextField), 'apple');
        await tester.pumpAndSettle();

        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Banana'), findsNothing);

        // Clear search
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();

        // Should show all items again
        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Banana'), findsOneWidget);
      });
    });

    group('Dynamic Updates', () {
      testWidgets('updates when stream emits new data', (tester) async {
        await tester.pumpWidget(createTestWidget(items: []));
        await tester.pumpAndSettle();

        // Initially no items
        expect(find.byKey(const ValueKey('item_0')), findsNothing);

        // Add items to stream
        streamController.add([TestItem('New Item')]);
        await tester.pumpAndSettle();

        // Should display new item
        expect(find.text('New Item'), findsOneWidget);
      });

      testWidgets('maintains search filter when stream updates',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(items: [TestItem('Apple'), TestItem('Banana')]),
        );
        await tester.pumpAndSettle();

        // Set search filter
        await tester.enterText(find.byType(TextField), 'ap');
        await tester.pumpAndSettle();

        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Banana'), findsNothing);

        // Update stream with new items
        streamController.add([
          TestItem('Apple'),
          TestItem('Banana'),
          TestItem('Apricot'),
        ]);
        await tester.pumpAndSettle();

        // Filter should still be applied
        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Apricot'), findsOneWidget);
        expect(find.text('Banana'), findsNothing);
      });
    });

    group('Edge Cases', () {
      testWidgets('handles items with empty names', (tester) async {
        final items = [
          TestItem(''),
          TestItem('Valid'),
        ];

        await tester.pumpWidget(createTestWidget(items: items));
        await tester.pumpAndSettle();

        // Should display both items (even with empty name)
        expect(find.text('Valid'), findsOneWidget);
        expect(find.byKey(const ValueKey('item_0')), findsOneWidget);
      });

      testWidgets('handles very long item names', (tester) async {
        final longName = 'A' * 100;
        final items = [TestItem(longName)];

        await tester.pumpWidget(createTestWidget(items: items));
        await tester.pumpAndSettle();

        // Should display item (text might be ellipsized)
        expect(find.textContaining('AAA'), findsOneWidget);
      });

      testWidgets('handles special characters in search', (tester) async {
        final items = [
          TestItem('Test-Item'),
          TestItem('Test_Item'),
          TestItem('Test Item'),
        ];

        await tester.pumpWidget(createTestWidget(items: items));
        await tester.pumpAndSettle();

        // Search with special characters
        await tester.enterText(find.byType(TextField), 'test-');
        await tester.pumpAndSettle();

        expect(find.text('Test-Item'), findsOneWidget);
        expect(find.text('Test_Item'), findsNothing);
        expect(find.text('Test Item'), findsNothing);
      });
    });
  });
}
