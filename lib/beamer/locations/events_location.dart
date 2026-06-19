import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/events/ui/pages/event_detail_page.dart';
import 'package:lotti/features/events/ui/pages/events_overview_page.dart';
import 'package:lotti/utils/uuid.dart';

/// Beamer location for the first-class Events feature: the overview at
/// `/events` and a single event's detail at `/events/:eventId`.
class EventsLocation extends BeamLocation<BeamState> {
  EventsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => ['/events', '/events/:eventId'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final eventId = state.pathParameters['eventId'];

    return [
      const BeamPage(
        key: ValueKey('events'),
        title: 'Events',
        child: EventsOverviewPage(),
      ),
      if (isUuid(eventId))
        BeamPage(
          key: ValueKey('events-$eventId'),
          child: EventDetailPage(eventId: eventId!),
        ),
    ];
  }
}
