import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/relationships_location.dart';
import 'package:lotti/features/relationships/ui/pages/relationship_chat_page.dart';
import 'package:lotti/features/relationships/ui/pages/relationship_details_page.dart';
import 'package:lotti/features/relationships/ui/pages/relationships_page.dart';

import '../../widget_test_utils.dart';

void main() {
  group('RelationshipsLocation', () {
    // buildPages resolves localized page titles, so it needs a real,
    // localization-carrying context rather than a mock.
    Future<BuildContext> localizedContext(WidgetTester tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return context;
    }

    List<BeamPage> pagesFor(BuildContext context, String path) {
      final location = RelationshipsLocation(
        RouteInformation(uri: Uri.parse(path)),
      );
      return location.buildPages(context, location.state);
    }

    test('exposes the people path patterns', () {
      final location = RelationshipsLocation(
        RouteInformation(uri: Uri.parse('/people')),
      );
      expect(location.pathPatterns, [
        '/people',
        '/people/:relationshipId',
        '/people/:relationshipId/chat',
      ]);
    });

    testWidgets('builds a single list page for /people', (tester) async {
      final context = await localizedContext(tester);

      final pages = pagesFor(context, '/people');

      expect(pages, hasLength(1));
      expect(pages.single.child, isA<RelationshipsPage>());
      expect(pages.single.key, const ValueKey('people'));
    });

    testWidgets('pushes the detail page on top for /people/<id>', (
      tester,
    ) async {
      final context = await localizedContext(tester);

      final pages = pagesFor(context, '/people/rel-1');

      expect(pages, hasLength(2));
      expect(pages[0].child, isA<RelationshipsPage>());
      final detail = pages[1].child;
      expect(detail, isA<RelationshipDetailsPage>());
      expect((detail as RelationshipDetailsPage).relationshipId, 'rel-1');
      expect(pages[1].key, const ValueKey('people-details-rel-1'));
    });

    testWidgets('stacks the chat page above the detail for '
        '/people/<id>/chat', (tester) async {
      final context = await localizedContext(tester);

      final pages = pagesFor(context, '/people/rel-1/chat');

      expect(pages, hasLength(3));
      expect(pages[1].child, isA<RelationshipDetailsPage>());
      final chat = pages[2].child;
      expect(chat, isA<RelationshipChatPage>());
      expect((chat as RelationshipChatPage).relationshipId, 'rel-1');
      expect(pages[2].key, const ValueKey('people-chat-rel-1'));
    });

    testWidgets('a plain detail path never mounts the chat page', (
      tester,
    ) async {
      final context = await localizedContext(tester);

      final pages = pagesFor(context, '/people/rel-1');

      expect(
        pages.map((page) => page.child),
        isNot(contains(isA<RelationshipChatPage>())),
      );
    });
  });
}
