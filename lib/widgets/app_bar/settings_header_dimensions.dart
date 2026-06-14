import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dimensions for the sync list header's filter-chip accessory row.
///
/// (The former title/collapse constants were retired when
/// `SettingsPageHeader` became a fixed, non-collapsing header; what
/// remains is only what the sync filter header still measures.)
class SettingsHeaderDimensions {
  /// Vertical padding inside each filter chip.
  static const double filterChipVerticalPadding = 6;

  /// Horizontal padding inside each filter chip.
  static const double filterChipHorizontalPadding = 8;

  /// Icon size inside filter chips.
  static const double filterChipIconSize = 14;

  /// Spacing between icon and label in filter chips.
  static const double filterChipIconSpacing = 4;

  /// Font size for filter chip labels.
  static const double filterChipFontSize = 12;

  /// Spacing between filter chips.
  static const double filterChipSpacing = 6;

  /// Padding inside the count badge.
  static const double filterChipCountPadding = 4;

  /// Font size for count badge text.
  static const double filterChipCountFontSize = 10;

  /// Horizontal padding inside the filter card container.
  static const double filterCardPadding = 10;

  /// Vertical padding inside the filter card container.
  static const double filterCardVerticalPadding = 8;

  /// Border width of the filter card (from ModernBaseCard's Border.all).
  static const double filterCardBorderWidth = 1;

  /// Spacing between filter card and summary text.
  static const double filterSummaryGap = 4;

  /// Font size for the summary text (e.g., "Error · 3 items").
  static const double filterSummaryFontSize = 12;

  /// Line height multiplier for summary text.
  static const double filterSummaryLineHeight = 1.4;

  /// Extra buffer for visual breathing room in the sync list header.
  static const double filterHeaderBottomBuffer = 11;

  /// Calculates the height of a single filter chip row.
  static double get filterChipRowHeight {
    // labelMedium typically has line height ~1.33, use 1.5 for safety margin
    const textHeight = filterChipFontSize * 1.5;
    return filterChipVerticalPadding * 2 +
        math.max(textHeight, filterChipIconSize);
  }

  /// Calculates the summary text height.
  static double get filterSummaryHeight {
    return filterSummaryFontSize * filterSummaryLineHeight;
  }

  /// Calculates the preferred height for a sync header bottom widget by
  /// measuring actual chip label widths and summary text.
  ///
  /// [context] is needed to access theme for text styles.
  /// [labels] are the localized filter labels.
  /// [counts] maps each label index to its count (for badge width estimation).
  /// [haveIcons] indicates which chips have icons (for accurate width calc).
  /// [availableWidth] is the width available for the chip layout.
  /// [horizontalPadding] is the total horizontal padding around the chip area.
  /// [summaryText] optional summary text to measure for potential wrapping.
  static double calculateFilterHeaderHeight({
    required BuildContext context,
    required List<String> labels,
    required List<int> counts,
    required List<bool> haveIcons,
    required double availableWidth,
    required double horizontalPadding,
    String? summaryText,
  }) {
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontSize: filterChipFontSize,
    );

    // Measure each chip's width
    final chipWidths = <double>[];
    for (var i = 0; i < labels.length; i++) {
      final label = labels[i];
      final count = i < counts.length ? counts[i] : 0;
      final hasIcon = i < haveIcons.length && haveIcons[i];

      // Measure label text width
      final textPainter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();

      // Calculate total chip width
      var chipWidth = filterChipHorizontalPadding * 2 + textPainter.width;

      // Add icon width if present
      if (hasIcon) {
        chipWidth += filterChipIconSize + filterChipIconSpacing;
      }

      // Add count badge width if count > 0
      if (count > 0) {
        final countText = count.toString();
        final countPainter = TextPainter(
          text: TextSpan(
            text: countText,
            style: textStyle?.copyWith(fontSize: filterChipCountFontSize),
          ),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        chipWidth +=
            filterChipIconSpacing +
            filterChipCountPadding * 2 +
            countPainter.width;
      }

      chipWidths.add(chipWidth);
    }

    // Calculate how chips wrap into rows
    final contentWidth =
        availableWidth - horizontalPadding - filterCardPadding * 2;
    var currentRowWidth = 0.0;
    var rowCount = 1;

    for (final chipWidth in chipWidths) {
      final widthWithSpacing = currentRowWidth > 0
          ? chipWidth + filterChipSpacing
          : chipWidth;

      if (currentRowWidth + widthWithSpacing > contentWidth &&
          currentRowWidth > 0) {
        // Wrap to new row
        rowCount++;
        currentRowWidth = chipWidth;
      } else {
        currentRowWidth += widthWithSpacing;
      }
    }

    // Calculate summary text height (may wrap on narrow screens)
    var summaryLineCount = 0;
    if (summaryText != null && summaryText.isNotEmpty) {
      final summaryStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: filterSummaryFontSize,
        height: filterSummaryLineHeight,
      );
      final summaryPainter = TextPainter(
        text: TextSpan(text: summaryText, style: summaryStyle),
        maxLines: 3,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: contentWidth);
      // Compute how many lines the summary text uses
      summaryLineCount = summaryPainter.computeLineMetrics().length;
    }

    // Calculate total height
    final chipRowsHeight =
        rowCount * filterChipRowHeight + (rowCount - 1) * filterChipSpacing;
    final summaryHeight = filterSummaryHeight * summaryLineCount;
    final cardHeight =
        filterCardVerticalPadding * 2 + // card vertical padding
        filterCardBorderWidth * 2 + // card border (top + bottom)
        chipRowsHeight;
    final totalHeight =
        cardHeight +
        (summaryLineCount > 0 ? filterSummaryGap : 0) +
        summaryHeight +
        filterHeaderBottomBuffer;

    return totalHeight;
  }

  /// Returns the responsive horizontal content padding for the given
  /// available `width`. Still used by `SettingsPageLayout` to align the
  /// body content grid across pane widths.
  static double horizontalPadding(double width) {
    if (width >= 1600) return 160;
    if (width >= 1200) return 120;
    if (width >= 992) return 88;
    if (width >= 720) return 56;
    if (width >= 540) return 36;
    if (width >= 420) return 28;
    return 20;
  }
}
