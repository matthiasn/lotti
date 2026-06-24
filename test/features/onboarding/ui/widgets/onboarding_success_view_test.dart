import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_success_view.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const accent = Color(0xFF00C2A8);

  Future<void> pumpView(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        SizedBox(
          width: 390,
          child: OnboardingSuccessView(
            accent: accent,
            title: "You're all set",
            subtitle:
                'Your AI brain is connected and ready to turn your words into tasks.',
            continueLabel: 'Get started',
            onContinue: () {},
          ),
        ),
        mediaQueryData: MediaQueryData(
          size: const Size(390, 844),
          disableAnimations: reduceMotion,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the checkmark, copy and CTA', (tester) async {
    await pumpView(tester, reduceMotion: true);

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text("You're all set"), findsOneWidget);
    expect(find.textContaining('turn your words into tasks'), findsOneWidget);
    expect(
      find.widgetWithText(DesignSystemButton, 'Get started'),
      findsOneWidget,
    );
  });

  testWidgets('the CTA invokes onContinue', (tester) async {
    var continues = 0;
    await tester.pumpWidget(
      makeTestableWidget(
        SizedBox(
          width: 390,
          child: OnboardingSuccessView(
            accent: accent,
            title: "You're all set",
            subtitle: 'Ready.',
            continueLabel: 'Get started',
            onContinue: () => continues++,
          ),
        ),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(DesignSystemButton, 'Get started'));
    expect(continues, 1);
  });

  testWidgets('animates the checkmark in without error', (tester) async {
    await pumpView(tester);

    // The backdrop loops, so step fixed frames rather than settling; the
    // one-shot checkmark reveal (~500ms) runs over these.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
    }
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text("You're all set"), findsOneWidget);
  });

  testWidgets('disposes cleanly when removed', (tester) async {
    await pumpView(tester);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.pumpWidget(makeTestableWidget(const SizedBox()));
    await tester.pump();

    expect(find.byType(OnboardingSuccessView), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
