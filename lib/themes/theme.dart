import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/themes/colors.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

const fontSizeSmall = 11.0;
const fontSizeMedium = 15.0;
const fontSizeMediumLarge = 20.0;
const fontSizeLarge = 25.0;

class AppTheme {
  // Modern card layout constants
  static const double cardBorderRadius = 20; // Increased for more modern look
  static const double cardPadding = 16; // Increased padding
  static const double cardPaddingCompact = 14;
  static const double cardElevationLight = 8; // Enhanced shadows
  static const double cardElevationDark = 12;
  static const double cardSpacing = 10; // Increased spacing between cards

  // Icon container constants
  static const double iconContainerSize = 44; // Slightly larger
  static const double iconContainerSizeCompact = 40;
  static const double iconContainerBorderRadius = 14; // More rounded
  static const double iconSize = 22; // Slightly larger icons
  static const double iconSizeCompact = 20;

  // Spacing constants
  static const double spacingXSmall = 4;
  static const double spacingSmall = 8;
  static const double spacingMedium = 12; // Increased
  static const double spacingLarge = 16; // Increased

  // Chevron icon size
  static const double chevronSize = 22; // Slightly larger
  static const double chevronSizeCompact = 20;

  // Typography constants - Modern typography scale
  static const double titleFontSize = 18; // Increased
  static const double titleFontSizeCompact = 17;
  static const double subtitleFontSize = 13; // Increased
  static const double subtitleFontSizeCompact = 12;
  static const double letterSpacingTitle = 0.15; // Increased letter spacing
  static const double letterSpacingSubtitle = 0.05;
  static const double lineHeightSubtitle = 1.5; // Better line height

  // Enhanced alpha values for colors
  static const double alphaOutline = 0.25; // Reduced for subtlety
  static const double alphaPrimaryContainer = 0.12; // More subtle
  static const double alphaShadowLight = 0.12; // Enhanced shadows
  static const double alphaShadowDark = 0.25;
  static const double alphaPrimary = 0.08; // More subtle
  static const double alphaPrimaryHighlight = 0.04;
  static const double alphaPrimaryBorder = 0.12;
  static const double alphaPrimaryIcon = 0.95; // More vibrant
  static const double alphaSurfaceVariant = 0.85; // Better contrast
  static const double alphaSurfaceVariantChevron = 0.7;
  static const double alphaDestructive = 0.25;

  // Animation constants - Smoother animations
  static const int animationDuration = 300; // Slightly longer
  static const Curve animationCurve =
      Curves.easeOutQuart; // More sophisticated curve

  // Spacing between elements
  static const double spacingBetweenTitleAndSubtitle = 6; // Increased
  static const double spacingBetweenTitleAndSubtitleCompact = 4;
  static const double spacingBetweenElements = 8; // Increased

  // Enhanced shadow offset
  static const Offset shadowOffset = Offset(0, 3); // More pronounced

  // Status indicator constants
  static const double statusIndicatorPaddingHorizontal = 8; // Increased
  static const double statusIndicatorPaddingVertical = 3; // Increased
  static const double statusIndicatorBorderRadius = 8; // More rounded
  static const double statusIndicatorBorderRadiusSmall = 6;
  static const double statusIndicatorBorderRadiusTiny = 5;
  static const double statusIndicatorBorderWidth = 0.8; // Slightly thicker
  static const double statusIndicatorSize = 26; // Slightly larger
  static const double statusIndicatorSizeCompact = 22;
  static const double statusIndicatorIconSize = 16; // Larger icons
  static const double statusIndicatorIconSizeCompact = 14;

  // Status indicator alpha values
  static const double alphaPrimaryContainerLight = 0.3; // Enhanced
  static const double alphaPrimaryContainerDark = 0.2;
  static const double alphaStatusIndicatorBorder = 0.15;
  static const double alphaSurfaceContainerHighest = 0.35;
  static const double alphaSurfaceVariantDim = 0.6;
  static const double alphaErrorContainer = 0.6;
  static const double alphaErrorText = 0.9;
  static const double alphaPrimaryContainerActive = 0.8;

  // Font sizes for status indicators
  static const double statusIndicatorFontSize = 12; // Increased
  static const double statusIndicatorFontSizeCompact = 11;
  static const double statusIndicatorFontSizeTiny = 10;

  // Modal item spacer widths
  static const double modalIconSpacerWidth = iconContainerSize;
  static const double modalChevronSpacerWidth = spacingLarge;
  static const double errorModalMargin = 16;
  static const double errorModalPadding = 20;
  static const double errorModalBorderRadius = 16;
  static const double errorModalIconPadding = 12;
  static const double errorModalIconBorderRadius = 12;
  static const double errorModalIconSize = 32;
  static const double errorModalSpacingLarge = 16;
  static const double errorModalSpacingSmall = 8;
  static const double errorModalSuggestionPadding = 12;
  static const double errorModalSuggestionBorderRadius = 8;
  static const double errorModalSuggestionSpacing = 4;
  static const double errorModalSpacingButton = 20;
  static const double errorModalSpacingButtonSecondary = 12;
}

