import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/lists/hover_divider_index.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/definitions_list_page.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';

import '../../../../test_utils/hover_divider_harness.dart';
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
        itemBuilder: (context, item, {required ListRowDivider divider}) =>
            ListTile(
              key: ValueKey('row-$item-divider-${divider.showDivider}'),
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

/// Pumps the template with real [DesignSystemListItem] rows so the hover
/// wiring is exercised end-to-end: a real pointer enters a row, the item
/// fires `onHoverChanged`, and the shell feeds `dividerColor` back on the
/// next build. Returns the design-system default divider colour so tests
/// can distinguish "faded" from "untouched".
///
/// Rows are titled by [items]; the shell sorts them, so pass names whose
/// alphabetical order is the intended row order.
Future<Color> _pumpHoverRows(
  WidgetTester tester, {
  required List<String> items,
}) async {
  late Color defaultDividerColor;
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      DefinitionsListPage<String>(
        title: 'Test Items',
        itemsAsync: AsyncValue.data(items),
        searchHint: 'Search test items',
        displayName: (item) => item,
        itemBuilder: (context, item, {required ListRowDivider divider}) {
          defaultDividerColor = context.designTokens.colors.decorative.level01;
          return DesignSystemListItem(
            title: item,
            showDivider: divider.showDivider,
            dividerColor: divider.color,
            onHoverChanged: divider.onHoverChanged,
            // DesignSystemListItem only reports hover for rows that are
            // tappable, which every real definition row is.
            onTap: () {},
          );
        },
        emptyIcon: Icons.inbox_outlined,
        emptyTitle: 'Nothing here yet',
        emptyHint: 'Tap create to add an item',
        noMatchMessage: (query) => 'No items match "$query"',
        errorTitle: 'Failed to load items',
        createLabel: 'Create item',
        onCreate: () {},
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return defaultDividerColor;
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
        'an entirely empty list hides the search field — search over '
        'zero items is dead UI; the empty state owns the screen',
        (tester) async {
          await _pumpPage(tester, itemsAsync: const AsyncValue.data([]));

          expect(find.byType(DesignSystemSearch), findsNothing);
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
              itemBuilder: (context, item, {required ListRowDivider divider}) =>
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

  // The shell owns the hover index for every definitions list, so these
  // cover the wiring once for all five pages: the row-index maths lives in
  // HoverDividerIndex (tested in isolation), while these prove the shell
  // feeds it a real pointer and paints the result back onto the rows.
  //
  // Three rows -> dividers beneath rows 0 and 1 only; the last row never
  // draws one.
  group('hover dividers', () {
    testWidgets('idle: every divider uses the design-system default', (
      tester,
    ) async {
      final defaultColor = await _pumpHoverRows(
        tester,
        items: ['Alpha', 'Beta', 'Gamma'],
      );

      expect(listRowDividerColors(tester), [defaultColor, defaultColor]);
    });

    testWidgets('hovering a middle row fades both hairlines bracketing it', (
      tester,
    ) async {
      final defaultColor = await _pumpHoverRows(
        tester,
        items: ['Alpha', 'Beta', 'Gamma'],
      );

      await hoverListRow(tester, find.text('Beta'));

      // Beta is row 1: the divider above it (0) and below it (1) both go.
      expect(listRowDividerColors(tester), [
        Colors.transparent,
        Colors.transparent,
      ]);
      expect(defaultColor, isNot(Colors.transparent));
    });

    testWidgets('hovering the first row fades only its own divider', (
      tester,
    ) async {
      final defaultColor = await _pumpHoverRows(
        tester,
        items: ['Alpha', 'Beta', 'Gamma'],
      );

      await hoverListRow(tester, find.text('Alpha'));

      // No row above row 0, so the second divider is untouched.
      expect(listRowDividerColors(tester), [Colors.transparent, defaultColor]);
    });

    testWidgets('hovering the last row fades the divider above it', (
      tester,
    ) async {
      final defaultColor = await _pumpHoverRows(
        tester,
        items: ['Alpha', 'Beta', 'Gamma'],
      );

      await hoverListRow(tester, find.text('Gamma'));

      // Gamma is the last row and draws no divider of its own; only the
      // hairline separating it from Beta fades.
      expect(listRowDividerColors(tester), [defaultColor, Colors.transparent]);
    });

    testWidgets('moving between rows retargets the fade', (tester) async {
      final defaultColor = await _pumpHoverRows(
        tester,
        items: ['Alpha', 'Beta', 'Gamma'],
      );

      final gesture = await hoverListRow(tester, find.text('Alpha'));
      expect(listRowDividerColors(tester), [Colors.transparent, defaultColor]);

      await gesture.moveTo(tester.getCenter(find.text('Gamma')));
      await tester.pump();

      // The enter/leave pair for a row-to-row move must settle on Gamma,
      // not leave Alpha's divider stuck faded.
      expect(listRowDividerColors(tester), [defaultColor, Colors.transparent]);
    });

    testWidgets('moving the pointer off the list restores every divider', (
      tester,
    ) async {
      final defaultColor = await _pumpHoverRows(
        tester,
        items: ['Alpha', 'Beta', 'Gamma'],
      );

      final gesture = await hoverListRow(tester, find.text('Beta'));
      expect(listRowDividerColors(tester), isNot(contains(defaultColor)));

      await unhoverRows(tester, gesture);

      expect(listRowDividerColors(tester), [defaultColor, defaultColor]);
    });

    testWidgets('hover changes colour only — it never shifts the layout', (
      tester,
    ) async {
      await _pumpHoverRows(tester, items: ['Alpha', 'Beta', 'Gamma']);

      final dividersBefore = listRowDividerColors(tester).length;
      final gammaBefore = tester.getTopLeft(find.text('Gamma'));

      await hoverListRow(tester, find.text('Beta'));

      // The regression this guards: fading via `showDivider` instead of
      // `dividerColor` would remove a 1px divider and jump the rows below.
      expect(listRowDividerColors(tester), hasLength(dividersBefore));
      expect(tester.getTopLeft(find.text('Gamma')), gammaBefore);
    });

    testWidgets('a single-row list renders no divider to fade', (tester) async {
      await _pumpHoverRows(tester, items: ['Alpha']);

      expect(listRowDividerColors(tester), isEmpty);

      // Hovering the only row must not throw despite there being no
      // divider for the mixin's index to colour.
      await hoverListRow(tester, find.text('Alpha'));
      expect(listRowDividerColors(tester), isEmpty);
    });
  });
}
