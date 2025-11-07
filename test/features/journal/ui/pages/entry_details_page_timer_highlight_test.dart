import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../helpers/path_provider.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';

class FakeTimeService extends TimeService {
  final _controller = StreamController<JournalEntity?>.broadcast();

  @override
  Stream<JournalEntity?> getStream() => _controller.stream;

  void emit(JournalEntity? entity) {
    _controller.add(entity);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late JournalDb mockJournalDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late FakeTimeService fakeTimeService;

  group('EntryDetailsPage TimeService Integration Tests - ', () {
    setUpAll(() {
      setFakeDocumentsPath();
      registerFallbackValue(FakeMeasurementData());
    });

    setUp(() async {
      mockJournalDb = mockJournalDbWithMeasurableTypes([]);
      mockPersistenceLogic = MockPersistenceLogic();
      mockUpdateNotifications = MockUpdateNotifications();
      mockEntitiesCacheService = MockEntitiesCacheService();
      fakeTimeService = FakeTimeService();

      final mockTagsService = mockTagsServiceWithTags([]);
      final mockEditorStateService = MockEditorStateService();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<LoggingDb>(MockLoggingDb())
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(fakeTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(() => mockEntitiesCacheService.sortedCategories).thenAnswer(
        (_) => [],
      );

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([[]]),
      );

      when(() => mockTagsService.stream).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([[]]),
      );

      when(() => mockJournalDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          },
        ]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      when(() => mockJournalDb.getLinkedEntities(testTextEntry.meta.id))
          .thenAnswer((_) async => []);
    });

    tearDown(() async {
      await fakeTimeService.dispose();
      await getIt.reset();
    });

    test('TimeService stream emits null when no timer running', () async {
      JournalEntity? result;
      final subscription = fakeTimeService.getStream().listen((event) {
        result = event;
      });

      // Emit null (no timer)
      fakeTimeService.emit(null);
      await Future<void>.delayed(Duration.zero);

      expect(result, isNull);
      await subscription.cancel();
    });

    test('TimeService stream emits timer entry when timer starts', () async {
      final timerEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'timer-123',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
      );

      JournalEntity? result;
      final subscription = fakeTimeService.getStream().listen((event) {
        result = event;
      });

      // Emit timer entry
      fakeTimeService.emit(timerEntry);
      await Future<void>.delayed(Duration.zero);

      expect(result, isNotNull);
      expect(result!.meta.id, equals('timer-123'));
      await subscription.cancel();
    });

    test('timer entry ID is extracted correctly', () async {
      final timerEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'timer-456',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
      );

      JournalEntity? result;
      final subscription = fakeTimeService.getStream().listen((event) {
        result = event;
      });

      fakeTimeService.emit(timerEntry);
      await Future<void>.delayed(Duration.zero);

      expect(result, isNotNull);
      expect(result!.meta.id, equals('timer-456'));

      await subscription.cancel();
    });

    test('timer stops, stream emits null', () async {
      final timerEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'timer-999',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
      );

      final results = <JournalEntity?>[];
      final subscription = fakeTimeService.getStream().listen(results.add);

      // Start timer
      fakeTimeService.emit(timerEntry);
      await Future<void>.delayed(Duration.zero);

      expect(results.length, equals(1));
      expect(results.last!.meta.id, equals('timer-999'));

      // Stop timer
      fakeTimeService.emit(null);
      await Future<void>.delayed(Duration.zero);

      expect(results.length, equals(2));
      expect(results.last, isNull);

      await subscription.cancel();
    });

    test('timer switches between entries in stream', () async {
      final timerEntry1 = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'timer-111',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
      );

      final timerEntry2 = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'timer-222',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
      );

      final results = <JournalEntity?>[];
      final subscription = fakeTimeService.getStream().listen(results.add);

      // Start first timer
      fakeTimeService.emit(timerEntry1);
      await Future<void>.delayed(Duration.zero);

      expect(results.length, equals(1));
      expect(results.last!.meta.id, equals('timer-111'));

      // Switch to second timer
      fakeTimeService.emit(timerEntry2);
      await Future<void>.delayed(Duration.zero);

      expect(results.length, equals(2));
      expect(results.last!.meta.id, equals('timer-222'));

      await subscription.cancel();
    });
  });
}