// Gradient and shadow constants
class GradientConstants {
  // Color blending factors for gradients
  static const double darkCardBlendFactor = 0.3;
  static const double darkCardEndBlendFactor = 0.5;

  // Shadow alpha values for enhanced cards
  static const double enhancedShadowLightAlpha = 0.15;
  static const double enhancedShadowSecondaryLightAlpha = 0.1;
  static const double enhancedShadowSecondaryDarkAlpha = 0.2;

  // Shadow blur and spread values
  static const double enhancedShadowBlurLight = 15;
  static const double enhancedShadowSecondaryBlurLight = 30;
  static const double enhancedShadowSecondaryBlurDark = 40;
  static const double enhancedShadowSecondarySpread = 4;
  static const double enhancedShadowOffsetY = 8;
  static const double enhancedShadowSecondaryOffsetY = 16;
}

// Input and form styling constants
class InputConstants {
  // Border radius values
  static const double inputBorderRadius = 12;

  // Border width values
  static const double focusedBorderWidth = 2.5;

  // Alpha values for borders and fills
  static const int inputBorderAlpha = 80;
}

// Spacing and layout constants
class SpacingConstants {
  // Modal spacing
  static const double verticalModalSpacerHeight = 32;
  static const double inputSpacerHeight = 28;
  static const double inputSpacerSmallHeight = 18;
  static const double enhancedSmallFontSize = 26;
}

// Typography constants
class TypographyConstants {
  // Font weight adjustments
  static const FontWeight bodyFontWeight = FontWeight.w400;
  static const FontWeight lightFontWeight = FontWeight.w200;
}

// Modal-specific constants
class ModalTheme {
  static const double padding = 32;
  static const double iconPadding = 16;
  static const double iconSize = 48;
  static const double spacing24 = 24;
  static const double spacing40 = 40;
  static const double buttonHeight = 56;
  static const double fontSize = 16;
  static const double letterSpacing = 0.5;
  static const double letterSpacingBold = 0.8;
  static const double buttonBorderWidth = 1.5;
  static const double iconBorderRadiusExtra = 4;
  static const double headlineLetterSpacing = -0.2;
  static const double headlineLineHeight = 1.3;
}

const double inputBorderRadius = InputConstants.inputBorderRadius;

const verticalModalSpacer = SizedBox(
  height: SpacingConstants.verticalModalSpacerHeight,
);

InputDecoration inputDecoration({
  required ThemeData themeData,
  String? labelText,
  String? semanticsLabel,
  Widget? suffixIcon,
}) {
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(
      inputBorderRadius,
    ),
    borderSide: BorderSide(
      color: themeData.colorScheme.outline
          .withAlpha(InputConstants.inputBorderAlpha),
    ),
  );

  final errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(
      inputBorderRadius,
    ),
    borderSide: BorderSide(
      color: themeData.colorScheme.error,
    ),
  );

  return InputDecoration(
    border: inputBorder,
    errorBorder: errorBorder,
    enabledBorder: inputBorder,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(
        inputBorderRadius,
      ),
      borderSide: BorderSide(
        color: themeData.colorScheme.outline,
        width: InputConstants.focusedBorderWidth,
      ),
    ),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    suffixIcon: suffixIcon,
    label: Text(
      labelText ?? '',
      semanticsLabel: semanticsLabel,
      style: TextStyle(
        fontSize: fontSizeMedium,
        fontWeight: TypographyConstants.bodyFontWeight,
        color: themeData.colorScheme.outline,
      ),
    ),
  );
}

InputDecoration createDialogInputDecoration({
  required ThemeData themeData,
  String? labelText,
  TextStyle? style,
}) {
  final decoration = inputDecoration(
    labelText: labelText,
    themeData: themeData,
  );

  if (style == null) {
    return decoration;
  } else {
    return decoration.copyWith(
      labelStyle: TextStyle(
        color: style.color,
      ),
    );
  }
}

const switchDecoration = InputDecoration(
  border: InputBorder.none,
);

const inputSpacer = SizedBox(
  height: SpacingConstants.inputSpacerHeight,
);
const inputSpacerSmall = SizedBox(
  height: SpacingConstants.inputSpacerSmallHeight,
);

