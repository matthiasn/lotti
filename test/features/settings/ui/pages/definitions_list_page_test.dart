import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/settings/ui/pages/definitions_list_page.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';

import '../../../../widget_test_utils.dart';

/// Pumps the generic template directly with plain [String] items — no
/// providers needed because the template consumes a ready [AsyncValue].
Future<void> _pumpPage(
  WidgetTester tester, {
  required AsyncValue<List<String>> itemsAsync,
  String Function(String item)? searchText,
  Widget Function(BuildContext context, String query)? noMatchActionBuilder,
  String? initialSearchTerm,
  ValueChanged<String>? searchCallback,
  VoidCallback? onCreate,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      DefinitionsListPage<String>(
        title: 'Test Items',
        itemsAsync: itemsAsync,
        searchHint: 'Search test items',
        displayName: (item) => item,
        itemBuilder: (context, item, {required bool showDivider}) => ListTile(
          key: ValueKey('row-$item-divider-$showDivider'),
          title: Text(item),
        ),
        emptyIcon: Icons.inbox_outlined,
        emptyTitle: 'Nothing here yet',
        emptyHint: 'Tap create to add an item',
        noMatchMessage: (query) => 'No items match "$query"',
        errorTitle: 'Failed to load items',
        createLabel: 'Create item',
        onCreate: onCreate ?? () {},
        searchText: searchText,
        noMatchActionBuilder: noMatchActionBuilder,
        initialSearchTerm: initialSearchTerm,
        searchCallback: searchCallback,
      ),
    ),
  );
  // A plain pump() does not advance the test clock; the header's
  // flutter_animate entrance schedules a zero-duration timer that must
  // fire before the test ends, so advance the clock explicitly.
  await tester.pump(const Duration(milliseconds: 100));
}

/// Row titles in render order (the template builds rows pre-sorted).
List<String> _rowTitles(WidgetTester tester) => tester
    .widgetList<ListTile>(find.byType(ListTile))
    .map((tile) => (tile.title! as Text).data!)
    .toList();

Future<void> _enterQuery(WidgetTester tester, String query) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(DesignSystemSearch),
      matching: find.byType(TextField),
    ),
    query,
  );
  await tester.pump();
}

