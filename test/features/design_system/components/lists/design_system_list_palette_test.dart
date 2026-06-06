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
  });
}
