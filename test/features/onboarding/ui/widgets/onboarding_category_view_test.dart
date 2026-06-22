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

  testWidgets('only the selected chip shows a check; unselected chips are '
      'label-only (no per-category icons)', (tester) async {
    await pumpView(tester, selected: const {'Work'});

    // Exactly one chip — the selected one — gains a leading check.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    // The mixed-metaphor per-category icons are gone entirely: unselected
    // chips render their label only.
    expect(find.byIcon(Icons.fitness_center_rounded), findsNothing);
    expect(find.byIcon(Icons.work_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.home_rounded), findsNothing);
    expect(find.byIcon(Icons.group_rounded), findsNothing);
    // Only the "add your own" chip keeps a glyph (the add affordance).
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    // Every label still renders regardless of selection.
    for (final option in options) {
      expect(find.text(option.label), findsOneWidget);
    }
  });

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