TextStyle choiceChipTextStyle({
  required ThemeData themeData,
  required bool isSelected,
}) =>
    TextStyle(
      fontSize: fontSizeMedium,
      fontWeight: TypographyConstants.bodyFontWeight,
      color: isSelected
          ? themeData.colorScheme.onSecondary
          : themeData.colorScheme.secondary,
    );

const chartTooltipStyle = TextStyle(
  fontSize: fontSizeSmall,
  fontWeight: TypographyConstants.bodyFontWeight,
);

const chartTooltipStyleBold = TextStyle(
  fontSize: fontSizeMedium,
  fontWeight: FontWeight.bold,
);

const appBarTextStyle = TextStyle(
  fontSize: fontSizeMedium,
  fontWeight: FontWeight.bold,
);

const appBarTextStyleNew = TextStyle(
  fontSize: fontSizeMedium,
  fontWeight: TypographyConstants.bodyFontWeight,
);

const appBarTextStyleNewLarge = TextStyle(
  fontSize: fontSizeLarge,
  fontWeight: TypographyConstants.lightFontWeight,
);

const settingsCardTextStyle = TextStyle(
  fontSize: fontSizeLarge,
  fontWeight: TypographyConstants.bodyFontWeight,
);

const titleStyle = TextStyle(
  fontSize: fontSizeLarge,
  fontWeight: TypographyConstants.bodyFontWeight,
);

const taskTitleStyle = TextStyle(
  fontSize: fontSizeLarge,
);

const multiSelectStyle = TextStyle(
  fontWeight: FontWeight.w200, // Slightly bolder
  fontSize: fontSizeLarge,
);

const chartTitleStyle = TextStyle(
  fontSize: fontSizeMedium,
  fontWeight: FontWeight.w400, // Slightly bolder
);

final TextStyle chartTitleStyleMonospace = chartTitleStyle.copyWith(
  fontFeatures: [
    const FontFeature.tabularFigures(),
  ],
);

const habitTitleStyle = TextStyle(
  fontSize: fontSizeMediumLarge,
  fontWeight: FontWeight.w400, // Slightly bolder
);

TextStyle saveButtonStyle(ThemeData themeData) => TextStyle(
      fontSize: fontSizeMediumLarge,
      fontWeight: FontWeight.bold,
      color: themeData.colorScheme.error,
    );

