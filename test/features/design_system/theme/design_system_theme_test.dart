import 'package:flutter/material.dart';
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

    testWidgets('designTokens getter returns the active extension', (
      tester,
    ) async {
      late DsTokens resolvedTokens;

      await tester.pumpWidget(
        MaterialApp(
          theme: DesignSystemTheme.light(),
          home: Builder(
            builder: (context) {
              resolvedTokens = context.designTokens;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolvedTokens, dsTokensLight);
    });

    testWidgets('designTokens getter throws a StateError when missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              context.designTokens;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final exception = tester.takeException();
      expect(exception, isA<StateError>());
      expect(
        exception.toString(),
        contains('DsTokens extension is missing from the active theme.'),
      );
    });
  });
}
