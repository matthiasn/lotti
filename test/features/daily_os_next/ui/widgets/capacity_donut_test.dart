import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

    test('formatDecimalHours rounds to one decimal and drops trailing .0', () {
      expect(CapacityDonut.formatDecimalHours(480), '8h');
      expect(CapacityDonut.formatDecimalHours(315), '5.3h');
      expect(CapacityDonut.formatDecimalHours(276), '4.6h');
      expect(CapacityDonut.formatDecimalHours(0), '0h');
      expect(CapacityDonut.formatDecimalHours(30), '0.5h');
    });

    glados.Glados(
      glados.IntAnys(glados.any).intInRange(0, 24 * 60),
      glados.ExploreConfig(numRuns: 120),
    ).test('formatDecimalHours stays within 0.05h of the true duration', (
      minutes,
    ) {
      final label = CapacityDonut.formatDecimalHours(minutes);
      expect(label.endsWith('h'), isTrue, reason: label);
      final value = double.parse(label.substring(0, label.length - 1));
      expect(
        (value - minutes / 60).abs(),
        lessThanOrEqualTo(0.05 + 1e-9),
        reason: '"$label" drifts from $minutes minutes',
      );
    }, tags: 'glados');
  });

  group('CapacityDonut widget', () {
    testWidgets('renders center hours label and the capacity eyebrow', (
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

      expect(find.text('5.3h'), findsOneWidget);
      final messages = tester.element(find.byType(CapacityDonut)).messages;
      expect(
        find.text(messages.dailyOsNextAgendaCapacityOf('8h').toUpperCase()),
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
        final eyebrow = tester.widget<Text>(
          find.text(messages.dailyOsNextAgendaCapacityOf('8h').toUpperCase()),
        );
        expect(
          eyebrow.style?.color,
          tokens.colors.alert.error.defaultColor,
        );
      },
    );

    testWidgets('neutral mode keeps the teal reading even when over', (
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
      final eyebrow = tester.widget<Text>(
        find.text(messages.dailyOsNextAgendaCapacityOf('8h').toUpperCase()),
      );
      // Neutral mode never flips the eyebrow to the error tone.
      expect(eyebrow.style?.color, tokens.colors.text.lowEmphasis);
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

      final messages = tester.element(find.byType(CapacityDonut)).messages;
      final node = tester.getSemantics(find.byType(CapacityDonut));
      expect(
        node.label,
        contains(messages.dailyOsNextAgendaSummary('4h', '8h')),
      );
      expect(node.value, '50%');
    });
  });
}
