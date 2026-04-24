import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/state/provisioning_error.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockMatrixService mockMatrixService;

  const provisionedBundle = SyncProvisioningBundle(
    v: 2,
    kind: SyncBundleKind.provisioned,
    homeServer: 'https://matrix.example.com',
    user: '@alice:example.com',
    password: 'secret123',
    roomId: '!room123:example.com',
  );

  const handoverBundle = SyncProvisioningBundle(
    v: 2,
    kind: SyncBundleKind.handover,
    homeServer: 'https://matrix.example.com',
    user: '@alice:example.com',
    password: 'rotated-by-peer',
    roomId: '!room123:example.com',
  );

  String encodeBundle(Map<String, dynamic> json) {
    return base64UrlEncode(utf8.encode(jsonEncode(json)));
  }

  final validProvisionedBase64 = encodeBundle(provisionedBundle.toJson());
  final validHandoverBase64 = encodeBundle(handoverBundle.toJson());

  setUpAll(() {
    registerFallbackValue(
      const MatrixConfig(
        homeServer: '',
        user: '',
        password: '',
      ),
    );
    registerFallbackValue(StackTrace.current);
  });

  setUp(() {
    mockMatrixService = MockMatrixService();

    when(() => mockMatrixService.setConfig(any())).thenAnswer((_) async {});
    when(
      () => mockMatrixService.login(
        waitForLifecycle: any(named: 'waitForLifecycle'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => mockMatrixService.joinRoom(any()),
    ).thenAnswer((_) async => provisionedBundle.roomId);
    when(() => mockMatrixService.saveRoom(any())).thenAnswer((_) async {});
    when(() => mockMatrixService.clearPersistedRoom()).thenAnswer((_) async {});
    when(
      () => mockMatrixService.getRoom(),
    ).thenAnswer((_) async => provisionedBundle.roomId);
    when(() => mockMatrixService.isLoggedIn()).thenReturn(false);
    when(() => mockMatrixService.logout()).thenAnswer((_) async {});
    when(() => mockMatrixService.deleteConfig()).thenAnswer((_) async {});
    when(() => mockMatrixService.loadConfig()).thenAnswer(
      (_) async => MatrixConfig(
        homeServer: provisionedBundle.homeServer,
        user: provisionedBundle.user,
        password: provisionedBundle.password,
      ),
    );
    when(
      () => mockMatrixService.changePassword(
        oldPassword: any(named: 'oldPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async {});

    final mockLoggingService = MockLoggingService();
    when(
      () => mockLoggingService.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        matrixServiceProvider.overrideWithValue(mockMatrixService),
        loggingServiceProvider.overrideWithValue(mockLoggingService),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('ProvisioningController', () {
    group('decodeBundle', () {
      test('decodes valid provisioned bundle', () {
        final bundle = container
            .read(provisioningControllerProvider.notifier)
            .decodeBundle(validProvisionedBase64);

        expect(bundle.v, 2);
        expect(bundle.kind, SyncBundleKind.provisioned);
        expect(bundle.homeServer, 'https://matrix.example.com');
        expect(bundle.user, '@alice:example.com');
        expect(bundle.password, 'secret123');
        expect(bundle.roomId, '!room123:example.com');

        container
            .read(provisioningControllerProvider)
            .when(
              initial: () => fail('Expected bundleDecoded'),
              bundleDecoded: (b) {
                expect(b.kind, SyncBundleKind.provisioned);
              },
              loggingIn: () => fail('Expected bundleDecoded'),
              joiningRoom: () => fail('Expected bundleDecoded'),
              rotatingPassword: () => fail('Expected bundleDecoded'),
              ready: (_) => fail('Expected bundleDecoded'),
              done: () => fail('Expected bundleDecoded'),
              error: (_) => fail('Expected bundleDecoded'),
            );
      });

      test('decodes valid handover bundle', () {
        final bundle = container
            .read(provisioningControllerProvider.notifier)
            .decodeBundle(validHandoverBase64);

        expect(bundle.kind, SyncBundleKind.handover);
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
        final missingFields = encodeBundle({
          'v': 2,
          'kind': 'provisioned',
          'homeServer': 'https://x',
        });
        expect(
          () => container
              .read(provisioningControllerProvider.notifier)
              .decodeBundle(missingFields),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for user without @ prefix', () {
        final badUser = encodeBundle({
          'v': 2,
          'kind': 'provisioned',
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
          'v': 2,
          'kind': 'provisioned',
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
          'v': 2,
          'kind': 'provisioned',
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

      test(
        'throws FormatException for http:// homeserver (requires https)',
        () {
          final httpServer = encodeBundle({
            'v': 2,
            'kind': 'provisioned',
            'homeServer': 'http://matrix.example.com',
            'user': '@alice:example.com',
            'password': 'secret',
            'roomId': '!room:example.com',
          });
          expect(
            () => container
                .read(provisioningControllerProvider.notifier)
                .decodeBundle(httpServer),
            throwsA(
              isA<FormatException>().having(
                (e) => e.message,
                'message',
                contains('https://'),
              ),
            ),
          );
        },
      );

      test('throws FormatException for malformed scheme like httpx://', () {
        final httpxServer = encodeBundle({
          'v': 2,
          'kind': 'provisioned',
          'homeServer': 'httpx://matrix.example.com',
          'user': '@alice:example.com',
          'password': 'secret',
          'roomId': '!room:example.com',
        });
        expect(
          () => container
              .read(provisioningControllerProvider.notifier)
              .decodeBundle(httpxServer),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for unsupported version', () {
        final badVersion = encodeBundle({
          'v': 99,
          'kind': 'provisioned',
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

      test('rejects legacy v:1 bundle without kind', () {
        final legacy = encodeBundle({
          'v': 1,
          'homeServer': 'https://matrix.example.com',
          'user': '@alice:example.com',
          'password': 'secret',
          'roomId': '!room:example.com',
        });
        expect(
          () => container
              .read(provisioningControllerProvider.notifier)
              .decodeBundle(legacy),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('version'),
            ),
          ),
        );
      });

      test('throws FormatException when kind is missing at v:2', () {
        final noKind = encodeBundle({
          'v': 2,
          'homeServer': 'https://matrix.example.com',
          'user': '@alice:example.com',
          'password': 'secret',
          'roomId': '!room:example.com',
        });
        expect(
          () => container
              .read(provisioningControllerProvider.notifier)
              .decodeBundle(noKind),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('kind'),
            ),
          ),
        );
      });

      test('throws FormatException for unknown kind value', () {
        final unknownKind = encodeBundle({
          'v': 2,
          'kind': 'malicious',
          'homeServer': 'https://matrix.example.com',
          'user': '@alice:example.com',
          'password': 'secret',
          'roomId': '!room:example.com',
        });
        expect(
          () => container
              .read(provisioningControllerProvider.notifier)
              .decodeBundle(unknownKind),
          throwsA(isA<FormatException>()),
        );
      });

      test('handles unpadded Base64url', () {
        final unpadded = base64UrlEncode(
          utf8.encode(jsonEncode(provisionedBundle.toJson())),
        ).replaceAll('=', '');
        final bundle = container
            .read(provisioningControllerProvider.notifier)
            .decodeBundle(unpadded);
        expect(bundle.user, '@alice:example.com');
      });
    });

    group('configureFromBundle - provisioned (rotates password)', () {
      test('progresses through all states to ready', () async {
        final controller = container.read(
          provisioningControllerProvider.notifier,
        )..decodeBundle(validProvisionedBase64);

        final states = <ProvisioningState>[];
        container.listen(
          provisioningControllerProvider,
          (_, next) => states.add(next),
        );

        await controller.configureFromBundle(provisionedBundle);

        expect(states.length, greaterThanOrEqualTo(4));
        expect(states[0], const ProvisioningState.loggingIn());
        expect(states[1], const ProvisioningState.joiningRoom());
        expect(states[2], const ProvisioningState.rotatingPassword());

        verify(() => mockMatrixService.setConfig(any())).called(1);
        verify(
          () => mockMatrixService.login(waitForLifecycle: false),
        ).called(1);
        verify(
          () => mockMatrixService.joinRoom(provisionedBundle.roomId),
        ).called(1);
        verify(
          () => mockMatrixService.saveRoom(provisionedBundle.roomId),
        ).called(1);
        verify(
          () => mockMatrixService.changePassword(
            oldPassword: any(named: 'oldPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        ).called(1);

        container
            .read(provisioningControllerProvider)
            .when(
              initial: () => fail('Expected ready'),
              bundleDecoded: (_) => fail('Expected ready'),
              loggingIn: () => fail('Expected ready'),
              joiningRoom: () => fail('Expected ready'),
              rotatingPassword: () => fail('Expected ready'),
              ready: (handover) {
                final decoded = utf8.decode(
                  base64Decode(
                    handover.padRight(
                      handover.length + (4 - handover.length % 4) % 4,
                      '=',
                    ),
                  ),
                );
                final json = jsonDecode(decoded) as Map<String, dynamic>;
                final handoverBundle = SyncProvisioningBundle.fromJson(json);
                expect(handoverBundle.kind, SyncBundleKind.handover);
                expect(handoverBundle.v, 2);
                expect(handoverBundle.homeServer, provisionedBundle.homeServer);
                expect(handoverBundle.user, provisionedBundle.user);
                expect(handoverBundle.roomId, provisionedBundle.roomId);
                expect(
                  handoverBundle.password,
                  isNot(provisionedBundle.password),
                );
              },
              done: () => fail('Expected ready'),
              error: (_) => fail('Expected ready'),
            );
      });

      test('sets error state when login fails', () async {
        when(
          () => mockMatrixService.login(waitForLifecycle: false),
        ).thenAnswer((_) async => false);

        await container
            .read(provisioningControllerProvider.notifier)
            .configureFromBundle(provisionedBundle);

        container
            .read(provisioningControllerProvider)
            .when(
              initial: () => fail('Expected error'),
              bundleDecoded: (_) => fail('Expected error'),
              loggingIn: () => fail('Expected error'),
              joiningRoom: () => fail('Expected error'),
              rotatingPassword: () => fail('Expected error'),
              ready: (_) => fail('Expected error'),
              done: () => fail('Expected error'),
              error: (error) {
                expect(error, ProvisioningError.loginFailed);
              },
            );
      });

      test('sets error state when joinRoom throws', () async {
        when(
          () => mockMatrixService.joinRoom(any()),
        ).thenThrow(Exception('Room not found'));

        await container
            .read(provisioningControllerProvider.notifier)
            .configureFromBundle(provisionedBundle);

        container
            .read(provisioningControllerProvider)
            .when(
              initial: () => fail('Expected error'),
              bundleDecoded: (_) => fail('Expected error'),
              loggingIn: () => fail('Expected error'),
              joiningRoom: () => fail('Expected error'),
              rotatingPassword: () => fail('Expected error'),
              ready: (_) => fail('Expected error'),
              done: () => fail('Expected error'),
              error: (error) {
                expect(error, ProvisioningError.configurationError);
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
            .configureFromBundle(provisionedBundle);

        container
            .read(provisioningControllerProvider)
            .when(
              initial: () => fail('Expected error'),
              bundleDecoded: (_) => fail('Expected error'),
              loggingIn: () => fail('Expected error'),
              joiningRoom: () => fail('Expected error'),
              rotatingPassword: () => fail('Expected error'),
              ready: (_) => fail('Expected error'),
              done: () => fail('Expected error'),
              error: (error) {
                expect(error, ProvisioningError.configurationError);
              },
            );
      });
    });

    group('configureFromBundle - handover (no rotation)', () {
      test('progresses to done without rotating password', () async {
        final states = <ProvisioningState>[];
        container.listen(
          provisioningControllerProvider,
          (_, next) => states.add(next),
        );

        await container
            .read(provisioningControllerProvider.notifier)
            .configureFromBundle(handoverBundle);

        expect(states.length, greaterThanOrEqualTo(3));
        expect(states[0], const ProvisioningState.loggingIn());
        expect(states[1], const ProvisioningState.joiningRoom());
        expect(states[2], const ProvisioningState.done());

        verify(() => mockMatrixService.setConfig(any())).called(1);
        verify(
          () => mockMatrixService.login(waitForLifecycle: false),
        ).called(1);
        verify(
          () => mockMatrixService.joinRoom(handoverBundle.roomId),
        ).called(1);
        verifyNever(
          () => mockMatrixService.changePassword(
            oldPassword: any(named: 'oldPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        );

        container
            .read(provisioningControllerProvider)
            .when(
              initial: () => fail('Expected done'),
              bundleDecoded: (_) => fail('Expected done'),
              loggingIn: () => fail('Expected done'),
              joiningRoom: () => fail('Expected done'),
              rotatingPassword: () => fail('Expected done'),
              ready: (_) => fail('Expected done'),
              done: () {},
              error: (_) => fail('Expected done'),
            );
      });
    });

    group('reset', () {
      test('resets to initial state', () {
        final controller = container.read(
          provisioningControllerProvider.notifier,
        )..decodeBundle(validProvisionedBase64);

        container
            .read(provisioningControllerProvider)
            .when(
              initial: () => fail('Expected bundleDecoded'),
              bundleDecoded: (_) {},
              loggingIn: () => fail('Expected bundleDecoded'),
              joiningRoom: () => fail('Expected bundleDecoded'),
              rotatingPassword: () => fail('Expected bundleDecoded'),
              ready: (_) => fail('Expected bundleDecoded'),
              done: () => fail('Expected bundleDecoded'),
              error: (_) => fail('Expected bundleDecoded'),
            );

        controller.reset();

        container
            .read(provisioningControllerProvider)
            .when(
              initial: () {},
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

    group('retry', () {
      test('retries the last configuration after error', () async {
        when(
          () => mockMatrixService.login(waitForLifecycle: false),
        ).thenAnswer((_) async => false);

        final controller = container.read(
          provisioningControllerProvider.notifier,
        );
        await controller.configureFromBundle(provisionedBundle);

        container
            .read(provisioningControllerProvider)
            .when(
              initial: () => fail('Expected error'),
              bundleDecoded: (_) => fail('Expected error'),
              loggingIn: () => fail('Expected error'),
              joiningRoom: () => fail('Expected error'),
              rotatingPassword: () => fail('Expected error'),
              ready: (_) => fail('Expected error'),
              done: () => fail('Expected error'),
              error: (error) {
                expect(error, ProvisioningError.loginFailed);
              },
            );

        when(
          () => mockMatrixService.login(waitForLifecycle: false),
        ).thenAnswer((_) async => true);

        await controller.retry();

        container
            .read(provisioningControllerProvider)
            .when(
              initial: () => fail('Expected ready'),
              bundleDecoded: (_) => fail('Expected ready'),
              loggingIn: () => fail('Expected ready'),
              joiningRoom: () => fail('Expected ready'),
              rotatingPassword: () => fail('Expected ready'),
              ready: (_) {},
              done: () => fail('Expected ready for provisioned retry'),
              error: (_) => fail('Expected ready'),
            );
      });

      test('retry preserves handover kind (no rotation)', () async {
        when(
          () => mockMatrixService.login(waitForLifecycle: false),
        ).thenAnswer((_) async => false);

        final controller = container.read(
          provisioningControllerProvider.notifier,
        );
        await controller.configureFromBundle(handoverBundle);

        when(
          () => mockMatrixService.login(waitForLifecycle: false),
        ).thenAnswer((_) async => true);

        await controller.retry();

        verifyNever(
          () => mockMatrixService.changePassword(
            oldPassword: any(named: 'oldPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        );
        container
            .read(provisioningControllerProvider)
            .when(
              initial: () => fail('Expected done'),
              bundleDecoded: (_) => fail('Expected done'),
              loggingIn: () => fail('Expected done'),
              joiningRoom: () => fail('Expected done'),
              rotatingPassword: () => fail('Expected done'),
              ready: (_) => fail('Expected done for handover retry'),
              done: () {},
              error: (_) => fail('Expected done'),
            );
      });

      test('does nothing when no bundle was configured', () async {
        final controller = container.read(
          provisioningControllerProvider.notifier,
        );

        await controller.retry();

        container
            .read(provisioningControllerProvider)
            .when(
              initial: () {},
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

    group('regenerateHandover', () {
      test('returns base64 when config and roomId available', () async {
        when(() => mockMatrixService.loadConfig()).thenAnswer(
          (_) async => const MatrixConfig(
            homeServer: 'https://matrix.example.com',
            user: '@alice:example.com',
            password: 'rotated-password',
          ),
        );
        when(
          () => mockMatrixService.syncRoomId,
        ).thenReturn('!room123:example.com');

        final result = await container
            .read(provisioningControllerProvider.notifier)
            .regenerateHandover();

        expect(result, isNotNull);

        final decoded = utf8.decode(
          base64Decode(
            result!.padRight(result.length + (4 - result.length % 4) % 4, '='),
          ),
        );
        final json = jsonDecode(decoded) as Map<String, dynamic>;
        final bundle = SyncProvisioningBundle.fromJson(json);
        expect(bundle.v, 2);
        expect(bundle.kind, SyncBundleKind.handover);
        expect(bundle.homeServer, 'https://matrix.example.com');
        expect(bundle.user, '@alice:example.com');
        expect(bundle.password, 'rotated-password');
        expect(bundle.roomId, '!room123:example.com');
      });

      test('returns null when config is null', () async {
        when(
          () => mockMatrixService.loadConfig(),
        ).thenAnswer((_) async => null);
        when(
          () => mockMatrixService.syncRoomId,
        ).thenReturn('!room123:example.com');

        final result = await container
            .read(provisioningControllerProvider.notifier)
            .regenerateHandover();

        expect(result, isNull);
      });

      test('returns null when roomId is null', () async {
        when(() => mockMatrixService.loadConfig()).thenAnswer(
          (_) async => const MatrixConfig(
            homeServer: 'https://matrix.example.com',
            user: '@alice:example.com',
            password: 'secret',
          ),
        );
        when(() => mockMatrixService.syncRoomId).thenReturn(null);

        final result = await container
            .read(provisioningControllerProvider.notifier)
            .regenerateHandover();

        expect(result, isNull);
      });
    });

    group('Base64 roundtrip', () {
      test('encode then decode produces same bundle', () {
        final json = jsonEncode(provisionedBundle.toJson());
        final encoded = base64UrlEncode(utf8.encode(json));

        final decoded = container
            .read(provisioningControllerProvider.notifier)
            .decodeBundle(encoded);

        expect(decoded, provisionedBundle);
      });
    });
  });
}
