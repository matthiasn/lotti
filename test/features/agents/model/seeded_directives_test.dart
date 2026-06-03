import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/seeded_directives.dart';

void main() {
  group('seedDirectiveChangelog', () {
    test('is non-empty', () {
      expect(seedDirectiveChangelog, isNotEmpty);
    });

    test('every entry has a non-empty date string', () {
      for (final entry in seedDirectiveChangelog) {
        expect(
          entry.date,
          isNotEmpty,
          reason: 'date must not be empty for entry: ${entry.description}',
        );
      }
    });

    test('every entry date parses to a valid DateTime without throwing', () {
      for (final entry in seedDirectiveChangelog) {
        expect(
          () => entry.dateTime,
          returnsNormally,
          reason: 'dateTime must parse for date="${entry.date}"',
        );
      }
    });

    test('every entry dateTime is year >= 2024', () {
      for (final entry in seedDirectiveChangelog) {
        expect(
          entry.dateTime.year,
          greaterThanOrEqualTo(2024),
          reason: 'date "${entry.date}" has year < 2024',
        );
      }
    });

    test('every entry dateTime has a valid month (1–12)', () {
      for (final entry in seedDirectiveChangelog) {
        expect(
          entry.dateTime.month,
          inInclusiveRange(1, 12),
          reason: 'date "${entry.date}" has invalid month',
        );
      }
    });

    test('every entry dateTime has a valid day (1–31)', () {
      for (final entry in seedDirectiveChangelog) {
        expect(
          entry.dateTime.day,
          inInclusiveRange(1, 31),
          reason: 'date "${entry.date}" has invalid day',
        );
      }
    });

    test('every entry has a non-empty description', () {
      for (final entry in seedDirectiveChangelog) {
        expect(
          entry.description,
          isNotEmpty,
          reason: 'description must not be empty for date="${entry.date}"',
        );
      }
    });

    test('entries have valid AgentTemplateKind', () {
      // Ensure the kind field is assigned a recognized enum value — this
      // fails at compile time for unknown literals, but the test documents
      // the constraint explicitly.
      for (final entry in seedDirectiveChangelog) {
        expect(
          entry.kind,
          isNotNull,
          reason: 'kind must not be null for date="${entry.date}"',
        );
      }
    });
  });

  group('SeedDirectiveChange.dateTime', () {
    test('parses a known date correctly', () {
      const change = SeedDirectiveChange(
        date: '2026-03-09',
        kind: AgentTemplateKind.taskAgent,
        description: 'Test change',
      );
      expect(change.dateTime, equals(DateTime(2026, 3, 9)));
    });

    test('date string is preserved', () {
      const change = SeedDirectiveChange(
        date: '2026-05-25',
        kind: AgentTemplateKind.dayAgent,
        description: 'Day agent change',
      );
      expect(change.date, equals('2026-05-25'));
      expect(change.dateTime.year, equals(2026));
      expect(change.dateTime.month, equals(5));
      expect(change.dateTime.day, equals(25));
    });
  });
}
