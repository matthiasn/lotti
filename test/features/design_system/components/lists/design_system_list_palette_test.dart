import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_palette.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

void main() {
  group('DesignSystemListPalette', () {
    test('activatedFillAlpha pins the documented 12% selection hint', () {
      expect(DesignSystemListPalette.activatedFillAlpha, 0.12);
    });

    test(
      'activatedFill is the interactive-enabled color at the shared alpha '
      'in both token sets',
      () {
        for (final tokens in const [dsTokensLight, dsTokensDark]) {
          final fill = DesignSystemListPalette.activatedFill(tokens);
          final source = tokens.colors.interactive.enabled;

          expect(
            fill,
            source.withValues(
              alpha: DesignSystemListPalette.activatedFillAlpha,
            ),
          );
          // Same hue as the source token, only the alpha differs.
          expect(fill.withValues(alpha: source.a), source);
        }
      },
    );

    test(
      'a pickable row climbs one primary ladder: hover under the selected '
      'band, pressed over it, in both token sets',
      () {
        for (final tokens in const [dsTokensLight, dsTokensDark]) {
          final primary = tokens.colors.interactive.enabled;
          final hover = DesignSystemListPalette.hoverFill(tokens);
          final selected = tokens.colors.surface.selected;
          final pressed = DesignSystemListPalette.pressedFill(tokens);

          for (final fill in [hover, selected, pressed]) {
            expect(fill.withValues(alpha: primary.a), primary);
          }
          expect(hover.a, lessThan(selected.a));
          expect(selected.a, lessThan(pressed.a));
        }
      },
    );
  });
}
