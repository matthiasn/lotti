import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/widgets/sync_list_scaffold.dart';
import 'package:lotti/widgets/cards/index.dart';

class _FilterCard<T, F extends Enum> extends StatelessWidget {
  const _FilterCard({
    required this.filters,
    required this.counts,
    required this.selected,
    required this.onChanged,
    required this.locale,
  });

  final Map<F, SyncFilterOption<T>> filters;
  final Map<F, int> counts;
  final F selected;
  final ValueChanged<F> onChanged;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final entries = filters.entries.toList(growable: false);
    return ModernBaseCard(
      padding: EdgeInsets.all(tokens.spacing.step3),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: tokens.spacing.step2,
        runSpacing: tokens.spacing.step2,
        children: entries.map((entry) {
          final rawLabel = entry.value.labelBuilder(context);
          final label = toBeginningOfSentenceCase(rawLabel, locale);
          final count = counts[entry.key] ?? 0;
          final shouldShowCount =
              entry.value.showCount &&
              (!entry.value.hideCountWhenZero || count > 0);
          final countAccent = entry.value.countAccentColor;

          return DesignSystemChip(
            key: ValueKey('syncFilter-${entry.key.name}'),
            label: label,
            leadingIcon: entry.value.icon,
            selected: selected == entry.key,
            semanticsLabel: shouldShowCount ? '$label, $count' : label,
            trailing: shouldShowCount
                ? ExcludeSemantics(
                    child: DsPill(
                      variant: countAccent == null
                          ? DsPillVariant.filled
                          : DsPillVariant.outline,
                      label: count.toString(),
                      color: countAccent,
                      bordered: countAccent == null,
                    ),
                  )
                : null,
            onPressed: () => onChanged(entry.key),
          );
        }).toList(),
      ),
    );
  }
}

class SyncHeaderBottom<T, F extends Enum> extends StatelessWidget
    implements PreferredSizeWidget {
  const SyncHeaderBottom({
    required this.filters,
    required this.counts,
    required this.selected,
    required this.onChanged,
    required this.locale,
    required this.summaryText,
    required this.padding,
    required this.preferredHeight,
    super.key,
  });

  final Map<F, SyncFilterOption<T>> filters;
  final Map<F, int> counts;
  final F selected;
  final ValueChanged<F> onChanged;
  final String locale;
  final String summaryText;
  final EdgeInsetsDirectional padding;

  /// Pre-calculated height based on actual label widths and layout constraints.
  final double preferredHeight;

  /// Measures the token-driven chips and optional summary before the
  /// [PreferredSizeWidget] is attached to the settings header.
  static double calculatePreferredHeight({
    required BuildContext context,
    required List<String> labels,
    required List<int> counts,
    required List<bool> haveIcons,
    required List<bool> showCounts,
    required double availableWidth,
    required double horizontalPadding,
    required String summaryText,
  }) {
    final tokens = context.designTokens;
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final chipGap = tokens.spacing.step2;
    final chipHorizontalPadding = tokens.spacing.step3;
    final chipVerticalPadding = tokens.spacing.step1;
    final cardPadding = tokens.spacing.step3;
    final labelStyle = tokens.typography.styles.body.bodySmall;
    final countStyle = tokens.typography.styles.others.caption.copyWith(
      height: 1,
    );
    final accessoryBoxSize = tokens.typography.lineHeight.bodySmall;
    final rawContentWidth =
        availableWidth - horizontalPadding - cardPadding * 2;
    final contentWidth = math.max(BorderWidths.hairline, rawContentWidth);

    final chipSizes = <Size>[];
    for (var i = 0; i < labels.length; i++) {
      final count = i < counts.length ? counts[i] : 0;
      final labelPainter = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        maxLines: 1,
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      var width = chipHorizontalPadding * 2 + labelPainter.width;
      var contentHeight = labelPainter.height;

      if (i < haveIcons.length && haveIcons[i]) {
        width += chipGap + accessoryBoxSize;
        contentHeight = math.max(contentHeight, accessoryBoxSize);
      }

      if (i < showCounts.length && showCounts[i]) {
        final countPainter = TextPainter(
          text: TextSpan(text: count.toString(), style: countStyle),
          maxLines: 1,
          textDirection: textDirection,
          textScaler: textScaler,
        )..layout();
        width += chipGap + countPainter.width + tokens.spacing.step3 * 2;
        contentHeight = math.max(contentHeight, DsPill.height);
      }

      chipSizes.add(
        Size(width, contentHeight + chipVerticalPadding * 2),
      );
    }

    var currentRowWidth = 0.0;
    var currentRowHeight = 0.0;
    var chipRowsHeight = 0.0;
    for (final chipSize in chipSizes) {
      final requiredWidth = currentRowWidth == 0
          ? chipSize.width
          : chipGap + chipSize.width;
      if (currentRowWidth > 0 &&
          currentRowWidth + requiredWidth > contentWidth) {
        chipRowsHeight += currentRowHeight + chipGap;
        currentRowWidth = chipSize.width;
        currentRowHeight = chipSize.height;
      } else {
        currentRowWidth += requiredWidth;
        currentRowHeight = math.max(currentRowHeight, chipSize.height);
      }
    }
    chipRowsHeight += currentRowHeight;

    var summaryHeight = 0.0;
    if (summaryText.isNotEmpty) {
      final summaryPainter = TextPainter(
        text: TextSpan(
          text: summaryText,
          style: tokens.typography.styles.body.bodySmall,
        ),
        maxLines: 3,
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout(maxWidth: contentWidth);
      summaryHeight = chipGap + summaryPainter.height;
    }

    return cardPadding * 2 +
        BorderWidths.hairline * 2 +
        chipRowsHeight +
        summaryHeight +
        tokens.spacing.step4;
  }

  @override
  Size get preferredSize => Size.fromHeight(preferredHeight);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: padding.start,
        end: padding.end,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterCard<T, F>(
            filters: filters,
            counts: counts,
            selected: selected,
            onChanged: onChanged,
            locale: locale,
          ),
          // An empty summary suppresses the count line entirely — used by
          // pages (e.g. the outbox) that carry their own plain-language
          // summary header and would otherwise duplicate the count.
          if (summaryText.isNotEmpty) ...[
            SizedBox(height: context.designTokens.spacing.step2),
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: context.designTokens.spacing.step3,
              ),
              child: Text(
                summaryText,
                style: context.designTokens.typography.styles.body.bodySmall
                    .copyWith(
                      color: context.designTokens.colors.text.mediumEmphasis,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
