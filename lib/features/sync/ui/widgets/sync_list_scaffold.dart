import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/settings_header_dimensions.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/ui/empty_state_widget.dart';

typedef SyncFilterPredicate<T> = bool Function(T item);

/// Configuration for an individual segmented filter option.
class SyncFilterOption<T> {
  const SyncFilterOption({
    required this.labelBuilder,
    required this.predicate,
    this.icon,
    this.selectedColor,
    this.selectedForegroundColor,
    this.showCount = true,
    this.hideCountWhenZero = false,
    this.countAccentColor,
    this.countAccentForegroundColor,
  });

  /// Builds the localized label shown in the segmented control.
  final String Function(BuildContext context) labelBuilder;

  /// Predicate used to determine whether an item belongs to this segment.
  final SyncFilterPredicate<T> predicate;

  /// Optional icon rendered next to the label.
  final IconData? icon;

  /// Optional background color applied when the segment is selected.
  final Color? selectedColor;

  /// Optional foreground color applied when the segment is selected.
  final Color? selectedForegroundColor;

  /// Whether the numeric badge should be shown for this segment.
  final bool showCount;

  /// Whether to suppress the badge when the count resolves to zero.
  final bool hideCountWhenZero;

  /// Optional accent color applied to the count badge when a non-zero total is present.
  final Color? countAccentColor;

  /// Optional foreground color used with [countAccentColor].
  final Color? countAccentForegroundColor;
}

/// Reusable scaffold for sync-oriented list pages with segmented filters,
/// shared empty/loading treatment, and inline count summaries.
class SyncListScaffold<T, F extends Enum> extends StatefulWidget {
  const SyncListScaffold({
    required this.title,
    required this.stream,
    required this.filters,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyTitleBuilder,
    required this.countSummaryBuilder,
    this.subtitle,
    this.emptyDescriptionBuilder,
    this.initialFilter,
    this.listPadding = const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
    this.listKey,
    this.backButton = true,
    super.key,
  });

  /// Sliver page title.
  final String title;
  final String? subtitle;

  /// Source stream that yields the full set of items. Filtering occurs locally.
  final Stream<List<T>> stream;

  /// Filter definitions mapped to their enum identifiers.
  final Map<F, SyncFilterOption<T>> filters;

  /// Item builder for the filtered list.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Icon displayed in the empty state.
  final IconData emptyIcon;

  /// Title builder for the empty state.
  final String Function(BuildContext context) emptyTitleBuilder;

  /// Optional description builder for the empty state.
  final String? Function(BuildContext context)? emptyDescriptionBuilder;

  /// Summary builder shown below the segmented control.
  final String Function(
    BuildContext context,
    String label,
    int count,
  ) countSummaryBuilder;

  /// Initial segment selection. Defaults to the first entry in [filters].
  final F? initialFilter;

  /// Padding applied around the list.
  final EdgeInsets listPadding;

  /// Optional key applied to the list view.
  final Key? listKey;

  /// Whether to display the back button in the `SliverTitleBar`.
  final bool backButton;

  @override
  State<SyncListScaffold<T, F>> createState() => _SyncListScaffoldState<T, F>();
}

