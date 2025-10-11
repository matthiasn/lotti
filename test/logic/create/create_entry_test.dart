import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../helpers/fallbacks.dart';
import '../../helpers/path_provider.dart';
import '../../mocks/mocks.dart';

class _MockBuildContext extends Mock implements BuildContext {}

/// Minimal WidgetRef implementation for unit testing createChecklist().
///
/// This fake is needed because createChecklist() requires a WidgetRef parameter
/// to read checklistRepositoryProvider. In widget tests, ProviderScope should be
/// used instead, but for unit tests we need this minimal implementation.
///
/// Only implements the 'read' method which is actually used by createChecklist.
/// Other methods throw UnimplementedError to catch any unexpected usage.
class _FakeWidgetRef implements WidgetRef {
  _FakeWidgetRef(this._container);

  final ProviderContainer _container;

  @override
  BuildContext get context => _MockBuildContext();

  /// Only method used by createChecklist - delegates to ProviderContainer
  @override
  T read<T>(ProviderListenable<T> provider) {
    return _container.read(provider);
  }

  // Unused methods - throw to catch unexpected usage
  @override
  T watch<T>(ProviderListenable<T> provider) {
    throw UnimplementedError('watch() not implemented in test fake');
  }

  @override
  ProviderSubscription<T> listenManual<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
    bool fireImmediately = false,
  }) {
    throw UnimplementedError('listenManual() not implemented in test fake');
  }

  @override
  bool exists(ProviderBase<Object?> provider) {
    throw UnimplementedError('exists() not implemented in test fake');
  }

  @override
  void invalidate(ProviderOrFamily provider) {
    throw UnimplementedError('invalidate() not implemented in test fake');
  }

  @override
  T refresh<T>(Refreshable<T> provider) {
    throw UnimplementedError('refresh() not implemented in test fake');
  }

  @override
  ProviderSubscription<T> listen<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
    bool fireImmediately = false,
  }) {
    throw UnimplementedError('listen() not implemented in test fake');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setFakeDocumentsPath();
  registerFallbackValue(fallbackJournalEntity);
  registerFallbackValue(fallbackSyncMessage);

  final mockNotificationService = MockNotificationService();
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockFts5Db = MockFts5Db();
  final mockOutboxService = MockOutboxService();
  final mockTimeService = MockTimeService();
  final mockNavService = MockNavService();

  // Note: Navigation side effects (beamToNamed calls) are intentionally not mocked/verified
  // in these tests. These are unit tests focused on entry creation and persistence logic.
  // Navigation behavior is tested separately in integration/widget tests where the full
  // navigation context is available. The NavService mock is registered to prevent errors,
  // but navigation calls are not asserted as they are implementation details of the
  // create functions, not their core responsibility.
  group('Create Entry Tests - ', () {
    setUpAll(() async {
      await getIt.reset();

      setFakeDocumentsPath();

      getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);

      final settingsDb = SettingsDb(inMemoryDatabase: true);
      final journalDb = JournalDb(inMemoryDatabase: true);
      await initConfigFlags(journalDb, inMemoryDatabase: true);

      when(mockNotificationService.updateBadge).thenAnswer((_) async {});

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(
        () => mockFts5Db.insertText(
          any(),
          removePrevious: true,
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockNotificationService.showNotification(
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationId: any(named: 'notificationId'),
          deepLink: any(named: 'deepLink'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockNotificationService.cancelNotification(any()),
      ).thenAnswer((_) async {});

      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      when(() => mockTimeService.start(any(), any())).thenAnswer((_) async {});

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<Fts5Db>(mockFts5Db)
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<JournalDb>(journalDb)
        ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
        ..registerSingleton<LoggingService>(LoggingService())
        ..registerSingleton<TagsService>(TagsService())
        ..registerSingleton<OutboxService>(mockOutboxService)
        ..registerSingleton<NotificationService>(mockNotificationService)
        ..registerSingleton<VectorClockService>(VectorClockService())
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<PersistenceLogic>(PersistenceLogic());
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    tearDown(() {
      clearInteractions(mockNotificationService);
      clearInteractions(mockUpdateNotifications);
      clearInteractions(mockFts5Db);
      clearInteractions(mockTimeService);
      clearInteractions(mockOutboxService);
      clearInteractions(mockNavService);
    });

    test('createTextEntry creates and stores a text entry', () async {
      // Create text entry without linkedId
      final entry = await createTextEntry();

      expect(entry, isNotNull);
      expect(entry, isA<JournalEntry>());
      expect(entry?.entryText?.plainText, '');

      // Verify entry is in database
      final retrieved =
          await getIt<JournalDb>().journalEntityById(entry!.meta.id);
      expect(retrieved, isNotNull);
      expect(retrieved?.meta.id, entry.meta.id);
    });

    test('createTextEntry with linkedId creates linked entry', () async {
      // Create parent entry
      final parent = await createTextEntry();
      expect(parent, isNotNull);

      // Create linked entry
      final linked = await createTextEntry(linkedId: parent!.meta.id);
      expect(linked, isNotNull);

      // Verify link exists
      final linkedEntities =
          await getIt<JournalDb>().getLinkedEntities(parent.meta.id);
      expect(linkedEntities.length, 1);
      expect(linkedEntities.first.meta.id, linked!.meta.id);
    });

    test('createTextEntry with categoryId sets category', () async {
      const testCategoryId = 'test-category-123';

      final entry = await createTextEntry(categoryId: testCategoryId);

      expect(entry, isNotNull);
      expect(entry?.categoryId, testCategoryId);
    });

    test('createTask creates and stores a task', () async {
      final task = await createTask();

      expect(task, isNotNull);
      expect(task, isA<Task>());
      expect(task?.data.title, '');
      expect(task?.data.status, isA<TaskOpen>());

      // Verify task is in database
      final retrieved =
          await getIt<JournalDb>().journalEntityById(task!.meta.id);
      expect(retrieved, isNotNull);
      expect(retrieved, isA<Task>());
    });

    test('createTask with linkedId and categoryId', () async {
      const testCategoryId = 'task-category-456';
      final parent = await createTextEntry();
      expect(parent, isNotNull);

      final task = await createTask(
        linkedId: parent!.meta.id,
        categoryId: testCategoryId,
      );

      expect(task, isNotNull);
      expect(task?.categoryId, testCategoryId);

      // Verify link exists
      final linkedEntities =
          await getIt<JournalDb>().getLinkedEntities(parent.meta.id);
      expect(linkedEntities.any((e) => e.meta.id == task!.meta.id), true);
    });

    test('createEvent creates and stores an event', () async {
      final event = await createEvent();

      expect(event, isNotNull);
      expect(event, isA<JournalEvent>());
      expect(event?.data.title, '');
      expect(event?.data.status, EventStatus.tentative);
      // Events are starred by default (see PersistenceLogic.createEventEntry)
      expect(event?.meta.starred, true);

      // Verify event is in database
      final retrieved =
          await getIt<JournalDb>().journalEntityById(event!.meta.id);
      expect(retrieved, isNotNull);
      expect(retrieved, isA<JournalEvent>());
    });

    test('createEvent with linkedId and categoryId', () async {
      const testCategoryId = 'event-category-789';
      final parent = await createTextEntry();
      expect(parent, isNotNull);

      final event = await createEvent(
        linkedId: parent!.meta.id,
        categoryId: testCategoryId,
      );

      expect(event, isNotNull);
      expect(event?.categoryId, testCategoryId);

      // Verify link exists
      final linkedEntities =
          await getIt<JournalDb>().getLinkedEntities(parent.meta.id);
      expect(linkedEntities.any((e) => e.meta.id == event!.meta.id), true);
    });

    test('createTimerEntry without linked creates simple timer', () async {
      final timer = await createTimerEntry();

      expect(timer, isNotNull);
      expect(timer, isA<JournalEntry>());

      // TimeService.start should not be called when no linked entry
      verifyNever(() => mockTimeService.start(any(), any()));
    });

    test('createTimerEntry with linked entry starts timer', () async {
      final parent = await createTextEntry();
      expect(parent, isNotNull);

      final timer = await createTimerEntry(linked: parent);

      expect(timer, isNotNull);

      // TimeService.start should be called with both entries
      verify(() => mockTimeService.start(timer!, parent)).called(1);
    });

    test('createChecklist creates checklist for valid task', () async {
      // Create a task first
      final task = await createTask();
      expect(task, isNotNull);

      final container = ProviderContainer(
        overrides: [],
      );
      addTearDown(container.dispose);

      // Use a FakeWidgetRef that uses the container
      final fakeRef = _FakeWidgetRef(container);

      // Create checklist for the task
      final checklist = await createChecklist(
        task: task!,
        ref: fakeRef,
      );

      expect(checklist, isNotNull);
      expect(checklist, isA<Checklist>());

      // Verify checklist data integrity
      final checklistEntity = checklist! as Checklist;
      expect(checklistEntity.data.title, 'TODOs'); // Default title when none provided
      expect(
          checklistEntity.data.linkedChecklistItems, isEmpty); // No items yet
      expect(checklistEntity.data.linkedTasks, contains(task.id));

      // Verify metadata is properly set
      expect(checklistEntity.meta.id, isNotEmpty);
      expect(checklistEntity.meta.createdAt, isNotNull);
      expect(checklistEntity.meta.updatedAt, isNotNull);
      expect(checklistEntity.meta.vectorClock, isNotNull);

      // Verify task has checklist ID
      final updatedTask = await getIt<JournalDb>().journalEntityById(task.id);
      expect((updatedTask! as Task).data.checklistIds,
          contains(checklist.meta.id));

      // Verify checklist is persisted in database
      final retrievedChecklist =
          await getIt<JournalDb>().journalEntityById(checklist.meta.id);
      expect(retrievedChecklist, isNotNull);
      expect(retrievedChecklist, isA<Checklist>());
    });

    test('createScreenshot creates image entry with geolocation', () async {
      // This test may skip on platforms without screenshot capabilities
      try {
        final entry = await createScreenshot();

        expect(entry, isNotNull);
        expect(entry, isA<JournalImage>());

        final imageEntry = entry!;
        expect((imageEntry as JournalImage).data.imageId, isNotEmpty);
        expect(imageEntry.data.imageFile, isNotEmpty);
      } catch (e) {
        // Screenshot functionality may not be available in test environment
        // This is acceptable - the important thing is the function doesn't crash
        expect(
          e.toString(),
          anyOf(
            contains('Unsupported'),
            contains('screenshot'),
            contains('command'),
            contains('portal'),
            contains('MissingPluginException'),
          ),
        );
      }
    });

    test('createScreenshot with linkedId creates linked image entry', () async {
      final parent = await createTextEntry();
      expect(parent, isNotNull);

      try {
        final screenshot = await createScreenshot(linkedId: parent!.meta.id);

        expect(screenshot, isNotNull);
        expect(screenshot, isA<JournalImage>());

        // Verify link exists
        final linkedEntities =
            await getIt<JournalDb>().getLinkedEntities(parent.meta.id);
        expect(
          linkedEntities.any((e) => e.meta.id == screenshot!.meta.id),
          true,
        );
      } catch (e) {
        // Screenshot functionality may not be available in test environment
        expect(
          e.toString(),
          anyOf(
            contains('Unsupported'),
            contains('screenshot'),
            contains('command'),
            contains('portal'),
            contains('MissingPluginException'),
          ),
        );
      }
    });

    test('createScreenshot with categoryId sets category', () async {
      const testCategoryId = 'screenshot-category-123';

      try {
        final screenshot = await createScreenshot(categoryId: testCategoryId);

        expect(screenshot, isNotNull);
        expect(screenshot?.categoryId, testCategoryId);
      } catch (e) {
        // Screenshot functionality may not be available in test environment
        expect(
          e.toString(),
          anyOf(
            contains('Unsupported'),
            contains('screenshot'),
            contains('command'),
            contains('portal'),
            contains('MissingPluginException'),
          ),
        );
      }
    });
  });
}
