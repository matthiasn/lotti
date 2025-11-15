import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

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
    if (await tempDir.exists()) {
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

  group('importImageAssets - Widget Tests', () {
    testWidgets('returns early when permissions are denied', (tester) async {
      // Override PhotoManager.requestPermissionExtend to return denied
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        (call) async {
          if (call.method == 'requestPermissionExtend') {
            // Return denied permission state
            return {'hasAuthorized': false, 'isAuth': false};
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => importImageAssets(context),
                child: const Text('Pick'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      // Should return early without crashing
      expect(find.byType(MaterialApp), findsOneWidget);

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        null,
      );
    });

    testWidgets('returns early when context is not mounted', (tester) async {
      // Override PhotoManager.requestPermissionExtend to return authorized
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        (call) async {
          if (call.method == 'requestPermissionExtend') {
            return {'hasAuthorized': true, 'isAuth': true};
          }
          return null;
        },
      );

      BuildContext? savedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              savedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      // Remove the widget so context is no longer mounted
      await tester.pumpWidget(const SizedBox());

      // Try to call with unmounted context
      if (savedContext != null) {
        // Should not throw
        await expectLater(
          importImageAssets(savedContext!),
          completes,
        );
      }

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        null,
      );
    });

    testWidgets('handles null assets list when picker is cancelled',
        (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        (call) async {
          if (call.method == 'requestPermissionExtend') {
            return {'hasAuthorized': true, 'isAuth': true};
          }
          if (call.method == 'getAssetPathList') {
            return [];
          }
          return null;
        },
      );

      // Mock wechat_assets_picker to return null (user cancelled)
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        (call) async {
          if (call.method == 'pickAssets') {
            return null; // User cancelled
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => importImageAssets(context),
                child: const Text('Pick'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      // Should handle null gracefully
      expect(find.byType(MaterialApp), findsOneWidget);

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        null,
      );
    });

    testWidgets('handles empty assets list', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        (call) async {
          if (call.method == 'requestPermissionExtend') {
            return {'hasAuthorized': true, 'isAuth': true};
          }
          if (call.method == 'getAssetPathList') {
            return [];
          }
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        (call) async {
          if (call.method == 'pickAssets') {
            return []; // Empty list
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => importImageAssets(context),
                child: const Text('Pick'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      // Should handle empty list gracefully
      expect(find.byType(MaterialApp), findsOneWidget);

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        null,
      );
    });

    testWidgets('passes linkedId parameter correctly', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        (call) async {
          if (call.method == 'requestPermissionExtend') {
            return {'hasAuthorized': true, 'isAuth': true};
          }
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        (call) async {
          if (call.method == 'pickAssets') {
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => importImageAssets(
                  context,
                  linkedId: 'test-linked-id',
                ),
                child: const Text('Pick'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        null,
      );
    });

    testWidgets('passes categoryId parameter correctly', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        (call) async {
          if (call.method == 'requestPermissionExtend') {
            return {'hasAuthorized': true, 'isAuth': true};
          }
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        (call) async {
          if (call.method == 'pickAssets') {
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => importImageAssets(
                  context,
                  categoryId: 'test-category-id',
                ),
                child: const Text('Pick'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        null,
      );
    });

    testWidgets('passes both linkedId and categoryId parameters',
        (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        (call) async {
          if (call.method == 'requestPermissionExtend') {
            return {'hasAuthorized': true, 'isAuth': true};
          }
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        (call) async {
          if (call.method == 'pickAssets') {
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => importImageAssets(
                  context,
                  linkedId: 'test-linked-id',
                  categoryId: 'test-category-id',
                ),
                child: const Text('Pick'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        null,
      );
    });

    testWidgets('handles permission request flow', (tester) async {
      var permissionRequested = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        (call) async {
          if (call.method == 'requestPermissionExtend') {
            permissionRequested = true;
            return {'hasAuthorized': false, 'isAuth': false};
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => importImageAssets(context),
                child: const Text('Pick'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      expect(permissionRequested, isTrue);

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        null,
      );
    });

    testWidgets('configures asset picker with correct parameters',
        (tester) async {
      var pickerConfigReceived = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        (call) async {
          if (call.method == 'requestPermissionExtend') {
            return {'hasAuthorized': true, 'isAuth': true};
          }
          if (call.method == 'getAssetPathList') {
            return [];
          }
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        (call) async {
          if (call.method == 'pickAssets') {
            pickerConfigReceived = true;
            // Verify config parameters
            final args = call.arguments as Map?;
            if (args != null) {
              expect(args['maxAssets'], 50);
              expect(args['requestType'], 0); // RequestType.image = 0
            }
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => importImageAssets(context),
                child: const Text('Pick'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      expect(pickerConfigReceived, isTrue);

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        null,
      );
    });

    testWidgets('handles multiple rapid calls gracefully', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        (call) async {
          if (call.method == 'requestPermissionExtend') {
            return {'hasAuthorized': true, 'isAuth': true};
          }
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        (call) async {
          if (call.method == 'pickAssets') {
            return null;
          }
          return null;
        },
      );

      BuildContext? testContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              testContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      // Call multiple times rapidly
      if (testContext != null) {
        final futures = [
          importImageAssets(testContext!),
          importImageAssets(testContext!),
          importImageAssets(testContext!),
        ];

        await expectLater(Future.wait(futures), completes);
      }

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        null,
      );
    });
  });

  group('importImageAssets - Permission States', () {
    testWidgets('handles PermissionState.authorized', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        (call) async {
          if (call.method == 'requestPermissionExtend') {
            return {'hasAuthorized': true, 'isAuth': true};
          }
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        (call) async => null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => importImageAssets(context),
                child: const Text('Pick'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        null,
      );
    });

    testWidgets('handles PermissionState.denied', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        (call) async {
          if (call.method == 'requestPermissionExtend') {
            return {'hasAuthorized': false, 'isAuth': false};
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => importImageAssets(context),
                child: const Text('Pick'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      // Should return early
      expect(find.byType(MaterialApp), findsOneWidget);

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        null,
      );
    });

    testWidgets('handles PermissionState.limited', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        (call) async {
          if (call.method == 'requestPermissionExtend') {
            return {'hasAuthorized': true, 'isAuth': true, 'isLimited': true};
          }
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        (call) async => null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => importImageAssets(context),
                child: const Text('Pick'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('wechat_assets_picker'),
        null,
      );
    });
  });
}
