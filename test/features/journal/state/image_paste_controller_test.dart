import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/journal/repository/clipboard_repository.dart';
import 'package:lotti/features/journal/state/image_paste_controller.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../../helpers/path_provider.dart';

class MockSystemClipboard extends Mock implements SystemClipboard {}

class MockClipboardReader extends Mock implements ClipboardReader {}

class MockClipboardDataReader extends Mock implements ClipboardDataReader {}

class MockDataReaderFile extends Mock implements DataReaderFile {}

class MockJournalDb extends Mock implements JournalDb {}

class MockFts5Db extends Mock implements Fts5Db {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockVectorClockService extends Mock implements VectorClockService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockOutboxService extends Mock implements OutboxService {}

class MockTagsService extends Mock implements TagsService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockTimeService extends Mock implements TimeService {}

class MockLoggingService extends Mock implements LoggingService {}

class FakeJournalImage extends Fake implements JournalImage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockSystemClipboard mockClipboard;
  late MockClipboardReader mockReader;
  late MockClipboardDataReader mockItem;
  late MockDataReaderFile mockFile;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockLoggingService mockLoggingService;

  setUpAll(() async {
    // Isolate all registrations in a dedicated scope for this file
    getIt.pushNewScope();
    setFakeDocumentsPath();

    // Mocktail fallback for typed argument matchers
    registerFallbackValue(FakeJournalImage());

    // Clear any existing registrations to avoid conflicts with other tests
    if (getIt.isRegistered<Directory>()) {
      getIt.unregister<Directory>();
    }
    if (getIt.isRegistered<LoggingDb>()) {
      getIt.unregister<LoggingDb>();
    }
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<Fts5Db>()) {
      getIt.unregister<Fts5Db>();
    }
    if (getIt.isRegistered<PersistenceLogic>()) {
      getIt.unregister<PersistenceLogic>();
    }
    if (getIt.isRegistered<VectorClockService>()) {
      getIt.unregister<VectorClockService>();
    }
    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }
    if (getIt.isRegistered<OutboxService>()) {
      getIt.unregister<OutboxService>();
    }
    if (getIt.isRegistered<TagsService>()) {
      getIt.unregister<TagsService>();
    }
    if (getIt.isRegistered<NotificationService>()) {
      getIt.unregister<NotificationService>();
    }
    if (getIt.isRegistered<TimeService>()) {
      getIt.unregister<TimeService>();
    }
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }

    // Create and keep references to mocks we need to stub
    mockPersistenceLogic = MockPersistenceLogic();
    mockLoggingService = MockLoggingService();

    // Register all required mock services
    getIt
      ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
      ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
      ..registerSingleton<JournalDb>(MockJournalDb())
      ..registerSingleton<Fts5Db>(MockFts5Db())
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<VectorClockService>(MockVectorClockService())
      ..registerSingleton<UpdateNotifications>(MockUpdateNotifications())
      ..registerSingleton<OutboxService>(MockOutboxService())
      ..registerSingleton<TagsService>(MockTagsService())
      ..registerSingleton<NotificationService>(MockNotificationService())
      ..registerSingleton<TimeService>(MockTimeService())
      ..registerSingleton<LoggingService>(mockLoggingService);
  });

  tearDownAll(() async {
    // Pop the scope and dispose resources
    await getIt.resetScope();
    await getIt.popScope();
    // Clean up GetIt registrations
    if (getIt.isRegistered<Directory>()) {
      getIt.unregister<Directory>();
    }
    if (getIt.isRegistered<LoggingDb>()) {
      getIt.unregister<LoggingDb>();
    }
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<Fts5Db>()) {
      getIt.unregister<Fts5Db>();
    }
    if (getIt.isRegistered<PersistenceLogic>()) {
      getIt.unregister<PersistenceLogic>();
    }
    if (getIt.isRegistered<VectorClockService>()) {
      getIt.unregister<VectorClockService>();
    }
    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }
    if (getIt.isRegistered<OutboxService>()) {
      getIt.unregister<OutboxService>();
    }
    if (getIt.isRegistered<TagsService>()) {
      getIt.unregister<TagsService>();
    }
    if (getIt.isRegistered<NotificationService>()) {
      getIt.unregister<NotificationService>();
    }
    if (getIt.isRegistered<TimeService>()) {
      getIt.unregister<TimeService>();
    }
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
  });

  setUp(() {
    mockClipboard = MockSystemClipboard();
    mockReader = MockClipboardReader();
    mockItem = MockClipboardDataReader();
    mockFile = MockDataReaderFile();

    container = ProviderContainer(
      overrides: [
        clipboardRepositoryProvider.overrideWithValue(mockClipboard),
      ],
    );

    when(() => mockClipboard.read()).thenAnswer((_) async => mockReader);
    // Mock the items list to contain a single item for most tests
    when(() => mockReader.items).thenReturn([mockItem]);

    // Stub persistence logic used by JournalRepository.createImageEntry
    when(
      () => mockPersistenceLogic.createMetadata(
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
        uuidV5Input: any(named: 'uuidV5Input'),
        flag: any(named: 'flag'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async {
      final now = DateTime.now();
      return Metadata(
        id: 'meta-id',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      );
    });

    when(
      () => mockPersistenceLogic.createDbEntity(
        any<JournalImage>(that: isA<JournalImage>()),
        linkedId: any(named: 'linkedId'),
        shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
        enqueueSync: any(named: 'enqueueSync'),
        addTags: any(named: 'addTags'),
      ),
    ).thenAnswer((_) async => true);

    // Silence logging side effects
    when(
      () => mockLoggingService.captureException(
        any<dynamic>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String?>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});
  });

  group('ImagePasteController', () {
    test('build returns false when clipboard is null', () async {
      final container = ProviderContainer(
        overrides: [
          clipboardRepositoryProvider.overrideWithValue(null),
        ],
      );

      final result = await container.read(
        imagePasteControllerProvider(
          linkedFromId: null,
          categoryId: null,
        ).future,
      );

      expect(result, false);
    });

    test('build returns true when PNG is available', () async {
      when(() => mockReader.canProvide(Formats.png)).thenReturn(true);
      when(() => mockReader.canProvide(Formats.jpeg)).thenReturn(false);

      final result = await container.read(
        imagePasteControllerProvider(
          linkedFromId: null,
          categoryId: null,
        ).future,
      );

      expect(result, true);
    });

    test('build returns true when JPEG is available', () async {
      when(() => mockReader.canProvide(Formats.png)).thenReturn(false);
      when(() => mockReader.canProvide(Formats.jpeg)).thenReturn(true);

      final result = await container.read(
        imagePasteControllerProvider(
          linkedFromId: null,
          categoryId: null,
        ).future,
      );

      expect(result, true);
    });

    test('paste handles PNG data correctly', () async {
      when(() => mockItem.canProvide(Formats.png)).thenReturn(true);
      when(() => mockItem.canProvide(Formats.jpeg)).thenReturn(false);

      when(() => mockItem.getFile(Formats.png, any()))
          .thenAnswer((invocation) {
        final callback =
            invocation.positionalArguments[1] as void Function(DataReaderFile);
        callback(mockFile);
        return null;
      });

      when(() => mockFile.readAll())
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

      final controller = container.read(
        imagePasteControllerProvider(
          linkedFromId: 'testLink',
          categoryId: 'testCategory',
        ).notifier,
      );

      await controller.paste();

      // Ensure async work triggered by paste completes to avoid interactions
      // with tearDown/other suites that may reset GetIt.
      await pumpEventQueue();

      verify(() => mockItem.getFile(Formats.png, any())).called(1);
      verify(() => mockFile.readAll()).called(1);
    });

    test('paste handles JPEG data correctly', () async {
      when(() => mockItem.canProvide(Formats.png)).thenReturn(false);
      when(() => mockItem.canProvide(Formats.jpeg)).thenReturn(true);

      when(() => mockItem.getFile(Formats.jpeg, any()))
          .thenAnswer((invocation) {
        final callback =
            invocation.positionalArguments[1] as void Function(DataReaderFile);
        callback(mockFile);
        return null;
      });

      when(() => mockFile.readAll())
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

      final controller = container.read(
        imagePasteControllerProvider(
          linkedFromId: 'testLink',
          categoryId: 'testCategory',
        ).notifier,
      );

      await controller.paste();

      // Ensure any pending async completes before expectations/teardown
      await pumpEventQueue();

      verify(() => mockItem.getFile(Formats.jpeg, any())).called(1);
      verify(() => mockFile.readAll()).called(1);
    });

    test('paste handles only JPEG when both PNG and JPEG are available',
        () async {
      when(() => mockItem.canProvide(Formats.png)).thenReturn(true);
      when(() => mockItem.canProvide(Formats.jpeg)).thenReturn(true);

      when(() => mockItem.getFile(Formats.jpeg, any()))
          .thenAnswer((invocation) {
        final callback =
            invocation.positionalArguments[1] as void Function(DataReaderFile);
        callback(mockFile);
        return null;
      });

      when(() => mockFile.readAll())
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

      final controller = container.read(
        imagePasteControllerProvider(
          linkedFromId: 'testLink',
          categoryId: 'testCategory',
        ).notifier,
      );

      await controller.paste();

      // Ensure any pending async completes before expectations/teardown
      await pumpEventQueue();

      verify(() => mockItem.getFile(Formats.jpeg, any())).called(1);
      verify(() => mockFile.readAll()).called(1);
      verifyNever(() => mockItem.getFile(Formats.png, any()));
    });

    test('paste handles multiple clipboard items (3 JPEG images)', () async {
      // Create 3 mock items
      final mockItem1 = MockClipboardDataReader();
      final mockItem2 = MockClipboardDataReader();
      final mockItem3 = MockClipboardDataReader();
      final mockFile1 = MockDataReaderFile();
      final mockFile2 = MockDataReaderFile();
      final mockFile3 = MockDataReaderFile();

      // Override the items list with 3 items
      when(() => mockReader.items)
          .thenReturn([mockItem1, mockItem2, mockItem3]);

      // Set up each item as JPEG
      for (final item in [mockItem1, mockItem2, mockItem3]) {
        when(() => item.canProvide(Formats.jpeg)).thenReturn(true);
        when(() => item.canProvide(Formats.png)).thenReturn(false);
      }

      when(() => mockItem1.getFile(Formats.jpeg, any()))
          .thenAnswer((invocation) {
        final callback =
            invocation.positionalArguments[1] as void Function(DataReaderFile);
        callback(mockFile1);
        return null;
      });

      when(() => mockItem2.getFile(Formats.jpeg, any()))
          .thenAnswer((invocation) {
        final callback =
            invocation.positionalArguments[1] as void Function(DataReaderFile);
        callback(mockFile2);
        return null;
      });

      when(() => mockItem3.getFile(Formats.jpeg, any()))
          .thenAnswer((invocation) {
        final callback =
            invocation.positionalArguments[1] as void Function(DataReaderFile);
        callback(mockFile3);
        return null;
      });

      when(() => mockFile1.readAll())
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
      when(() => mockFile2.readAll())
          .thenAnswer((_) async => Uint8List.fromList([4, 5, 6]));
      when(() => mockFile3.readAll())
          .thenAnswer((_) async => Uint8List.fromList([7, 8, 9]));

      final controller = container.read(
        imagePasteControllerProvider(
          linkedFromId: 'testLink',
          categoryId: 'testCategory',
        ).notifier,
      );

      await controller.paste();
      await pumpEventQueue();

      // Verify all 3 items were processed
      verify(() => mockItem1.getFile(Formats.jpeg, any())).called(1);
      verify(() => mockItem2.getFile(Formats.jpeg, any())).called(1);
      verify(() => mockItem3.getFile(Formats.jpeg, any())).called(1);
      verify(() => mockFile1.readAll()).called(1);
      verify(() => mockFile2.readAll()).called(1);
      verify(() => mockFile3.readAll()).called(1);
    });

    test('paste handles mixed formats (2 items: PNG + JPEG)', () async {
      final mockItem1 = MockClipboardDataReader();
      final mockItem2 = MockClipboardDataReader();
      final mockFile1 = MockDataReaderFile();
      final mockFile2 = MockDataReaderFile();

      when(() => mockReader.items).thenReturn([mockItem1, mockItem2]);

      // First item is PNG only
      when(() => mockItem1.canProvide(Formats.png)).thenReturn(true);
      when(() => mockItem1.canProvide(Formats.jpeg)).thenReturn(false);

      // Second item is JPEG only
      when(() => mockItem2.canProvide(Formats.jpeg)).thenReturn(true);
      when(() => mockItem2.canProvide(Formats.png)).thenReturn(false);

      when(() => mockItem1.getFile(Formats.png, any()))
          .thenAnswer((invocation) {
        final callback =
            invocation.positionalArguments[1] as void Function(DataReaderFile);
        callback(mockFile1);
        return null;
      });

      when(() => mockItem2.getFile(Formats.jpeg, any()))
          .thenAnswer((invocation) {
        final callback =
            invocation.positionalArguments[1] as void Function(DataReaderFile);
        callback(mockFile2);
        return null;
      });

      when(() => mockFile1.readAll())
          .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
      when(() => mockFile2.readAll())
          .thenAnswer((_) async => Uint8List.fromList([4, 5, 6]));

      final controller = container.read(
        imagePasteControllerProvider(
          linkedFromId: 'testLink',
          categoryId: 'testCategory',
        ).notifier,
      );

      await controller.paste();
      await pumpEventQueue();

      verify(() => mockItem1.getFile(Formats.png, any())).called(1);
      verify(() => mockItem2.getFile(Formats.jpeg, any())).called(1);
      verify(() => mockFile1.readAll()).called(1);
      verify(() => mockFile2.readAll()).called(1);
    });

    test('paste handles empty items list gracefully', () async {
      when(() => mockReader.items).thenReturn([]);

      final controller = container.read(
        imagePasteControllerProvider(
          linkedFromId: 'testLink',
          categoryId: 'testCategory',
        ).notifier,
      );

      // Should complete without errors
      await controller.paste();
      await pumpEventQueue();

      // No getFile calls should occur
      verifyNever(() => mockItem.getFile(any(), any()));
    });

    test('paste skips items with no supported formats', () async {
      final mockItem1 = MockClipboardDataReader();
      final mockItem2 = MockClipboardDataReader();

      when(() => mockReader.items).thenReturn([mockItem1, mockItem2]);

      // Both items have no supported formats
      when(() => mockItem1.canProvide(Formats.png)).thenReturn(false);
      when(() => mockItem1.canProvide(Formats.jpeg)).thenReturn(false);
      when(() => mockItem2.canProvide(Formats.png)).thenReturn(false);
      when(() => mockItem2.canProvide(Formats.jpeg)).thenReturn(false);

      final controller = container.read(
        imagePasteControllerProvider(
          linkedFromId: 'testLink',
          categoryId: 'testCategory',
        ).notifier,
      );

      await controller.paste();
      await pumpEventQueue();

      // No getFile calls should occur
      verifyNever(() => mockItem1.getFile(any(), any()));
      verifyNever(() => mockItem2.getFile(any(), any()));
    });
  });
}
