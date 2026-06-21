import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/state/event_view_mapping.dart';
import 'package:lotti/features/events/state/events_overview_controller.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/events_overview_view.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';

/// Route-level page for the Events overview.
///
/// Watches [eventsOverviewControllerProvider] — a paged, category-filterable
/// source that loads the archive a page at a time — maps the loaded events into
/// localized cards and time sections, and renders them in [EventsOverviewView].
/// Scrolling near the bottom fetches the next page; the category chips (sourced
/// from all active categories) filter server-side so results stay correct across
/// pages.
class EventsOverviewPage extends ConsumerStatefulWidget {
  const EventsOverviewPage({super.key});

  @override
  ConsumerState<EventsOverviewPage> createState() => _EventsOverviewPageState();
}

class _EventsOverviewPageState extends ConsumerState<EventsOverviewPage> {
  Future<void> _createEvent() async {
    final event = await createEvent();
    if (event != null) {
      beamToNamed('/events/${event.meta.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncEvents = ref.watch(eventsOverviewControllerProvider);
    return asyncEvents.when(
      skipLoadingOnReload: true,
      data: (data) => _content(context, data),
      loading: () => Scaffold(
        backgroundColor: dsPageSurface(context),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: dsPageSurface(context),
        body: Center(
          child: Icon(
            Icons.error_outline_rounded,
            color: context.colorScheme.error,
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, EventsOverviewState data) {
    final messages = context.messages;
    final now = DateTime.now();
    final fallbackTitle = messages.entryTypeLabelJournalEvent;
    final controller = ref.read(eventsOverviewControllerProvider.notifier);

    final cards = [
      for (final r in data.events)
        eventCardDataFromEvent(
          r.event,
          dateLabel: eventDateLabel(r.event.meta.dateFrom, now),
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

    // Chips come from all active categories (not just the loaded page), so the
    // filter is stable and complete regardless of how far the user has scrolled.
    final activeCategories = getIt<EntitiesCacheService>().sortedCategories;
    final categories = <EventCategoryFilter>[
      if (activeCategories.isNotEmpty)
        EventCategoryFilter(
          id: null,
          label: messages.eventsFilterAll,
          color: context.colorScheme.primary,
        ),
      for (final category in activeCategories)
        EventCategoryFilter(
          id: category.id,
          label: category.name,
          color: colorFromCssHex(category.color),
        ),
    ];

    return EventsOverviewView(
      sections: sections,
      categories: categories,
      selectedCategoryId: data.categoryId,
      onSelectCategory: controller.setCategory,
      onOpenEvent: (event) => beamToNamed('/events/${event.id}'),
      onCreate: _createEvent,
      onLoadMore: data.hasMore ? controller.loadMore : null,
      isLoadingMore: data.isLoadingMore,
    );
  }
}
