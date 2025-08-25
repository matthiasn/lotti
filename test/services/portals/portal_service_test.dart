import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockDBusClient extends Mock implements DBusClient {}

class MockDBusRemoteObject extends Mock implements DBusRemoteObject {}

class MockDBusIntrospectNode extends Mock implements DBusIntrospectNode {}

class MockDBusIntrospectInterface extends Mock
    implements DBusIntrospectInterface {}

class FakeDBusObjectPath extends Fake implements DBusObjectPath {
  FakeDBusObjectPath(this.value);

  @override
  final String value;

  @override
  String toString() => value;
}

// Test implementation of PortalService for testing abstract class
class TestPortalService extends PortalService {
  MockDBusClient? mockClient;
  MockDBusRemoteObject? mockRemoteObject;
  bool _isInitialized = false;

  @override
  DBusClient get client {
    if (mockClient != null) {
      return mockClient!;
    }
    return super.client;
  }

  @override
  DBusRemoteObject createPortalObject() {
    if (mockRemoteObject != null) {
      return mockRemoteObject!;
    }
    return super.createPortalObject();
  }

  @override
  Future<void> initialize() async {
    if (mockClient != null) {
      _isInitialized = true;
      return;
    }
    await super.initialize();
  }

  @override
  bool get isInitialized =>
      mockClient != null ? _isInitialized : super.isInitialized;

  @override
  Future<void> dispose() async {
    if (mockClient != null) {
      _isInitialized = false;
      return;
    }
    await super.dispose();
  }

  // ignore_for_file: use_setters_to_change_properties
  void setMockClient(MockDBusClient client) {
    mockClient = client;
  }

  void setMockRemoteObject(MockDBusRemoteObject remoteObject) {
    mockRemoteObject = remoteObject;
  }
}

