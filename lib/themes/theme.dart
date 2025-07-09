// ignore_for_file: equal_keys_in_map
import 'package:flutter/material.dart';
import 'package:lotti/themes/colors.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

const fontSizeSmall = 11.0;
const fontSizeMedium = 15.0;
const fontSizeMediumLarge = 20.0;
const fontSizeLarge = 25.0;

class AppTheme {
  // Settings card layout constants
  static const double cardBorderRadius = 16;
  static const double cardPadding = 14;
  static const double cardPaddingCompact = 12;
  static const double cardElevationLight = 6;
  static const double cardElevationDark = 10;
  static const double cardSpacing = 8; // Spacing between cards

  // Icon container constants
  static const double iconContainerSize = 40;
  static const double iconContainerSizeCompact = 36;
  static const double iconContainerBorderRadius = 12;
  static const double iconSize = 20;
  static const double iconSizeCompact = 18;

  // Spacing constants
  static const double spacingXSmall = 4;
  static const double spacingSmall = 8;
  static const double spacingMedium = 10;
  static const double spacingLarge = 12;

  // Chevron icon size
  static const double chevronSize = 20;
  static const double chevronSizeCompact = 18;

  // Typography constants
  static const double titleFontSize = 16;
  static const double titleFontSizeCompact = 15;
  static const double subtitleFontSize = 12;
  static const double subtitleFontSizeCompact = 11;
  static const double letterSpacingTitle = 0.1;
  static const double letterSpacingSubtitle = 0;
  static const double lineHeightSubtitle = 1.4;

  // Alpha values for colors
  static const double alphaOutline = 0.3;
  static const double alphaPrimaryContainer = 0.15;
  static const double alphaShadowLight = 0.08;
  static const double alphaShadowDark = 0.15;
  static const double alphaPrimary = 0.1;
  static const double alphaPrimaryHighlight = 0.05;
  static const double alphaPrimaryBorder = 0.15;
  static const double alphaPrimaryIcon = 0.9;
  static const double alphaSurfaceVariant = 0.8;
  static const double alphaSurfaceVariantChevron = 0.6;
  static const double alphaDestructive = 0.3;

  // Animation constants
  static const int animationDuration = 200;
  static const Curve animationCurve = Curves.easeOutCubic;

  // Spacing between elements
  static const double spacingBetweenTitleAndSubtitle = 4;
  static const double spacingBetweenTitleAndSubtitleCompact = 2;
  static const double spacingBetweenElements = 6;

  // Offset for shadows
  static const Offset shadowOffset = Offset(0, 2);

  // Status indicator constants
  static const double statusIndicatorPaddingHorizontal = 6;
  static const double statusIndicatorPaddingHorizontalCompact = 5;
  static const double statusIndicatorPaddingVertical = 2;
  static const double statusIndicatorBorderRadius = 6;
  static const double statusIndicatorBorderRadiusSmall = 5;
  static const double statusIndicatorBorderRadiusTiny = 4;
  static const double statusIndicatorBorderWidth = 0.5;
  static const double statusIndicatorSize = 24;
  static const double statusIndicatorSizeCompact = 20;
  static const double statusIndicatorIconSize = 14;
  static const double statusIndicatorIconSizeCompact = 12;

  // Status indicator alpha values
  static const double alphaPrimaryContainerLight = 0.25;
  static const double alphaPrimaryContainerDark = 0.15;
  static const double alphaStatusIndicatorBorder = 0.1;
  static const double alphaSurfaceContainerHighest = 0.3;
  static const double alphaSurfaceVariantDim = 0.5;
  static const double alphaErrorContainer = 0.5;
  static const double alphaErrorText = 0.8;
  static const double alphaPrimaryContainerActive = 0.7;

  // Font sizes for status indicators
  static const double statusIndicatorFontSize = 11;
  static const double statusIndicatorFontSizeCompact = 10;
  static const double statusIndicatorFontSizeTiny = 9;

  // Modal item spacer widths
  static const double modalIconSpacerWidth = iconContainerSize * 1.1;
  static const double modalChevronSpacerWidth = spacingLarge;
}

const double inputBorderRadius = 10;

