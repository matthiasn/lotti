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

part 'sync_list_scaffold_widgets.dart';

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
    required this.filters,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyTitleBuilder,
    required this.countSummaryBuilder,
    this.stream,
    this.items,
    this.isLoading = false,
    this.onRefresh,
    this.subtitle,
    this.emptyDescriptionBuilder,
    this.initialFilter,
    this.listPadding = const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
    this.headerSliver,
    this.listKey,
    this.backButton = true,
    super.key,
  }) : assert(
         stream == null || items == null,
         'Provide at most one of `stream` or `items`. Pass `items: null` '
         'with `isLoading: true` to render the spinner before the first '
         'fetch resolves; with `isLoading: false` it falls through to the '
         'empty state.',
       );

  /// Sliver page title.
  final String title;
  final String? subtitle;

  /// Source stream that yields the full set of items. Filtering occurs
  /// locally. Mutually exclusive with [items]; pages that prefer
  /// fetch-on-demand should pass [items] + [onRefresh] instead so they
  /// do not hold a live `watch()` open.
  final Stream<List<T>>? stream;

  /// Pre-fetched item snapshot. When non-null, [stream] must be null.
  /// `null` together with [isLoading] = `true` shows the loading
  /// spinner; `null` with [isLoading] = `false` is treated as empty.
  final List<T>? items;

  /// When true and [items] is null, render the loading spinner. Used
  /// while the first fetch is in flight on snapshot-based pages.
  final bool isLoading;

  /// Optional pull-to-refresh handler. When set, the scaffold wraps its
  /// scroll view in a Material `RefreshIndicator`.
  final Future<void> Function()? onRefresh;

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
  )
  countSummaryBuilder;

  /// Initial segment selection. Defaults to the first entry in [filters].
  final F? initialFilter;

  /// Padding applied around the list.
  final EdgeInsets listPadding;

  /// Optional key applied to the list view.
  final Key? listKey;

  /// Optional widget inserted as a sliver between the header and list content.
  final Widget? headerSliver;

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
    if (widget.stream != null) {
      return StreamBuilder<List<T>>(
        stream: widget.stream,
        builder: (context, snapshot) => _buildBody(
          context,
          items: snapshot.data ?? <T>[],
          hasData: snapshot.hasData,
        ),
      );
    }

    return _buildBody(
      context,
      items: widget.items ?? <T>[],
      hasData: !widget.isLoading || widget.items != null,
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required List<T> items,
    required bool hasData,
  }) {
    final locale = Localizations.localeOf(context).toString();

    final counts = <F, int>{
      for (final entry in widget.filters.entries)
        entry.key: items.where(entry.value.predicate).length,
    };

    final filteredItems = items
        .where(widget.filters[_selectedFilter]!.predicate)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectivePadding = _effectivePaddingForWidth(
          constraints.maxWidth,
        );
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
        final filterEntries = widget.filters.entries.toList(
          growable: false,
        );
        final labels = filterEntries
            .map(
              (e) => toBeginningOfSentenceCase(
                e.value.labelBuilder(context),
                locale,
              ),
            )
            .toList();
        final countsList = filterEntries
            .map((e) => counts[e.key] ?? 0)
            .toList();
        final haveIcons = filterEntries
            .map((e) => e.value.icon != null)
            .toList();

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

        final scrollView = CustomScrollView(
          controller: _scrollController,
          // RefreshIndicator needs the scroll view to be reachable
          // even when the list is empty — otherwise pull-to-refresh
          // can't be triggered from the empty state.
          physics: widget.onRefresh != null
              ? const AlwaysScrollableScrollPhysics()
              : null,
          slivers: [
            SettingsPageHeader(
              title: widget.title,
              subtitle: widget.subtitle,
              showBackButton: widget.backButton,
              bottom: headerBottom,
            ),
            if (widget.headerSliver != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: effectivePadding.start,
                    end: effectivePadding.end,
                  ),
                  child: widget.headerSliver,
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
                  child: Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: horizontalPaddingForEmpty,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child:
                          EmptyStateWidget(
                            icon: widget.emptyIcon,
                            title: widget.emptyTitleBuilder(context),
                            description: widget.emptyDescriptionBuilder?.call(
                              context,
                            ),
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
        );

        final onRefresh = widget.onRefresh;
        return Scaffold(
          body: onRefresh == null
              ? scrollView
              : RefreshIndicator(
                  onRefresh: onRefresh,
                  child: scrollView,
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
