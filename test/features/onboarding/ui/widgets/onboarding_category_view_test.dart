import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_category_view.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_choice_chip.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_speech_bubble.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_stage.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const options = [
    OnboardingCategoryOption(label: 'Work', icon: LottiIcons.work),
    OnboardingCategoryOption(
      label: 'Fitness',
      icon: LottiIcons.fitness,
    ),
    OnboardingCategoryOption(label: 'Family', icon: LottiIcons.home),
    OnboardingCategoryOption(label: 'Friends', icon: LottiIcons.people),
  ];

  Future<void> pumpView(
    WidgetTester tester, {
    required Set<String> selected,
    TextScaler textScaler = TextScaler.noScaling,
    void Function(String)? onToggle,
    VoidCallback? onWhy,
    VoidCallback? onAddOwn,
    VoidCallback? onContinue,
    Widget? companion,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        SizedBox(
          width: 390,
          child: OnboardingCategoryView(
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
            companion: companion,
          ),
        ),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          disableAnimations: true,
        ).copyWith(textScaler: textScaler),
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
    expect(find.byIcon(LottiIcons.work), findsOneWidget);
    expect(find.byIcon(LottiIcons.fitness), findsOneWidget);
    expect(find.byIcon(LottiIcons.home), findsOneWidget);
    expect(find.byIcon(LottiIcons.people), findsOneWidget);
    // The selected chip additionally shows the trailing check (selection cue).
    expect(find.byIcon(LottiIcons.confirm), findsOneWidget);
    // The "add your own" chip keeps its add glyph.
    expect(find.byIcon(LottiIcons.add), findsOneWidget);
    for (final option in options) {
      expect(find.text(option.label), findsOneWidget);
    }
  });

  testWidgets(
    'every chip is the shared onboarding chip: the picked one marked by its '
    'outline and a check, the rest quiet, "Add your own" an action on a row '
    'of its own',
    (tester) async {
      await pumpView(tester, selected: const {'Work'});

      final chips = tester
          .widgetList<OnboardingChoiceChip>(find.byType(OnboardingChoiceChip))
          .toList();
      expect(chips.map((c) => c.label), [
        'Work',
        'Fitness',
        'Family',
        'Friends',
        'Add your own',
      ]);
      expect(chips.map((c) => c.selected), [true, false, false, false, null]);
      expect(find.byIcon(LottiIcons.confirm), findsOneWidget);
      // "Add your own" spans the grid's width.
      final grid = tester.getRect(find.text('Work')).left;
      final addOwn = tester.getRect(
        find.widgetWithText(OnboardingChoiceChip, 'Add your own'),
      );
      final work = tester.getRect(
        find.widgetWithText(OnboardingChoiceChip, 'Work'),
      );
      final fitness = tester.getRect(
        find.widgetWithText(OnboardingChoiceChip, 'Fitness'),
      );
      expect(grid, greaterThan(addOwn.left));
      expect(addOwn.left, work.left);
      expect(addOwn.right, fitness.right);
    },
  );

  testWidgets(
    'with no selection no chip shows a check and labels still render',
    (tester) async {
      await pumpView(tester, selected: const {});

      expect(find.byIcon(LottiIcons.confirm), findsNothing);
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

  testWidgets('option and add-own actions activate via keyboard', (
    tester,
  ) async {
    final toggled = <String>[];
    var added = 0;
    await pumpView(
      tester,
      selected: const {},
      onToggle: toggled.add,
      onAddOwn: () => added++,
    );

    final work = find.text('Work');
    final workFocus = Focus.of(tester.element(work))..requestFocus();
    await tester.pump();
    expect(workFocus.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(toggled, ['Work']);

    final addOwn = find.text('Add your own');
    final addFocus = Focus.of(tester.element(addOwn))..requestFocus();
    await tester.pump();
    expect(addFocus.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(added, 1);

    for (final finder in [work, addOwn]) {
      expect(
        tester
            .getSemantics(finder)
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
    }
  });

  testWidgets('large text collapses category choices to one readable column', (
    tester,
  ) async {
    for (final scale in [2.0, 3.2]) {
      await pumpView(
        tester,
        selected: const {},
        textScaler: TextScaler.linear(scale),
      );

      final workRect = tester.getRect(find.text('Work'));
      final fitnessRect = tester.getRect(find.text('Fitness'));
      expect(
        fitnessRect.top,
        greaterThan(workRect.bottom),
        reason: 'text scale $scale should use a single-column layout',
      );
      expect(tester.widget<Text>(find.text('Work')).overflow, isNull);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('tapping an option in the single-column layout reports the '
      'toggle', (tester) async {
    final toggled = <String>[];
    await pumpView(
      tester,
      selected: const {},
      textScaler: const TextScaler.linear(2),
      onToggle: toggled.add,
    );

    await tester.tap(find.text('Family'));
    await tester.pump();

    expect(toggled, ['Family']);
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

  testWidgets('without her the explanation is plain text under the title', (
    tester,
  ) async {
    await pumpView(tester, selected: const {});

    expect(find.byType(OnboardingSpeechBubble), findsNothing);
    expect(
      find.textContaining('keeps each area of your life'),
      findsOneWidget,
    );
  });

  testWidgets('with her the title and explanation are her bubble, under '
      'her on the stage', (tester) async {
    await pumpView(
      tester,
      selected: const {},
      companion: const ColoredBox(key: ValueKey('her'), color: Colors.red),
    );

    final her = find.byKey(const ValueKey('her'));
    final bubble = tester.widget<OnboardingSpeechBubble>(
      find.byType(OnboardingSpeechBubble),
    );
    expect(bubble.title, 'Where should your AI work?');
    expect(bubble.text, startsWith('Lotti keeps each area'));
    expect(
      tester.getBottomLeft(her).dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byType(OnboardingSpeechBubble)).dy,
      ),
    );
  });

  testWidgets('the caption names the chips, the close button leaves, and '
      'the progress is the one handed in', (tester) async {
    var left = 0;
    await tester.pumpWidget(
      makeTestableWidget(
        SizedBox(
          width: 390,
          child: OnboardingCategoryView(
            title: 'Where should your AI work?',
            explanation: 'Each area gets its own space.',
            caption: 'Your areas',
            whyLabel: 'Why areas?',
            continueLabel: 'Continue',
            addOwnLabel: 'Add your own',
            options: options,
            selected: const {},
            onToggle: (_) {},
            onWhy: () {},
            onAddOwn: () {},
            onContinue: () {},
            progress: const OnboardingProgress(done: 1, current: 0.5),
            onClose: () => left++,
          ),
        ),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 1400),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pump();

    // The caption sits over the first chip.
    expect(
      tester.getBottomLeft(find.text('Your areas')).dy,
      lessThan(tester.getTopLeft(find.text('Work')).dy),
    );
    expect(
      tester
          .widget<OnboardingProgressBar>(find.byType(OnboardingProgressBar))
          .progress,
      const OnboardingProgress(done: 1, current: 0.5),
    );
    await tester.tap(find.byIcon(LottiIcons.close));
    expect(left, 1);
  });
}
