import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child) => makeTestableWidget2(
  Scaffold(body: Center(child: child)),
  mediaQueryData: const MediaQueryData(size: Size(800, 600)),
);

void main() {
  group('PlanViewToggle', () {
    testWidgets('renders both Agenda + Day labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlanViewToggle(
            selected: PlanView.agenda,
            onChanged: (_) {},
          ),
        ),
      );

      final messages = tester.element(find.byType(PlanViewToggle)).messages;
      expect(find.text(messages.dailyOsNextPlanViewAgenda), findsOneWidget);
      expect(find.text(messages.dailyOsNextPlanViewDay), findsOneWidget);
    });

    testWidgets('selected Agenda chip uses teal fg + bold weight', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlanViewToggle(
            selected: PlanView.agenda,
            onChanged: (_) {},
          ),
        ),
      );

      final ctx = tester.element(find.byType(PlanViewToggle));
      final tokens = ctx.designTokens;
      final teal = tokens.colors.interactive.enabled;
      final agendaText = tester.widget<Text>(
        find.text(ctx.messages.dailyOsNextPlanViewAgenda),
      );
      final dayText = tester.widget<Text>(
        find.text(ctx.messages.dailyOsNextPlanViewDay),
      );

      expect(agendaText.style?.color, teal);
      expect(agendaText.style?.fontWeight, FontWeight.w600);
      expect(dayText.style?.color, isNot(teal));
      expect(dayText.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('selected Day chip swaps the highlight to the Day side', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PlanViewToggle(
            selected: PlanView.day,
            onChanged: (_) {},
          ),
        ),
      );

      final ctx = tester.element(find.byType(PlanViewToggle));
      final tokens = ctx.designTokens;
      final teal = tokens.colors.interactive.enabled;
      final agendaText = tester.widget<Text>(
        find.text(ctx.messages.dailyOsNextPlanViewAgenda),
      );
      final dayText = tester.widget<Text>(
        find.text(ctx.messages.dailyOsNextPlanViewDay),
      );

      expect(dayText.style?.color, teal);
      expect(dayText.style?.fontWeight, FontWeight.w600);
      expect(agendaText.style?.color, isNot(teal));
      expect(agendaText.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('tapping Day chip fires onChanged(PlanView.day)', (
      tester,
    ) async {
      PlanView? received;
      await tester.pumpWidget(
        _wrap(
          PlanViewToggle(
            selected: PlanView.agenda,
            onChanged: (v) => received = v,
          ),
        ),
      );

      final messages = tester.element(find.byType(PlanViewToggle)).messages;
      await tester.tap(find.text(messages.dailyOsNextPlanViewDay));
      await tester.pump();

      expect(received, PlanView.day);
    });

    testWidgets('tapping Agenda chip fires onChanged(PlanView.agenda)', (
      tester,
    ) async {
      PlanView? received;
      await tester.pumpWidget(
        _wrap(
          PlanViewToggle(
            selected: PlanView.day,
            onChanged: (v) => received = v,
          ),
        ),
      );

      final messages = tester.element(find.byType(PlanViewToggle)).messages;
      await tester.tap(find.text(messages.dailyOsNextPlanViewAgenda));
      await tester.pump();

      expect(received, PlanView.agenda);
    });

    testWidgets(
      'tapping the already-selected chip still fires onChanged',
      (tester) async {
        var count = 0;
        await tester.pumpWidget(
          _wrap(
            PlanViewToggle(
              selected: PlanView.agenda,
              onChanged: (_) => count++,
            ),
          ),
        );

        final messages = tester.element(find.byType(PlanViewToggle)).messages;
        await tester.tap(find.text(messages.dailyOsNextPlanViewAgenda));
        await tester.pump();

        expect(count, 1);
      },
    );
  });
}
