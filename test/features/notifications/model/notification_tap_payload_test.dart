import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/notifications/model/notification_tap_payload.dart';

void main() {
  group('NotificationTapPayload.encode', () {
    test('writes the route and the inbox row as one JSON object', () {
      const payload = NotificationTapPayload(
        route: '/people/rel-1',
        inboxId: 'row-1',
      );

      expect(
        jsonDecode(payload.encode()),
        {'route': '/people/rel-1', 'inboxId': 'row-1'},
      );
    });

    test('omits the inbox key for a notification without a row', () {
      const payload = NotificationTapPayload(route: '/calendar');

      expect(jsonDecode(payload.encode()), {'route': '/calendar'});
    });
  });

  group('NotificationTapPayload.decode', () {
    test('reads back a payload with a row', () {
      const payload = NotificationTapPayload(
        route: '/tasks/task-1',
        inboxId: 'row-1',
      );

      expect(NotificationTapPayload.decode(payload.encode()), payload);
    });

    test('reads back a payload without a row', () {
      const payload = NotificationTapPayload(route: '/habits');

      expect(NotificationTapPayload.decode(payload.encode()), payload);
    });

    test(
      'accepts a bare route — what rowless producers pass and what every '
      'alarm armed before tap routing still carries',
      () {
        expect(
          NotificationTapPayload.decode('/settings/advanced/conflicts'),
          const NotificationTapPayload(route: '/settings/advanced/conflicts'),
        );
      },
    );

    test('drops an empty inbox id but keeps the route', () {
      expect(
        NotificationTapPayload.decode('{"route":"/tasks/t","inboxId":""}'),
        const NotificationTapPayload(route: '/tasks/t'),
      );
    });

    test('drops an inbox id that is not a string but keeps the route', () {
      // The screen is what the user tapped for; a malformed row reference is
      // not a reason to leave them where they were.
      expect(
        NotificationTapPayload.decode('{"route":"/tasks/t","inboxId":7}'),
        const NotificationTapPayload(route: '/tasks/t'),
      );
    });

    for (final (label, raw) in <(String, String?)>[
      ('null', null),
      ('an empty string', ''),
      ('a path without a leading slash', 'calendar'),
      ('prose', 'not a payload'),
      ('truncated JSON', '{"route": "/tasks'),
      ('a JSON array', '[1, 2]'),
      ('a JSON object without a route', '{"inboxId": "row-1"}'),
      ('a route that is not a string', '{"route": 5}'),
      ('a route without a leading slash', '{"route": "tasks/t"}'),
    ]) {
      test('rejects $label', () {
        expect(NotificationTapPayload.decode(raw), isNull);
      });
    }
  });

  group('NotificationTapPayload value semantics', () {
    test('payloads with the same route and row are equal', () {
      const a = NotificationTapPayload(route: '/tasks/t', inboxId: 'row');
      const b = NotificationTapPayload(route: '/tasks/t', inboxId: 'row');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different row makes a different payload', () {
      const a = NotificationTapPayload(route: '/tasks/t', inboxId: 'row-1');
      const b = NotificationTapPayload(route: '/tasks/t', inboxId: 'row-2');
      const c = NotificationTapPayload(route: '/tasks/t');

      expect(a, isNot(b));
      expect(a, isNot(c));
    });

    test('toString names the route and the row', () {
      expect(
        const NotificationTapPayload(
          route: '/tasks/t',
          inboxId: 'row',
        ).toString(),
        'NotificationTapPayload(route: /tasks/t, inboxId: row)',
      );
    });
  });

  glados.Glados2<String, String>(
    glados.any.letterOrDigits,
    glados.any.letterOrDigits,
    glados.ExploreConfig(numRuns: 64),
  ).test(
    'every payload survives an encode/decode round trip',
    (segment, id) {
      final payload = NotificationTapPayload(
        route: '/$segment',
        inboxId: id.isEmpty ? null : id,
      );

      final encoded = payload.encode();

      expect(encoded, startsWith('{'));
      expect(NotificationTapPayload.decode(encoded), payload);
    },
    tags: 'glados',
  );
}