void main() {
  group('DefinitionsListPage', () {
    group('data rendering', () {
      testWidgets(
        'renders header title and all items sorted case-insensitively '
        'by display name inside a DesignSystemGroupedList',
        (tester) async {
          await _pumpPage(
            tester,
            itemsAsync: const AsyncValue.data(['banana', 'Cherry', 'Apple']),
          );

          expect(find.byType(SettingsPageHeader), findsOneWidget);
          expect(find.text('Test Items'), findsOneWidget);
          expect(find.byType(DesignSystemGroupedList), findsOneWidget);
          expect(_rowTitles(tester), ['Apple', 'banana', 'Cherry']);
        },
      );

      testWidgets(
        'passes showDivider=true to every row except the last in sorted order',
        (tester) async {
          await _pumpPage(
            tester,
            itemsAsync: const AsyncValue.data(['Zulu', 'Alpha', 'Mike']),
          );

          expect(
            find.byKey(const ValueKey('row-Alpha-divider-true')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('row-Mike-divider-true')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('row-Zulu-divider-false')),
            findsOneWidget,
          );
        },
      );

      testWidgets('a single row gets showDivider=false', (tester) async {
        await _pumpPage(
          tester,
          itemsAsync: const AsyncValue.data(['Only']),
        );

        expect(
          find.byKey(const ValueKey('row-Only-divider-false')),
          findsOneWidget,
        );
      });
    });

    group('search filtering', () {
      testWidgets(
        'filters rows by case-insensitive substring of the display name',
        (tester) async {
          await _pumpPage(
            tester,
            itemsAsync: const AsyncValue.data(
              ['Apple', 'Banana', 'Apricot'],
            ),
          );

          await _enterQuery(tester, 'AP');

          expect(_rowTitles(tester), ['Apple', 'Apricot']);

          await _enterQuery(tester, 'banana');

          expect(_rowTitles(tester), ['Banana']);
        },
      );

      testWidgets(
        'a whitespace-only query keeps the full list visible',
        (tester) async {
          await _pumpPage(
            tester,
            itemsAsync: const AsyncValue.data(['Apple', 'Banana']),
          );

          await _enterQuery(tester, '   ');

          expect(_rowTitles(tester), ['Apple', 'Banana']);
        },
      );

      testWidgets(
        'searchText overrides the haystack while displayName keeps '
        'driving labels and sort order',
        (tester) async {
          await _pumpPage(
            tester,
            itemsAsync: const AsyncValue.data(['Beta', 'Alpha']),
            searchText: (item) =>
                item == 'Alpha' ? 'Alpha fruity extras' : 'Beta plain',
          );

          await _enterQuery(tester, 'fruity');

          expect(_rowTitles(tester), ['Alpha']);

          // The display name itself still matches via the override haystack.
          await _enterQuery(tester, 'beta');

          expect(_rowTitles(tester), ['Beta']);
        },
      );

      testWidgets(
        'the clear button restores the full list and reports an empty '
        'query through searchCallback',
        (tester) async {
          final queries = <String>[];
          await _pumpPage(
            tester,
            itemsAsync: const AsyncValue.data(['Apple', 'Banana']),
            searchCallback: queries.add,
          );

          await _enterQuery(tester, 'apple');
          expect(_rowTitles(tester), ['Apple']);

          await tester.tap(find.byIcon(Icons.cancel_rounded));
          await tester.pump();

          expect(_rowTitles(tester), ['Apple', 'Banana']);
          expect(queries, ['apple', '']);
        },
      );
    });

    group('empty state', () {
      testWidgets(
        'shows empty icon, title, and hint when no definitions exist',
        (tester) async {
          await _pumpPage(tester, itemsAsync: const AsyncValue.data([]));

          expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
          expect(find.text('Nothing here yet'), findsOneWidget);
          expect(find.text('Tap create to add an item'), findsOneWidget);
          // One create affordance: the inline button carries it; the
          // corner FAB hides so the same action isn't offered twice.
          expect(find.byType(DesignSystemFloatingActionButton), findsNothing);
        },
      );

      testWidgets(
        'an active query over an entirely empty list still shows the '
        'global empty state, not the no-match state',
        (tester) async {
          await _pumpPage(tester, itemsAsync: const AsyncValue.data([]));

          await _enterQuery(tester, 'anything');

          expect(find.text('Nothing here yet'), findsOneWidget);
          expect(find.byIcon(Icons.search_off_rounded), findsNothing);
        },
      );
    });

    group('no-match state', () {
      testWidgets(
        'shows the no-match message with the trimmed query and no rows',
        (tester) async {
          await _pumpPage(
            tester,
            itemsAsync: const AsyncValue.data(['Apple']),
          );

          await _enterQuery(tester, ' zzz ');

          expect(find.byType(ListTile), findsNothing);
          expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
          expect(find.text('No items match "zzz"'), findsOneWidget);
        },
      );

      testWidgets(
        'renders the noMatchActionBuilder output for the query and '
        'forwards taps to it',
        (tester) async {
          String? actionQuery;
          var actionTapped = false;
          await _pumpPage(
            tester,
            itemsAsync: const AsyncValue.data(['Apple']),
            noMatchActionBuilder: (context, query) {
              actionQuery = query;
              return TextButton(
                onPressed: () => actionTapped = true,
                child: Text('Create "$query"'),
              );
            },
          );

          await _enterQuery(tester, 'Pear');

          expect(actionQuery, 'Pear');
          expect(find.text('Create "Pear"'), findsOneWidget);

          await tester.tap(find.text('Create "Pear"'));
          await tester.pump();

          expect(actionTapped, isTrue);
        },
      );

      testWidgets(
        'omits the action area when no noMatchActionBuilder is given',
        (tester) async {
          await _pumpPage(
            tester,
            itemsAsync: const AsyncValue.data(['Apple']),
          );

          await _enterQuery(tester, 'Pear');

          expect(find.text('No items match "Pear"'), findsOneWidget);
          expect(find.byType(TextButton), findsNothing);
        },
      );
    });

    group('error state', () {
      testWidgets(
        'shows the error title and the error itself instead of the list',
        (tester) async {
          await _pumpPage(
            tester,
            itemsAsync: AsyncValue.error(
              Exception('boom'),
              StackTrace.empty,
            ),
          );

          expect(find.byIcon(Icons.error_outline), findsOneWidget);
          expect(find.text('Failed to load items'), findsOneWidget);
          expect(find.textContaining('boom'), findsOneWidget);
          // No search field or rows render alongside the error shell.
          expect(find.byType(DesignSystemSearch), findsNothing);
          expect(find.byType(ListTile), findsNothing);
        },
      );
    });

    group('loading state', () {
      testWidgets('shows a progress indicator without content slivers', (
        tester,
      ) async {
        await _pumpPage(tester, itemsAsync: const AsyncValue.loading());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(DesignSystemSearch), findsNothing);
        expect(find.byType(DesignSystemGroupedList), findsNothing);
      });
    });

    group('create button', () {
      testWidgets(
        'renders the DS FAB with the given semantic label and invokes '
        'onCreate when tapped',
        (tester) async {
          var created = false;
          final semantics = tester.ensureSemantics();

          await _pumpPage(
            tester,
            itemsAsync: const AsyncValue.data(['Apple']),
            onCreate: () => created = true,
          );

          final fab = find.byType(DesignSystemFloatingActionButton);
          expect(
            find.descendant(
              of: fab,
              matching: find.bySemanticsLabel('Create item'),
            ),
            findsOneWidget,
          );

          await tester.tap(fab);
          await tester.pump();

          expect(created, isTrue);
          semantics.dispose();
        },
      );
    });

    group('initialSearchTerm', () {
      testWidgets(
        'seeds the search field text and pre-filters the list',
        (tester) async {
          await _pumpPage(
            tester,
            itemsAsync: const AsyncValue.data(
              ['Apple', 'Banana', 'Apricot'],
            ),
            initialSearchTerm: 'ap',
          );

          expect(_rowTitles(tester), ['Apple', 'Apricot']);
          expect(
            find.descendant(
              of: find.byType(DesignSystemSearch),
              matching: find.text('ap'),
            ),
            findsOneWidget,
          );
        },
      );
    });

    group('searchCallback', () {
      testWidgets('is notified about every query edit', (tester) async {
        final queries = <String>[];
        await _pumpPage(
          tester,
          itemsAsync: const AsyncValue.data(['Apple']),
          searchCallback: queries.add,
        );

        await _enterQuery(tester, 'a');
        await _enterQuery(tester, 'ap');

        expect(queries, ['a', 'ap']);
      });
    });
  });
  testWidgets('empty state offers an inline create action', (tester) async {
    var created = false;
    await _pumpPage(
      tester,
      itemsAsync: const AsyncValue.data([]),
      onCreate: () => created = true,
    );

    final inlineCreate = find.descendant(
      of: find.byType(DesignSystemButton),
      matching: find.text('Create item'),
    );
    expect(inlineCreate, findsOneWidget);

    await tester.tap(inlineCreate);
    expect(created, isTrue);
  });

  testWidgets(
    'desktop replaces the corner FAB with a header create button',
    (tester) async {
      tester.view
        ..physicalSize = const Size(1440, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var created = false;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          MediaQuery(
            data: const MediaQueryData(size: Size(1440, 900)),
            child: DefinitionsListPage<String>(
              title: 'Test Items',
              itemsAsync: const AsyncValue.data(['Alpha']),
              searchHint: 'Search test items',
              displayName: (item) => item,
              itemBuilder: (context, item, {required bool showDivider}) =>
                  ListTile(title: Text(item)),
              emptyIcon: Icons.inbox_outlined,
              emptyTitle: 'Nothing here yet',
              emptyHint: 'Tap create to add an item',
              noMatchMessage: (query) => 'No items match "$query"',
              errorTitle: 'Failed to load items',
              createLabel: 'Create item',
              onCreate: () => created = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DesignSystemFloatingActionButton), findsNothing);
      final headerCreate = find.descendant(
        of: find.byType(DesignSystemButton),
        matching: find.text('Create item'),
      );
      expect(headerCreate, findsOneWidget);

      await tester.tap(headerCreate);
      expect(created, isTrue);
    },
  );
}
