import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/events/state/event_view_mapping.dart';
import 'package:lotti/features/events/state/events_controller.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/events_overview_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';

/// Route-level page for the Events overview.
///
/// Watches [eventsStreamProvider], maps the resolved events into localized
/// cards and time sections (the locale-dependent labelling that the pure view
/// models can't do), and renders them in [EventsOverviewView]. Owns the
/// category-filter selection and the create/open navigation.
class EventsOverviewPage extends ConsumerStatefulWidget {
  const EventsOverviewPage({super.key});

  @override
  ConsumerState<EventsOverviewPage> createState() => _EventsOverviewPageState();
}

class _EventsOverviewPageState extends ConsumerState<EventsOverviewPage> {
  String? _selectedCategoryId;

  Future<void> _createEvent() async {
    final event = await createEvent();
    if (event != null) {
      beamToNamed('/events/${event.meta.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncEvents = ref.watch(eventsStreamProvider);
    return asyncEvents.when(
      skipLoadingOnReload: true,
      data: (resolved) => _content(context, resolved),
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

  Widget _content(BuildContext context, List<ResolvedEvent> resolved) {
    final messages = context.messages;
    final now = DateTime.now();
    final fallbackTitle = messages.entryTypeLabelJournalEvent;

    // First-seen colour/name per category, for the filter chips.
    final categoryColors = <String, Color>{};
    final categoryNames = <String, String>{};
    for (final r in resolved) {
      final id = r.event.meta.categoryId;
      final name = r.categoryName;
      if (id != null && name != null) {
        categoryColors.putIfAbsent(id, () => r.categoryColor);
        categoryNames.putIfAbsent(id, () => name);
      }
    }

    final visible = _selectedCategoryId == null
        ? resolved
        : resolved
              .where((r) => r.event.meta.categoryId == _selectedCategoryId)
              .toList();

    final cards = [
      for (final r in visible)
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

    final categories = <EventCategoryFilter>[
      if (categoryNames.isNotEmpty)
        EventCategoryFilter(
          id: null,
          label: messages.eventsFilterAll,
          color: context.colorScheme.primary,
        ),
      for (final entry in categoryNames.entries)
        EventCategoryFilter(
          id: entry.key,
          label: entry.value,
          color: categoryColors[entry.key]!,
        ),
    ];

    return EventsOverviewView(
      sections: sections,
      categories: categories,
      selectedCategoryId: _selectedCategoryId,
      onSelectCategory: (id) => setState(() => _selectedCategoryId = id),
      onOpenEvent: (event) => beamToNamed('/events/${event.id}'),
      onCreate: _createEvent,
    );
  }
}