// Utility style for monospaced, tabular-digit text with adjustable size.
TextStyle monoTabularStyle({
  required double fontSize,
  Color? color,
  FontWeight fontWeight = FontWeight.w500,
}) {
  return TextStyle(
    fontFamily: 'Inconsolata',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

TextStyle failButtonStyle() => TextStyle(
      fontSize: fontSizeMediumLarge,
      fontWeight: FontWeight.bold,
      color: failColor,
    );

const segmentItemStyle = TextStyle(
  fontSize: fontSizeMedium,
);

const badgeStyle = TextStyle(
  fontWeight: FontWeight.w400, // Slightly bolder
  fontSize: fontSizeSmall,
);

const settingsIconSize = 26.0; // Slightly larger

const habitCompletionHeaderStyle = TextStyle(
  fontSize: 22, // Increased
);

TextStyle searchLabelStyle() => TextStyle(
      color: secondaryTextColor,
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.w200, // Slightly bolder
    );

ThemeData withOverrides(ThemeData themeData) {
  // Use a slightly lighter, scheme-derived background in dark mode.
  // This keeps the background darker than cards (which use surfaceContainer*)
  // while avoiding a pure-black canvas. It also aligns the app bar and
  // bottom navigation bar tones via canvasColor.
  final isDark = themeData.brightness == Brightness.dark;
  final darkScaffold =
      isDark ? themeData.colorScheme.surface : null; // leave light theme as-is

  return themeData.copyWith(
      scaffoldBackgroundColor:
          darkScaffold ?? themeData.scaffoldBackgroundColor,
      // Align Material canvas (used by bottom bars) with the scaffold.
      canvasColor: darkScaffold ?? themeData.canvasColor,
      cardTheme: themeData.cardTheme.copyWith(
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        ),
      ),
      appBarTheme: themeData.appBarTheme.copyWith(
        backgroundColor: darkScaffold ?? themeData.scaffoldBackgroundColor,
        elevation: 10,
        shadowColor: Colors.transparent,
      ),
      sliderTheme: themeData.sliderTheme.copyWith(
        activeTrackColor: themeData.colorScheme.secondary,
        inactiveTrackColor: themeData.colorScheme.secondary.withAlpha(
          150, // Slightly more visible
        ),
        thumbColor: themeData.colorScheme.secondary,
        thumbShape: const RoundSliderThumbShape(),
        overlayColor: themeData.colorScheme.secondary.withAlpha(
          100, // More subtle overlay
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        clipBehavior: Clip.hardEdge,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      textTheme: themeData.textTheme.copyWith(
        titleMedium: themeData.textTheme.titleMedium?.copyWith(
          fontSize: fontSizeMedium,
          fontWeight: FontWeight.w500, // Slightly bolder
        ),
        bodyLarge: themeData.textTheme.bodyLarge?.copyWith(
          fontSize: fontSizeMedium,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: themeData.textTheme.bodyMedium?.copyWith(
          fontSize: fontSizeMedium,
          fontWeight: FontWeight.w400,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          alignment: Alignment.center,
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStateProperty.resolveWith(
            (states) => const TextStyle(
              fontSize: fontSizeSmall,
              fontWeight: FontWeight.w500, // Slightly bolder
            ),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            return BorderSide(
              color: themeData.colorScheme.tertiary,
              width: 1.5, // Slightly thicker
            );
          }),
          shape: WidgetStateProperty.resolveWith((states) {
            return RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                inputBorderRadius,
              ),
            );
          }),
          padding: WidgetStateProperty.resolveWith((states) {
            return const EdgeInsets.symmetric(
              horizontal: 8, // Increased padding
              vertical: 4,
            );
          }),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: themeData.primaryColor.withAlpha(20), // Subtle fill
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            inputBorderRadius,
          ),
          borderSide: BorderSide(
            color: themeData.colorScheme.outline.withAlpha(60), // More subtle
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            inputBorderRadius,
          ),
          borderSide: BorderSide(
            color: themeData.colorScheme.error,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            inputBorderRadius,
          ),
          borderSide: BorderSide(
            color: themeData.primaryColor,
            width: 2.5, // Slightly thicker
          ),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStateProperty.resolveWith((states) {
            return const TextStyle(
              fontSize: fontSizeMediumLarge,
              fontWeight: FontWeight.w500, // Slightly bolder
            );
          }),
          padding: WidgetStateProperty.resolveWith((states) {
            return const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            );
          }),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.pressed) ? 2 : 4;
          }),
          shape: WidgetStateProperty.resolveWith((states) {
            return RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // More rounded
            );
          }),
          padding: WidgetStateProperty.resolveWith((states) {
            return const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            );
          }),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{},
      ),
      extensions: <ThemeExtension>[
        const WoltModalSheetThemeData(
          animationStyle: WoltModalSheetAnimationStyle(
            paginationAnimationStyle: WoltModalSheetPaginationAnimationStyle(
              modalSheetHeightTransitionCurve: Interval(0, 0.1),
            ),
          ),
        ),
        GptMarkdownThemeData(
          brightness: themeData.brightness,
          h1: themeData.textTheme.titleLarge?.copyWith(
            fontSize: fontSizeMediumLarge,
            fontWeight: FontWeight.w600,
          ),
          h2: themeData.textTheme.titleMedium?.copyWith(
            fontSize: fontSizeMedium + 2,
            fontWeight: FontWeight.w500,
          ),
          h3: themeData.textTheme.titleSmall?.copyWith(
            fontSize: fontSizeMedium,
            fontWeight: FontWeight.w500,
          ),
          h4: themeData.textTheme.bodyLarge?.copyWith(
            fontSize: fontSizeMedium,
            fontWeight: FontWeight.w500,
          ),
          h5: themeData.textTheme.bodyMedium?.copyWith(
            fontSize: fontSizeMedium,
            fontWeight: FontWeight.w400,
          ),
          h6: themeData.textTheme.bodySmall?.copyWith(
            fontSize: fontSizeSmall,
            fontWeight: FontWeight.w400,
          ),
        ),
      ]);
}

extension AppThemeExtension on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}

extension TextThemeExtension on TextStyle {
  TextStyle get withTabularFigures => copyWith(
        fontFeatures: const [
          FontFeature.tabularFigures(),
        ],
      );
}

/// Gradient themes for consistent card styling across the app
class GradientThemes {
  /// Creates a subtle top-left to bottom-right gradient for cards
  static LinearGradient? cardGradient(BuildContext context) {
    return ModernGradientThemes.cardGradient(context);
  }

  /// Creates a subtle gradient for icon containers
  static LinearGradient iconContainerGradient(BuildContext context) {
    return ModernGradientThemes.accentGradient(context);
  }

  /// Creates a modern primary gradient
  static LinearGradient primaryGradient(BuildContext context) {
    return ModernGradientThemes.primaryGradient(context);
  }

  /// Creates a modern accent gradient
  static LinearGradient accentGradient(BuildContext context) {
    return ModernGradientThemes.accentGradient(context);
  }

  /// Creates a background gradient
  static LinearGradient backgroundGradient(BuildContext context) {
    return ModernGradientThemes.backgroundGradient(context);
  }
}