class _SyncListScaffoldState<T, F extends Enum>
    extends State<SyncListScaffold<T, F>> {
  late final ScrollController _scrollController;
  late F _selectedFilter;
  late final void Function() _activityListener;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _activityListener = getIt<UserActivityService>().updateActivity;
    _scrollController.addListener(_activityListener);
    _selectedFilter = widget.initialFilter ?? widget.filters.keys.first;
  }

  @override
  void didUpdateWidget(covariant SyncListScaffold<T, F> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.filters.containsKey(_selectedFilter)) {
      _selectedFilter = widget.filters.keys.first;
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_activityListener)
      ..dispose();
    super.dispose();
  }

  EdgeInsetsDirectional _effectivePaddingForWidth(double width) {
    final base = widget.listPadding;

    double targetHorizontal;
    if (width >= 1800) {
      targetHorizontal = 196;
    } else if (width >= 1600) {
      targetHorizontal = 168;
    } else if (width >= 1400) {
      targetHorizontal = 136;
    } else if (width >= 1200) {
      targetHorizontal = 112;
    } else if (width >= 992) {
      targetHorizontal = 80;
    } else if (width >= 840) {
      targetHorizontal = 56;
    } else if (width >= 720) {
      targetHorizontal = 40;
    } else if (width >= 600) {
      targetHorizontal = 28;
    } else if (width >= 400) {
      targetHorizontal = 20;
    } else {
      targetHorizontal = (base.left + base.right) / 2;
    }

    final safeMax = width > 0 ? width / 2 - 32 : targetHorizontal;
    if (safeMax > 0 && targetHorizontal > safeMax) {
      targetHorizontal = safeMax;
    }

    final start = base.left >= targetHorizontal ? base.left : targetHorizontal;
    final end = base.right >= targetHorizontal ? base.right : targetHorizontal;

    return EdgeInsetsDirectional.only(
      start: start,
      end: end,
      top: base.top,
      bottom: base.bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: widget.stream,
      builder: (context, snapshot) {
        final locale = Localizations.localeOf(context).toString();
        final items = snapshot.data ?? <T>[];

        final counts = <F, int>{
          for (final entry in widget.filters.entries)
            entry.key: items.where(entry.value.predicate).length,
        };

        final filteredItems =
            items.where(widget.filters[_selectedFilter]!.predicate).toList();

        final hasData = snapshot.hasData;

        return LayoutBuilder(
          builder: (context, constraints) {
            final effectivePadding =
                _effectivePaddingForWidth(constraints.maxWidth);
            final horizontalPaddingForEmpty =
                (effectivePadding.start + effectivePadding.end) / 2;
            final listPadding = EdgeInsets.only(
              left: effectivePadding.start,
              right: effectivePadding.end,
              top: AppTheme.spacingSmall,
              bottom: effectivePadding.bottom,
            );

            final summaryLabel = _formatLabel(
              context,
              widget.filters[_selectedFilter]!,
              locale,
            );
            final summaryText = widget.countSummaryBuilder(
              context,
              summaryLabel,
              filteredItems.length,
            );

            // Build labels, counts, and icon presence lists for height calculation.
            final filterEntries =
                widget.filters.entries.toList(growable: false);
            final labels = filterEntries
                .map((e) => toBeginningOfSentenceCase(
                      e.value.labelBuilder(context),
                      locale,
                    ))
                .toList();
            final countsList =
                filterEntries.map((e) => counts[e.key] ?? 0).toList();
            final haveIcons =
                filterEntries.map((e) => e.value.icon != null).toList();

            // Calculate dynamic header height based on actual content.
            final headerHorizontalPadding =
                effectivePadding.start + effectivePadding.end;
            final headerHeight =
                SettingsHeaderDimensions.calculateFilterHeaderHeight(
              context: context,
              labels: labels,
              counts: countsList,
              haveIcons: haveIcons,
              availableWidth: constraints.maxWidth,
              horizontalPadding: headerHorizontalPadding,
              summaryText: summaryText,
            );

            final headerBottom = _SyncHeaderBottom<T, F>(
              filters: widget.filters,
              counts: counts,
              selected: _selectedFilter,
              onChanged: (value) => setState(() => _selectedFilter = value),
              locale: locale,
              summaryText: summaryText,
              padding: EdgeInsetsDirectional.only(
                start: effectivePadding.start,
                end: effectivePadding.end,
              ),
              preferredHeight: headerHeight,
            );

            return Scaffold(
              body: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SettingsPageHeader(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    showBackButton: widget.backButton,
                    bottom: headerBottom,
                  ),
                  if (!hasData)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    )
                  else if (filteredItems.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsetsDirectional.symmetric(
                            horizontal: horizontalPaddingForEmpty,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: EmptyStateWidget(
                              icon: widget.emptyIcon,
                              title: widget.emptyTitleBuilder(context),
                              description:
                                  widget.emptyDescriptionBuilder?.call(context),
                            ).animate().fadeIn(
                                  duration: const Duration(
                                    milliseconds: AppTheme.animationDuration,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: listPadding,
                      sliver: SliverList(
                        key: widget.listKey,
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index.isEven) {
                              final itemIndex = index ~/ 2;
                              return widget.itemBuilder(
                                context,
                                filteredItems[itemIndex],
                              );
                            }
                            return const SizedBox(height: AppTheme.cardSpacing);
                          },
                          childCount: filteredItems.isEmpty
                              ? 0
                              : filteredItems.length * 2 - 1,
                          addAutomaticKeepAlives: false,
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: EdgeInsetsDirectional.only(
                      start: effectivePadding.start,
                      end: effectivePadding.end,
                      bottom: effectivePadding.bottom,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: SizedBox(height: widget.listPadding.bottom),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatLabel(
    BuildContext context,
    SyncFilterOption<T> option,
    String locale,
  ) {
    final base = option.labelBuilder(context);
    return toBeginningOfSentenceCase(base, locale) ?? base;
  }
}

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
          final selectedColor = entry.value.selectedColor ??
              Theme.of(context).colorScheme.primary;
          final selectedForeground = entry.value.selectedForegroundColor ??
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

class _SyncHeaderBottom<T, F extends Enum> extends StatelessWidget
    implements PreferredSizeWidget {
  const _SyncHeaderBottom({
    required this.filters,
    required this.counts,
    required this.selected,
    required this.onChanged,
    required this.locale,
    required this.summaryText,
    required this.padding,
    required this.preferredHeight,
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
    final foregroundColor =
        isSelected ? selectedForegroundColor : colorScheme.onSurface;
    final iconColor =
        isSelected ? selectedForegroundColor : colorScheme.onSurfaceVariant;
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
              borderRadius:
                  BorderRadius.circular(AppTheme.cardBorderRadius / 1.6),
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
