import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme_constants.dart';
import 'package:material_ui/material_ui.dart';

const double inputBorderRadius = InputConstants.inputBorderRadius;

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
      color: themeData.colorScheme.outline.withAlpha(
        InputConstants.inputBorderAlpha,
      ),
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

const chartTooltipStyle = TextStyle(
  fontSize: fontSizeSmall,
  fontWeight: TypographyConstants.bodyFontWeight,
);

const chartTooltipStyleBold = TextStyle(
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

// Utility style for monospaced, tabular-digit text with adjustable size.
// Reserved for code-style surfaces (JSON payloads, log readouts). For
// timer / date / count labels in the UI prefer [tabularFigureStyle],
// which keeps the regular UI font and stabilises digits via
// [numericBadgeFontFeatures].
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

// Tabular-digit text in the regular UI font (Inter). Use for timers,
// dates, counts, and any digit-heavy label where stable digit columns
// matter but a true monospace font would look out of place.
TextStyle tabularFigureStyle({
  required double fontSize,
  Color? color,
  FontWeight fontWeight = FontWeight.w500,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    fontFeatures: numericBadgeFontFeatures,
  );
}

/// OpenType features applied to every count-style numeric surface (badges,
/// timers, etc.) so digit shapes stay visually steady across renders:
///
/// - `tnum` / [FontFeature.tabularFigures] — every digit advances by the
///   same width; counts ticking from `9` → `10` → `99` no longer twitch.
/// - `cv02` / `cv03` / `cv04` — Inter's open-digit character variants
///   (open four, open six, open nine). The default Inter forms have
///   closed counters that read as smudges at small badge sizes; the open
///   variants stay legible at 11–12 px. Fonts that don't define these variants
///   silently ignore them, so the constant is safe to share.
/// - `zero` / [FontFeature.slashedZero] — slashed zero so it cannot be
///   confused with `O` or `8` on dense badges.
const numericBadgeFontFeatures = <FontFeature>[
  FontFeature.tabularFigures(),
  FontFeature('cv02'),
  FontFeature('cv03'),
  FontFeature('cv04'),
  FontFeature.slashedZero(),
];

const badgeStyle = TextStyle(
  fontWeight: FontWeight.w400, // Slightly bolder
  fontSize: fontSizeSmall,
  fontFeatures: numericBadgeFontFeatures,
);

const habitCompletionHeaderStyle = TextStyle(
  fontSize: 22, // Increased
);

TextStyle searchLabelStyle() => TextStyle(
  color: secondaryTextColor,
  fontSize: fontSizeMedium,
  fontWeight: FontWeight.w200, // Slightly bolder
);
