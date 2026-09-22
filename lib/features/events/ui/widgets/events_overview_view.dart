import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/chips/active_filter_chip.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/components/headers/tab_section_header.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_card.dart';
import 'package:lotti/features/events/ui/widgets/event_feature_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_launcher.dart';
import 'package:material_ui/material_ui.dart';

/// The Events overview: a memory-forward, photo-led wall of event cards,
/// grouped into time sections, searchable and filterable by category.
///
/// Pure/presentational — it takes already-resolved [sections] and renders the
/// shared tab header (title, search field, filter funnel), the removable chips
/// of the active category filter, and a responsive card layout: featured
/// sections become full-width hero cards, ordinary sections become a
/// width-filling card grid. Header and cards share one content column, so the
/// title, the search field and the first card start on the same edge. A page
/// supplies the data; this widget owns only layout.
class EventsOverviewView extends StatelessWidget {
  const EventsOverviewView({
    required this.sections,
    this.query = '',
    this.activeCategories = const [],
    this.onQueryChanged,
    this.onFilterPressed,
    this.onRemoveCategory,
    this.onClearFilters,
    this.onOpenEvent,
    this.onCreate,
    this.onLoadMore,
    this.isLoadingMore = false,
    super.key,
  });

  final List<EventSection> sections;

  /// The search text, seeded into the header's field.
  final String query;

  /// Categories currently narrowing the list, rendered as removable chips.
  final List<EventCategoryFilter> activeCategories;

  /// Called on every edit of the search field, and with `''` when cleared.
  final ValueChanged<String>? onQueryChanged;

  /// Opens the category filter. The funnel tints while [activeCategories]
  /// is non-empty.
  final VoidCallback? onFilterPressed;

  /// Removes one category from the filter (the chip's id).
  final ValueChanged<String>? onRemoveCategory;

  /// Drops the query and every category at once.
  final VoidCallback? onClearFilters;

  final ValueChanged<EventCardData>? onOpenEvent;

  /// Creates an event. Floats as the page's action button, unless the mobile
  /// navigation launcher docks it on its own row.
  final VoidCallback? onCreate;

  /// Called when the user scrolls near the bottom and more pages remain. Null
  /// when the full archive is loaded, which also hides the trailing spinner.
  final VoidCallback? onLoadMore;

  /// Whether the next page is currently being fetched (shows a trailing
  /// progress indicator).
  final bool isLoadingMore;

  /// Target card width; column count is derived from the available width.
  static const double _targetCardWidth = 280;

  bool get _isFiltered =>
      activeCategories.isNotEmpty || query.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final gap = tokens.spacing.step4;
    final create = onCreate;
    final showFab =
        create != null && !mobileNavigationLauncherOwnsPageActions(context);

