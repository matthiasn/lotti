import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_palette.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('TaskShowcasePalette', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        'maps every palette entry to its design token ($brightness)',
        (tester) async {
          await tester.pumpWidget(
            makeTestableWidget2(
              Theme(
                data: brightness == Brightness.dark
                    ? DesignSystemTheme.dark()
                    : DesignSystemTheme.light(),
                child: const Scaffold(body: SizedBox.shrink()),
              ),
            ),
          );

          final context = tester.element(find.byType(SizedBox));
          final tokens = context.designTokens;

          // Pins the palette → token mapping so a silently re-pointed
          // entry (e.g. page → level02) fails loudly in both themes.
          expect(
            TaskShowcasePalette.page(context),
            tokens.colors.background.level01,
          );
          expect(
            TaskShowcasePalette.surface(context),
            tokens.colors.background.level02,
          );
          expect(
            TaskShowcasePalette.border(context),
            tokens.colors.decorative.level01,
          );
          expect(
            TaskShowcasePalette.highText(context),
            tokens.colors.text.highEmphasis,
          );
          expect(
            TaskShowcasePalette.mediumText(context),
            tokens.colors.text.mediumEmphasis,
          );
          expect(
            TaskShowcasePalette.lowText(context),
            tokens.colors.text.lowEmphasis,
          );
          expect(
            TaskShowcasePalette.selectedRow(context),
            DesignSystemListPalette.activatedFill(tokens),
          );
          expect(
            TaskShowcasePalette.hoverFill(context),
            tokens.colors.surface.hover,
          );
          expect(
            TaskShowcasePalette.subtleFill(context),
            tokens.colors.surface.enabled,
          );
          expect(
            TaskShowcasePalette.accent(context),
            tokens.colors.interactive.enabled,
          );
          expect(
            TaskShowcasePalette.success(context),
            tokens.colors.alert.success.defaultColor,
          );
          expect(
            TaskShowcasePalette.warning(context),
            tokens.colors.alert.warning.defaultColor,
          );
          expect(
            TaskShowcasePalette.error(context),
            tokens.colors.alert.error.defaultColor,
          );
          expect(
            TaskShowcasePalette.info(context),
            tokens.colors.alert.info.defaultColor,
          );
        },
      );
    }

    testWidgets('light and dark themes resolve to different page colors', (
      tester,
    ) async {
      final resolved = <Brightness, Color>{};
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          makeTestableWidget2(
            Theme(
              data: brightness == Brightness.dark
                  ? DesignSystemTheme.dark()
                  : DesignSystemTheme.light(),
              child: const Scaffold(body: SizedBox.shrink()),
            ),
          ),
        );
        resolved[brightness] = TaskShowcasePalette.page(
          tester.element(find.byType(SizedBox)),
        );
      }

      // Guards against both themes accidentally sharing one token set.
      expect(resolved[Brightness.light], isNot(resolved[Brightness.dark]));
    });
  });
}
