import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_chip.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt();
    beamToNamedOverride = (_) {};
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  Future<void> pumpMeasurablesPage(
    WidgetTester tester, {
    List<MeasurableDataType> measurables = const [],
    Object? error,
    bool loading = false,
    Widget child = const MeasurablesPage(),
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        child,
        overrides: [
          measurableDataTypesStreamProvider.overrideWith(
            (ref) => loading
                ? const Stream<List<MeasurableDataType>>.empty()
                : error != null
                ? Stream<List<MeasurableDataType>>.error(error)
                : Stream.value(measurables),
          ),
        ],
      ),
    );
    // A plain pump() does not advance the test clock; the header's
    // flutter_animate entrance schedules a zero-duration timer that must
    // fire before the test ends, so advance the clock explicitly.
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('MeasurablesPage', () {
    group('data rendering', () {
      testWidgets('displays measurable names sorted alphabetically', (
        tester,
      ) async {
        await pumpMeasurablesPage(
          tester,
          measurables: [measurableWater, measurableChocolate],
        );

        final items = find.byType(DesignSystemListItem);
        expect(items, findsNWidgets(2));
        expect(
          [
            tester.widget<DesignSystemListItem>(items.at(0)).title,
            tester.widget<DesignSystemListItem>(items.at(1)).title,
          ],
          [measurableChocolate.displayName, measurableWater.displayName],
        );
      });

      testWidgets('subtitle prefers the description over the raw unit', (
        tester,
      ) async {
        await pumpMeasurablesPage(tester, measurables: [measurableWater]);

        expect(find.text(measurableWater.description), findsOneWidget);
        expect(find.text(measurableWater.unitName), findsNothing);
      });

      testWidgets('falls back to the unit without a description', (
        tester,
      ) async {
        final bare = measurableWater.copyWith(description: '');
        await pumpMeasurablesPage(tester, measurables: [bare]);

        expect(find.text(measurableWater.unitName), findsOneWidget);
      });

      testWidgets('omits subtitle when unit and description are empty', (
        tester,
      ) async {
        final unitless = measurableWater.copyWith(
          unitName: '',
          description: '',
        );
        await pumpMeasurablesPage(tester, measurables: [unitless]);

        final item = tester.widget<DesignSystemListItem>(
          find.byType(DesignSystemListItem),
        );
        expect(item.subtitle, isNull);
      });

      testWidgets(
        'leads with a neutral first-letter chip and chevron trailing icon',
        (tester) async {
          await pumpMeasurablesPage(tester, measurables: [measurableWater]);

          // No repeated decorative trend-line glyph.
          expect(find.byIcon(Icons.trending_up_rounded), findsNothing);
          expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

          // The chip carries the measurable's first letter so rows are
          // distinguishable at a glance.
          final chipFinder = find.byType(DefinitionIconChip);
          expect(chipFinder, findsOneWidget);
          expect(
            find.descendant(of: chipFinder, matching: find.text('W')),
            findsOneWidget,
          );
        },
      );

      testWidgets('each row chip shows its own first letter', (tester) async {
        await pumpMeasurablesPage(
          tester,
          measurables: [measurableWater, measurableChocolate],
        );

        final chips = find.byType(DefinitionIconChip);
        expect(chips, findsNWidgets(2));
        expect(
          find.descendant(of: chips, matching: find.text('C')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: chips, matching: find.text('W')),
          findsOneWidget,
        );
      });
    });

    group('status icons', () {
      final cases =
          <
            ({
              String description,
              MeasurableDataType measurable,
              IconData icon,
              bool expected,
            })
          >[
            (
              description: 'shows lock icon when private',
              measurable: measurableWater.copyWith(private: true),
              icon: Icons.lock_outline,
              expected: true,
            ),
            (
              description: 'hides lock icon when not private',
              measurable: measurableWater,
              icon: Icons.lock_outline,
              expected: false,
            ),
            (
              description: 'shows outlined star icon when favorite',
              measurable: measurableWater.copyWith(favorite: true),
              icon: Icons.star_outline_rounded,
              expected: true,
            ),
            (
              description: 'hides star icon when not favorite',
              measurable: measurableWater,
              icon: Icons.star_outline_rounded,
              expected: false,
            ),
          ];

      for (final testCase in cases) {
        testWidgets(testCase.description, (tester) async {
          await pumpMeasurablesPage(
            tester,
            measurables: [testCase.measurable],
          );

          expect(
            find.byIcon(testCase.icon),
            testCase.expected ? findsOneWidget : findsNothing,
          );
        });
      }

      testWidgets('shows both private and favorite icons', (tester) async {
        final fullMeasurable = measurableWater.copyWith(
          private: true,
          favorite: true,
        );
        await pumpMeasurablesPage(tester, measurables: [fullMeasurable]);

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        // One icon weight across the trailing slot — the star is an
        // outline like its lock neighbor; amber carries the favorite
        // signal.
        final star = find.byIcon(Icons.star_outline_rounded);
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
        await pumpMeasurablesPage(
          tester,
          measurables: [
            measurableWater,
            measurableChocolate,
            measurableCoverage,
          ],
        );

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
        await pumpMeasurablesPage(tester, measurables: [measurableWater]);

        final item = tester.widget<DesignSystemListItem>(
          find.byType(DesignSystemListItem),
        );
        expect(item.showDivider, isFalse);
      });
    });

    group('empty, error, and loading states', () {
      testWidgets('shows localized empty state when no measurables exist', (
        tester,
      ) async {
        await pumpMeasurablesPage(tester);

        expect(find.text('No measurables yet'), findsOneWidget);
        expect(
          find.text(
            'Measurables are numbers you track over time — weight, water, '
            'steps.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows localized error state when the stream errors', (
        tester,
      ) async {
        await pumpMeasurablesPage(tester, error: Exception('types broke'));
        // Riverpod 3 retries failed providers with backoff; the spinner
        // keeps scheduling frames, so settling pumps virtual time through
        // the retries until the terminal AsyncError renders.
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Error loading measurables'), findsOneWidget);
        expect(find.textContaining('types broke'), findsOneWidget);
      });

      testWidgets('shows progress indicator while loading', (tester) async {
        await pumpMeasurablesPage(tester, loading: true);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(DesignSystemSearch), findsNothing);
      });
    });

    group('search', () {
      testWidgets('filters measurables by display name case-insensitively', (
        tester,
      ) async {
        await pumpMeasurablesPage(
          tester,
          measurables: [measurableWater, measurableChocolate],
        );

        await tester.enterText(find.byType(TextField), 'WATER');
        await tester.pump();

        expect(find.text(measurableWater.displayName), findsOneWidget);
        expect(find.text(measurableChocolate.displayName), findsNothing);
      });

      testWidgets('shows localized no-match message for unmatched query', (
        tester,
      ) async {
        await pumpMeasurablesPage(tester, measurables: [measurableWater]);

        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pump();

        expect(find.byType(DesignSystemListItem), findsNothing);
        expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
        expect(find.text('No measurables match "zzz"'), findsOneWidget);
      });
    });

    group('navigation', () {
      testWidgets(
        'FAB carries create-measurable semantics and beams to create',
        (tester) async {
          String? beamedTo;
          beamToNamedOverride = (path) => beamedTo = path;

          await pumpMeasurablesPage(tester, measurables: [measurableWater]);

          final fab = find.byType(DesignSystemFloatingActionButton);
          expect(
            tester.widget<DesignSystemFloatingActionButton>(fab).semanticLabel,
            'Create measurable',
          );

          await tester.tap(fab);
          await tester.pump();

          expect(beamedTo, '/settings/measurables/create');
        },
      );

      testWidgets('tapping a measurable row beams to its detail route', (
        tester,
      ) async {
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        await pumpMeasurablesPage(tester, measurables: [measurableWater]);

        await tester.tap(find.byType(DesignSystemListItem));
        await tester.pump();

        expect(beamedTo, '/settings/measurables/${measurableWater.id}');
      });
    });

    group('MeasurablesBody embedded alias', () {
      testWidgets('renders a MeasurablesPage with its content', (
        tester,
      ) async {
        await pumpMeasurablesPage(
          tester,
          measurables: [measurableWater],
          child: const MeasurablesBody(),
        );

        expect(find.byType(MeasurablesPage), findsOneWidget);
        expect(find.text(measurableWater.displayName), findsOneWidget);
      });
    });
  });
}
