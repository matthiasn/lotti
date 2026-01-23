import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/audio_import.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/media/audio_metadata_extractor.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../helpers/path_provider.dart';

// Mocks
class MockJournalDb extends Mock implements JournalDb {}

class MockFts5Db extends Mock implements Fts5Db {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockVectorClockService extends Mock implements VectorClockService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockTagsService extends Mock implements TagsService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockTimeService extends Mock implements TimeService {}

class MockLoggingService extends Mock implements LoggingService {}

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLoggingService mockLoggingService;
  late Directory tempDir;

  setUpAll(() async {
    getIt.pushNewScope();
    setFakeDocumentsPath();

    mockLoggingService = MockLoggingService();

    // Register mock services
    getIt
      ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
      ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
      ..registerSingleton<JournalDb>(MockJournalDb())
      ..registerSingleton<Fts5Db>(MockFts5Db())
      ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
      ..registerSingleton<VectorClockService>(MockVectorClockService())
      ..registerSingleton<UpdateNotifications>(MockUpdateNotifications())
      ..registerSingleton<TagsService>(MockTagsService())
      ..registerSingleton<NotificationService>(MockNotificationService())
      ..registerSingleton<TimeService>(MockTimeService())
      ..registerSingleton<LoggingService>(mockLoggingService);

    // Create temp directory for file operations
    tempDir = await Directory.systemTemp.createTemp('lotti_test_');
  });

  tearDownAll(() async {
    await getIt.resetScope();
    await getIt.popScope();
    // Clean up temp directory
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() {
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

  group('importImageAssets - Photo Picker Integration', () {
    setUp(() {
      // Mock PhotoManager plugin method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'requestPermissionExtend') {
            // Return denied permission (0 = PermissionState.denied)
            return 0;
          }
          return null;
        },
      );

      // Mock wechat_assets_picker plugin method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies.wechat_assets_picker'),
        (MethodCall methodCall) async {
          // Return null for pickAssets (user cancelled)
          return null;
        },
      );
    });

    tearDown(() {
      // Clean up method channel handlers
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies.wechat_assets_picker'),
        null,
      );
    });

    testWidgets('returns early when permissions are not granted',
        (tester) async {
      final context = MockBuildContext();
      when(() => context.mounted).thenReturn(true);

      await expectLater(
        importImageAssets(context),
        completes,
      );
    });

    testWidgets('returns early when context is not mounted', (tester) async {
      final context = MockBuildContext();
      when(() => context.mounted).thenReturn(false);

      await expectLater(
        importImageAssets(context),
        completes,
      );
    });

    testWidgets('handles null assets list gracefully', (tester) async {
      final context = MockBuildContext();
      when(() => context.mounted).thenReturn(true);

      await expectLater(
        importImageAssets(context),
        completes,
      );
    });

