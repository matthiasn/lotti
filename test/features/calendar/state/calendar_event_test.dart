import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/calendar/state/calendar_event.dart';

void main() {
  group('CalendarEvent', () {
    test('creates CalendarEvent with required entity', () {
      // Arrange
      final dateFrom = DateTime(2024, 1, 15, 10);
      final dateTo = dateFrom.add(const Duration(hours: 2));

      final testEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'test-id',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      // Act
      final event = CalendarEvent(entity: testEntry);

      // Assert
      expect(event.entity, testEntry);
      expect(event.linkedFrom, isNull);
      expect(event.categoryId, isNull);
    });

    test('creates CalendarEvent with linkedFrom entity', () {
      // Arrange
      final dateFrom = DateTime(2024, 1, 15, 10);
      final dateTo = dateFrom.add(const Duration(hours: 2));

      final testEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry-id',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      // Use another JournalEntry as linkedFrom
      final linkedEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'linked-id',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
          categoryId: 'category-123',
        ),
        entryText: const EntryText(plainText: 'Linked entry'),
      );

      // Act
      final event = CalendarEvent(
        entity: testEntry,
        linkedFrom: linkedEntry,
      );

      // Assert
      expect(event.entity, testEntry);
      expect(event.linkedFrom, linkedEntry);
      expect(event.categoryId, isNull); // Not set by constructor
    });

    test('creates CalendarEvent with categoryId for privacy filtering', () {
      // Arrange
      final dateFrom = DateTime(2024, 1, 15, 10);
      final dateTo = dateFrom.add(const Duration(hours: 2));

      final testEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry-id',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      // Act
      final event = CalendarEvent(
        entity: testEntry,
        categoryId: 'work-category',
      );

      // Assert
      expect(event.entity, testEntry);
      expect(event.linkedFrom, isNull);
      expect(event.categoryId, 'work-category');
    });

    test('creates CalendarEvent with all optional parameters', () {
      // Arrange
      final dateFrom = DateTime(2024, 1, 15, 10);
      final dateTo = dateFrom.add(const Duration(hours: 2));

      final testEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry-id',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      final linkedEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'linked-id',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
          categoryId: 'category-123',
        ),
        entryText: const EntryText(plainText: 'Linked entry'),
      );

      // Act
      final event = CalendarEvent(
        entity: testEntry,
        linkedFrom: linkedEntry,
        categoryId: 'category-123',
      );

      // Assert
      expect(event.entity, testEntry);
      expect(event.linkedFrom, linkedEntry);
      expect(event.categoryId, 'category-123');
    });

    test('categoryId can be empty string for unassigned entries', () {
      // Arrange
      final dateFrom = DateTime(2024, 1, 15, 10);
      final dateTo = dateFrom.add(const Duration(hours: 2));

      final testEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry-id',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
        ),
        entryText: const EntryText(plainText: 'Unassigned entry'),
      );

      // Act
      final event = CalendarEvent(
        entity: testEntry,
        categoryId: '', // Empty string = unassigned
      );

      // Assert
      expect(event.categoryId, isEmpty);
    });

    test('fields are mutable', () {
      // Arrange
      final dateFrom = DateTime(2024, 1, 15, 10);
      final dateTo = dateFrom.add(const Duration(hours: 2));

      final testEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry-id',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
        ),
        entryText: const EntryText(plainText: 'Test entry'),
      );

      final updatedEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'updated-entry-id',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
        ),
        entryText: const EntryText(plainText: 'Updated entry'),
      );

      final linkedEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'linked-id',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
        ),
        entryText: const EntryText(plainText: 'Linked entry'),
      );

      // Act
      final event = CalendarEvent(entity: testEntry)
        ..entity = updatedEntry
        ..linkedFrom = linkedEntry
        ..categoryId = 'new-category';

      // Assert
      expect(event.entity, updatedEntry);
      expect(event.linkedFrom, linkedEntry);
      expect(event.categoryId, 'new-category');
    });
  });
}
