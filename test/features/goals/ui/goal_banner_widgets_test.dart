import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/ui/goal_banner_style.dart';
import 'package:lotti/features/goals/ui/goal_banner_widgets.dart';

import '../../../widget_test_utils.dart';

void main() {
  final tokens = resolveTestTheme().extension<DsTokens>()!;
  final style = goalBannerStyle(
    tone: GoalNudgeTone.nudge,
    accent: GoalBannerAccent.ember,
    colors: tokens.colors,
    brightness: Brightness.dark,
  );

  Size chipSize(WidgetTester tester) =>
      tester.getSize(find.byType(GoalBannerPersonaChip));

  testWidgets('the persona monogram is the goal title initial, uppercased', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalBannerPersonaChip(
          monogram: GoalBannerPersonaChip.monogramFor('expedition fitness'),
          style: style,
        ),
      ),
    );
    expect(find.text('E'), findsOneWidget);
  });

  testWidgets('the persona chip grows with the text scale so the monogram '
      'never outgrows its circle', (tester) async {
    Future<void> pumpAt(double scale) => tester.pumpWidget(
      makeTestableWidgetNoScroll(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Center(
            child: GoalBannerPersonaChip(monogram: 'E', style: style),
          ),
        ),
      ),
    );

    await pumpAt(1);
    final base = chipSize(tester);
    await pumpAt(3);
    final scaled = chipSize(tester);
    expect(
      scaled.width,
      greaterThan(base.width),
      reason: 'the circle must scale with the glyph at 3× text',
    );
  });

  testWidgets('the CTA pill renders its label and is tappable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalBannerCtaPill(
          label: 'Log a walk',
          style: style,
          onTap: () => tapped = true,
        ),
      ),
    );
    expect(find.text('Log a walk'), findsOneWidget);
    await tester.tap(find.text('Log a walk'));
    expect(tapped, isTrue);
  });
}
