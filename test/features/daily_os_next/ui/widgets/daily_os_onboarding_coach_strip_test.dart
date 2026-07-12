import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/daily_os_onboarding_coach_strip.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DailyOsOnboardingCoachStrip', () {
    testWidgets('renders the injected message', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DailyOsOnboardingCoachStrip(
            message: 'Say what is pulling at your attention.',
          ),
        ),
      );

      expect(
        find.text('Say what is pulling at your attention.'),
        findsOneWidget,
      );
    });

    testWidgets('shows no hide affordance when onHide is null', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DailyOsOnboardingCoachStrip(message: 'Coaching line'),
        ),
      );

      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('renders the hide affordance and invokes onHide on tap', (
      tester,
    ) async {
      var hidden = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DailyOsOnboardingCoachStrip(
            message: 'Coaching line',
            hideLabel: 'Hide tips',
            onHide: () => hidden++,
          ),
        ),
      );

      expect(find.widgetWithText(TextButton, 'Hide tips'), findsOneWidget);
      await tester.tap(find.text('Hide tips'));
      await tester.pump();

      expect(hidden, 1);
    });

    test('asserts hideLabel is provided when onHide is set', () {
      expect(
        () => DailyOsOnboardingCoachStrip(message: 'x', onHide: () {}),
        throwsAssertionError,
      );
    });
  });
}
