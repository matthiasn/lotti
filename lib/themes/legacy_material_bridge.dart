import 'package:flutter/material.dart' as legacy;
import 'package:flutter_localizations/flutter_localizations.dart' as legacy;
import 'package:material_ui/material_ui.dart';

/// Carries unmigrated packages' extensions through the app's modern theme.
class LegacyMaterialExtensions
    extends ThemeExtension<LegacyMaterialExtensions> {
  const LegacyMaterialExtensions(this.values);

  final List<legacy.ThemeExtension<dynamic>> values;

  @override
  LegacyMaterialExtensions copyWith({
    List<legacy.ThemeExtension<dynamic>>? values,
  }) => LegacyMaterialExtensions(values ?? this.values);

  @override
  LegacyMaterialExtensions lerp(LegacyMaterialExtensions? other, double t) {
    if (other == null) return this;
    final targets = {for (final value in other.values) value.type: value};
    return LegacyMaterialExtensions([
      for (final value in values) value.lerp(targets.remove(value.type), t),
      ...targets.values,
    ]);
  }
}

/// Maps design state for dependencies whose public types still belong to Flutter.
///
/// The upstream compatibility bridge drops component themes and extensions.
/// Preserve the editor, Markdown and modal styling here until those packages
/// migrate. App widgets continue to read the surrounding Material UI theme.
legacy.ThemeData legacyMaterialTheme(ThemeData theme) {
  final scheme = theme.colorScheme;
  final text = theme.textTheme;
  return legacy.ThemeData(
    useMaterial3: theme.useMaterial3,
    platform: theme.platform,
    brightness: theme.brightness,
    scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
    canvasColor: theme.canvasColor,
    primaryColor: theme.primaryColor,
    dividerColor: theme.dividerColor,
    disabledColor: theme.disabledColor,
    visualDensity: legacy.VisualDensity(
      horizontal: theme.visualDensity.horizontal,
      vertical: theme.visualDensity.vertical,
    ),
    colorScheme: legacy.ColorScheme(
      brightness: scheme.brightness,
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      primaryContainer: scheme.primaryContainer,
      onPrimaryContainer: scheme.onPrimaryContainer,
      secondary: scheme.secondary,
      onSecondary: scheme.onSecondary,
      secondaryContainer: scheme.secondaryContainer,
      onSecondaryContainer: scheme.onSecondaryContainer,
      tertiary: scheme.tertiary,
      onTertiary: scheme.onTertiary,
      tertiaryContainer: scheme.tertiaryContainer,
      onTertiaryContainer: scheme.onTertiaryContainer,
      error: scheme.error,
      onError: scheme.onError,
      errorContainer: scheme.errorContainer,
      onErrorContainer: scheme.onErrorContainer,
      surface: scheme.surface,
      onSurface: scheme.onSurface,
      surfaceDim: scheme.surfaceDim,
      surfaceBright: scheme.surfaceBright,
      surfaceContainerLowest: scheme.surfaceContainerLowest,
      surfaceContainerLow: scheme.surfaceContainerLow,
      surfaceContainer: scheme.surfaceContainer,
      surfaceContainerHigh: scheme.surfaceContainerHigh,
      surfaceContainerHighest: scheme.surfaceContainerHighest,
      onSurfaceVariant: scheme.onSurfaceVariant,
      outline: scheme.outline,
      outlineVariant: scheme.outlineVariant,
      shadow: scheme.shadow,
      scrim: scheme.scrim,
      inverseSurface: scheme.inverseSurface,
      onInverseSurface: scheme.onInverseSurface,
      inversePrimary: scheme.inversePrimary,
      surfaceTint: scheme.surfaceTint,
    ),
    textTheme: legacy.TextTheme(
      displayLarge: text.displayLarge,
      displayMedium: text.displayMedium,
      displaySmall: text.displaySmall,
      headlineLarge: text.headlineLarge,
      headlineMedium: text.headlineMedium,
      headlineSmall: text.headlineSmall,
      titleLarge: text.titleLarge,
      titleMedium: text.titleMedium,
      titleSmall: text.titleSmall,
      bodyLarge: text.bodyLarge,
      bodyMedium: text.bodyMedium,
      bodySmall: text.bodySmall,
      labelLarge: text.labelLarge,
      labelMedium: text.labelMedium,
      labelSmall: text.labelSmall,
    ),
    elevatedButtonTheme: legacy.ElevatedButtonThemeData(
      style: _legacyButtonStyle(theme.elevatedButtonTheme.style),
    ),
    extensions: theme.extension<LegacyMaterialExtensions>()?.values,
  );
}

legacy.ButtonStyle? _legacyButtonStyle(ButtonStyle? style) => style == null
    ? null
    : legacy.ButtonStyle(
        textStyle: style.textStyle,
        backgroundColor: style.backgroundColor,
        foregroundColor: style.foregroundColor,
        overlayColor: style.overlayColor,
        shadowColor: style.shadowColor,
        surfaceTintColor: style.surfaceTintColor,
        elevation: style.elevation,
        padding: style.padding,
        minimumSize: style.minimumSize,
        fixedSize: style.fixedSize,
        maximumSize: style.maximumSize,
        iconColor: style.iconColor,
        iconSize: style.iconSize,
        side: style.side,
        shape: style.shape,
        mouseCursor: style.mouseCursor,
        animationDuration: style.animationDuration,
        enableFeedback: style.enableFeedback,
        alignment: style.alignment,
        visualDensity: style.visualDensity == null
            ? null
            : legacy.VisualDensity(
                horizontal: style.visualDensity!.horizontal,
                vertical: style.visualDensity!.vertical,
              ),
        tapTargetSize: style.tapTargetSize == null
            ? null
            : legacy.MaterialTapTargetSize.values[style.tapTargetSize!.index],
      );

/// Supplies legacy dependencies with the active theme and localization delegates.
class LegacyMaterialBridge extends StatelessWidget {
  const LegacyMaterialBridge({required this.child, super.key});

  final Widget child;

  /// Hosts modern controls and toasts above a legacy Wolt route's scaffold.
  ///
  /// Wolt owns keyboard avoidance; applying it here too would double the inset.
  static Widget modalSurface(Widget child) => Scaffold(
    backgroundColor: Colors.transparent,
    resizeToAvoidBottomInset: false,
    body: child,
  );

  /// Keeps caller-provided modal decoration inside the modern scaffold.
  static Widget Function(Widget) wrapModalDecorator(
    Widget Function(Widget)? decorate,
  ) =>
      (child) => modalSurface(decorate?.call(child) ?? child);

  /// Shared MaterialApp builder for production and test entry points.
  static Widget builder(BuildContext context, Widget? child) =>
      LegacyMaterialBridge(child: child ?? const SizedBox.shrink());

  /// Retains an entry point's builder while bridging its complete subtree.
  static TransitionBuilder wrapBuilder(TransitionBuilder? build) =>
      (context, child) => LegacyMaterialBridge(
        child: build?.call(context, child) ?? child ?? const SizedBox.shrink(),
      );

  @override
  Widget build(BuildContext context) => legacy.Theme(
    data: legacyMaterialTheme(Theme.of(context)),
    child: Localizations.override(
      context: context,
      delegates: legacy.GlobalMaterialLocalizations.delegates,
      child: child,
    ),
  );
}
