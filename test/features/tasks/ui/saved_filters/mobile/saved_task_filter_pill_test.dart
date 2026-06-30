import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filter_pill.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';
import '../../../../categories/test_utils.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget pill, {
  MediaQueryData? mq,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(pill, mediaQueryData: mq),
  );
  await tester.pump();
}

void main() {
  group('SavedTaskFilterPill widget', () {
    testWidgets('inactive pill shows the count and has no selection check', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        SavedTaskFilterPill(
          label: 'Backlog',
          semanticsLabel: 'Backlog, 12 tasks',
          count: 12,
          onTap: () => taps++,
        ),
      );

      expect(find.text('Backlog'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      await tester.tap(find.byType(SavedTaskFilterPill));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets(
      'active pill shows the chevron but no redundant check; tap opens sheet',
      (tester) async {
        var opened = 0;
        await _pump(
          tester,
          SavedTaskFilterPill(
            label: 'In Progress',
            semanticsLabel: 'In Progress, 5 tasks',
            selected: true,
            count: 5,
            onTap: () => opened++,
            onOpenSheet: () {},
          ),
        );

        // The active state is already encoded by the border/fill/bold name, so
        // the in-pill check is gone — only the disclosure chevron remains.
        expect(find.byIcon(Icons.check_rounded), findsNothing);
        expect(
          find.byKey(SavedTaskFilterPill.chevronKey('In Progress')),
          findsOneWidget,
        );

        await tester.tap(find.byType(SavedTaskFilterPill));
        await tester.pump();
        expect(opened, 1);
      },
    );

    testWidgets('zero count renders a dimmed 0', (tester) async {
      await _pump(
        tester,
        SavedTaskFilterPill(
          label: 'Empty',
          semanticsLabel: 'Empty, 0 tasks',
          count: 0,
          onTap: () {},
        ),
      );

      final text = tester.widget<Text>(find.text('0'));
      // Zero uses a dimmed low-emphasis token, distinct from the
      // medium-emphasis colour a non-zero count would carry.
      expect(text.style?.color, dsTokensLight.colors.text.lowEmphasis);
    });

    testWidgets('loading count renders the placeholder dash', (tester) async {
      await _pump(
        tester,
        SavedTaskFilterPill(
          label: 'Loading',
          semanticsLabel: 'Loading',
          countLoading: true,
          onTap: () {},
        ),
      );

      expect(find.text('–'), findsOneWidget);
    });

    testWidgets('count above the cap renders 999+', (tester) async {
      await _pump(
        tester,
        SavedTaskFilterPill(
          label: 'Huge',
          semanticsLabel: 'Huge, 1200 tasks',
          count: 1200,
          onTap: () {},
        ),
      );

      expect(find.text('999+'), findsOneWidget);
    });

    testWidgets(
      'count slot grows at large text so multi-digit counts never clip',
      (tester) async {
        // The headline defect: at large text the fixed-width slot clipped
        // "214"→"21". The slot now sizes to its full content. 2x is a strictly
        // harder case than the reviewed 1.6x, so passing here covers it.
        await _pump(
          tester,
          SavedTaskFilterPill(
            label: 'Quarterly planning backlog with a very long name',
            semanticsLabel: 'Quarterly, 214 tasks',
            count: 214,
            onTap: () {},
          ),
          mq: phoneMediaQueryData.copyWith(
            textScaler: const TextScaler.linear(2),
          ),
        );

        expect(find.text('214'), findsOneWidget);
        // The slot grew past the step7 (32) reserve to hold all three digits;
        // the old fixed-width slot would clamp to 32 and clip the digits.
        expect(
          tester.getSize(find.text('214')).width,
          greaterThan(32),
        );
      },
    );

    testWidgets(
      'count reads secondary (medium-emphasis) whether selected or not',
      (tester) async {
        // The same datum must not change colour between states: the count is
        // medium-emphasis in BOTH the selected and unselected pill (matching
        // the sheet), with the active state carried by border/fill/bold name.
        for (final selected in [false, true]) {
          await _pump(
            tester,
            SavedTaskFilterPill(
              label: 'Active',
              semanticsLabel: 'Active, 5 tasks',
              selected: selected,
              count: 5,
              onTap: () {},
              onOpenSheet: selected ? () {} : null,
            ),
          );

          expect(
            tester.widget<Text>(find.text('5')).style?.color,
            dsTokensLight.colors.text.mediumEmphasis,
            reason: 'count colour must be secondary when selected=$selected',
          );
        }
      },
    );

    testWidgets('selected pill chevron stays high-emphasis (legible cue)', (
      tester,
    ) async {
      // The chevron is a disclosure affordance, not a count — it keeps
      // high-emphasis so it reads over the mint selected fill in light theme.
      await _pump(
        tester,
        SavedTaskFilterPill(
          label: 'Active',
          semanticsLabel: 'Active, 5 tasks',
          selected: true,
          count: 5,
          onTap: () {},
          onOpenSheet: () {},
        ),
      );

      expect(
        tester
            .widget<Icon>(find.byKey(SavedTaskFilterPill.chevronKey('Active')))
            .color,
        dsTokensLight.colors.text.highEmphasis,
      );
    });

    testWidgets(
      'long "Category · Status" name truncates the prefix, keeps the status',
      (tester) async {
        // The category dot already encodes the category, so when the name must
        // truncate the leading "Lotti · " prefix yields width first while the
        // trailing "· In Progress" status segment stays fully visible.
        await _pump(
          tester,
          SavedTaskFilterPill(
            label: 'Lotti · In Progress',
            semanticsLabel: 'Lotti, In Progress, 5 tasks',
            selected: true,
            count: 5,
            onTap: () {},
            onOpenSheet: () {},
          ),
          mq: phoneMediaQueryData.copyWith(
            textScaler: const TextScaler.linear(2.4),
          ),
        );

        // The status segment renders in full as its own (pinned) text node…
        final tail = tester.widget<Text>(find.text('· In Progress'));
        expect(tail.overflow, TextOverflow.ellipsis);
        // …while the category prefix is a separate, ellipsizing node.
        final head = tester.widget<Text>(find.text('Lotti '));
        expect(head.overflow, TextOverflow.ellipsis);
      },
    );

    testWidgets('category dot paints the supplied colour', (tester) async {
      const dot = Color(0xFF8833AA);
      await _pump(
        tester,
        SavedTaskFilterPill(
          label: 'Lotti',
          semanticsLabel: 'Lotti, 3 tasks',
          categoryColor: dot,
          count: 3,
          onTap: () {},
        ),
      );

      final circle = tester
          .widgetList<Container>(find.byType(Container))
          .firstWhere((c) {
            final decoration = c.decoration;
            return decoration is BoxDecoration &&
                decoration.shape == BoxShape.circle &&
                decoration.color == dot;
          });
      expect((circle.decoration! as BoxDecoration).color, dot);
    });

    testWidgets('hidden count slot omits the count entirely (Custom)', (
      tester,
    ) async {
      await _pump(
        tester,
        SavedTaskFilterPill(
          label: 'Custom',
          semanticsLabel: 'Custom',
          selected: true,
          showCount: false,
          count: 9,
          onTap: () {},
        ),
      );

      expect(find.text('9'), findsNothing);
      expect(find.text('–'), findsNothing);
    });

    testWidgets('exposes a single selectable button semantics node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await _pump(
        tester,
        SavedTaskFilterPill(
          label: 'In Progress',
          semanticsLabel: 'Lotti, In Progress, 5 tasks',
          selected: true,
          count: 5,
          onTap: () {},
          onOpenSheet: () {},
        ),
      );

      final node = tester.getSemantics(find.byType(SavedTaskFilterPill));
      expect(node.label, 'Lotti, In Progress, 5 tasks');
      // ignore: deprecated_member_use
      expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);
      // ignore: deprecated_member_use
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
      handle.dispose();
    });

    testWidgets('tap target is at least 48dp tall', (tester) async {
      await _pump(
        tester,
        SavedTaskFilterPill(
          label: 'Tap',
          semanticsLabel: 'Tap',
          count: 1,
          onTap: () {},
        ),
      );

      final size = tester.getSize(
        find
            .descendant(
              of: find.byType(SavedTaskFilterPill),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });
  });

  group('category resolution helpers', () {
    late MockEntitiesCacheService cache;

    setUp(() async {
      await setUpTestGetIt(
        additionalSetup: () {
          cache = MockEntitiesCacheService();
          getIt.registerSingleton<EntitiesCacheService>(cache);
        },
      );
    });

    tearDown(tearDownTestGetIt);

    test('returns the first resolvable category colour and name', () {
      final category = CategoryTestUtils.createTestCategory(
        id: 'cat-1',
        name: 'Lotti',
        color: '#FF0000',
      );
      when(() => cache.getCategoryById('cat-1')).thenReturn(category);

      const filter = SavedTaskFilter(
        id: 'sv-1',
        name: 'Lotti work',
        filter: TasksFilter(selectedCategoryIds: {'cat-1'}),
      );

      expect(savedFilterCategoryColor(filter), const Color(0xFFFF0000));
      expect(savedFilterCategoryName(filter), 'Lotti');
    });

    test('returns null when the filter selects no category', () {
      const filter = SavedTaskFilter(
        id: 'sv-1',
        name: 'No category',
        filter: TasksFilter(selectedTaskStatuses: {'OPEN'}),
      );

      expect(savedFilterCategoryColor(filter), isNull);
      expect(savedFilterCategoryName(filter), isNull);
    });
  });
}
