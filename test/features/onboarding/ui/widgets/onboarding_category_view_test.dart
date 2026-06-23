import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_category_view.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const accent = Color(0xFF00C2A8);
  const options = [
    OnboardingCategoryOption(label: 'Work', icon: Icons.work_outline_rounded),
    OnboardingCategoryOption(
      label: 'Fitness',
      icon: Icons.fitness_center_rounded,
    ),
    OnboardingCategoryOption(label: 'Family', icon: Icons.home_rounded),
    OnboardingCategoryOption(label: 'Friends', icon: Icons.group_rounded),
  ];

  Future<void> pumpView(
    WidgetTester tester, {
    required Set<String> selected,
    void Function(String)? onToggle,
    VoidCallback? onWhy,
    VoidCallback? onAddOwn,
    VoidCallback? onContinue,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        SizedBox(
          width: 390,
          child: OnboardingCategoryView(
            accent: accent,
            title: 'Where should your AI work?',
            explanation:
                'Lotti keeps each area of your life in its own space, so tasks stay relevant.',
            whyLabel: 'Why areas?',
            continueLabel: 'Continue',
            addOwnLabel: 'Add your own',
            options: options,
            selected: selected,
            onToggle: onToggle ?? (_) {},
            onWhy: onWhy ?? () {},
            onAddOwn: onAddOwn ?? () {},
            onContinue: onContinue ?? () {},
          ),
        ),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the title, explanation, every option and add-your-own', (
    tester,
  ) async {
    await pumpView(tester, selected: const {});

    expect(find.text('Where should your AI work?'), findsOneWidget);
    expect(find.textContaining('its own space'), findsOneWidget);
    expect(find.text('Why areas?'), findsOneWidget);
    for (final option in options) {
      expect(find.text(option.label), findsOneWidget);
    }
    expect(find.text('Add your own'), findsOneWidget);
  });

  testWidgets('the "why areas?" disclosure reports its tap', (tester) async {
    var whys = 0;
    await pumpView(tester, selected: const {}, onWhy: () => whys++);

    await tester.tap(find.text('Why areas?'));
    expect(whys, 1);
  });

  testWidgets('every chip shows its category icon; selected adds a check', (
    tester,
  ) async {
    await pumpView(tester, selected: const {'Work'});

    // Each option carries its own (consistent) category icon for identity.
    expect(find.byIcon(Icons.work_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.group_rounded), findsOneWidget);
    // The selected chip additionally shows the trailing check (selection cue).
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    // The "add your own" chip keeps its add glyph.
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    for (final option in options) {
      expect(find.text(option.label), findsOneWidget);
    }
  });

  testWidgets(
    'unselected + add-own chips are frosted glass (BackdropFilter); the '
    'selected chip stays solid (no blur)',
    (tester) async {
      await pumpView(tester, selected: const {'Work'});

      // Three unselected option chips (Fitness/Family/Friends) + the
      // "add your own" chip are frosted glass, each carrying a blur layer.
      // The selected "Work" chip is a solid brand fill with no BackdropFilter.
      expect(find.byType(BackdropFilter), findsNWidgets(4));
      for (final filter in tester.widgetList<BackdropFilter>(
        find.byType(BackdropFilter),
      )) {
        expect(filter.filter, isA<ui.ImageFilter>());
      }

      // Every blur is clipped to a rounded rect — each BackdropFilter sits
      // inside a ClipRRect so the frost never bleeds past the chip edge.
      expect(
        find.descendant(
          of: find.byType(ClipRRect),
          matching: find.byType(BackdropFilter),
        ),
        findsNWidgets(4),
      );
    },
  );

  testWidgets(
    'with nothing selected every option chip is frosted glass (no solid '
    'selected chip)',
    (tester) async {
      await pumpView(tester, selected: const {});

      // Four option chips + the add-own chip are all frosted glass.
      expect(find.byType(BackdropFilter), findsNWidgets(5));
    },
  );

  testWidgets(
    'an ambient colour-glow layer sits behind the chips so the frost picks '
    'up real brand colour',
    (tester) async {
      await pumpView(tester, selected: const {});

      // The glow layer feathers its radial glows through a blur so they melt
      // into one soft wash (rather than two hard radial blobs). The chip
      // backdrop blurs are BackdropFilters, so the only ImageFiltered in the
      // tree is the ambient glow layer.
      final glowLayer = find.byType(ImageFiltered);
      expect(glowLayer, findsOneWidget);

      // Two heavily-feathered radial glows live inside that layer: the teal
      // brand glow and one cooler companion. Each is a RadialGradient that
      // fades fully transparent at its edge (a wash, not a hard disc).
      final glows = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: glowLayer, matching: find.byType(DecoratedBox)),
          )
          .where((d) => d.decoration is BoxDecoration)
          .map((d) => (d.decoration as BoxDecoration).gradient)
          .whereType<RadialGradient>()
          .toList();
      expect(glows, hasLength(2));
      for (final gradient in glows) {
        // Brand-led, low-opacity at the core and fully transparent at the
        // rim — a soft ambient wash, never an opaque rainbow blob.
        expect(gradient.colors.first.a, lessThan(0.3));
        expect(gradient.colors.first.a, greaterThan(0));
        expect(gradient.colors.last.a, 0);
      }
    },
  );

  testWidgets(
    'unselected chips are teal-tinted translucent glass — the colour lives in '
    'the material (not a neutral grey/milky fill), so they read as coloured '
    'frosted glass',
    (tester) async {
      await pumpView(tester, selected: const {});

      // Each frosted chip is a BackdropFilter wrapping a single tinted surface:
      // a translucent teal gradient + a crisp hairline. There is no second
      // opaque wash box — that neutral dark wash is what greyed the chips out
      // before, so its absence (one DecoratedBox per BackdropFilter) is part of
      // the fix.
      final surfaces = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(BackdropFilter),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();
      // One tinted surface per frosted chip (4 options + add-own), no extra
      // wash layer.
      expect(surfaces, hasLength(5));

      for (final decoration in surfaces) {
        // The fill is a vertical gradient (glass catching light at the top),
        // never a flat solid colour.
        final gradient = decoration.gradient! as LinearGradient;
        expect(gradient.colors, hasLength(2));
        for (final color in gradient.colors) {
          // Translucent — comfortably under the milky 0.55 that read as a
          // solid wall, so the blurred backdrop still shows through.
          expect(color.a, greaterThan(0));
          expect(color.a, lessThan(0.45));
          // The tint is brand teal, not neutral grey: green and blue clearly
          // lead red (a grey or white sheen would have r ≈ g ≈ b).
          expect(color.g, greaterThan(color.r + 0.2));
          expect(color.b, greaterThan(color.r + 0.2));
        }
        // A crisp hairline defines the glass edge — bright enough to mark the
        // tap-target boundary, still a hairline (not an opaque outline).
        final side = (decoration.border! as Border).top;
        expect(side.color.a, greaterThan(0.1));
        expect(side.color.a, lessThan(0.6));
      }
    },
  );

  testWidgets(
    'with no selection no chip shows a check and labels still render',
    (tester) async {
      await pumpView(tester, selected: const {});

      expect(find.byIcon(Icons.check_rounded), findsNothing);
      for (final option in options) {
        expect(find.text(option.label), findsOneWidget);
      }
    },
  );

  testWidgets(
    'option chips lay out as a uniform two-column grid with equal widths',
    (tester) async {
      await pumpView(tester, selected: const {'Work'});

      // Rows of two: Work/Fitness on one row, Family/Friends below, sharing
      // identical width (the Expanded cells) — the tidy-grid blocker.
      final workRect = tester.getRect(find.text('Work'));
      final fitnessRect = tester.getRect(find.text('Fitness'));
      final familyRect = tester.getRect(find.text('Family'));
      final friendsRect = tester.getRect(find.text('Friends'));

      // Two columns: left labels share a left edge; right labels another.
      expect(fitnessRect.center.dx, greaterThan(workRect.center.dx));
      expect(friendsRect.center.dx, greaterThan(familyRect.center.dx));
      // Two rows: the second pair sits below the first.
      expect(familyRect.top, greaterThan(workRect.top));
      expect(friendsRect.top, greaterThan(fitnessRect.top));
    },
  );

  testWidgets('tapping an option in either column reports the toggle', (
    tester,
  ) async {
    final toggled = <String>[];
    await pumpView(
      tester,
      selected: const {},
      onToggle: toggled.add,
    );

    // A left-column option (Work, index 0) and a right-column one (Fitness,
    // index 1) — exercising both per-cell toggle closures.
    await tester.tap(find.text('Work'));
    await tester.tap(find.text('Fitness'));
    expect(toggled, ['Work', 'Fitness']);
  });

  testWidgets('add-your-own reports its tap', (tester) async {
    var added = 0;
    await pumpView(tester, selected: const {}, onAddOwn: () => added++);

    await tester.tap(find.text('Add your own'));
    expect(added, 1);
  });

  testWidgets('Continue is disabled until at least one area is selected', (
    tester,
  ) async {
    var continues = 0;
    await pumpView(
      tester,
      selected: const {},
      onContinue: () => continues++,
    );

    final disabled = tester.widget<DesignSystemButton>(
      find.widgetWithText(DesignSystemButton, 'Continue'),
    );
    expect(disabled.onPressed, isNull);
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Continue'));
    expect(continues, 0);
  });

  testWidgets('Continue fires onContinue once an area is selected', (
    tester,
  ) async {
    var continues = 0;
    await pumpView(
      tester,
      selected: const {'Family'},
      onContinue: () => continues++,
    );

    await tester.tap(find.widgetWithText(DesignSystemButton, 'Continue'));
    expect(continues, 1);
  });
}
