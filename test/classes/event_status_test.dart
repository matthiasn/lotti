import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/event_status.dart';

void main() {
  // -------------------------------------------------------------------------
  // EventStatusX.label — all 8 branches
  // -------------------------------------------------------------------------
  group('EventStatusX.label — all variants', () {
    test('tentative label is TENTATIVE', () {
      expect(EventStatus.tentative.label, 'TENTATIVE');
    });

    test('planned label is PLANNED', () {
      expect(EventStatus.planned.label, 'PLANNED');
    });

    test('ongoing label is ONGOING', () {
      expect(EventStatus.ongoing.label, 'ONGOING');
    });

    test('completed label is COMPLETED', () {
      expect(EventStatus.completed.label, 'COMPLETED');
    });

    test('cancelled label is CANCELLED', () {
      expect(EventStatus.cancelled.label, 'CANCELLED');
    });

    test('postponed label is POSTPONED', () {
      expect(EventStatus.postponed.label, 'POSTPONED');
    });

    test('rescheduled label is RESCHEDULED', () {
      expect(EventStatus.rescheduled.label, 'RESCHEDULED');
    });

    test('missed label is MISSED', () {
      expect(EventStatus.missed.label, 'MISSED');
    });

    test('label is all-caps and non-empty for every variant', () {
      for (final status in EventStatus.values) {
        final lbl = status.label;
        expect(
          lbl,
          isNotEmpty,
          reason: '${status.name}.label must be non-empty',
        );
        expect(
          lbl,
          equals(lbl.toUpperCase()),
          reason: '${status.name}.label must be ALL_CAPS',
        );
      }
    });

    test('each variant has a unique label', () {
      final labels = EventStatus.values.map((s) => s.label).toList();
      expect(
        labels.toSet().length,
        EventStatus.values.length,
        reason: 'all labels must be distinct',
      );
    });
  });

  // -------------------------------------------------------------------------
  // EventStatusX.label — Glados property: choose over all enum values
  // -------------------------------------------------------------------------
  group('EventStatusX.label — Glados properties', () {
    glados.Glados<EventStatus>(
      glados.any.eventStatus,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'label is non-empty and all-caps for any EventStatus',
      (status) {
        final lbl = status.label;
        expect(lbl, isNotEmpty);
        expect(lbl, equals(lbl.toUpperCase()));
      },
      tags: 'glados',
    );
  });

  // -------------------------------------------------------------------------
  // EventStatusX.color — spot-checks for every variant
  // -------------------------------------------------------------------------
  group('EventStatusX.color — all variants return a valid Color', () {
    test('every variant has a non-null color', () {
      for (final status in EventStatus.values) {
        final c = status.color;
        // Verify the value is a Color (i.e. 32-bit ARGB).  Alpha must be
        // positive so the widget is not invisible.
        expect(c, isA<Color>(), reason: '${status.name}.color must be a Color');
        expect(
          c.a,
          greaterThan(0),
          reason: '${status.name}.color must be visible',
        );
      }
    });

    test('tentative color is grey', () {
      expect(EventStatus.tentative.color, Colors.grey);
    });

    test('planned color is blue', () {
      expect(EventStatus.planned.color, Colors.blue);
    });

    test('ongoing color is orange', () {
      expect(EventStatus.ongoing.color, Colors.orange);
    });

    test('completed color is green', () {
      expect(EventStatus.completed.color, Colors.green);
    });

    test('cancelled color is red', () {
      expect(EventStatus.cancelled.color, Colors.red);
    });

    test('postponed color is yellow', () {
      expect(EventStatus.postponed.color, Colors.yellow);
    });

    test('rescheduled color is purple', () {
      expect(EventStatus.rescheduled.color, Colors.purple);
    });

    test('missed color is red', () {
      expect(EventStatus.missed.color, Colors.red);
    });
  });

  // -------------------------------------------------------------------------
  // EventStatusX.color — Glados property
  // -------------------------------------------------------------------------
  group('EventStatusX.color — Glados properties', () {
    glados.Glados<EventStatus>(
      glados.any.eventStatus,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'color is a visible Color for any EventStatus',
      (status) {
        final c = status.color;
        expect(c, isA<Color>());
        expect(c.a, greaterThan(0));
      },
      tags: 'glados',
    );
  });
}

// ---------------------------------------------------------------------------
// Glados generator for EventStatus.
// ---------------------------------------------------------------------------

extension _AnyEventStatus on glados.Any {
  glados.Generator<EventStatus> get eventStatus =>
      glados.AnyUtils(this).choose(EventStatus.values);
}
