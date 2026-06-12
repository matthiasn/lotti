import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/widgets/settings/settings_form_action_bar.dart';

import '../../test_helper.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required SettingsFormActionBar bar,
    double textScale = 1.0,
  }) {
    return tester.pumpWidget(
      WidgetTestBench(
        mediaQueryData: MediaQueryData(
          size: const Size(400, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: bar,
      ),
    );
  }

  testWidgets('renders on a glass strip and fires the primary action', (
    tester,
  ) async {
    var saved = false;
    await pumpBar(
      tester,
      bar: SettingsFormActionBar(
        primaryLabel: 'Save',
        onPrimary: () => saved = true,
      ),
    );

    expect(find.byType(DesignSystemGlassStrip), findsOneWidget);
    await tester.tap(find.text('Save'));
    expect(saved, isTrue);
  });

  testWidgets('disabled primary pill does not fire', (tester) async {
    var saved = false;
    await pumpBar(
      tester,
      bar: SettingsFormActionBar(
        primaryLabel: 'Save',
        onPrimary: () => saved = true,
        primaryEnabled: false,
      ),
    );

    await tester.tap(find.text('Save'));
    expect(saved, isFalse);
  });

  testWidgets('secondary pill fires its callback', (tester) async {
    var cancelled = false;
    await pumpBar(
      tester,
      bar: SettingsFormActionBar(
        primaryLabel: 'Save',
        onPrimary: () {},
        secondaryLabel: 'Cancel',
        onSecondary: () => cancelled = true,
      ),
    );

    await tester.tap(find.text('Cancel'));
    expect(cancelled, isTrue);
  });

  testWidgets(
    'large accessibility text stacks the pills with the primary first',
    (tester) async {
      await pumpBar(
        tester,
        textScale: 1.6,
        bar: SettingsFormActionBar(
          primaryLabel: 'Save',
          onPrimary: () {},
          secondaryLabel: 'Cancel',
          onSecondary: () {},
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Primary on top: a skimming thumb lands on Save, not on a
      // destructive-by-omission Cancel.
      final cancelY = tester.getTopLeft(find.text('Cancel')).dy;
      final saveY = tester.getTopLeft(find.text('Save')).dy;
      expect(saveY, lessThan(cancelY));
    },
  );

  testWidgets(
    'row layout renders pills at intrinsic width — long labels never '
    'get squeezed into ellipses by flex sharing',
    (tester) async {
      await pumpBar(
        tester,
        bar: SettingsFormActionBar(
          primaryLabel: 'Speichern',
          onPrimary: () {},
          secondaryLabel: 'Abbrechen',
          onSecondary: () {},
        ),
      );

      // Both full labels render (no "S…" truncation), end-aligned with
      // cancel before save.
      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.text('Speichern'), findsOneWidget);
      final cancelX = tester.getCenter(find.text('Abbrechen')).dx;
      final saveX = tester.getCenter(find.text('Speichern')).dx;
      expect(cancelX, lessThan(saveX));
    },
  );
}
