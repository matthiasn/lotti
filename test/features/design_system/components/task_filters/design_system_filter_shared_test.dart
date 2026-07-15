import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('stripTrailingColon', () {
    test('removes only a trailing colon and preceding whitespace', () {
      expect(stripTrailingColon('Status:'), 'Status');
      expect(stripTrailingColon('Statut :'), 'Statut');
      expect(stripTrailingColon('Label\t:'), 'Label');
      expect(stripTrailingColon(':middle: colon'), ':middle: colon');
      expect(stripTrailingColon(''), '');
    });

    glados.Glados<String>(
      glados.any.letterOrDigits,
      glados.ExploreConfig(numRuns: 120),
    ).test('is idempotent', (value) {
      for (final candidate in [value, '$value:', '$value :']) {
        final once = stripTrailingColon(candidate);
        expect(stripTrailingColon(once), once);
      }
    }, tags: 'glados');
  });

  group('DesignSystemFilterToggleRow', () {
    testWidgets(
      'exposes one full-row toggle target and reports the next value',
      (
        tester,
      ) async {
        bool? changedValue;
        await tester.pumpWidget(
          makeTestableWidget(
            DesignSystemFilterToggleRow(
              label: 'Show due date',
              value: false,
              onChanged: (value) => changedValue = value,
            ),
          ),
        );

        final semantics = tester.getSemantics(
          find.byType(DesignSystemFilterToggleRow),
        );
        expect(semantics.label, 'Show due date');
        expect(semantics.flagsCollection.isButton, isTrue);
        expect(semantics.flagsCollection.isToggled, Tristate.isFalse);
        expect(find.byType(DesignSystemToggle), findsOneWidget);
        final ignoredToggleLayers = tester.widgetList<IgnorePointer>(
          find.ancestor(
            of: find.byType(DesignSystemToggle),
            matching: find.byType(IgnorePointer),
          ),
        );
        expect(ignoredToggleLayers.any((layer) => layer.ignoring), isTrue);
        expect(
          tester.getSize(find.byType(DesignSystemFilterToggleRow)).height,
          greaterThanOrEqualTo(dsTokensLight.spacing.step9),
        );

        await tester.tap(find.text('Show due date'));
        expect(changedValue, isTrue);
      },
    );
  });

  group('DesignSystemFilterChoicePill', () {
    Future<void> pumpPill(
      WidgetTester tester, {
      required bool selected,
      DesignSystemFilterChoiceRole role =
          DesignSystemFilterChoiceRole.multiSelect,
      VoidCallback? onTap,
      Widget? leading,
      String? semanticsLabel,
      String label = 'Priority',
      MediaQueryData? mediaQueryData,
      double? width,
    }) {
      return tester.pumpWidget(
        makeTestableWidget(
          Center(
            child: SizedBox(
              width: width,
              child: DesignSystemFilterChoicePill(
                label: label,
                selected: selected,
                role: role,
                semanticsLabel: semanticsLabel,
                leading: leading,
                onTap: onTap,
              ),
            ),
          ),
          mediaQueryData: mediaQueryData,
        ),
      );
    }

    BoxDecoration decoration(WidgetTester tester) {
      return tester
              .widget<Ink>(
                find.descendant(
                  of: find.byType(DesignSystemFilterChoicePill),
                  matching: find.byType(Ink),
                ),
              )
              .decoration!
          as BoxDecoration;
    }

    testWidgets('uses token surfaces and animates selection for 400 ms', (
      tester,
    ) async {
      await pumpPill(tester, selected: false, onTap: () {});
      expect(decoration(tester).color, Colors.transparent);
      expect(
        decoration(tester).border!.top.color,
        dsTokensLight.colors.decorative.level01,
      );

      await pumpPill(tester, selected: true, onTap: () {});
      await tester.pump(DesignSystemFilterChoicePill.animationDuration);

      expect(
        decoration(tester).color,
        dsTokensLight.colors.surface.selected,
      );
      expect(
        decoration(tester).border!.top.color,
        dsTokensLight.colors.interactive.enabled,
      );
      expect(
        DesignSystemFilterChoicePill.animationDuration,
        const Duration(milliseconds: 400),
      );
    });

    testWidgets('keeps a 48px target and forwards taps with leading content', (
      tester,
    ) async {
      var taps = 0;
      await pumpPill(
        tester,
        selected: false,
        onTap: () => taps++,
        leading: const Icon(Icons.flag_outlined),
      );

      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      expect(
        tester.getSize(find.byType(DesignSystemFilterChoicePill)).height,
        greaterThanOrEqualTo(dsTokensLight.spacing.step9),
      );
      await tester.tap(find.byType(DesignSystemFilterChoicePill));
      expect(taps, 1);
    });

    testWidgets('exposes the correct semantic role for every choice type', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      for (final role in DesignSystemFilterChoiceRole.values) {
        await pumpPill(
          tester,
          selected: true,
          role: role,
          semanticsLabel: 'Filter priority',
          onTap: () {},
        );

        final node = tester.getSemantics(
          find.byType(DesignSystemFilterChoicePill),
        );
        final flags = node.flagsCollection;
        expect(node.label, 'Filter priority');
        expect(flags.isButton, isTrue);
        expect(
          flags.isSelected,
          role == DesignSystemFilterChoiceRole.singleSelect
              ? Tristate.isTrue
              : Tristate.none,
        );
        expect(
          flags.isChecked,
          role == DesignSystemFilterChoiceRole.multiSelect
              ? CheckedState.isTrue
              : CheckedState.none,
        );
        expect(
          flags.isInMutuallyExclusiveGroup,
          role == DesignSystemFilterChoiceRole.singleSelect,
        );
      }

      semantics.dispose();
    });

    testWidgets('disabled choices expose disabled semantics and ignore taps', (
      tester,
    ) async {
      await pumpPill(tester, selected: false);

      final node = tester.getSemantics(
        find.byType(DesignSystemFilterChoicePill),
      );
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
      await tester.tap(find.byType(DesignSystemFilterChoicePill));
    });

    testWidgets('keyboard focus adds a ring without hiding selection', (
      tester,
    ) async {
      await pumpPill(tester, selected: true, onTap: () {});

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(decoration(tester).color, dsTokensLight.colors.surface.selected);
      expect(
        decoration(tester).border!.top.color,
        dsTokensLight.colors.interactive.enabled,
      );
      expect(
        decoration(tester).boxShadow!.single.color,
        dsTokensLight.colors.text.highEmphasis,
      );
      expect(
        decoration(tester).boxShadow!.single.spreadRadius,
        dsTokensLight.spacing.step1,
      );
    });

    testWidgets('large text can wrap to two lines and grow the target', (
      tester,
    ) async {
      const label = 'A longer filter choice';
      await pumpPill(
        tester,
        selected: false,
        onTap: () {},
        label: label,
        width: dsTokensLight.spacing.step13,
        mediaQueryData: const MediaQueryData(
          size: Size(320, 800),
          textScaler: TextScaler.linear(2),
        ),
      );

      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 2);
      expect(
        tester.getSize(find.byType(DesignSystemFilterChoicePill)).height,
        greaterThan(dsTokensLight.spacing.step9),
      );
    });
  });
}
