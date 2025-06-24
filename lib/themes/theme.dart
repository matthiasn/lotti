// ignore_for_file: equal_keys_in_map
import 'package:flutter/material.dart';
import 'package:lotti/themes/colors.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

const fontSizeSmall = 11.0;
const fontSizeMedium = 15.0;
const fontSizeMediumLarge = 20.0;
const fontSizeLarge = 25.0;

class AppTheme {
  static const double bottomNavIconSize = 24;

  static const chartDateHorizontalPadding = EdgeInsets.only(
    right: 4,
  );

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
  static const double spacingSmall = 8;
  static const double spacingMedium = 10;
  static const double spacingLarge = 12;

  // Chevron icon size
  static const double chevronSize = 20;
  static const double chevronSizeCompact = 18;
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

const transcriptHeaderStyle = TextStyle(
  fontSize: fontSizeSmall,
  fontWeight: FontWeight.w300,
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

final TextStyle monospaceTextStyleLarge = monospaceTextStyle.copyWith(
  fontSize: fontSizeLarge,
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
          context.colorScheme.surfaceContainerLow,
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

  /// Creates a subtle gradient for provider name containers
  static LinearGradient providerNameGradient(BuildContext context) {
    return LinearGradient(
      colors: [
        context.colorScheme.primaryContainer.withValues(alpha: 0.25),
        context.colorScheme.primaryContainer.withValues(alpha: 0.15),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
