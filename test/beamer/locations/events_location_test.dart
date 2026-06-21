import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/events_location.dart';
import 'package:lotti/features/events/ui/pages/event_detail_page.dart';
import 'package:lotti/features/events/ui/pages/events_overview_page.dart';
import 'package:mocktail/mocktail.dart';

class _MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('EventsLocation', () {
    late _MockBuildContext context;

    setUp(() => context = _MockBuildContext());

    List<BeamPage> pagesFor(String path) {
      final location = EventsLocation(
        RouteInformation(uri: Uri.parse(path)),
      );
      return location.buildPages(context, location.state);
    }

    test('exposes the events path patterns', () {
      final location = EventsLocation(
        RouteInformation(uri: Uri.parse('/events')),
      );
      expect(location.pathPatterns, ['/events', '/events/:eventId']);
    });

    test('builds a single overview page for /events', () {
      final pages = pagesFor('/events');
      expect(pages, hasLength(1));
      expect(pages.single.child, isA<EventsOverviewPage>());
      expect(pages.single.key, const ValueKey('events'));
    });

    test('pushes a detail page on top when the id is a uuid', () {
      const id = '11111111-1111-4111-8111-111111111111';
      final pages = pagesFor('/events/$id');

      expect(pages, hasLength(2));
      expect(pages[0].child, isA<EventsOverviewPage>());
      final detail = pages[1].child;
      expect(detail, isA<EventDetailPage>());
      expect((detail as EventDetailPage).eventId, id);
      expect(pages[1].key, const ValueKey('events-$id'));
    });

    test('ignores a non-uuid event id (overview only)', () {
      final pages = pagesFor('/events/not-a-uuid');
      expect(pages, hasLength(1));
      expect(pages.single.child, isA<EventsOverviewPage>());
    });
  });
}
