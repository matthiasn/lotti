import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Centralized dimensions and helpers for SettingsPageHeader.
///
/// This groups all spacing constants and layout breakpoints so they can be
/// tuned consistently and referenced across files. Each value is documented
/// with its intended role in the header layout.
class SettingsHeaderDimensions {
  // Spacing above the title block inside the flexible space area.
  static const double topSpacing = 16;

  // Gap between title and subtitle.
  static const double subtitleGap = 6;

  // Gap between subtitle and a provided bottom widget (e.g., segmented chips).
  static const double subtitleBottomGapWithBottom = 4;

  // Tiny spacer above the bottom widget to separate from the header container.
  static const double bottomShim = 2;

  // Footer spacing when a subtitle is present but no bottom widget is provided.
  static const double footerWithSubtitle = 8;

  // Footer spacing when neither subtitle nor bottom widget is provided.
  static const double footerNoSubtitle = 6;

  // Minimum collapsed body height when a subtitle exists (excludes top inset).
  static const double collapsedMinWithSubtitle = 48;

  // Minimum collapsed body height when no subtitle exists (excludes top inset).
  static const double collapsedMinNoSubtitle = 48;

  // ─────────────────────────────────────────────────────────────────────────
  // Filter chip dimensions (used in sync list header bottom)
  // ─────────────────────────────────────────────────────────────────────────

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
        chipWidth += filterChipIconSpacing +
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
      final widthWithSpacing =
          currentRowWidth > 0 ? chipWidth + filterChipSpacing : chipWidth;

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
    final cardHeight = filterCardVerticalPadding * 2 + // card vertical padding
        filterCardBorderWidth * 2 + // card border (top + bottom)
        chipRowsHeight;
    final totalHeight = cardHeight +
        (summaryLineCount > 0 ? filterSummaryGap : 0) +
        summaryHeight +
        filterHeaderBottomBuffer;

    return totalHeight;
  }

  /// Returns the responsive horizontal padding for the header content given
  /// the available `width`.
  static double horizontalPadding(double width) {
    if (width >= 1600) return 160;
    if (width >= 1200) return 120;
    if (width >= 992) return 88;
    if (width >= 720) return 56;
    if (width >= 540) return 36;
    if (width >= 420) return 28;
    return 20;
  }

  /// Returns the responsive title font size. When `wide` is true, uses wider
  /// desktop/tablet sizing at mid‑range widths.
  static double titleFontSize({required double width, required bool wide}) {
    if (width >= 1600) return 36;
    if (width >= 1200) return 32;
    if (width >= 992) return 30;
    if (wide) return 28;
    if (width >= 600) return 26;
    if (width >= 420) return 24;
    return 22;
  }

  /// Normalized collapse progress [0..1] for a flexible space with the given
  /// heights.
  static double collapseProgress(
    double expandedHeight,
    double collapsedHeight,
    double currentHeight,
  ) {
    final available = expandedHeight - collapsedHeight;
    if (available <= 0) return 1;
    final delta = expandedHeight - currentHeight;
    return (delta / available).clamp(0.0, 1.0);
  }
}