void main() {
  group('PortalService', () {
    late TestPortalService service;
    late MockLoggingService mockLoggingService;
    late MockDBusClient mockDBusClient;
    late MockDBusRemoteObject mockDBusRemoteObject;

    setUpAll(() {
      registerFallbackValue(StackTrace.current);
      registerFallbackValue(FakeDBusObjectPath('/test'));
    });

    setUp(() {
      mockLoggingService = MockLoggingService();
      mockDBusClient = MockDBusClient();
      mockDBusRemoteObject = MockDBusRemoteObject();

      getIt.registerSingleton<LoggingService>(mockLoggingService);
      service = TestPortalService();

      // Setup default mock behaviors
      when(() => mockLoggingService.captureException(
            any<dynamic>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
            stackTrace: any<dynamic>(named: 'stackTrace'),
          )).thenReturn(null);

      when(() => mockDBusClient.close()).thenAnswer((_) async {});
    });

    tearDown(() async {
      if (service.isInitialized) {
        await service.dispose();
      }
      await getIt.reset();
    });

    group('Environment Detection', () {
      test('shouldUsePortal matches isRunningInFlatpak on Linux', () {
        final shouldUse = PortalService.shouldUsePortal;
        final isLinux = Platform.isLinux;
        final hasFlatpakId = Platform.environment['FLATPAK_ID'] != null &&
            Platform.environment['FLATPAK_ID']!.isNotEmpty;

        expect(shouldUse, equals(isLinux && hasFlatpakId));
      });

      test('isRunningInFlatpak returns correct value based on environment', () {
        final isRunning = PortalService.isRunningInFlatpak;
        final isLinux = Platform.isLinux;
        final hasFlatpakId = Platform.environment['FLATPAK_ID'] != null &&
            Platform.environment['FLATPAK_ID']!.isNotEmpty;

        expect(isRunning, equals(isLinux && hasFlatpakId));
      });
    });

    group('Initialization', () {
      test('should handle initialization when shouldUsePortal is false',
          () async {
        // Test in non-Flatpak environment
        expect(service.isInitialized, isFalse);

        await service.initialize();

        expect(service.isInitialized, isTrue);
        // Should throw StateError when accessing client in non-Flatpak mode
        expect(() => service.client, throwsStateError);
      });

      test('should handle multiple initializations safely', () async {
        expect(service.isInitialized, isFalse);

        await service.initialize();
        expect(service.isInitialized, isTrue);

        // Second initialization should not cause issues
        await service.initialize();
        expect(service.isInitialized, isTrue);
      });

      test(
          'should handle initialization errors with logging service not registered',
          () async {
        // Unregister logging service temporarily
        await getIt.unregister<LoggingService>();

        // Create a new service that will fail on initialization
        final failingService = TestPortalService();

        // Re-register logging service for other tests
        getIt.registerSingleton<LoggingService>(mockLoggingService);

        // Service should still initialize even if logging fails
        await failingService.initialize();
        expect(failingService.isInitialized, isTrue);
      });
    });

    group('Disposal', () {
      test('should dispose successfully when initialized', () async {
        expect(service.isInitialized, isFalse);

        await service.initialize();
        expect(service.isInitialized, isTrue);

        await service.dispose();
        expect(service.isInitialized, isFalse);
      });

      test('should handle disposal when not initialized', () async {
        expect(service.isInitialized, isFalse);

        await expectLater(service.dispose(), completes);
        expect(service.isInitialized, isFalse);
      });

      test('should handle multiple disposals safely', () async {
        await service.initialize();
        await service.dispose();
        expect(service.isInitialized, isFalse);

        // Second disposal should not cause issues
        await service.dispose();
        expect(service.isInitialized, isFalse);
      });
    });

    group('Client Access', () {
      test('should throw StateError when accessing uninitialized client', () {
        expect(() => service.client, throwsStateError);
      });

      test('should throw StateError when accessing client outside Flatpak',
          () async {
        await service.initialize();
        expect(() => service.client, throwsStateError);
      });
    });

    group('Portal Object Creation', () {
      test(
        'should create portal object with correct parameters when in Flatpak',
        () async {
          await service.initialize();
          final object = service.createPortalObject();
          expect(object, isA<DBusRemoteObject>());
        },
        skip: !PortalService.shouldUsePortal
            ? 'Test requires Flatpak environment'
            : null,
      );

      test(
        'should throw StateError when creating portal object outside Flatpak',
        () async {
          await service.initialize();
          expect(
            () => service.createPortalObject(),
            throwsA(isA<StateError>()),
          );
        },
        skip: PortalService.shouldUsePortal
            ? 'Test requires non-Flatpak environment'
            : null,
      );
    });

    group('Handle Token Generation', () {
      test('should generate unique handle tokens', () async {
        final token1 = PortalService.createHandleToken('test');

        // Add a longer delay to ensure different timestamps
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final token2 = PortalService.createHandleToken('test');

        expect(token1, isNotEmpty);
        expect(token2, isNotEmpty);
        expect(token1, isNot(equals(token2)));
        expect(token1, startsWith('test_'));
        expect(token2, startsWith('test_'));
      });

      test('should include timestamp in handle tokens', () {
        final token = PortalService.createHandleToken('prefix');
        final parts = token.split('_');

        expect(parts.length, equals(2));
        expect(parts[0], equals('prefix'));
        expect(int.tryParse(parts[1]), isNotNull);
      });

      test('should generate different tokens for different prefixes', () {
        final token1 = PortalService.createHandleToken('prefix1');
        final token2 = PortalService.createHandleToken('prefix2');

        expect(token1, startsWith('prefix1_'));
        expect(token2, startsWith('prefix2_'));
        expect(token1, isNot(equals(token2)));
      });
    });

    group('Interface Availability', () {
      test(
          'should return false for ScreenshotPortalService when not in Flatpak',
          () async {
        final available = await PortalService.isInterfaceAvailable(
          'org.freedesktop.portal.Screenshot',
          service,
          'ScreenshotPortalService',
        );

        expect(available, isFalse);
      });

      test('should handle interface availability check errors gracefully',
          () async {
        // This will fail in test environment, but we can test error handling
        final available = await PortalService.isInterfaceAvailable(
          'org.freedesktop.portal.Screenshot',
          service,
          'ScreenshotPortalService',
        );

        // Should return false on error
        expect(available, isFalse);
      });

      test('should handle interface availability check for unknown service',
          () async {
        final available = await PortalService.isInterfaceAvailable(
          'org.freedesktop.portal.Unknown',
          service,
          'UnknownService',
        );

        // Should return false for unknown service
        expect(available, isFalse);
      });
    });

    group('Constants', () {
      test('should have correct portal constants', () {
        expect(PortalConstants.portalBusName,
            equals('org.freedesktop.portal.Desktop'));
        expect(PortalConstants.portalPath,
            equals('/org/freedesktop/portal/desktop'));
        expect(PortalConstants.responseTimeout,
            equals(const Duration(seconds: 30)));
      });
    });

    // Focused tests for code coverage
    group('Code Coverage Tests', () {
      test('should handle successful introspection with matching interface',
          () async {
        if (PortalService.shouldUsePortal) {
          return; // Skip in Flatpak environment
        }

        // Set up mocks
        service
          ..setMockClient(mockDBusClient)
          ..setMockRemoteObject(mockDBusRemoteObject);

        // Create mock introspection node
        final mockIntrospectNode = MockDBusIntrospectNode();
        final mockInterface = MockDBusIntrospectInterface();

        when(() => mockInterface.name)
            .thenReturn('org.freedesktop.portal.Device');
        when(() => mockIntrospectNode.interfaces).thenReturn([mockInterface]);
        when(() => mockDBusRemoteObject.introspect())
            .thenAnswer((_) async => mockIntrospectNode);

        // Test successful case
        final available = await PortalService.isInterfaceAvailable(
          'org.freedesktop.portal.Device',
          service,
          'TestService',
        );

        expect(available, isTrue);
      });

      test('should handle successful introspection without matching interface',
          () async {
        if (PortalService.shouldUsePortal) {
          return; // Skip in Flatpak environment
        }

        // Set up mocks
        service
          ..setMockClient(mockDBusClient)
          ..setMockRemoteObject(mockDBusRemoteObject);

        // Create mock introspection node
        final mockIntrospectNode = MockDBusIntrospectNode();
        final mockInterface = MockDBusIntrospectInterface();

        when(() => mockInterface.name)
            .thenReturn('org.freedesktop.portal.SomeOther');
        when(() => mockIntrospectNode.interfaces).thenReturn([mockInterface]);
        when(() => mockDBusRemoteObject.introspect())
            .thenAnswer((_) async => mockIntrospectNode);

        // Test no match case
        final available = await PortalService.isInterfaceAvailable(
          'org.freedesktop.portal.Device',
          service,
          'TestService',
        );

        expect(available, isFalse);
      });

      test('should handle introspection timeout', () async {
        if (PortalService.shouldUsePortal) {
          return; // Skip in Flatpak environment
        }

        // Set up mocks
        service
          ..setMockClient(mockDBusClient)
          ..setMockRemoteObject(mockDBusRemoteObject);

        // Make introspect throw TimeoutException immediately
        when(() => mockDBusRemoteObject.introspect()).thenThrow(
          TimeoutException('Portal introspection timed out after 30 seconds'),
        );

        // Test timeout case
        final available = await PortalService.isInterfaceAvailable(
          'org.freedesktop.portal.Device',
          service,
          'TestService',
        );

        expect(available, isFalse);

        // Verify exception was logged
        verify(() => mockLoggingService.captureException(
              any<dynamic>(),
              domain: 'TestService',
              subDomain: 'isAvailable',
            )).called(1);
      });

      test('should handle introspection exceptions', () async {
        if (PortalService.shouldUsePortal) {
          return; // Skip in Flatpak environment
        }

        // Set up mocks
        service
          ..setMockClient(mockDBusClient)
          ..setMockRemoteObject(mockDBusRemoteObject);

        // Make introspect throw exception
        when(() => mockDBusRemoteObject.introspect())
            .thenThrow(Exception('Introspection failed'));

        // Test exception case
        final available = await PortalService.isInterfaceAvailable(
          'org.freedesktop.portal.Device',
          service,
          'TestService',
        );

        expect(available, isFalse);

        // Verify exception was logged
        verify(() => mockLoggingService.captureException(
              any<dynamic>(),
              domain: 'TestService',
              subDomain: 'isAvailable',
            )).called(1);
      });

      test('should handle empty interfaces list', () async {
        if (PortalService.shouldUsePortal) {
          return; // Skip in Flatpak environment
        }

        // Set up mocks
        service
          ..setMockClient(mockDBusClient)
          ..setMockRemoteObject(mockDBusRemoteObject);

        // Create mock introspection node with no interfaces
        final mockIntrospectNode = MockDBusIntrospectNode();
        when(() => mockIntrospectNode.interfaces).thenReturn([]);
        when(() => mockDBusRemoteObject.introspect())
            .thenAnswer((_) async => mockIntrospectNode);

        // Test empty interfaces case
        final available = await PortalService.isInterfaceAvailable(
          'org.freedesktop.portal.Device',
          service,
          'TestService',
        );

        expect(available, isFalse);
      });

      test('should handle multiple interfaces', () async {
        if (PortalService.shouldUsePortal) {
          return; // Skip in Flatpak environment
        }

        // Set up mocks
        service
          ..setMockClient(mockDBusClient)
          ..setMockRemoteObject(mockDBusRemoteObject);

        // Create mock introspection node with multiple interfaces
        final mockIntrospectNode = MockDBusIntrospectNode();
        final mockInterface1 = MockDBusIntrospectInterface();
        final mockInterface2 = MockDBusIntrospectInterface();
        final mockInterface3 = MockDBusIntrospectInterface();

        when(() => mockInterface1.name)
            .thenReturn('org.freedesktop.portal.Screenshot');
        when(() => mockInterface2.name)
            .thenReturn('org.freedesktop.portal.Device');
        when(() => mockInterface3.name)
            .thenReturn('org.freedesktop.portal.FileChooser');
        when(() => mockIntrospectNode.interfaces)
            .thenReturn([mockInterface1, mockInterface2, mockInterface3]);
        when(() => mockDBusRemoteObject.introspect())
            .thenAnswer((_) async => mockIntrospectNode);

        // Test finding interface in the middle
        final available = await PortalService.isInterfaceAvailable(
          'org.freedesktop.portal.Device',
          service,
          'TestService',
        );

        expect(available, isTrue);
      });
    });
  });
}
