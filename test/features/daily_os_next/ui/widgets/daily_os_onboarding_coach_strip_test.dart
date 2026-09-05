import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/daily_os_onboarding_coach_strip.dart';
import 'package:material_ui/material_ui.dart';

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

    testWidgets('renders as a static strip with no interactive affordance', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DailyOsOnboardingCoachStrip(message: 'Coaching line'),
        ),
      );

      expect(find.text('Coaching line'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });
  });
}
