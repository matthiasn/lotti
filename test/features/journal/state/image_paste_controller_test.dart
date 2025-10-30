import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockSystemClipboard mockClipboard;
  late MockClipboardReader mockReader;
  late MockDataReaderFile mockFile;

  setUpAll(() async {
    // Isolate all registrations in a dedicated scope for this file
    getIt.pushNewScope();
    setFakeDocumentsPath();

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

    // Register all required mock services
    getIt
      ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
      ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
      ..registerSingleton<JournalDb>(MockJournalDb())
      ..registerSingleton<Fts5Db>(MockFts5Db())
      ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
      ..registerSingleton<VectorClockService>(MockVectorClockService())
      ..registerSingleton<UpdateNotifications>(MockUpdateNotifications())
      ..registerSingleton<OutboxService>(MockOutboxService())
      ..registerSingleton<TagsService>(MockTagsService())
      ..registerSingleton<NotificationService>(MockNotificationService())
      ..registerSingleton<TimeService>(MockTimeService())
      ..registerSingleton<LoggingService>(MockLoggingService());
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
    mockFile = MockDataReaderFile();

    container = ProviderContainer(
      overrides: [
        clipboardRepositoryProvider.overrideWithValue(mockClipboard),
      ],
    );

    when(() => mockClipboard.read()).thenAnswer((_) async => mockReader);
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
      when(() => mockReader.canProvide(Formats.png)).thenReturn(true);
      when(() => mockReader.canProvide(Formats.jpeg)).thenReturn(false);

      when(() => mockReader.getFile(Formats.png, any()))
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

      verify(() => mockReader.getFile(Formats.png, any())).called(1);
      verify(() => mockFile.readAll()).called(1);
    });

    test('paste handles JPEG data correctly', () async {
      when(() => mockReader.canProvide(Formats.png)).thenReturn(false);
      when(() => mockReader.canProvide(Formats.jpeg)).thenReturn(true);

      when(() => mockReader.getFile(Formats.jpeg, any()))
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

      verify(() => mockReader.getFile(Formats.jpeg, any())).called(1);
      verify(() => mockFile.readAll()).called(1);
    });

    test('paste handles only JPEG when both PNG and JPEG are available',
        () async {
      when(() => mockReader.canProvide(Formats.png)).thenReturn(true);
      when(() => mockReader.canProvide(Formats.jpeg)).thenReturn(true);

      when(() => mockReader.getFile(Formats.jpeg, any()))
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

      verify(() => mockReader.getFile(Formats.jpeg, any())).called(1);
      verify(() => mockFile.readAll()).called(1);
      verifyNever(() => mockReader.getFile(Formats.png, any()));
    });
  });
}
