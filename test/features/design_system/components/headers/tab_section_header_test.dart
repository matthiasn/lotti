import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/headers/tab_section_header.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_palette.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('TabSectionHeader', () {
    Future<void> pump(
      WidgetTester tester, {
      required TabSectionHeader header,
      Size size = const Size(1200, 800),
    }) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(body: header),
          ),
          mediaQueryData: MediaQueryData(size: size),
        ),
      );
      await tester.pump();
    }

    TabSectionHeader buildHeader({
      ValueChanged<String>? onSearchChanged,
      VoidCallback? onSearchCleared,
      ValueChanged<String>? onSearchPressed,
      VoidCallback? onFilterPressed,
      Widget? titleTrailing,
      Widget? titleSuffix,
      bool filtersActive = false,
      String query = '',
    }) {
      return TabSectionHeader(
        title: 'Tasks',
        query: query,
        searchHint: 'Search tasks',
        filterTooltip: 'Filter tasks',
        onSearchChanged: onSearchChanged ?? (_) {},
        onSearchCleared: onSearchCleared ?? () {},
        onSearchPressed: onSearchPressed ?? (_) {},
        onFilterPressed: onFilterPressed ?? () {},
        titleTrailing: titleTrailing,
        titleSuffix: titleSuffix,
        filtersActive: filtersActive,
      );
    }

    testWidgets('renders title, default bell, search input and filter icon', (
      tester,
    ) async {
      await pump(tester, header: buildHeader());

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
    });

    testWidgets('fires onSearchChanged as the user types', (tester) async {
      final changes = <String>[];
      await pump(
        tester,
        header: buildHeader(onSearchChanged: changes.add),
      );

      await tester.enterText(find.byType(TextField), 'agentic');
      await tester.pump();

      expect(changes, contains('agentic'));
    });

    testWidgets('fires onSearchPressed with the current query on submit', (
      tester,
    ) async {
      final pressed = <String>[];
      await pump(
        tester,
        header: buildHeader(
          query: 'agentic',
          onSearchPressed: pressed.add,
        ),
      );

      // The leading search action button forwards the controller text.
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pump();

      expect(pressed, ['agentic']);
    });

    testWidgets('fires onSearchCleared when the clear button is tapped', (
      tester,
    ) async {
      var cleared = 0;
      final changes = <String>[];
      await pump(
        tester,
        header: buildHeader(
          query: 'agentic',
          onSearchCleared: () => cleared++,
          onSearchChanged: changes.add,
        ),
      );

      // A non-empty query exposes the cancel affordance.
      await tester.tap(find.byIcon(Icons.cancel_rounded));
      await tester.pump();

      expect(cleared, 1);
      // Clearing also resets the text through onChanged('').
      expect(changes, contains(''));
      expect(find.text('agentic'), findsNothing);
    });

    testWidgets('fires onFilterPressed when the filter icon is tapped', (
      tester,
    ) async {
      var filterTaps = 0;
      await pump(
        tester,
        header: buildHeader(onFilterPressed: () => filterTaps++),
      );

      await tester.tap(find.byIcon(Icons.filter_list_rounded));
      await tester.pump();

      expect(filterTaps, 1);
    });

    testWidgets(
      'replaces the default bell with [titleTrailing] when supplied',
      (
        tester,
      ) async {
        await pump(
          tester,
          header: buildHeader(
            titleTrailing: const Icon(
              Icons.add_alert_rounded,
              key: ValueKey('custom-trailing'),
            ),
          ),
        );

        expect(find.byKey(const ValueKey('custom-trailing')), findsOneWidget);
        // Default bell is replaced, not layered.
        expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
      },
    );

    testWidgets('renders the inline titleSuffix after the title', (
      tester,
    ) async {
      await pump(
        tester,
        header: buildHeader(
          titleSuffix: const Text(
            '· My filter',
            key: ValueKey('title-suffix'),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('title-suffix')), findsOneWidget);
    });

    testWidgets(
      'filter affordance is neutral at rest and accent-with-fill when '
      'filters are active',
      (tester) async {
        Icon filterIcon() => tester.widget<Icon>(
          find.byIcon(Icons.filter_list_rounded),
        );
        IconButton filterButton() => tester.widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.filter_list_rounded),
            matching: find.byType(IconButton),
          ),
        );

        await pump(tester, header: buildHeader());
        final context = tester.element(find.byType(TabSectionHeader));
        final tokens = context.designTokens;
        // At rest: quiet neutral, no tonal fill — accent is reserved for
        // state.
        expect(filterIcon().color, tokens.colors.text.mediumEmphasis);
        expect(filterButton().style, isNull);

        await pump(tester, header: buildHeader(filtersActive: true));
        // Active: accent glyph on the activated tonal fill, so a narrowed
        // list can't masquerade as the full feed.
        expect(filterIcon().color, tokens.colors.interactive.enabled);
        expect(
          filterButton().style?.backgroundColor?.resolve(const {}),
          DesignSystemListPalette.activatedFill(tokens),
        );
      },
    );
  });
}
