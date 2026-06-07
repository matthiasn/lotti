import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/animation/ai_state_shader_animation.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_planning_thinking_shader.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DayPlanningThinkingShader', () {
    testWidgets('renders nothing while not thinking', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DayPlanningThinkingShader(isThinking: false),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(
        find.byKey(DayPlanningThinkingShader.indicatorKey),
        findsNothing,
      );
      expect(find.byType(AiThinkingLineShader), findsNothing);
    });

    testWidgets('fades the shader in once thinking starts', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DayPlanningThinkingShader(isThinking: true),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Seeded fully shown at mount (no entry animation), so the shader is
      // present immediately.
      expect(
        find.byKey(DayPlanningThinkingShader.indicatorKey),
        findsOneWidget,
      );
      final shader = tester.widget<AiThinkingLineShader>(
        find.byType(AiThinkingLineShader),
      );
      expect(shader.route, AiThinkingShaderRoute.decoderBars);
      expect(shader.opacity, 1);
    });

    testWidgets('fades the shader in over the transition when thinking '
        'starts after mount', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DayPlanningThinkingShader(isThinking: false),
          theme: DesignSystemTheme.light(),
        ),
      );
      expect(find.byKey(DayPlanningThinkingShader.indicatorKey), findsNothing);

      // Flip to thinking — the presence envelope animates in rather than
      // seeding fully shown (which only happens when mounted already true).
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DayPlanningThinkingShader(isThinking: true),
          theme: DesignSystemTheme.light(),
        ),
      );
      await tester.pump(); // kick the controller forward
      await tester.pump(AiRunningDecoderBars.transitionDuration ~/ 2);
      // Part-way through entry: present but not yet at full opacity.
      expect(
        find.byKey(DayPlanningThinkingShader.indicatorKey),
        findsOneWidget,
      );
      final midShader = tester.widget<AiThinkingLineShader>(
        find.byType(AiThinkingLineShader),
      );
      expect(midShader.opacity, greaterThan(0));
      expect(midShader.opacity, lessThan(1));

      // After the full transition it settles fully shown.
      await tester.pump(AiRunningDecoderBars.transitionDuration);
      expect(
        tester
            .widget<AiThinkingLineShader>(find.byType(AiThinkingLineShader))
            .opacity,
        1,
      );
    });

    testWidgets('reverses out and collapses when thinking stops', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DayPlanningThinkingShader(isThinking: true),
          theme: DesignSystemTheme.light(),
        ),
      );
      expect(
        find.byKey(DayPlanningThinkingShader.indicatorKey),
        findsOneWidget,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DayPlanningThinkingShader(isThinking: false),
          theme: DesignSystemTheme.light(),
        ),
      );
      // Let the exit transition complete.
      await tester.pump(AiRunningDecoderBars.transitionDuration);
      await tester.pump(AiRunningDecoderBars.transitionDuration);

      expect(
        find.byKey(DayPlanningThinkingShader.indicatorKey),
        findsNothing,
      );
      expect(find.byType(AiThinkingLineShader), findsNothing);
    });
  });
}
