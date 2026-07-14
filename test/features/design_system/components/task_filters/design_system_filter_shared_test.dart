import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
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

  group('DesignSystemFilterChoicePill', () {
    Future<void> pumpPill(
      WidgetTester tester, {
      required bool selected,
      DesignSystemFilterChoiceRole role =
          DesignSystemFilterChoiceRole.multiSelect,
      VoidCallback? onTap,
      Widget? leading,
      String? semanticsLabel,
    }) {
      return tester.pumpWidget(
        makeTestableWidget(
          Center(
            child: DesignSystemFilterChoicePill(
              label: 'Priority',
              selected: selected,
              role: role,
              semanticsLabel: semanticsLabel,
              leading: leading,
              onTap: onTap,
            ),
          ),
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
  });
}