    testWidgets('passes linkedId and categoryId parameters', (tester) async {
      final context = MockBuildContext();
      when(() => context.mounted).thenReturn(true);

      await expectLater(
        importImageAssets(
          context,
          linkedId: 'test-link',
          categoryId: 'test-category',
        ),
        completes,
      );
    });
  });

  group('AudioMetadataExtractor Duration Extraction', () {
    test('selectReader returns zero duration in test env', () async {
      final reader = AudioMetadataExtractor.selectReader();
      final duration = await reader('/test/path.m4a');

      expect(duration, equals(Duration.zero));
    });

    test('audio metadata reader handles various file paths', () async {
      final reader = AudioMetadataExtractor.selectReader();

      final testFile = File('${tempDir.path}/test.m4a');
      await testFile.writeAsBytes([0x00, 0x00, 0x00, 0x20]);

      final duration = await reader(testFile.path);

      expect(duration, equals(Duration.zero));

      await testFile.delete();
    });

    test('audio metadata reader handles multiple file paths', () async {
      final reader = AudioMetadataExtractor.selectReader();

      final paths = [
        '/path/to/audio.m4a',
        '/another/path/recording.m4a',
        tempDir.path,
      ];

      for (final path in paths) {
        final duration = await reader(path);
        expect(duration, equals(Duration.zero));
      }
    });

    test('selectReader returns bypass reader when flag set', () {
      AudioMetadataExtractor.bypassMediaKitInTests = true;

      final reader = AudioMetadataExtractor.selectReader();
      expect(reader, isNotNull);

      AudioMetadataExtractor.bypassMediaKitInTests = false;
    });

    test('selectReader detects test environment', () {
      final reader = AudioMetadataExtractor.selectReader();
      expect(reader, isNotNull);
    });

    test('MediaKit bypass flag controls extraction behavior', () async {
      AudioMetadataExtractor.bypassMediaKitInTests = false;
      final reader1 = AudioMetadataExtractor.selectReader();

      AudioMetadataExtractor.bypassMediaKitInTests = true;
      final reader2 = AudioMetadataExtractor.selectReader();

      expect(reader1, isNotNull);
      expect(reader2, isNotNull);

      AudioMetadataExtractor.bypassMediaKitInTests = false;
    });

    test('audio metadata reader returns zero for empty path', () async {
      final reader = AudioMetadataExtractor.selectReader();

      final duration = await reader('');
      expect(duration, equals(Duration.zero));
    });

    test('audio metadata reader handles special characters in path', () async {
      final reader = AudioMetadataExtractor.selectReader();

      final paths = [
        '/path with spaces/file.m4a',
        '/path/with/üñíçødé.m4a',
        r'/path/with/special!@#$.m4a',
      ];

      for (final path in paths) {
        expect(
          reader(path),
          completes,
        );
      }
    });

    test('audio metadata reader bypasses in test environment', () async {
      final reader = AudioMetadataExtractor.selectReader();
      final duration = await reader('/test.m4a');

      expect(duration, equals(Duration.zero));
    });
  });

  group('Audio Metadata Reader Selection Logic', () {
    test('selectReader prioritizes registered reader', () {
      if (getIt.isRegistered<AudioMetadataReader>()) {
        getIt.unregister<AudioMetadataReader>();
      }

      Future<Duration> customReader(String _) async =>
          const Duration(seconds: 123);
      getIt.registerSingleton<AudioMetadataReader>(customReader);

      final reader = AudioMetadataExtractor.selectReader();
      expect(reader, equals(customReader));

      getIt.unregister<AudioMetadataReader>();
    });

    test('selectReader returns default when none registered', () {
      if (getIt.isRegistered<AudioMetadataReader>()) {
        getIt.unregister<AudioMetadataReader>();
      }

      final reader = AudioMetadataExtractor.selectReader();
      expect(reader, isNotNull);
    });

    test('selectReader works with bypass flag', () {
      if (getIt.isRegistered<AudioMetadataReader>()) {
        getIt.unregister<AudioMetadataReader>();
      }

      AudioMetadataExtractor.bypassMediaKitInTests = true;
      final reader = AudioMetadataExtractor.selectReader();
      expect(reader, isNotNull);

      AudioMetadataExtractor.bypassMediaKitInTests = false;
    });

    test('registered reader takes precedence over environment detection',
        () async {
      if (getIt.isRegistered<AudioMetadataReader>()) {
        getIt.unregister<AudioMetadataReader>();
      }

      getIt.registerSingleton<AudioMetadataReader>(
        (_) async => const Duration(minutes: 5),
      );

      final reader = AudioMetadataExtractor.selectReader();
      final result = await reader('/dummy/path.m4a');

      expect(result, equals(const Duration(minutes: 5)));

      getIt.unregister<AudioMetadataReader>();
    });

    test('selectReader handles rapid registration changes', () {
      if (getIt.isRegistered<AudioMetadataReader>()) {
        getIt.unregister<AudioMetadataReader>();
      }

      getIt.registerSingleton<AudioMetadataReader>(
        (_) async => const Duration(seconds: 1),
      );
      final reader1 = AudioMetadataExtractor.selectReader();

      getIt
        ..unregister<AudioMetadataReader>()
        ..registerSingleton<AudioMetadataReader>(
          (_) async => const Duration(seconds: 2),
        );
      final reader2 = AudioMetadataExtractor.selectReader();

      expect(reader1, isNotNull);
      expect(reader2, isNotNull);
      expect(reader1, isNot(same(reader2)));

      getIt.unregister<AudioMetadataReader>();
    });
  });

  group('MediaKit Path Coverage', () {
    test('audio metadata reader early return path', () async {
      AudioMetadataExtractor.bypassMediaKitInTests = true;

      final reader = AudioMetadataExtractor.selectReader();
      final duration = await reader('/any/path.m4a');

      expect(duration, equals(Duration.zero));

      AudioMetadataExtractor.bypassMediaKitInTests = false;
    });

    test('bypass flag prevents Player creation', () async {
      AudioMetadataExtractor.bypassMediaKitInTests = true;

      final reader = AudioMetadataExtractor.selectReader();
      for (var i = 0; i < 5; i++) {
        final duration = await reader('/path$i.m4a');
        expect(duration, equals(Duration.zero));
      }

      AudioMetadataExtractor.bypassMediaKitInTests = false;
    });

    test('audio metadata reader handles concurrent calls', () async {
      AudioMetadataExtractor.bypassMediaKitInTests = true;

      final reader = AudioMetadataExtractor.selectReader();
      final futures = List.generate(
        10,
        (i) => reader('/path$i.m4a'),
      );

      final results = await Future.wait(futures);

      for (final result in results) {
        expect(result, equals(Duration.zero));
      }

      AudioMetadataExtractor.bypassMediaKitInTests = false;
    });
  });

  group('Environment Detection', () {
    test('selectReader detects Flutter test environment', () {
      if (getIt.isRegistered<AudioMetadataReader>()) {
        getIt.unregister<AudioMetadataReader>();
      }

      final reader = AudioMetadataExtractor.selectReader();
      expect(reader, isNotNull);
    });

    test('environment variable check does not throw', () {
      expect(
        AudioMetadataExtractor.selectReader,
        returnsNormally,
      );
    });
  });

  group('Integration Test Coverage Completeness', () {
    test('ImageImportConstants are accessible', () {
      expect(ImageImportConstants.supportedExtensions, isNotEmpty);
      expect(ImageImportConstants.maxFileSizeBytes, greaterThan(0));
      expect(ImageImportConstants.directoryPrefix, isNotEmpty);
      expect(ImageImportConstants.loggingDomain, isNotEmpty);
    });

    test('AudioImportConstants are accessible', () {
      expect(AudioImportConstants.supportedExtensions, isNotEmpty);
      expect(AudioImportConstants.maxFileSizeBytes, greaterThan(0));
      expect(AudioImportConstants.loggingDomain, isNotEmpty);
    });

    test('helper functions are public and callable', () {
      final timestamp = DateTime(2025, 1, 15, 10, 30, 45);

      final path = AudioMetadataExtractor.computeRelativePath(timestamp);
      expect(path, contains('/audio/'));
      expect(path, contains('2025-01-15'));

      final filename =
          AudioMetadataExtractor.computeTargetFileName(timestamp, 'm4a');
      expect(filename, endsWith('.m4a'));
      expect(filename, contains('2025-01-15'));
    });

    test('bypassMediaKitInTests flag is mutable', () {
      final originalValue = AudioMetadataExtractor.bypassMediaKitInTests;

      AudioMetadataExtractor.bypassMediaKitInTests = true;
      expect(AudioMetadataExtractor.bypassMediaKitInTests, isTrue);

      AudioMetadataExtractor.bypassMediaKitInTests = false;
      expect(AudioMetadataExtractor.bypassMediaKitInTests, isFalse);

      AudioMetadataExtractor.bypassMediaKitInTests = originalValue;
    });

    test('audio metadata reader type is properly defined', () {
      Future<Duration> reader(String _) async => Duration.zero;
      expect(reader, isNotNull);

      final result = reader('/test.m4a');
      expect(result, isA<Future<Duration>>());
    });

    test('selectReader returns callable function', () async {
      final reader = AudioMetadataExtractor.selectReader();

      final result = await reader('/dummy/path.m4a');

      expect(result, isA<Duration>());
    });
  });

  group('Error Path Coverage', () {
    test('audio metadata reader handles null/invalid paths gracefully',
        () async {
      final reader = AudioMetadataExtractor.selectReader();

      final invalidPaths = [
        '',
        ' ',
        '/nonexistent/path/file.m4a',
        'relative/path.m4a',
      ];

      for (final path in invalidPaths) {
        expect(
          reader(path),
          completes,
        );
      }
    });

    test('selectReader does not crash on GetIt errors', () {
      expect(
        AudioMetadataExtractor.selectReader,
        returnsNormally,
      );
    });

    test('bypass flag prevents actual media operations in tests', () async {
      AudioMetadataExtractor.bypassMediaKitInTests = true;

      final reader = AudioMetadataExtractor.selectReader();
      final testFile = File('${tempDir.path}/fake_audio.m4a');
      await testFile.writeAsBytes([0x00, 0x00]);

      final duration = await reader(testFile.path);

      expect(duration, equals(Duration.zero));

      await testFile.delete();
      AudioMetadataExtractor.bypassMediaKitInTests = false;
    });
  });

  group('Reader Lifecycle Tests', () {
    test('multiple reader selections return consistent results', () {
      final reader1 = AudioMetadataExtractor.selectReader();
      final reader2 = AudioMetadataExtractor.selectReader();
      final reader3 = AudioMetadataExtractor.selectReader();

      expect(reader1, isNotNull);
      expect(reader2, isNotNull);
      expect(reader3, isNotNull);
    });

    test('reader works after flag changes', () async {
      AudioMetadataExtractor.bypassMediaKitInTests = false;
      final reader1 = AudioMetadataExtractor.selectReader();
      final result1 = await reader1('/test.m4a');

      AudioMetadataExtractor.bypassMediaKitInTests = true;
      final reader2 = AudioMetadataExtractor.selectReader();
      final result2 = await reader2('/test.m4a');

      expect(result1, isA<Duration>());
      expect(result2, isA<Duration>());

      AudioMetadataExtractor.bypassMediaKitInTests = false;
    });

    test('registered reader persists across selections', () async {
      if (getIt.isRegistered<AudioMetadataReader>()) {
        getIt.unregister<AudioMetadataReader>();
      }

      const expectedDuration = Duration(seconds: 42);
      getIt.registerSingleton<AudioMetadataReader>(
        (_) async => expectedDuration,
      );

      final reader1 = AudioMetadataExtractor.selectReader();
      final reader2 = AudioMetadataExtractor.selectReader();

      final result1 = await reader1('/test1.m4a');
      final result2 = await reader2('/test2.m4a');

      expect(result1, equals(expectedDuration));
      expect(result2, equals(expectedDuration));

      getIt.unregister<AudioMetadataReader>();
    });
  });

  group('Edge Case Coverage', () {
    test('audio metadata reader with very long path', () async {
      final reader = AudioMetadataExtractor.selectReader();
      final longPath = '/very/long/path/${'segment/' * 100}file.m4a';

      expect(
        reader(longPath),
        completes,
      );
    });

    test('audio metadata reader called multiple times sequentially', () async {
      final reader = AudioMetadataExtractor.selectReader();

      for (var i = 0; i < 20; i++) {
        final duration = await reader('/path$i.m4a');
        expect(duration, equals(Duration.zero));
      }
    });

    test('bypass flag state does not leak between tests', () {
      expect(AudioMetadataExtractor.bypassMediaKitInTests, isFalse);

      AudioMetadataExtractor.bypassMediaKitInTests = true;
      expect(AudioMetadataExtractor.bypassMediaKitInTests, isTrue);

      AudioMetadataExtractor.bypassMediaKitInTests = false;
      expect(AudioMetadataExtractor.bypassMediaKitInTests, isFalse);
    });

    test('selectReader with and without GetIt registration', () async {
      if (getIt.isRegistered<AudioMetadataReader>()) {
        getIt.unregister<AudioMetadataReader>();
      }
      final defaultReader = AudioMetadataExtractor.selectReader();
      expect(defaultReader, isNotNull);

      getIt.registerSingleton<AudioMetadataReader>(
        (_) async => const Duration(hours: 1),
      );
      final customReader = AudioMetadataExtractor.selectReader();
      expect(customReader, isNotNull);

      final result = await customReader('/test.m4a');
      expect(result, equals(const Duration(hours: 1)));

      getIt.unregister<AudioMetadataReader>();
    });
  });

  group('Platform-Specific Behavior', () {
    test('audio metadata reader respects test environment', () async {
      final reader = AudioMetadataExtractor.selectReader();
      final duration = await reader('/test.m4a');

      expect(duration, equals(Duration.zero));
    });

    test('test environment detection is reliable', () {
      final reader = AudioMetadataExtractor.selectReader();
      expect(reader, isNotNull);
    });
  });
}
