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
                'Lotti uses a different AI for each area of your life. Pick where Gemini should help.',
            continueLabel: 'Continue',
            addOwnLabel: 'Add your own',
            options: options,
            selected: selected,
            onToggle: onToggle ?? (_) {},
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
    expect(find.textContaining('different AI for each area'), findsOneWidget);
    for (final option in options) {
      expect(find.text(option.label), findsOneWidget);
    }
    expect(find.text('Add your own'), findsOneWidget);
  });

  testWidgets('selected options show a check; unselected show their icon', (
    tester,
  ) async {
    await pumpView(tester, selected: const {'Work'});

    // The selected chip swaps its category icon for a check.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    // Unselected options keep their own icons.
    expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
    expect(find.byIcon(Icons.work_outline_rounded), findsNothing);
  });

  testWidgets('tapping an option reports the toggle', (tester) async {
    String? toggled;
    await pumpView(
      tester,
      selected: const {},
      onToggle: (label) => toggled = label,
    );

    await tester.tap(find.text('Fitness'));
    expect(toggled, 'Fitness');
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
