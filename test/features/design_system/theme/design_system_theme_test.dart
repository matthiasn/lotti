import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

void main() {
  group('DesignSystemTheme', () {
    test('light theme attaches the light token extension', () {
      final theme = DesignSystemTheme.light();

      expect(theme.extension<DsTokens>(), dsTokensLight);
      expect(
        theme.colorScheme.primary,
        dsTokensLight.colors.interactive.enabled,
      );
      expect(
        theme.colorScheme.surface,
        dsTokensLight.colors.background.level01,
      );
      expect(
        theme.textTheme.labelLarge?.fontSize,
        dsTokensLight.typography.styles.subtitle.subtitle2.fontSize,
      );
    });

    test('dark theme attaches the dark token extension', () {
      final theme = DesignSystemTheme.dark();

      expect(theme.extension<DsTokens>(), dsTokensDark);
      expect(
        theme.colorScheme.primary,
        dsTokensDark.colors.interactive.enabled,
      );
      expect(theme.colorScheme.surface, dsTokensDark.colors.background.level01);
      expect(
        theme.textTheme.labelLarge?.fontSize,
        dsTokensDark.typography.styles.subtitle.subtitle2.fontSize,
      );
    });
  });
}
