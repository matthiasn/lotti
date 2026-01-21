import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

class MockVectorClockService extends Mock implements VectorClockService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MetadataService', () {
    late MetadataService metadataService;
    late MockVectorClockService mockVectorClockService;

    setUp(() {
      mockVectorClockService = MockVectorClockService();

      // Setup default mock behavior
      when(() => mockVectorClockService.getNextVectorClock(
              previous: any(named: 'previous')))
          .thenAnswer((_) async => const VectorClock({'test-host': 1}));
      when(() => mockVectorClockService.getNextVectorClock())
          .thenAnswer((_) async => const VectorClock({'test-host': 1}));
      when(() => mockVectorClockService.getHost())
          .thenAnswer((_) async => 'test-host');

      metadataService = MetadataService(
        vectorClockService: mockVectorClockService,
      );
    });

    group('generateId', () {
      test('generates unique UUID v1 when uuidV5Input is null', () {
        final id1 = metadataService.generateId();
        final id2 = metadataService.generateId();
        final id3 = metadataService.generateId();

        expect(id1, isNot(id2));
        expect(id2, isNot(id3));
        expect(id1, isNot(id3));

        // UUID v1 format validation
        expect(id1, matches(RegExp(r'^[0-9a-f-]{36}$')));
        expect(id2, matches(RegExp(r'^[0-9a-f-]{36}$')));
        expect(id3, matches(RegExp(r'^[0-9a-f-]{36}$')));
      });

      test('generates deterministic UUID v5 when uuidV5Input is provided', () {
        const input = 'unique-input-string';
        final id1 = metadataService.generateId(uuidV5Input: input);
        final id2 = metadataService.generateId(uuidV5Input: input);
        final id3 = metadataService.generateId(uuidV5Input: input);

        expect(id1, equals(id2));
        expect(id2, equals(id3));

        // UUID format validation
        expect(id1, matches(RegExp(r'^[0-9a-f-]{36}$')));
      });

      test('generates different UUIDs for different v5 inputs', () {
        final id1 = metadataService.generateId(uuidV5Input: 'input-a');
        final id2 = metadataService.generateId(uuidV5Input: 'input-b');
        final id3 = metadataService.generateId(uuidV5Input: 'input-c');

        expect(id1, isNot(id2));
        expect(id2, isNot(id3));
        expect(id1, isNot(id3));
      });

      test('handles empty string as v5 input', () {
        final id1 = metadataService.generateId(uuidV5Input: '');
        final id2 = metadataService.generateId(uuidV5Input: '');

        expect(id1, equals(id2));
        expect(id1, matches(RegExp(r'^[0-9a-f-]{36}$')));
      });

      test('handles special characters in v5 input', () {
        const specialInput = 'special!@#\$%^&*()_+{}|:"<>?[]\\;\',./`~';
        final id1 = metadataService.generateId(uuidV5Input: specialInput);
        final id2 = metadataService.generateId(uuidV5Input: specialInput);

        expect(id1, equals(id2));
        expect(id1, matches(RegExp(r'^[0-9a-f-]{36}$')));
      });
    });

    group('createMetadata', () {
      test('creates metadata with vector clock from service', () async {
        const expectedVectorClock = VectorClock({'test-host': 42});
        when(() => mockVectorClockService.getNextVectorClock())
            .thenAnswer((_) async => expectedVectorClock);

        final metadata = await metadataService.createMetadata();

        expect(metadata.vectorClock, equals(expectedVectorClock));
        verify(() => mockVectorClockService.getNextVectorClock()).called(1);
      });

      test('creates metadata with default timestamps (now)', () async {
        final beforeCreate = DateTime.now();
        final metadata = await metadataService.createMetadata();
        final afterCreate = DateTime.now();

        expect(
          metadata.createdAt.isAfter(beforeCreate) ||
              metadata.createdAt.isAtSameMomentAs(beforeCreate),
          isTrue,
        );
        expect(
          metadata.createdAt.isBefore(afterCreate) ||
              metadata.createdAt.isAtSameMomentAs(afterCreate),
          isTrue,
        );
        expect(metadata.createdAt, equals(metadata.updatedAt));
        expect(metadata.dateFrom, equals(metadata.createdAt));
        expect(metadata.dateTo, equals(metadata.createdAt));
      });

      test('creates metadata with custom dateFrom and dateTo', () async {
        final dateFrom = DateTime(2024, 1, 15, 10, 30);
        final dateTo = DateTime(2024, 1, 15, 11, 30);

        final metadata = await metadataService.createMetadata(
          dateFrom: dateFrom,
          dateTo: dateTo,
        );

        expect(metadata.dateFrom, equals(dateFrom));
        expect(metadata.dateTo, equals(dateTo));
      });

      test('creates metadata with dateFrom only (dateTo defaults to now)',
          () async {
        final dateFrom = DateTime(2024, 1, 15, 10, 30);
        final beforeCreate = DateTime.now();

        final metadata = await metadataService.createMetadata(
          dateFrom: dateFrom,
        );

        expect(metadata.dateFrom, equals(dateFrom));
        expect(
          metadata.dateTo.isAfter(beforeCreate) ||
              metadata.dateTo.isAtSameMomentAs(beforeCreate),
          isTrue,
        );
      });

      test('creates metadata with UUID v5 when uuidV5Input provided', () async {
        const input = 'health-data-unique-id';

        final metadata1 =
            await metadataService.createMetadata(uuidV5Input: input);
        final metadata2 =
            await metadataService.createMetadata(uuidV5Input: input);

        expect(metadata1.id, equals(metadata2.id));
      });

      test('creates metadata with UUID v1 when uuidV5Input not provided',
          () async {
        final metadata1 = await metadataService.createMetadata();
        final metadata2 = await metadataService.createMetadata();

        expect(metadata1.id, isNot(metadata2.id));
      });

      test('creates metadata with all optional parameters', () async {
        final dateFrom = DateTime(2024, 6, 1, 9);
        final dateTo = DateTime(2024, 6, 1, 10);
        const tagIds = ['tag1', 'tag2'];
        const labelIds = ['label1', 'label2'];
        const categoryId = 'category-123';

        final metadata = await metadataService.createMetadata(
          dateFrom: dateFrom,
          dateTo: dateTo,
          uuidV5Input: 'unique-input',
          private: true,
          tagIds: tagIds,
          labelIds: labelIds,
          categoryId: categoryId,
          starred: true,
          flag: EntryFlag.import,
        );

        expect(metadata.dateFrom, equals(dateFrom));
        expect(metadata.dateTo, equals(dateTo));
        expect(metadata.private, isTrue);
        expect(metadata.tagIds, equals(tagIds));
        expect(metadata.labelIds, equals(labelIds));
        expect(metadata.categoryId, equals(categoryId));
        expect(metadata.starred, isTrue);
        expect(metadata.flag, equals(EntryFlag.import));
      });

      test('creates metadata with timezone and utcOffset', () async {
        final metadata = await metadataService.createMetadata();

        expect(metadata.timezone, isNotNull);
        expect(metadata.utcOffset, isNotNull);
        expect(metadata.utcOffset,
            equals(DateTime.now().timeZoneOffset.inMinutes));
      });

      test('creates metadata with null optional parameters by default',
          () async {
        final metadata = await metadataService.createMetadata();

        expect(metadata.private, isNull);
        expect(metadata.tagIds, isNull);
        expect(metadata.labelIds, isNull);
        expect(metadata.categoryId, isNull);
        expect(metadata.starred, isNull);
        expect(metadata.flag, isNull);
        expect(metadata.deletedAt, isNull);
      });

      test('creates metadata with starred=false explicitly', () async {
        final metadata = await metadataService.createMetadata(starred: false);

        expect(metadata.starred, isFalse);
      });

      test('creates metadata with private=false explicitly', () async {
        final metadata = await metadataService.createMetadata(private: false);

        expect(metadata.private, isFalse);
      });
    });

    group('updateMetadata', () {
      late Metadata originalMetadata;

      setUp(() {
        originalMetadata = Metadata(
          id: 'original-id',
          createdAt: DateTime(2024, 1, 1, 10),
          updatedAt: DateTime(2024, 1, 1, 10),
          dateFrom: DateTime(2024, 1, 1, 9),
          dateTo: DateTime(2024, 1, 1, 10),
          categoryId: 'original-category',
          labelIds: ['label1', 'label2'],
          vectorClock: const VectorClock({'old-host': 5}),
        );
      });

      test('updates vectorClock using service', () async {
        const newVectorClock = VectorClock({'test-host': 10, 'old-host': 5});
        when(
          () => mockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
          ),
        ).thenAnswer((_) async => newVectorClock);

        final updated = await metadataService.updateMetadata(originalMetadata);

        expect(updated.vectorClock, equals(newVectorClock));
        verify(
          () => mockVectorClockService.getNextVectorClock(
            previous: originalMetadata.vectorClock,
          ),
        ).called(1);
      });

      test('updates updatedAt to current time', () async {
        final beforeUpdate = DateTime.now();
        final updated = await metadataService.updateMetadata(originalMetadata);
        final afterUpdate = DateTime.now();

        expect(
          updated.updatedAt.isAfter(beforeUpdate) ||
              updated.updatedAt.isAtSameMomentAs(beforeUpdate),
          isTrue,
        );
        expect(
          updated.updatedAt.isBefore(afterUpdate) ||
              updated.updatedAt.isAtSameMomentAs(afterUpdate),
          isTrue,
        );
      });

      test('preserves original id', () async {
        final updated = await metadataService.updateMetadata(originalMetadata);

        expect(updated.id, equals(originalMetadata.id));
      });

      test('preserves original createdAt', () async {
        final updated = await metadataService.updateMetadata(originalMetadata);

        expect(updated.createdAt, equals(originalMetadata.createdAt));
      });

      test('preserves original values when not specified', () async {
        final updated = await metadataService.updateMetadata(originalMetadata);

        expect(updated.dateFrom, equals(originalMetadata.dateFrom));
        expect(updated.dateTo, equals(originalMetadata.dateTo));
        expect(updated.categoryId, equals(originalMetadata.categoryId));
        expect(updated.labelIds, equals(originalMetadata.labelIds));
      });

      test('updates dateFrom when specified', () async {
        final newDateFrom = DateTime(2024, 2, 1, 8);

        final updated = await metadataService.updateMetadata(
          originalMetadata,
          dateFrom: newDateFrom,
        );

        expect(updated.dateFrom, equals(newDateFrom));
        expect(updated.dateTo, equals(originalMetadata.dateTo));
      });

      test('updates dateTo when specified', () async {
        final newDateTo = DateTime(2024, 2, 1, 11);

        final updated = await metadataService.updateMetadata(
          originalMetadata,
          dateTo: newDateTo,
        );

        expect(updated.dateTo, equals(newDateTo));
        expect(updated.dateFrom, equals(originalMetadata.dateFrom));
      });

      test('updates categoryId when specified', () async {
        const newCategoryId = 'new-category';

        final updated = await metadataService.updateMetadata(
          originalMetadata,
          categoryId: newCategoryId,
        );

        expect(updated.categoryId, equals(newCategoryId));
      });

      test('clears categoryId when clearCategoryId is true', () async {
        final updated = await metadataService.updateMetadata(
          originalMetadata,
          clearCategoryId: true,
        );

        expect(updated.categoryId, isNull);
      });

      test('clearCategoryId takes precedence over categoryId', () async {
        final updated = await metadataService.updateMetadata(
          originalMetadata,
          categoryId: 'should-be-ignored',
          clearCategoryId: true,
        );

        expect(updated.categoryId, isNull);
      });

      test('updates labelIds when specified', () async {
        const newLabelIds = ['new-label1', 'new-label2'];

        final updated = await metadataService.updateMetadata(
          originalMetadata,
          labelIds: newLabelIds,
        );

        expect(updated.labelIds, equals(newLabelIds));
      });

      test('clears labelIds when clearLabelIds is true', () async {
        final updated = await metadataService.updateMetadata(
          originalMetadata,
          clearLabelIds: true,
        );

        expect(updated.labelIds, isNull);
      });

      test('clearLabelIds takes precedence over labelIds', () async {
        final updated = await metadataService.updateMetadata(
          originalMetadata,
          labelIds: ['should-be-ignored'],
          clearLabelIds: true,
        );

        expect(updated.labelIds, isNull);
      });

      test('sets deletedAt when specified', () async {
        final deletedAt = DateTime(2024, 3);

        final updated = await metadataService.updateMetadata(
          originalMetadata,
          deletedAt: deletedAt,
        );

        expect(updated.deletedAt, equals(deletedAt));
      });

      test('preserves existing deletedAt when not specified', () async {
        final metadataWithDeletedAt = originalMetadata.copyWith(
          deletedAt: DateTime(2024, 2, 15),
        );

        final updated =
            await metadataService.updateMetadata(metadataWithDeletedAt);

        expect(updated.deletedAt, equals(metadataWithDeletedAt.deletedAt));
      });

      test('updates multiple fields at once', () async {
        final newDateFrom = DateTime(2024, 2, 1, 8);
        final newDateTo = DateTime(2024, 2, 1, 9);
        const newCategoryId = 'new-category';
        const newLabelIds = ['new-label'];
        final deletedAt = DateTime(2024, 3);

        final updated = await metadataService.updateMetadata(
          originalMetadata,
          dateFrom: newDateFrom,
          dateTo: newDateTo,
          categoryId: newCategoryId,
          labelIds: newLabelIds,
          deletedAt: deletedAt,
        );

        expect(updated.dateFrom, equals(newDateFrom));
        expect(updated.dateTo, equals(newDateTo));
        expect(updated.categoryId, equals(newCategoryId));
        expect(updated.labelIds, equals(newLabelIds));
        expect(updated.deletedAt, equals(deletedAt));
      });
    });

    group('getNextVectorClock', () {
      test('delegates to VectorClockService without previous', () async {
        const expectedClock = VectorClock({'host': 123});
        when(() => mockVectorClockService.getNextVectorClock())
            .thenAnswer((_) async => expectedClock);

        final result = await metadataService.getNextVectorClock();

        expect(result, equals(expectedClock));
        verify(() => mockVectorClockService.getNextVectorClock()).called(1);
      });

      test('delegates to VectorClockService with previous', () async {
        const previousClock = VectorClock({'old-host': 5});
        const expectedClock = VectorClock({'old-host': 5, 'new-host': 1});
        when(
          () => mockVectorClockService.getNextVectorClock(
            previous: previousClock,
          ),
        ).thenAnswer((_) async => expectedClock);

        final result =
            await metadataService.getNextVectorClock(previous: previousClock);

        expect(result, equals(expectedClock));
        verify(
          () => mockVectorClockService.getNextVectorClock(
            previous: previousClock,
          ),
        ).called(1);
      });
    });

    group('getHost', () {
      test('delegates to VectorClockService', () async {
        const expectedHost = 'my-unique-host-id';
        when(() => mockVectorClockService.getHost())
            .thenAnswer((_) async => expectedHost);

        final result = await metadataService.getHost();

        expect(result, equals(expectedHost));
        verify(() => mockVectorClockService.getHost()).called(1);
      });

      test('returns null when VectorClockService returns null', () async {
        when(() => mockVectorClockService.getHost())
            .thenAnswer((_) async => null);

        final result = await metadataService.getHost();

        expect(result, isNull);
      });
    });
  });

  group('MetadataService integration with real VectorClockService', () {
    late MetadataService metadataService;
    late VectorClockService vectorClockService;
    late SettingsDb settingsDb;

    setUp(() async {
      await getIt.reset();
      settingsDb = SettingsDb(inMemoryDatabase: true);
      getIt.registerSingleton<SettingsDb>(settingsDb);

      vectorClockService = VectorClockService();
      // Allow init() to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      metadataService = MetadataService(
        vectorClockService: vectorClockService,
      );
    });

    tearDown(() async {
      await getIt.reset();
    });

    test('creates metadata with incrementing vector clocks', () async {
      final host = await vectorClockService.getHost();

      final meta1 = await metadataService.createMetadata();
      final meta2 = await metadataService.createMetadata();
      final meta3 = await metadataService.createMetadata();

      // Each metadata should have an incrementing counter for our host
      expect(meta1.vectorClock?.vclock[host], isNotNull);
      expect(meta2.vectorClock?.vclock[host], isNotNull);
      expect(meta3.vectorClock?.vclock[host], isNotNull);

      final counter1 = meta1.vectorClock!.vclock[host]!;
      final counter2 = meta2.vectorClock!.vclock[host]!;
      final counter3 = meta3.vectorClock!.vclock[host]!;

      expect(counter2, equals(counter1 + 1));
      expect(counter3, equals(counter2 + 1));
    });

    test('updateMetadata merges vector clocks', () async {
      final host = await vectorClockService.getHost();

      final original = await metadataService.createMetadata();
      final updated = await metadataService.updateMetadata(original);

      // Updated should have higher counter for our host
      final originalCounter = original.vectorClock!.vclock[host]!;
      final updatedCounter = updated.vectorClock!.vclock[host]!;

      expect(updatedCounter, greaterThan(originalCounter));
    });
  });
}
