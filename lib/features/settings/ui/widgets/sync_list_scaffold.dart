import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/sliver_title_bar.dart';
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
    this.emptyDescriptionBuilder,
    this.initialFilter,
    this.listPadding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    this.listKey,
    this.backButton = true,
    super.key,
  });

  /// Sliver page title.
  final String title;

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
      _selectedFilter = widget.filters.keys.firstWhere((_) => true);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_activityListener)
      ..dispose();
    super.dispose();
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

        return Scaffold(
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverTitleBar(
                widget.title,
                showBackButton: widget.backButton,
                pinned: true,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: widget.listPadding.left,
                    right: widget.listPadding.right,
                    top: widget.listPadding.top,
                    bottom: AppTheme.spacingMedium,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FilterCard<F>(
                        filters: widget.filters,
                        counts: counts,
                        selected: _selectedFilter,
                        onChanged: (value) => setState(
                          () => _selectedFilter = value,
                        ),
                        locale: locale,
                      ),
                      const SizedBox(height: AppTheme.spacingLarge),
                      Text(
                        widget.countSummaryBuilder(
                          context,
                          _formatLabel(
                            context,
                            widget.filters[_selectedFilter]!,
                            locale,
                          ),
                          filteredItems.length,
                        ),
                        style: context.textTheme.titleSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingLarge),
                    ],
                  ).animate().fadeIn(
                        duration: const Duration(
                          milliseconds: AppTheme.animationDuration,
                        ),
                      ),
                ),
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
                )
              else
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: widget.listPadding.left,
                    right: widget.listPadding.right,
                    bottom: widget.listPadding.bottom,
                  ),
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
            ],
          ),
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
    return ModernBaseCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPadding,
        vertical: AppTheme.cardPaddingCompact,
      ),
      child: Center(
        child: SegmentedButton<F>(
          segments: filters.entries.map((entry) {
            final rawLabel = entry.value.labelBuilder(context);
            final label = toBeginningOfSentenceCase(
              rawLabel,
              locale,
            );
            final count = counts[entry.key] ?? 0;
            return ButtonSegment<F>(
              value: entry.key,
              icon: entry.value.icon == null
                  ? null
                  : Icon(
                      entry.value.icon,
                      size: AppTheme.iconSizeCompact,
                    ),
              label: _SegmentLabel(
                label: label,
                count: count,
                filter: entry.key.name,
              ),
            );
          }).toList(),
          showSelectedIcon: false,
          style: ButtonStyle(
            padding: WidgetStateProperty.all<EdgeInsets>(
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          selected: {selected},
          onSelectionChanged: (newSelection) {
            if (newSelection.isEmpty) {
              return;
            }
            onChanged(newSelection.first);
          },
        ),
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({
    required this.label,
    required this.count,
    required this.filter,
  });

  final String label;
  final int count;
  final String filter;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return Semantics(
      label: '$label, $count',
      child: Row(
        key: ValueKey('syncFilter-$filter'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.titleSmall,
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: context.colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count.toString(),
              style: textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
