import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/sync/ui/widgets/sync_list_scaffold.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/settings_header_dimensions.dart';
import 'package:lotti/widgets/cards/index.dart';

class _FilterCard<F extends Enum> extends StatelessWidget {
  const _FilterCard({
    required this.filters,
    required this.counts,
    required this.selected,
    required this.onChanged,
    required this.locale,
  });

  final Map<F, SyncFilterOption<dynamic>> filters;
  final Map<F, int> counts;
  final F selected;
  final ValueChanged<F> onChanged;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final entries = filters.entries.toList(growable: false);
    return ModernBaseCard(
      padding: const EdgeInsets.symmetric(
        horizontal: SettingsHeaderDimensions.filterCardPadding,
        vertical: SettingsHeaderDimensions.filterCardVerticalPadding,
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: SettingsHeaderDimensions.filterChipSpacing,
        runSpacing: SettingsHeaderDimensions.filterChipSpacing,
        children: entries.map((entry) {
          final rawLabel = entry.value.labelBuilder(context);
          final label = toBeginningOfSentenceCase(rawLabel, locale);
          final count = counts[entry.key] ?? 0;
          final selectedColor =
              entry.value.selectedColor ??
              Theme.of(context).colorScheme.primary;
          final selectedForeground =
              entry.value.selectedForegroundColor ??
              Theme.of(context).colorScheme.onPrimary;

          return _SegmentChip(
            label: label,
            count: count,
            filter: entry.key.name,
            icon: entry.value.icon,
            isSelected: selected == entry.key,
            selectedColor: selectedColor,
            selectedForegroundColor: selectedForeground,
            showCount: entry.value.showCount,
            hideCountWhenZero: entry.value.hideCountWhenZero,
            countAccentColor: entry.value.countAccentColor,
            countAccentForegroundColor: entry.value.countAccentForegroundColor,
            onTap: () => onChanged(entry.key),
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
          _FilterCard<F>(
            filters: filters,
            counts: counts,
            selected: selected,
            onChanged: onChanged,
            locale: locale,
          ),
          const SizedBox(height: SettingsHeaderDimensions.filterSummaryGap),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: SettingsHeaderDimensions.filterCardPadding,
            ),
            child: Text(
              summaryText,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                fontSize: SettingsHeaderDimensions.filterSummaryFontSize,
                height: SettingsHeaderDimensions.filterSummaryLineHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.count,
    required this.filter,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.selectedForegroundColor,
    required this.showCount,
    required this.hideCountWhenZero,
    required this.countAccentColor,
    required this.countAccentForegroundColor,
    required this.onTap,
  });

  final String label;
  final int count;
  final String filter;
  final IconData? icon;
  final bool isSelected;
  final Color? selectedColor;
  final Color selectedForegroundColor;
  final bool showCount;
  final bool hideCountWhenZero;
  final Color? countAccentColor;
  final Color? countAccentForegroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = isSelected
        ? selectedForegroundColor
        : colorScheme.onSurface;
    final iconColor = isSelected
        ? selectedForegroundColor
        : colorScheme.onSurfaceVariant;
    final shouldShowCount = showCount && (!hideCountWhenZero || count > 0);
    final hasAccent = shouldShowCount && count > 0 && countAccentColor != null;
    final accentForeground = hasAccent
        ? countAccentForegroundColor ??
              (ThemeData.estimateBrightnessForColor(countAccentColor!) ==
                      Brightness.dark
                  ? Colors.white
                  : Colors.black)
        : null;
    final hasAccentSelection = hasAccent && isSelected;
    final countBackground = selectedColor;
    final countForeground = hasAccent
        ? accentForeground!
        : isSelected
        ? selectedForegroundColor
        : colorScheme.onSurfaceVariant;
    final countBorderColor = isSelected
        ? countForeground.withValues(alpha: 0.68)
        : Colors.transparent;

    return Semantics(
      button: true,
      toggled: isSelected,
      label: shouldShowCount ? '$label, $count' : label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
          AppTheme.cardBorderRadius / 1.6,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius / 1.6),
          onTap: onTap,
          child: AnimatedContainer(
            key: ValueKey('syncFilter-$filter'),
            duration: const Duration(milliseconds: AppTheme.animationDuration),
            padding: const EdgeInsets.symmetric(
              horizontal: SettingsHeaderDimensions.filterChipHorizontalPadding,
              vertical: SettingsHeaderDimensions.filterChipVerticalPadding,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? selectedColor
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.26),
              borderRadius: BorderRadius.circular(
                AppTheme.cardBorderRadius / 1.6,
              ),
              border: Border.all(
                color: isSelected
                    ? selectedColor ?? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.08),
                width: isSelected ? 1.4 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: SettingsHeaderDimensions.filterChipIconSize,
                    color: iconColor,
                  ),
                  const SizedBox(
                    width: SettingsHeaderDimensions.filterChipIconSpacing,
                  ),
                ],
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textTheme.labelMedium?.copyWith(
                    color: foregroundColor,
                    fontSize: SettingsHeaderDimensions.filterChipFontSize,
                  ),
                ),
                if (shouldShowCount) ...[
                  const SizedBox(
                    width: SettingsHeaderDimensions.filterChipIconSpacing,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal:
                          SettingsHeaderDimensions.filterChipCountPadding,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: countBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: countBorderColor,
                        width: hasAccentSelection
                            ? 1.3
                            : hasAccent
                            ? 1.1
                            : 1.2,
                      ),
                    ),
                    child: Text(
                      count.toString(),
                      style: textTheme.labelSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                        fontSize:
                            SettingsHeaderDimensions.filterChipCountFontSize,
                        color: countForeground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
