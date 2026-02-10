import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixService extends Mock implements MatrixService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockMatrixService mockMatrixService;

  const testBundle = SyncProvisioningBundle(
    v: 1,
    homeServer: 'https://matrix.example.com',
    user: '@alice:example.com',
    password: 'secret123',
    roomId: '!room123:example.com',
  );

  String encodeBundle(Map<String, dynamic> json) {
    return base64UrlEncode(utf8.encode(jsonEncode(json)));
  }

  final validBase64 = encodeBundle(testBundle.toJson());

  setUpAll(() {
    registerFallbackValue(
      const MatrixConfig(
        homeServer: '',
        user: '',
        password: '',
      ),
    );
  });

  setUp(() {
    mockMatrixService = MockMatrixService();

    when(() => mockMatrixService.setConfig(any())).thenAnswer((_) async {});
    when(() => mockMatrixService.login()).thenAnswer((_) async => true);
    when(() => mockMatrixService.joinRoom(any()))
        .thenAnswer((_) async => testBundle.roomId);
    when(() => mockMatrixService.saveRoom(any())).thenAnswer((_) async {});
    when(() => mockMatrixService.loadConfig()).thenAnswer(
      (_) async => MatrixConfig(
        homeServer: testBundle.homeServer,
        user: testBundle.user,
        password: testBundle.password,
      ),
    );
    when(
      () => mockMatrixService.changePassword(
        oldPassword: any(named: 'oldPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        matrixServiceProvider.overrideWithValue(mockMatrixService),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('ProvisioningController', () {
    group('decodeBundle', () {
      test('decodes valid Base64 bundle', () {
        final bundle = container
            .read(provisioningControllerProvider.notifier)
            .decodeBundle(validBase64);

        expect(bundle.v, 1);
        expect(bundle.homeServer, 'https://matrix.example.com');
        expect(bundle.user, '@alice:example.com');
        expect(bundle.password, 'secret123');
        expect(bundle.roomId, '!room123:example.com');

        container.read(provisioningControllerProvider).when(
              initial: () => fail('Expected bundleDecoded'),
              bundleDecoded: (b) {
                expect(b.user, '@alice:example.com');
              },
              loggingIn: () => fail('Expected bundleDecoded'),
              joiningRoom: () => fail('Expected bundleDecoded'),
              rotatingPassword: () => fail('Expected bundleDecoded'),
              ready: (_) => fail('Expected bundleDecoded'),
              done: () => fail('Expected bundleDecoded'),
              error: (_) => fail('Expected bundleDecoded'),
            );
      });

      test('throws FormatException for invalid Base64', () {
        expect(
          () => container
              .read(provisioningControllerProvider.notifier)
              .decodeBundle('not-valid-base64!!!'),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for valid Base64 but invalid JSON', () {
        final invalidJson = base64UrlEncode(utf8.encode('not json'));
        expect(
          () => container
              .read(provisioningControllerProvider.notifier)
              .decodeBundle(invalidJson),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for missing required fields', () {
        final missingFields = encodeBundle({'v': 1, 'homeServer': 'https://x'});
        expect(
          () => container
              .read(provisioningControllerProvider.notifier)
              .decodeBundle(missingFields),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for user without @ prefix', () {
        final badUser = encodeBundle({
          'v': 1,
          'homeServer': 'https://matrix.example.com',
          'user': 'alice:example.com',
          'password': 'secret',
          'roomId': '!room:example.com',
        });
        expect(
          () => container
              .read(provisioningControllerProvider.notifier)
              .decodeBundle(badUser),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('MXID'),
            ),
          ),
        );
      });

      test('throws FormatException for roomId without ! prefix', () {
        final badRoom = encodeBundle({
          'v': 1,
          'homeServer': 'https://matrix.example.com',
          'user': '@alice:example.com',
          'password': 'secret',
          'roomId': 'room:example.com',
        });
        expect(
          () => container
              .read(provisioningControllerProvider.notifier)
              .decodeBundle(badRoom),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('room ID'),
            ),
          ),
        );
      });

      test('throws FormatException for invalid homeserver URL', () {
        final badServer = encodeBundle({
          'v': 1,
          'homeServer': 'not-a-url',
          'user': '@alice:example.com',
          'password': 'secret',
          'roomId': '!room:example.com',
        });
        expect(
          () => container
              .read(provisioningControllerProvider.notifier)
              .decodeBundle(badServer),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('homeserver'),
            ),
          ),
        );
      });

      test('throws FormatException for unsupported version', () {
        final badVersion = encodeBundle({
          'v': 99,
          'homeServer': 'https://matrix.example.com',
          'user': '@alice:example.com',
          'password': 'secret',
          'roomId': '!room:example.com',
        });
        expect(
          () => container
              .read(provisioningControllerProvider.notifier)
              .decodeBundle(badVersion),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('version'),
            ),
          ),
        );
      });

      test('handles unpadded Base64url', () {
        // Create a base64url string without padding
        final unpadded = base64UrlEncode(
          utf8.encode(jsonEncode(testBundle.toJson())),
        ).replaceAll('=', '');
        final bundle = container
            .read(provisioningControllerProvider.notifier)
            .decodeBundle(unpadded);
        expect(bundle.user, '@alice:example.com');
      });
    });

    group('configureFromBundle - desktop (rotatePassword: true)', () {
      test('progresses through all states to ready', () async {
        final controller = container
            .read(provisioningControllerProvider.notifier)
          ..decodeBundle(validBase64);

        final states = <ProvisioningState>[];
        container.listen(
          provisioningControllerProvider,
          (_, next) => states.add(next),
        );

        await controller.configureFromBundle(testBundle);

        // Verify the service was called
        verify(() => mockMatrixService.setConfig(any())).called(1);
        verify(() => mockMatrixService.login()).called(1);
        verify(() => mockMatrixService.joinRoom(testBundle.roomId)).called(1);
        verify(() => mockMatrixService.saveRoom(testBundle.roomId)).called(1);
        verify(
          () => mockMatrixService.changePassword(
            oldPassword: any(named: 'oldPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        ).called(1);

        // Final state should be ready with a handover base64 string
        container.read(provisioningControllerProvider).when(
              initial: () => fail('Expected ready'),
              bundleDecoded: (_) => fail('Expected ready'),
              loggingIn: () => fail('Expected ready'),
              joiningRoom: () => fail('Expected ready'),
              rotatingPassword: () => fail('Expected ready'),
              ready: (handover) {
                // Verify the handover can be decoded
                final decoded = utf8.decode(base64Decode(
                  handover.padRight(
                    handover.length + (4 - handover.length % 4) % 4,
                    '=',
                  ),
                ));
                final json = jsonDecode(decoded) as Map<String, dynamic>;
                final handoverBundle = SyncProvisioningBundle.fromJson(json);
                expect(handoverBundle.homeServer, testBundle.homeServer);
                expect(handoverBundle.user, testBundle.user);
                expect(handoverBundle.roomId, testBundle.roomId);
                // Password should be different (rotated)
                expect(
                  handoverBundle.password,
                  isNot(testBundle.password),
                );
              },
              done: () => fail('Expected ready'),
              error: (_) => fail('Expected ready'),
            );
      });

      test('sets error state when login fails', () async {
        when(() => mockMatrixService.login()).thenAnswer((_) async => false);

        await container
            .read(provisioningControllerProvider.notifier)
            .configureFromBundle(testBundle);

        container.read(provisioningControllerProvider).when(
              initial: () => fail('Expected error'),
              bundleDecoded: (_) => fail('Expected error'),
              loggingIn: () => fail('Expected error'),
              joiningRoom: () => fail('Expected error'),
              rotatingPassword: () => fail('Expected error'),
              ready: (_) => fail('Expected error'),
              done: () => fail('Expected error'),
              error: (message) {
                expect(message, contains('Login failed'));
              },
            );
      });

      test('sets error state when joinRoom throws', () async {
        when(() => mockMatrixService.joinRoom(any()))
            .thenThrow(Exception('Room not found'));

        await container
            .read(provisioningControllerProvider.notifier)
            .configureFromBundle(testBundle);

        container.read(provisioningControllerProvider).when(
              initial: () => fail('Expected error'),
              bundleDecoded: (_) => fail('Expected error'),
              loggingIn: () => fail('Expected error'),
              joiningRoom: () => fail('Expected error'),
              rotatingPassword: () => fail('Expected error'),
              ready: (_) => fail('Expected error'),
              done: () => fail('Expected error'),
              error: (message) {
                expect(message, contains('Room not found'));
              },
            );
      });

      test('sets error state when changePassword throws', () async {
        when(
          () => mockMatrixService.changePassword(
            oldPassword: any(named: 'oldPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenThrow(Exception('Password change denied'));

        await container
            .read(provisioningControllerProvider.notifier)
            .configureFromBundle(testBundle);

        container.read(provisioningControllerProvider).when(
              initial: () => fail('Expected error'),
              bundleDecoded: (_) => fail('Expected error'),
              loggingIn: () => fail('Expected error'),
              joiningRoom: () => fail('Expected error'),
              rotatingPassword: () => fail('Expected error'),
              ready: (_) => fail('Expected error'),
              done: () => fail('Expected error'),
              error: (message) {
                expect(message, contains('Password change denied'));
              },
            );
      });
    });

    group('configureFromBundle - mobile (rotatePassword: false)', () {
      test('progresses to done without rotating password', () async {
        await container
            .read(provisioningControllerProvider.notifier)
            .configureFromBundle(
              testBundle,
              rotatePassword: false,
            );

        verify(() => mockMatrixService.setConfig(any())).called(1);
        verify(() => mockMatrixService.login()).called(1);
        verify(() => mockMatrixService.joinRoom(testBundle.roomId)).called(1);
        verifyNever(
          () => mockMatrixService.changePassword(
            oldPassword: any(named: 'oldPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        );

        container.read(provisioningControllerProvider).when(
              initial: () => fail('Expected done'),
              bundleDecoded: (_) => fail('Expected done'),
              loggingIn: () => fail('Expected done'),
              joiningRoom: () => fail('Expected done'),
              rotatingPassword: () => fail('Expected done'),
              ready: (_) => fail('Expected done'),
              done: () {}, // expected
              error: (_) => fail('Expected done'),
            );
      });
    });

    group('reset', () {
      test('resets to initial state', () {
        final controller = container
            .read(provisioningControllerProvider.notifier)
          ..decodeBundle(validBase64);

        // Verify we're in bundleDecoded state
        container.read(provisioningControllerProvider).when(
              initial: () => fail('Expected bundleDecoded'),
              bundleDecoded: (_) {}, // expected
              loggingIn: () => fail('Expected bundleDecoded'),
              joiningRoom: () => fail('Expected bundleDecoded'),
              rotatingPassword: () => fail('Expected bundleDecoded'),
              ready: (_) => fail('Expected bundleDecoded'),
              done: () => fail('Expected bundleDecoded'),
              error: (_) => fail('Expected bundleDecoded'),
            );

        controller.reset();

        container.read(provisioningControllerProvider).when(
              initial: () {}, // expected
              bundleDecoded: (_) => fail('Expected initial'),
              loggingIn: () => fail('Expected initial'),
              joiningRoom: () => fail('Expected initial'),
              rotatingPassword: () => fail('Expected initial'),
              ready: (_) => fail('Expected initial'),
              done: () => fail('Expected initial'),
              error: (_) => fail('Expected initial'),
            );
      });
    });

    group('Base64 roundtrip', () {
      test('encode then decode produces same bundle', () {
        final json = jsonEncode(testBundle.toJson());
        final encoded = base64UrlEncode(utf8.encode(json));

        final decoded = container
            .read(provisioningControllerProvider.notifier)
            .decodeBundle(encoded);

        expect(decoded, testBundle);
      });
    });
  });
}
