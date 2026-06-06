import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';

void main() {
  // -------------------------------------------------------------------------
  // EventData JSON round-trips — static examples
  // -------------------------------------------------------------------------
  group('EventData JSON round-trips — static examples', () {
    EventData roundTrip(EventData d) => EventData.fromJson(
      jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>,
    );

    test('EventData with tentative status survives JSON round-trip', () {
      const d = EventData(
        title: 'Team standup',
        stars: 3,
        status: EventStatus.tentative,
      );
      final decoded = roundTrip(d);
      expect(decoded, d, reason: 'tentative EventData round-trip');
      expect(decoded.title, 'Team standup');
      expect(decoded.stars, 3.0);
      expect(decoded.status, EventStatus.tentative);
    });

    test('EventData with planned status survives JSON round-trip', () {
      const d = EventData(
        title: 'Sprint planning',
        stars: 4.5,
        status: EventStatus.planned,
      );
      final decoded = roundTrip(d);
      expect(decoded, d, reason: 'planned EventData round-trip');
      expect(decoded.status, EventStatus.planned);
      expect(decoded.stars, 4.5);
    });

    test('EventData with completed status survives JSON round-trip', () {
      const d = EventData(
        title: 'Q1 review',
        stars: 5,
        status: EventStatus.completed,
      );
      final decoded = roundTrip(d);
      expect(decoded, d, reason: 'completed EventData round-trip');
      expect(decoded.status, EventStatus.completed);
      expect(decoded.stars, 5.0);
    });

    test('EventData with cancelled status survives JSON round-trip', () {
      const d = EventData(
        title: 'Cancelled meeting',
        stars: 0,
        status: EventStatus.cancelled,
      );
      final decoded = roundTrip(d);
      expect(decoded, d, reason: 'cancelled EventData round-trip');
      expect(decoded.status, EventStatus.cancelled);
    });

    test('EventData with missed status survives JSON round-trip', () {
      const d = EventData(
        title: 'Missed dentist',
        stars: 1,
        status: EventStatus.missed,
      );
      final decoded = roundTrip(d);
      expect(decoded, d, reason: 'missed EventData round-trip');
      expect(decoded.status, EventStatus.missed);
    });

    test('EventData with zero stars survives JSON round-trip', () {
      const d = EventData(
        title: 'Boring event',
        stars: 0,
        status: EventStatus.ongoing,
      );
      final decoded = roundTrip(d);
      expect(decoded, d);
      expect(decoded.stars, 0.0);
    });

    test('EventData with fractional stars survives JSON round-trip', () {
      const d = EventData(
        title: 'Half-good event',
        stars: 2.5,
        status: EventStatus.postponed,
      );
      final decoded = roundTrip(d);
      expect(decoded, d);
      expect(decoded.stars, closeTo(2.5, 1e-10));
    });

    test('EventData toJson emits correct keys', () {
      const d = EventData(
        title: 'Demo',
        stars: 3,
        status: EventStatus.rescheduled,
      );
      final json = d.toJson();
      expect(json.containsKey('title'), isTrue, reason: 'title key present');
      expect(json.containsKey('stars'), isTrue, reason: 'stars key present');
      expect(json.containsKey('status'), isTrue, reason: 'status key present');
      expect(json['title'], 'Demo');
      expect(json['stars'], 3.0);
    });

    test('EventData with special-character title survives JSON round-trip', () {
      const d = EventData(
        title: 'Meeting: "year-end" & review — 2024',
        stars: 4,
        status: EventStatus.completed,
      );
      final decoded = roundTrip(d);
      expect(decoded, d);
      expect(decoded.title, 'Meeting: "year-end" & review — 2024');
    });
  });

  // -------------------------------------------------------------------------
  // EventData equality
  // -------------------------------------------------------------------------
  group('EventData equality', () {
    test('two EventData with same fields are equal', () {
      const a = EventData(
        title: 'A',
        stars: 2,
        status: EventStatus.planned,
      );
      const b = EventData(
        title: 'A',
        stars: 2,
        status: EventStatus.planned,
      );
      expect(a, b);
    });

    test('EventData with different status are not equal', () {
      const a = EventData(
        title: 'A',
        stars: 2,
        status: EventStatus.planned,
      );
      const b = EventData(
        title: 'A',
        stars: 2,
        status: EventStatus.completed,
      );
      expect(a, isNot(equals(b)));
    });

    test('EventData with different stars are not equal', () {
      const a = EventData(
        title: 'A',
        stars: 1,
        status: EventStatus.planned,
      );
      const b = EventData(
        title: 'A',
        stars: 2,
        status: EventStatus.planned,
      );
      expect(a, isNot(equals(b)));
    });
  });

  // -------------------------------------------------------------------------
  // EventData Glados round-trip — all 8 EventStatus variants
  // -------------------------------------------------------------------------
  group('EventData Glados round-trips', () {
    glados.Glados<_GeneratedEventData>(
      glados.any.generatedEventData,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'EventData round-trips through JSON for any status and stars',
      (scenario) {
        final d = scenario.eventData;
        final decoded = EventData.fromJson(
          jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>,
        );
        expect(decoded, d, reason: '$scenario');
        expect(decoded.title, d.title, reason: 'title preserved');
        expect(
          decoded.stars,
          closeTo(d.stars, 1e-10),
          reason: 'stars preserved',
        );
        expect(decoded.status, d.status, reason: 'status preserved');
      },
      tags: 'glados',
    );
  });
}

// ---------------------------------------------------------------------------
// Glados generator helpers for EventData.
// ---------------------------------------------------------------------------

class _GeneratedEventData {
  const _GeneratedEventData({
    required this.titleSlot,
    required this.starsSlot,
    required this.statusSlot,
  });

  final int titleSlot;
  final int starsSlot;
  final int statusSlot;

  static const _titles = <String>[
    'Team standup',
    'Sprint retrospective',
    'Q4 planning',
    'Client demo',
    'Design review',
  ];

  EventData get eventData {
    final title = _titles[titleSlot % _titles.length];
    // stars: 0.0, 0.5, 1.0, … up to ~5.0
    final stars = (starsSlot % 11) * 0.5;
    final status = EventStatus.values[statusSlot % EventStatus.values.length];
    return EventData(title: title, stars: stars, status: status);
  }

  @override
  String toString() =>
      '_GeneratedEventData(titleSlot: $titleSlot, '
      'starsSlot: $starsSlot, statusSlot: $statusSlot)';
}

extension _AnyEventData on glados.Any {
  glados.Generator<_GeneratedEventData> get generatedEventData =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(0, 10),
        glados.IntAnys(this).intInRange(0, EventStatus.values.length - 1),
        (titleSlot, starsSlot, statusSlot) => _GeneratedEventData(
          titleSlot: titleSlot,
          starsSlot: starsSlot,
          statusSlot: statusSlot,
        ),
      );
}