    return Scaffold(
      backgroundColor: dsPageSurface(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: showFab
          ? DesignSystemBottomNavigationFabPadding(
              // A bare glyph, like Projects: the page title already says
              // what the plus makes (see [MobileNavDockAction]).
              child: DesignSystemFloatingActionButton(
                semanticLabel: context.messages.eventsNewEvent,
                onPressed: create,
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        // One LayoutBuilder at the top resolves the shared content column and
        // the grid's column count, so the lazy slivers below can chunk events
        // into rows without each re-measuring.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final insets = detailContentInsets(
              context,
              availableWidth: constraints.maxWidth,
            );
            final contentWidth = constraints.maxWidth - insets.horizontal;
            final columns = (contentWidth / _targetCardWidth).floor().clamp(
              1,
              4,
            );
            return NotificationListener<ScrollNotification>(
              // Fetch the next page as the user nears the bottom. The controller
              // ignores repeat calls while a fetch is in flight or the archive
              // is fully loaded, so firing on every scroll tick is safe.
              onNotification: (notification) {
                final loadMore = onLoadMore;
                // depth == 0 keeps nested scrollables (the search field's own
                // horizontal text scroll) from triggering pagination.
                if (loadMore != null &&
                    notification.depth == 0 &&
                    notification.metrics.axis == Axis.vertical &&
                    notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 600) {
                  loadMore();
                }
                return false;
              },
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: TabSectionHeader(
                      title: context.messages.eventsPageTitle,
                      query: query,
                      searchHint: context.messages.eventsSearchHint,
                      filterTooltip: context.messages.eventsFilterTooltip,
                      filtersActive: activeCategories.isNotEmpty,
                      onSearchChanged: (value) => onQueryChanged?.call(value),
                      onSearchCleared: () => onQueryChanged?.call(''),
                      onSearchPressed: (value) => onQueryChanged?.call(value),
                      onFilterPressed: () => onFilterPressed?.call(),
                    ),
                  ),
                  if (activeCategories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _ActiveFilters(
                        categories: activeCategories,
                        searchActive: query.trim().isNotEmpty,
                        onRemoveCategory: onRemoveCategory,
                        onClearFilters: onClearFilters,
                      ),
                    ),
                  if (sections.isEmpty && _isFiltered)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: DesignSystemEmptyState(
                        icon: LottiIcons.searchOff,
                        title: context.messages.eventsNoResults,
                        action: onClearFilters == null
                            ? null
                            : DesignSystemButton(
                                label: context.messages.tasksFilterClearAll,
                                variant: DesignSystemButtonVariant.secondary,
                                onPressed: onClearFilters,
                              ),
                      ),
                    ),
                  for (final (index, section) in sections.indexed) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        // The first section sits one beat under the header so
                        // it reads as the start of the content; later
                        // sections keep the wider break between years.
                        padding: insets.copyWith(
                          top: index == 0
                              ? tokens.spacing.step4
                              : tokens.spacing.step7,
                          bottom: tokens.spacing.step3,
                        ),
                        child: Text(
                          section.title,
                          style: tokens.typography.styles.subtitle.subtitle1
                              .copyWith(color: tokens.colors.text.highEmphasis),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: insets,
                      sliver: section.featured
                          ? _featuredSliver(section, gap)
                          : _gridSliver(
                              section,
                              columns: columns,
                              contentWidth: contentWidth,
                              gap: gap,
                            ),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: tokens.spacing.step6,
                      ),
                      child: Center(
                        child: isLoadingMore
                            ? const CircularProgressIndicator()
                            // Clears the floating action button, so the last
                            // row of cards can scroll out from under it.
                            : SizedBox(height: tokens.spacing.step10),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Featured sections (Upcoming) render one full-width hero card per row, built
  /// lazily so a long upcoming list doesn't decode every cover up front.
  Widget _featuredSliver(EventSection section, double gap) {
    final events = section.events;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final event = events[index];
          return Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: EventFeatureCard(
              data: event,
              onTap: onOpenEvent == null ? null : () => onOpenEvent!(event),
            ),
          );
        },
        childCount: events.length,
      ),
    );
  }

  /// Ordinary sections render a width-filling card grid as a lazy [SliverList]
  /// of row chunks: only rows near the viewport are built, so hundreds of events
  /// never instantiate hundreds of cards (and decode hundreds of cover photos)
  /// at once — the cause of the mobile OOM crash. Off-screen rows stay unbuilt.
  Widget _gridSliver(
    EventSection section, {
    required int columns,
    required double contentWidth,
    required double gap,
  }) {
    final events = section.events;
    final rawWidth = columns <= 1
        ? contentWidth
        : (contentWidth - gap * (columns - 1)) / columns;
    final cardWidth = rawWidth.isFinite && rawWidth > 0
        ? rawWidth
        : contentWidth;
    final rowCount = (events.length + columns - 1) ~/ columns;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, rowIndex) {
          final start = rowIndex * columns;
          final end = (start + columns) > events.length
              ? events.length
              : start + columns;
          return Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = start; i < end; i++) ...[
                  if (i > start) SizedBox(width: gap),
                  SizedBox(
                    width: cardWidth,
                    child: EventCard(
                      data: events[i],
                      onTap: onOpenEvent == null
                          ? null
                          : () => onOpenEvent!(events[i]),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        childCount: rowCount,
      ),
    );
  }
}

/// The active category filter as removable chips — the same row the Tasks and
/// Projects tabs render under their header. Each chip wears its category's
/// own colour, so a category reads as one colour on the chip and on its cards.
/// From two narrowings up (the search query counts as one), a "Clear all"
/// chip ends the whole filter session in one tap.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.categories,
    required this.searchActive,
    required this.onRemoveCategory,
    required this.onClearFilters,
  });

  final List<EventCategoryFilter> categories;
  final bool searchActive;
  final ValueChanged<String>? onRemoveCategory;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final clearAll = onClearFilters;
    final showClearAll =
        clearAll != null && categories.length + (searchActive ? 1 : 0) >= 2;

    return DetailContentWidth(
      child: Padding(
        padding: EdgeInsets.only(
          top: tokens.spacing.step2,
          bottom: tokens.spacing.step3,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: tokens.spacing.step3,
            runSpacing: tokens.spacing.step3,
            children: [
              for (final category in categories)
                ActiveFilterChip(
                  label: category.label,
                  accentColor: category.color,
                  onRemove: () => onRemoveCategory?.call(category.id),
                ),
              // No extra leading pad (unlike the row's single-chip removals):
              // when the action wraps, a pad would indent it off the column
              // edge the chips above start on.
              if (showClearAll)
                DesignSystemChip(
                  size: DesignSystemChipSize.compactPill,
                  label: context.messages.tasksFilterClearAll,
                  leadingIcon: LottiIcons.close,
                  onPressed: clearAll,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
