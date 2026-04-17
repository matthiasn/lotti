import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/headers/tab_section_header.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

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
  });
}
