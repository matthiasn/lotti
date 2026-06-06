import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('WidgetbookSection / WidgetbookPreviewCase', () {
    testWidgets('render their titles above the child', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WidgetbookSection(
                title: 'Section title',
                child: Text('section child'),
              ),
              WidgetbookPreviewCase(
                label: 'Case label',
                child: Text('case child'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Section title'), findsOneWidget);
      expect(find.text('section child'), findsOneWidget);
      expect(find.text('Case label'), findsOneWidget);
      expect(find.text('case child'), findsOneWidget);
    });
  });

  group('WidgetbookViewport', () {
    testWidgets('clamps to the finite incoming constraint and scales down', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const Center(
            child: SizedBox(
              width: 300,
              child: WidgetbookViewport(
                width: 600,
                child: SizedBox(height: 10, child: Text('wide')),
              ),
            ),
          ),
        ),
      );

      // Outer box adopts the finite 300px constraint, the inner design
      // surface keeps its 600px layout width and is scaled down to fit.
      expect(tester.getSize(find.byType(WidgetbookViewport)).width, 300);
      final inner = tester.getSize(
        find.descendant(
          of: find.byType(FittedBox),
          matching: find.byType(SizedBox).last,
        ),
      );
      expect(inner.width, 600);
    });

    testWidgets('falls back to the requested width under infinite '
        'constraints', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: WidgetbookViewport(
              width: 420,
              child: SizedBox(height: 10, child: Text('wide')),
            ),
          ),
        ),
      );

      // Horizontal scroll view hands down an unbounded max width — the
      // viewport must size itself to its own requested width.
      expect(tester.getSize(find.byType(WidgetbookViewport)).width, 420);
    });
  });

  group('widgetbookNavigationDestinations', () {
    testWidgets('builds the six localized destinations in nav order', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final destinations = widgetbookNavigationDestinations(context);
      expect(destinations, hasLength(6));
      expect(
        destinations.map((d) => d.label),
        [
          context.messages.designSystemNavigationMyDailyLabel,
          context.messages.navTabTitleTasks,
          context.messages.designSystemBreadcrumbProjectsLabel,
          context.messages.navTabTitleHabits,
          context.messages.designSystemNavigationInsightsLabel,
          context.messages.navTabTitleJournal,
        ],
      );
      expect(destinations.every((d) => !d.active), isTrue);
    });
  });
}
