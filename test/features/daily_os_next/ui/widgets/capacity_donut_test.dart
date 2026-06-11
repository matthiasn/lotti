import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/capacity_donut.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child) => makeTestableWidget2(
  Center(child: child),
  mediaQueryData: const MediaQueryData(size: Size(800, 800)),
);

void main() {
  group('CapacityDonut statics', () {
    test('ratioFor divides scheduled by capacity and guards zero capacity', () {
      expect(CapacityDonut.ratioFor(240, 480), 0.5);
      expect(CapacityDonut.ratioFor(540, 480), closeTo(1.125, 1e-9));
      expect(CapacityDonut.ratioFor(60, 0), 0);
      expect(CapacityDonut.ratioFor(60, -10), 0);
    });
  });

  group('CapacityDonut widget', () {
    testWidgets('renders the remaining capacity over a LEFT eyebrow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CapacityDonut(
            scheduledMinutes: 315,
            capacityMinutes: 480,
          ),
        ),
      );

      // 480 - 315 = 165m remaining; the headline summary already shows
      // the scheduled/capacity pair, so the center answers "what's left".
      expect(find.text('2h 45m'), findsOneWidget);
      final messages = tester.element(find.byType(CapacityDonut)).messages;
      expect(
        find.text(messages.dailyOsNextAgendaDonutLeft.toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets(
      'over-capacity day flips the eyebrow color to the error tone',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CapacityDonut(
              scheduledMinutes: 540,
              capacityMinutes: 480,
            ),
          ),
        );

        final context = tester.element(find.byType(CapacityDonut));
        final messages = context.messages;
        final tokens = context.designTokens;
        // 540 of 480 → 60m over, narrated by the OVER eyebrow in the
        // error tone.
        expect(find.text('1h'), findsOneWidget);
        final eyebrow = tester.widget<Text>(
          find.text(messages.dailyOsNextAgendaDonutOver.toUpperCase()),
        );
        expect(
          eyebrow.style?.color,
          tokens.colors.alert.error.defaultColor,
        );
      },
    );

    testWidgets(
      'neutral mode stays honest about OVER but keeps the calm tone',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            const CapacityDonut(
              scheduledMinutes: 540,
              capacityMinutes: 480,
              neutral: true,
            ),
          ),
        );

        final context = tester.element(find.byType(CapacityDonut));
        final messages = context.messages;
        final tokens = context.designTokens;
        // The WORD is always honest — 60m over is OVER even in neutral mode
        // (a "1h LEFT" reading here would be a lie). Neutral only keeps the
        // calm color instead of the error tone.
        expect(find.text('1h'), findsOneWidget);
        final eyebrow = tester.widget<Text>(
          find.text(messages.dailyOsNextAgendaDonutOver.toUpperCase()),
        );
        expect(eyebrow.style?.color, tokens.colors.text.lowEmphasis);
      },
    );

    testWidgets('without a capacity the center shows the scheduled total '
        'and no eyebrow word', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CapacityDonut(
            scheduledMinutes: 135,
            capacityMinutes: 0,
            neutral: true,
          ),
        ),
      );

      final messages = tester.element(find.byType(CapacityDonut)).messages;
      // No capacity → no remainder to narrate; LEFT/OVER would both be
      // meaningless, so the ring just reports what is scheduled.
      expect(find.text('2h 15m'), findsOneWidget);
      expect(
        find.text(messages.dailyOsNextAgendaDonutLeft.toUpperCase()),
        findsNothing,
      );
      expect(
        find.text(messages.dailyOsNextAgendaDonutOver.toUpperCase()),
        findsNothing,
      );
    });

    testWidgets('semantics expose the scheduled/capacity summary and percent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CapacityDonut(
            scheduledMinutes: 240,
            capacityMinutes: 480,
          ),
        ),
      );

      final semanticsHandle = tester.ensureSemantics();
      final messages = tester.element(find.byType(CapacityDonut)).messages;
      final node = tester.getSemantics(find.byType(CapacityDonut));
      expect(
        node.label,
        contains(messages.dailyOsNextAgendaSummary('4h', '8h')),
      );
      expect(node.value, '50%');
      semanticsHandle.dispose();
    });
  });
}
