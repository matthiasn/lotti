import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/data/journal_repository.dart';
import 'package:lotti/features/journal/riverpod/journal_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

void main() {
  late MockJournalRepository mockRepository;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockJournalRepository();
    container = ProviderContainer(
      overrides: [
        journalRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('JournalFilters', () {
    test('copyWith creates a new instance with updated values', () {
      // Arrange
      const original = JournalFilters(showTasks: false);

      // Act
      final updated = original.copyWith(showTasks: true);

      // Assert
      expect(updated.showTasks, true);
      expect(updated.selectedEntryTypes, original.selectedEntryTypes);
      expect(updated.filters, original.filters);
      expect(updated.searchQuery, original.searchQuery);
    });
  });

  group('journalFiltersProvider', () {
    test('provides default JournalFilters', () {
      // Act
      final filters = container.read(journalFiltersProvider);

      // Assert
      expect(filters.showTasks, false);
      expect(filters.selectedEntryTypes.isNotEmpty, true);
    });

    test('can be updated', () {
      // Act
      container.read(journalFiltersProvider.notifier).update(
            (state) => state.copyWith(showTasks: true),
          );
      final filters = container.read(journalFiltersProvider);

      // Assert
      expect(filters.showTasks, true);
    });
  });

  group('journalPagingControllerProvider', () {
    test('initializes controller and triggers initial data load', () {
      // Arrange
      when(() => mockRepository.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            offset: any(named: 'offset'),
            ids: any(named: 'ids'),
            categoryIds: any(named: 'categoryIds'),
          )).thenAnswer((_) async => <JournalEntity>[]);

      when(() => mockRepository.fullTextSearch(any()))
          .thenAnswer((_) async => <String>{});

      when(() => mockRepository.updateStream)
          .thenAnswer((_) => Stream.fromIterable([<String>{}]));

      // Act
      final controller = container.read(journalPagingControllerProvider);

      // Assert
      expect(controller, isNotNull);
      verify(() => mockRepository.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            offset: 0,
            ids: null,
            categoryIds: null,
          )).called(1);
    });

    test('refreshes data when filters change', () async {
      // Arrange
      when(() => mockRepository.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            offset: any(named: 'offset'),
            ids: any(named: 'ids'),
            categoryIds: any(named: 'categoryIds'),
          )).thenAnswer((_) async => <JournalEntity>[]);

      when(() => mockRepository.fullTextSearch(any()))
          .thenAnswer((_) async => <String>{});

      when(() => mockRepository.updateStream)
          .thenAnswer((_) => Stream.fromIterable([<String>{}]));

      // Initial controller creation to set up the listener
      container.read(journalPagingControllerProvider);

      // Reset the mock counter since the provider already called once during initialization
      reset(mockRepository);

      when(() => mockRepository.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            offset: any(named: 'offset'),
            ids: any(named: 'ids'),
            categoryIds: any(named: 'categoryIds'),
          )).thenAnswer((_) async => <JournalEntity>[]);

      when(() => mockRepository.fullTextSearch(any()))
          .thenAnswer((_) async => <String>{});

      // Act - update the filters
      container.read(journalFiltersProvider.notifier).update(
            (state) => state.copyWith(showTasks: true),
          );

      // Wait for the listeners to be called
      await Future<void>.delayed(Duration.zero);

      // Assert
      verify(() => mockRepository.fullTextSearch('')).called(1);
    });
  });
}
