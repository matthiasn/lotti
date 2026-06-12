import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_chip.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/habits/habits_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        // _HabitListItem renders CategoryIconChip.fromId, which resolves
        // the habit's category through the cache; the unstubbed mock
        // returns null and triggers the neutral fallback chip, which is
        // fine for most tests here.
        getIt.registerSingleton<EntitiesCacheService>(
          MockEntitiesCacheService(),
        );
      },
    );
    beamToNamedOverride = (_) {};
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  Future<void> pumpHabitsPage(
    WidgetTester tester, {
    List<HabitDefinition> habits = const [],
    Object? error,
    bool loading = false,
    String? initialSearchTerm,
    Widget child = const HabitsPage(),
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        initialSearchTerm != null
            ? HabitsPage(initialSearchTerm: initialSearchTerm)
            : child,
        overrides: [
          habitDefinitionsStreamProvider.overrideWith(
            (ref) => loading
                ? const Stream<List<HabitDefinition>>.empty()
                : error != null
                ? Stream<List<HabitDefinition>>.error(error)
                : Stream.value(habits),
          ),
        ],
      ),
    );
    // A plain pump() does not advance the test clock; the header's
    // flutter_animate entrance schedules a zero-duration timer that must
    // fire before the test ends, so advance the clock explicitly.
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('HabitsPage', () {
    group('data rendering', () {
      testWidgets('displays habit name with chevron', (tester) async {
        await pumpHabitsPage(tester, habits: [habitFlossing]);

        expect(find.text(habitFlossing.name), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      });

      testWidgets('sorts habits alphabetically by name', (tester) async {
        await pumpHabitsPage(
          tester,
          habits: [
            habitFlossing.copyWith(id: 'habit-y', name: 'Yoga'),
            habitFlossing,
            habitFlossing.copyWith(id: 'habit-m', name: 'Meditation'),
          ],
        );

        final items = find.byType(DesignSystemListItem);
        expect(items, findsNWidgets(3));
        expect(
          [
            tester.widget<DesignSystemListItem>(items.at(0)).title,
            tester.widget<DesignSystemListItem>(items.at(1)).title,
            tester.widget<DesignSystemListItem>(items.at(2)).title,
          ],
          ['Flossing', 'Meditation', 'Yoga'],
        );
      });
    });

    group('leading category chip', () {
      testWidgets(
        'unresolved category renders the neutral chip with the habit '
        'initial — never the more_horiz glyph',
        (tester) async {
          // habitFlossing has no categoryId, so the cache resolves null.
          await pumpHabitsPage(tester, habits: [habitFlossing]);

          final chipFinder = find.byType(CategoryIconChip);
          expect(chipFinder, findsOneWidget);
          expect(
            find.descendant(of: chipFinder, matching: find.text('F')),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.more_horiz), findsNothing);
          expect(find.byIcon(Icons.category_outlined), findsNothing);
        },
      );

      testWidgets(
        'resolved category renders the HABIT first letter on the category '
        'color — never the category initial or icon',
        (tester) async {
          final cache =
              getIt<EntitiesCacheService>() as MockEntitiesCacheService;
          when(
            () => cache.getCategoryById(categoryMindfulness.id),
          ).thenReturn(categoryMindfulness);

          await pumpHabitsPage(
            tester,
            habits: [
              habitFlossing.copyWith(categoryId: categoryMindfulness.id),
            ],
          );

          final chipFinder = find.byType(CategoryIconChip);
          expect(chipFinder, findsOneWidget);
          expect(find.byIcon(Icons.more_horiz), findsNothing);
          // The habit's own initial ('F' for Flossing), not the
          // category's ('M' for Mindfulness)...
          expect(
            find.descendant(of: chipFinder, matching: find.text('F')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: chipFinder, matching: find.text('M')),
            findsNothing,
          );
          // ...while the chip background carries the category color.
          final inner = tester.widget<DefinitionIconChip>(
            find.descendant(
              of: chipFinder,
              matching: find.byType(DefinitionIconChip),
            ),
          );
          expect(inner.background, colorFromCssHex(categoryMindfulness.color));
        },
      );
    });

    group('status icons', () {
      final cases =
          <
            ({
              String description,
              HabitDefinition habit,
              IconData icon,
              bool expected,
            })
          >[
            (
              description: 'shows lock icon when private',
              habit: habitFlossing.copyWith(private: true),
              icon: Icons.lock_outline,
              expected: true,
            ),
            (
              description: 'hides lock icon when not private',
              habit: habitFlossing,
              icon: Icons.lock_outline,
              expected: false,
            ),
            (
              description: 'shows inactive icon when not active',
              habit: habitFlossing.copyWith(active: false),
              icon: Icons.visibility_off_outlined,
              expected: true,
            ),
            (
              description: 'hides inactive icon when active',
              habit: habitFlossing,
              icon: Icons.visibility_off_outlined,
              expected: false,
            ),
            (
              description: 'shows outlined star icon when favorite',
              habit: habitFlossing.copyWith(priority: true),
              icon: Icons.star_rounded,
              expected: true,
            ),
            (
              description: 'hides star icon when not favorite',
              habit: habitFlossing,
              icon: Icons.star_rounded,
              expected: false,
            ),
          ];

      for (final testCase in cases) {
        testWidgets(testCase.description, (tester) async {
          await pumpHabitsPage(tester, habits: [testCase.habit]);

          expect(
            find.byIcon(testCase.icon),
            testCase.expected ? findsOneWidget : findsNothing,
          );
        });
      }

      testWidgets('shows all status icons together', (tester) async {
        final fullHabit = habitFlossing.copyWith(
          private: true,
          active: false,
          priority: true,
        );
        await pumpHabitsPage(tester, habits: [fullHabit]);

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
        // One icon weight across the trailing slot — the star is an
        // outline like its lock/eye-off neighbors; amber carries the
        // favorite signal.
        final star = find.byIcon(Icons.star_rounded);
        expect(star, findsOneWidget);
        final tokens = tester.element(star).designTokens;
        expect(
          tester.widget<Icon>(star).color,
          tokens.colors.text.mediumEmphasis,
        );
      });
    });

    group('dividers', () {
      testWidgets('shows dividers between items but not after last', (
        tester,
      ) async {
        final habits = [
          habitFlossing,
          habitFlossing.copyWith(
            id: 'habit-2',
            name: 'Meditation',
          ),
          habitFlossing.copyWith(
            id: 'habit-3',
            name: 'Yoga',
          ),
        ];
        await pumpHabitsPage(tester, habits: habits);

        final items = find.byType(DesignSystemListItem);
        expect(items, findsNWidgets(3));

        final first = tester.widget<DesignSystemListItem>(items.at(0));
        final second = tester.widget<DesignSystemListItem>(items.at(1));
        final third = tester.widget<DesignSystemListItem>(items.at(2));

        expect(first.showDivider, isTrue);
        expect(second.showDivider, isTrue);
        expect(third.showDivider, isFalse);
      });

      testWidgets('single item has no divider', (tester) async {
        await pumpHabitsPage(tester, habits: [habitFlossing]);

        final item = tester.widget<DesignSystemListItem>(
          find.byType(DesignSystemListItem),
        );
        expect(item.showDivider, isFalse);
      });
    });

    group('empty, error, and loading states', () {
      testWidgets('shows localized empty state when no habits exist', (
        tester,
      ) async {
        await pumpHabitsPage(tester);

        expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
        expect(find.text('No habits yet'), findsOneWidget);
        expect(
          find.text('Tap the + button to create your first habit.'),
          findsOneWidget,
        );
      });

      testWidgets('shows localized error state when the stream errors', (
        tester,
      ) async {
        await pumpHabitsPage(tester, error: Exception('habits broke'));
        // Riverpod 3 retries failed providers with backoff; the spinner
        // keeps scheduling frames, so settling pumps virtual time through
        // the retries until the terminal AsyncError renders.
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Error loading habits'), findsOneWidget);
        expect(find.textContaining('habits broke'), findsOneWidget);
      });

      testWidgets('shows progress indicator while loading', (tester) async {
        await pumpHabitsPage(tester, loading: true);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(DesignSystemSearch), findsNothing);
      });
    });

    group('search', () {
      testWidgets('filters habits by name case-insensitively', (tester) async {
        await pumpHabitsPage(
          tester,
          habits: [
            habitFlossing,
            habitFlossing.copyWith(id: 'habit-2', name: 'Meditation'),
          ],
        );

        await tester.enterText(find.byType(TextField), 'FLOSS');
        await tester.pump();

        expect(find.text('Flossing'), findsOneWidget);
        expect(find.text('Meditation'), findsNothing);
      });

      testWidgets('shows localized no-match message for unmatched query', (
        tester,
      ) async {
        await pumpHabitsPage(tester, habits: [habitFlossing]);

        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pump();

        expect(find.byType(DesignSystemListItem), findsNothing);
        expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
        expect(find.text('No habits match "zzz"'), findsOneWidget);
      });

      testWidgets('initialSearchTerm pre-filters the list', (tester) async {
        await pumpHabitsPage(
          tester,
          habits: [
            habitFlossing,
            habitFlossing.copyWith(id: 'habit-2', name: 'Meditation'),
          ],
          initialSearchTerm: 'medi',
        );

        expect(find.text('Meditation'), findsOneWidget);
        expect(find.text('Flossing'), findsNothing);
      });
    });

    group('navigation', () {
      testWidgets('FAB carries create-habit semantics and beams to create', (
        tester,
      ) async {
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        await pumpHabitsPage(tester, habits: [habitFlossing]);

        final fab = find.byType(DesignSystemFloatingActionButton);
        expect(
          tester.widget<DesignSystemFloatingActionButton>(fab).semanticLabel,
          'Create habit',
        );

        await tester.tap(fab);
        await tester.pump();

        expect(beamedTo, '/settings/habits/create');
      });

      testWidgets('tapping a habit row beams to its detail route', (
        tester,
      ) async {
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        await pumpHabitsPage(tester, habits: [habitFlossing]);

        await tester.tap(find.byType(DesignSystemListItem));
        await tester.pump();

        expect(beamedTo, '/settings/habits/by_id/${habitFlossing.id}');
      });
    });

    group('HabitsBody embedded alias', () {
      testWidgets('renders a HabitsPage with its content', (tester) async {
        await pumpHabitsPage(
          tester,
          habits: [habitFlossing],
          child: const HabitsBody(),
        );

        expect(find.byType(HabitsPage), findsOneWidget);
        expect(find.text(habitFlossing.name), findsOneWidget);
      });
    });
  });
}