const verticalModalSpacer = SizedBox(
  height: 30,
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
      color: themeData.colorScheme.outline.withAlpha(100),
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
        width: 2,
      ),
    ),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    suffixIcon: suffixIcon,
    label: Text(
      labelText ?? '',
      semanticsLabel: semanticsLabel,
      style: TextStyle(
        fontSize: fontSizeMedium,
        fontWeight: FontWeight.w300,
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
  height: 25,
);
const inputSpacerSmall = SizedBox(
  height: 15,
);

TextStyle choiceChipTextStyle({
  required ThemeData themeData,
  required bool isSelected,
}) =>
    TextStyle(
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.w300,
      color: isSelected
          ? themeData.colorScheme.onSecondary
          : themeData.colorScheme.secondary,
    );

const chartTooltipStyle = TextStyle(
  fontSize: fontSizeSmall,
  fontWeight: FontWeight.w300,
);

const chartTooltipStyleBold = TextStyle(
  fontSize: fontSizeMedium,
  fontWeight: FontWeight.bold,
);

const monospaceTextStyle = TextStyle(
  fontSize: fontSizeMedium,
  fontWeight: FontWeight.w500,
  fontFeatures: [
    FontFeature.tabularFigures(),
  ],
);

final TextStyle monospaceTextStyleSmall = monospaceTextStyle.copyWith(
  fontSize: fontSizeSmall,
);

const appBarTextStyle = TextStyle(
  fontSize: fontSizeMedium,
  fontWeight: FontWeight.bold,
);

const appBarTextStyleNew = TextStyle(
  fontSize: fontSizeMedium,
  fontWeight: FontWeight.w300,
);

const appBarTextStyleNewLarge = TextStyle(
  fontSize: fontSizeLarge,
  fontWeight: FontWeight.w100,
);

const settingsCardTextStyle = TextStyle(
  fontSize: fontSizeLarge,
  fontWeight: FontWeight.w300,
);

const titleStyle = TextStyle(
  fontSize: fontSizeLarge,
  fontWeight: FontWeight.w300,
);

const taskTitleStyle = TextStyle(
  fontSize: fontSizeLarge,
);

const multiSelectStyle = TextStyle(
  fontWeight: FontWeight.w100,
  fontSize: fontSizeLarge,
);

const chartTitleStyle = TextStyle(
  fontSize: fontSizeMedium,
  fontWeight: FontWeight.w300,
);

final TextStyle chartTitleStyleMonospace = chartTitleStyle.copyWith(
  fontFeatures: [
    const FontFeature.tabularFigures(),
  ],
);

const habitTitleStyle = TextStyle(
  fontSize: fontSizeMediumLarge,
  fontWeight: FontWeight.w300,
);

TextStyle saveButtonStyle(ThemeData themeData) => TextStyle(
      fontSize: fontSizeMediumLarge,
      fontWeight: FontWeight.bold,
      color: themeData.colorScheme.error,
    );

TextStyle failButtonStyle() => TextStyle(
      fontSize: fontSizeMediumLarge,
      fontWeight: FontWeight.bold,
      color: failColor,
    );

const segmentItemStyle = TextStyle(
  fontSize: fontSizeMedium,
);

const badgeStyle = TextStyle(
  fontWeight: FontWeight.w300,
  fontSize: fontSizeSmall,
);

const settingsIconSize = 24.0;

const habitCompletionHeaderStyle = TextStyle(
  fontSize: 20,
);

TextStyle searchLabelStyle() => TextStyle(
      color: secondaryTextColor,
      fontSize: fontSizeMedium,
      fontWeight: FontWeight.w100,
    );

ThemeData withOverrides(ThemeData themeData) {
  return themeData.copyWith(
      cardTheme: themeData.cardTheme.copyWith(
        clipBehavior: Clip.hardEdge,
        color: themeData.colorScheme.surfaceContainer,
      ),
      appBarTheme: themeData.appBarTheme.copyWith(
        backgroundColor: themeData.scaffoldBackgroundColor,
      ),
      sliderTheme: themeData.sliderTheme.copyWith(
        activeTrackColor: themeData.colorScheme.secondary,
        inactiveTrackColor: themeData.colorScheme.secondary.withAlpha(
          178,
        ),
        thumbColor: themeData.colorScheme.secondary,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 8,
        ),
        overlayColor: themeData.colorScheme.secondary.withAlpha(
          127,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        clipBehavior: Clip.hardEdge,
        elevation: 100,
      ),
      textTheme: themeData.textTheme.copyWith(
        titleMedium: themeData.textTheme.titleMedium?.copyWith(
          fontSize: fontSizeMedium,
          fontWeight: FontWeight.normal,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          alignment: Alignment.center,
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStateProperty.resolveWith(
            (states) => const TextStyle(
              fontSize: fontSizeSmall,
            ),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            return BorderSide(
              color: themeData.colorScheme.tertiary,
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
              horizontal: 5,
            );
          }),
          enableFeedback: true,
        ),
      ),
      chipTheme: const ChipThemeData(
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: themeData.primaryColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            inputBorderRadius,
          ),
          borderSide: BorderSide(
            color: themeData.colorScheme.outline,
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
            width: 2,
          ),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStateProperty.resolveWith((states) {
            return const TextStyle(
              fontSize: fontSizeMediumLarge,
            );
          }),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{},
      ),
      extensions: const <ThemeExtension>[
        WoltModalSheetThemeData(
          animationStyle: WoltModalSheetAnimationStyle(
            paginationAnimationStyle: WoltModalSheetPaginationAnimationStyle(
              modalSheetHeightTransitionCurve: Interval(0, 0.1),
            ),
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
    if (Theme.of(context).brightness == Brightness.light) {
      return null;
    }

    return LinearGradient(
      colors: [
        Color.lerp(
          context.colorScheme.surfaceContainer,
          context.colorScheme.surfaceContainerHigh,
          0.3,
        )!,
        Color.lerp(
          context.colorScheme.surface,
          context.colorScheme.surfaceContainer,
          0.5,
        )!,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Creates a subtle gradient for icon containers
  static LinearGradient iconContainerGradient(BuildContext context) {
    return LinearGradient(
      colors: [
        context.colorScheme.primaryContainer.withValues(alpha: 0.3),
        context.colorScheme.primaryContainer.withValues(alpha: 0.2),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
