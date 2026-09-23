import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/state/event_view_mapping.dart';
import 'package:lotti/features/events/state/events_overview_controller.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/events_filter_modal.dart';
import 'package:lotti/features/events/ui/widgets/events_overview_view.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_launcher.dart';
import 'package:material_ui/material_ui.dart';

/// Creates an event and opens it — the one create path shared by the page's
/// floating button and the mobile launcher's docked action.
Future<void> createEventAndOpen() async {
  final event = await createEvent();
  if (event != null) {
    beamToNamed('/events/${event.meta.id}');
  }
}

/// The Events tab's create action, docked on the mobile navigation launcher
/// while the tab is active. A bare glyph: the page's own title already says
/// what the plus makes.
MobileNavDockAction eventsTabDockAction(BuildContext context) =>
    MobileNavDockAction.glyph(
      label: context.messages.eventsNewEvent,
      icon: LottiIcons.add,
      onPressed: () => unawaited(createEventAndOpen()),
    );

/// Route-level page for the Events overview.
///
/// Watches [eventsOverviewControllerProvider] — a paged, searchable,
/// category-filterable source that loads the archive a page at a time — maps
/// the loaded events into localized cards and time sections, and renders them
/// in [EventsOverviewView]. The header's search field and filter funnel drive
/// the controller; scrolling near the bottom fetches the next page. The filter
/// offers every active category (not just the loaded page), so it is stable
/// and complete however far the user has scrolled.
class EventsOverviewPage extends ConsumerWidget {
  const EventsOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEvents = ref.watch(eventsOverviewControllerProvider);
    return asyncEvents.when(
      skipLoadingOnReload: true,
      data: (data) => _content(context, ref, data),
      loading: () => Scaffold(
        backgroundColor: dsPageSurface(context),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: dsPageSurface(context),
        body: Center(
          child: Icon(
            LottiIcons.error,
            color: context.colorScheme.error,
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    EventsOverviewState data,
  ) {
    final messages = context.messages;
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toString();
    final fallbackTitle = messages.entryTypeLabelJournalEvent;
    final controller = ref.read(eventsOverviewControllerProvider.notifier);

    final cards = [
      for (final r in data.events)
        eventCardDataFromEvent(
          r.event,
          dateLabel: eventDateLabel(
            r.event.meta.dateFrom,
            now,
            locale: locale,
          ),
          categoryColor: r.categoryColor,
          categoryName: r.categoryName,
          fallbackTitle: fallbackTitle,
          coverImage: r.coverImage,
        ),
    ];

    final sections = groupEventsIntoSections(
      cards,
      now: now,
      upcomingTitle: messages.eventsSectionUpcoming,
      yearTitle: (year) => '$year',
    );

    final categories = getIt<EntitiesCacheService>().sortedCategories;
    final selected = data.categoryIds;
    // Chips follow the filter sheet's order — Unassigned, then the sorted
    // categories — rather than the order the ids were picked in. A category
    // deleted since it was picked has no chip to show.
    final activeCategories = <EventCategoryFilter>[
      if (selected.contains(''))
        EventCategoryFilter(
          id: '',
          label: messages.tasksQuickFilterUnassignedLabel,
          color: context.designTokens.colors.text.mediumEmphasis,
        ),
      for (final category in categories)
        if (selected.contains(category.id))
          EventCategoryFilter(
            id: category.id,
            label: category.name,
            color: colorFromCssHex(category.color),
          ),
    ];

    return EventsOverviewView(
      sections: sections,
      query: data.query,
      activeCategories: activeCategories,
      onQueryChanged: (query) => unawaited(controller.setQuery(query)),
      onFilterPressed: () => unawaited(
        showEventsFilterModal(
          context: context,
          selectedCategoryIds: selected,
          categories: categories,
          onApplied: (ids) => unawaited(controller.setCategoryIds(ids)),
        ),
      ),
      onRemoveCategory: (id) =>
          unawaited(controller.setCategoryIds(selected.difference({id}))),
      onClearFilters: () => unawaited(controller.clearFilters()),
      onOpenEvent: (event) => beamToNamed('/events/${event.id}'),
      onCreate: () => unawaited(createEventAndOpen()),
      onLoadMore: data.hasMore ? controller.loadMore : null,
      isLoadingMore: data.isLoadingMore,
    );
  }
}
