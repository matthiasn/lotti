import 'package:flutter/material.dart';

const fontSizeSmall = 11.0;
const fontSizeMedium = 15.0;
const fontSizeMediumLarge = 20.0;
const fontSizeLarge = 25.0;

class AppTheme {
  // Modern card layout constants
  static const double cardBorderRadius = 16; // Clean, modern radius
  static const double cardPadding = 16; // Increased padding
  static const double cardPaddingHalf = cardPadding / 2;
  static const double cardPaddingCompact = 14;
  static const double cardElevationLight =
      2; // Subtle shadows for polished look
  static const double cardElevationDark =
      4; // Slightly more visible in dark mode
  static const double cardSpacing = 10; // Increased spacing between cards

  // Icon container constants
  static const double iconContainerSize = 44; // Slightly larger
  static const double iconContainerSizeCompact = 40;
  static const double iconContainerBorderRadius = 14; // More rounded
  static const double iconSize = 22; // Slightly larger icons
  static const double iconSizeCompact = 20;
  // Entry-card header action glyphs (star/AI/chevron/overflow/edit): a larger
  // glyph than the default body icon so the thin outline controls (esp. the
  // unfavorited star) stay perceptible for low-vision users on the dark card.
  static const double headerActionIconSize = 28;

  // Spacing constants
  static const double spacingXSmall = 4;
  static const double spacingSmall = 8;
  static const double spacingMedium = 12; // Increased
  static const double spacingLarge = 16; // Increased

  // Chevron icon size
  static const double chevronSize = 22; // Slightly larger

  // Collapse animation durations
  static const Duration chevronRotationDuration = Duration(milliseconds: 500);
  static const Duration collapseAnimationDuration = Duration(milliseconds: 600);

  // Collapsed header thumbnail constants
  static const double thumbnailSize = 40;
  static const double thumbnailBorderRadius = 6;
  static const double thumbnailCacheMultiplier = 2; // for retina
  static const double previewIconSize = 24;

  // Typography constants - Modern typography scale
  static const double titleFontSize = 18; // Increased
  static const double titleFontSizeCompact = 17;
  static const double subtitleFontSize = 13; // Increased
  static const double subtitleFontSizeCompact = 12;
  static const double letterSpacingTitle = 0.15; // Increased letter spacing
  static const double letterSpacingSubtitle = 0.05;
  static const double lineHeightSubtitle = 1.5; // Better line height

  // Enhanced alpha values for colors - tuned for polished look
  static const double alphaOutline = 0.08; // Very subtle borders in light mode
  static const double alphaPrimaryContainer = 0.08; // Subtle container tints
  static const double alphaShadowLight = 0.04; // Minimal shadows for clean look
  static const double alphaShadowDark = 0.15; // Subtle shadows in dark mode
  static const double alphaPrimary = 0.08; // More subtle
  static const double alphaPrimaryHighlight = 0.04;
  static const double alphaPrimaryBorder = 0.12;
  static const double alphaPrimaryIcon = 0.95; // More vibrant
  static const double alphaSurfaceVariant = 0.85; // Better contrast
  static const double alphaSurfaceVariantChevron = 0.7;

  // List item alpha values
  static const double alphaDisabled = 0.38; // Material Design disabled state
  static const double alphaDivider = 0.15; // Subtle dividers between list items
  static const double alphaIconTrailing = 0.7; // Secondary/trailing icons

  // List item icon size (slightly larger for visual balance in menus)
  static const double listItemIconSize = iconSize + 2;

  // Slider alpha values
  static const int alphaSliderInactiveTrack = 150;
  static const int alphaSliderOverlay = 100;

  // Card border alpha values
  static const double alphaCardBorderDark = 0.3;
  static const double alphaCardBorderLight = 0.06;

  // Icon container alpha values
  static const double alphaIconContainerGradientStartDark = 0.3;
  static const double alphaIconContainerGradientStartLight = 0.15;
  static const double alphaIconContainerGradientEndDark = 0.2;
  static const double alphaIconContainerGradientEndLight = 0.1;
  static const double alphaIconContainerBorderDark = 0.2;
  static const double alphaIconContainerBorderLight = 0.08;
  static const double iconContainerBorderWidth = 0.5;

  // Animation constants - Smoother animations
  static const int animationDuration = 300; // Slightly longer
  static const Curve animationCurve =
      Curves.easeOutQuart; // More sophisticated curve

  // Spacing between elements
  static const double spacingBetweenTitleAndSubtitle = 6; // Increased
  static const double spacingBetweenTitleAndSubtitleCompact = 4;
  static const double spacingBetweenElements = 8; // Increased

  // Clean shadow offset - subtle and modern
  static const Offset shadowOffset = Offset(
    0,
    1,
  ); // Minimal offset for clean look

  // Status indicator constants
  static const double statusIndicatorPaddingHorizontal = 8; // Increased
  static const double statusIndicatorPaddingVertical = 3; // Increased
  static const double statusIndicatorBorderRadius = 8; // More rounded
  static const double statusIndicatorBorderRadiusSmall = 6;
  static const double statusIndicatorBorderRadiusTiny = 5;
  static const double statusIndicatorBorderWidth = 0.8; // Slightly thicker
  static const double statusIndicatorSize = 26; // Slightly larger
  static const double statusIndicatorIconSize = 16; // Larger icons

  // Label chip padding (Linear-style)
  static const double labelChipPaddingLeft = 8;
  static const double labelChipPaddingRight = 10;
  static const double labelChipPaddingVertical = 4;

  // Filter chip styling constants
  static const double filterChipSpacing = 6;
  static const double filterChipIconSize = 16;
  static const double filterChipFontSize = 13;
  static const double filterChipLetterSpacing = 0.2;
  static const double filterChipPaddingHorizontal = 12;
  static const double filterChipPaddingVertical = 6;
  static const double alphaFilterChipBackground = 0.5;
  static const double alphaFilterChipSelected = 0.7;
  static const double alphaFilterChipBorderSelected = 0.8;
  static const double alphaFilterChipBorderUnselected = 0.3;
  static const double alphaFilterChipTextUnselected = 0.8;

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

  // Modal item spacer widths
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
