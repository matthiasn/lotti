import 'package:flutter/material.dart' as legacy;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:lotti/themes/theme_overrides.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

void main() {
  testWidgets('legacy consumers follow the active theme and locale', (
    tester,
  ) async {
    for (final theme in [
      withOverrides(DesignSystemTheme.light()),
      withOverrides(DesignSystemTheme.dark()),
    ]) {
      late BuildContext consumer;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          locale: const Locale('de'),
          supportedLocales: const [Locale('de')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: LegacyMaterialBridge.builder,
          home: Builder(
            builder: (context) {
              consumer = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
      final oldTheme = legacy.Theme.of(consumer);
      expect(oldTheme.brightness, theme.brightness);
      expect(oldTheme.colorScheme.primary, theme.colorScheme.primary);
      expect(
        oldTheme.colorScheme.surfaceContainer,
        theme.colorScheme.surfaceContainer,
      );
      expect(
        oldTheme.textTheme.bodyMedium?.fontFamily,
        theme.textTheme.bodyMedium?.fontFamily,
      );
      expect(
        oldTheme.textTheme.bodyMedium?.fontSize,
        theme.textTheme.bodyMedium?.fontSize,
      );
      expect(
        oldTheme.textTheme.bodyMedium?.color,
        theme.textTheme.bodyMedium?.color,
      );
      expect(
        oldTheme.extension<WoltModalSheetThemeData>()?.surfaceTintColor,
        Colors.transparent,
      );
      expect(
        Theme.of(consumer).extension<DsTokens>(),
        theme.extension<DsTokens>(),
      );
      expect(
        legacy.MaterialLocalizations.of(consumer).cancelButtonLabel,
        MaterialLocalizations.of(consumer).cancelButtonLabel,
      );
      expect(
        legacy.MaterialLocalizations.of(consumer).cancelButtonLabel,
        'Abbrechen',
      );
    }
  });

  test(
    'legacy extensions interpolate instead of disappearing during theme changes',
    () {
      const a = LegacyMaterialExtensions([
        WoltModalSheetThemeData(surfaceTintColor: Colors.black),
      ]);
      const b = LegacyMaterialExtensions([
        WoltModalSheetThemeData(surfaceTintColor: Colors.white),
      ]);
      final mixed = a.lerp(b, 0.5);
      expect(
        (mixed.values.single as WoltModalSheetThemeData).surfaceTintColor,
        Color.lerp(Colors.black, Colors.white, 0.5),
      );
      expect(a.lerp(null, 0.5), same(a));
      expect(a.copyWith().values, same(a.values));
      expect(a.copyWith(values: b.values).values, same(b.values));
    },
  );
}
