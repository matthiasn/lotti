import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
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
    'destructive action renders as icon-only round button in the row '
    'layout and fires',
    (tester) async {
      var deleted = false;
      await pumpBar(
        tester,
        bar: SettingsFormActionBar(
          primaryLabel: 'Save',
          onPrimary: () {},
          destructiveLabel: 'Delete',
          onDestructive: () => deleted = true,
        ),
      );

      expect(find.byType(DsGlassRoundButton), findsOneWidget);
      // Icon-only: the label is semantic, not visible text.
      expect(find.text('Delete'), findsNothing);

      await tester.tap(find.byType(DsGlassRoundButton));
      expect(deleted, isTrue);
    },
  );

  testWidgets('disabled destructive button does not fire', (tester) async {
    var deleted = false;
    await pumpBar(
      tester,
      bar: SettingsFormActionBar(
        primaryLabel: 'Save',
        onPrimary: () {},
        destructiveLabel: 'Delete',
        onDestructive: () => deleted = true,
        destructiveEnabled: false,
      ),
    );

    await tester.tap(find.byType(DsGlassRoundButton));
    expect(deleted, isFalse);
  });

  testWidgets(
    'large accessibility text stacks all actions as labeled pills with '
    'the primary action last',
    (tester) async {
      await pumpBar(
        tester,
        textScale: 1.6,
        bar: SettingsFormActionBar(
          primaryLabel: 'Save',
          onPrimary: () {},
          secondaryLabel: 'Cancel',
          onSecondary: () {},
          destructiveLabel: 'Delete',
          onDestructive: () {},
        ),
      );

      // Stacked: destructive becomes a labeled pill, no round button.
      expect(find.byType(DsGlassRoundButton), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Primary lands closest to the thumb (greatest dy), destructive
      // farthest from it (smallest dy).
      final deleteY = tester.getTopLeft(find.text('Delete')).dy;
      final cancelY = tester.getTopLeft(find.text('Cancel')).dy;
      final saveY = tester.getTopLeft(find.text('Save')).dy;
      expect(deleteY, lessThan(cancelY));
      expect(cancelY, lessThan(saveY));
    },
  );

  testWidgets(
    'row layout keeps destructive at the start and primary at the end',
    (tester) async {
      await pumpBar(
        tester,
        bar: SettingsFormActionBar(
          primaryLabel: 'Save',
          onPrimary: () {},
          secondaryLabel: 'Cancel',
          onSecondary: () {},
          destructiveLabel: 'Delete',
          onDestructive: () {},
        ),
      );

      final deleteX = tester.getCenter(find.byType(DsGlassRoundButton)).dx;
      final cancelX = tester.getCenter(find.text('Cancel')).dx;
      final saveX = tester.getCenter(find.text('Save')).dx;
      expect(deleteX, lessThan(cancelX));
      expect(cancelX, lessThan(saveX));
    },
  );
}
