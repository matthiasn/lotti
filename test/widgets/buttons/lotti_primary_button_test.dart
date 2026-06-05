import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';

import '../../widget_test_utils.dart';

Future<void> _pump(WidgetTester tester, Widget widget) =>
    tester.pumpWidget(makeTestableWidgetWithScaffold(widget));

void main() {
  group('LottiPrimaryButton', () {
    testWidgets('renders label and triggers onPressed', (tester) async {
      var pressCount = 0;
      await _pump(
        tester,
        LottiPrimaryButton(
          onPressed: () => pressCount++,
          label: 'Save',
        ),
      );

      expect(find.text('Save'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(pressCount, 1);
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      await _pump(
        tester,
        const LottiPrimaryButton(
          onPressed: null,
          label: 'Save',
        ),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.enabled, isFalse);
    });

    testWidgets('renders icon before label when icon is provided', (
      tester,
    ) async {
      await _pump(
        tester,
        LottiPrimaryButton(
          onPressed: () {},
          label: 'Add entry',
          icon: Icons.add,
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('Add entry'), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(Icons.add));
      expect(icon.size, 20);
    });

    testWidgets('uses primary colors by default and error colors when '
        'isDestructive', (tester) async {
      for (final destructive in [false, true]) {
        await _pump(
          tester,
          LottiPrimaryButton(
            onPressed: () {},
            label: 'Delete',
            isDestructive: destructive,
          ),
        );

        final context = tester.element(find.byType(FilledButton));
        final colorScheme = Theme.of(context).colorScheme;
        final button = tester.widget<FilledButton>(find.byType(FilledButton));

        expect(
          button.style?.backgroundColor?.resolve({}),
          destructive ? colorScheme.error : colorScheme.primary,
        );
        expect(
          button.style?.foregroundColor?.resolve({}),
          destructive ? colorScheme.onError : colorScheme.onPrimary,
        );
      }
    });

    testWidgets('custom style merges over the default style', (tester) async {
      await _pump(
        tester,
        LottiPrimaryButton(
          onPressed: () {},
          label: 'Styled',
          style: FilledButton.styleFrom(backgroundColor: Colors.teal),
        ),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      // Override wins...
      expect(button.style?.backgroundColor?.resolve({}), Colors.teal);
      // ...while unspecified properties keep the default (rounded shape).
      final shape = button.style?.shape?.resolve({}) as RoundedRectangleBorder?;
      expect(shape?.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('applies semanticsLabel to the label text', (tester) async {
      await _pump(
        tester,
        LottiPrimaryButton(
          onPressed: () {},
          label: 'OK',
          semanticsLabel: 'Confirm changes',
        ),
      );

      final text = tester.widget<Text>(find.text('OK'));
      expect(text.semanticsLabel, 'Confirm changes');
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, 1);
    });
  });
}
