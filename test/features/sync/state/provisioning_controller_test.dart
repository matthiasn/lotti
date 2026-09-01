import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/state/bundle_decode_error.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/state/provisioning_error.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockMatrixService mockMatrixService;
  late MockOnboardingSyncService mockOnboardingSyncService;
  late MockDomainLogger mockLoggingService;

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

  setUp(() async {
    mockMatrixService = MockMatrixService();
    mockOnboardingSyncService = MockOnboardingSyncService();

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
    when(
      () => mockMatrixService.createRoom(),
    ).thenAnswer((_) async => '!created:example.com');
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
    when(
      () => mockOnboardingSyncService.beginInboundPreflight(
        recipientUserId: any(named: 'recipientUserId'),
      ),
    ).thenAnswer((_) async => 'preflight-1');
    when(
      () => mockOnboardingSyncService.cancelInboundPreflight(any()),
    ).thenAnswer((_) async {});

    mockLoggingService = MockDomainLogger();
    when(
      () => mockLoggingService.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(mockLoggingService);
      },
    );

    container = ProviderContainer(
      overrides: [
        matrixServiceProvider.overrideWithValue(mockMatrixService),
        provisioningControllerProvider.overrideWith(
          () => ProvisioningController(
            onboardingSyncService: mockOnboardingSyncService,
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
  });

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

      test('a payload with no version at all is malformed, not outdated', () {
        // "Update both devices" is a guess when the code never announced a
        // version — the remedy is to replace a payload that is not a pairing
        // code at all.
        final noVersion = encodeBundle({
          'kind': 'handover',
          'homeServer': 'https://matrix.example.com',
          'user': '@alice:example.com',
          'password': 'secret',
          'roomId': '!room:example.com',
        });

        expect(
          () => container
              .read(provisioningControllerProvider.notifier)
              .decodeBundle(noVersion),
          throwsA(
            isA<BundleDecodeException>().having(
              (e) => e.error,
              'error',
              BundleDecodeError.malformedPayload,
            ),
          ),
        );
      });

      test('a non-integer version is malformed, not outdated', () {
        final textVersion = encodeBundle({
          'v': 'two',
          'kind': 'handover',
          'homeServer': 'https://matrix.example.com',
          'user': '@alice:example.com',
          'password': 'secret',
          'roomId': '!room:example.com',
        });

        expect(
          () => container
              .read(provisioningControllerProvider.notifier)
              .decodeBundle(textVersion),
          throwsA(
            isA<BundleDecodeException>().having(
              (e) => e.error,
              'error',
              BundleDecodeError.malformedPayload,
            ),
          ),
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

      glados.Glados2<int, int>(
        glados.IntAnys(glados.any).intInRange(0, 6),
        glados.IntAnys(glados.any).intInRange(0, 1 << 12),
        glados.ExploreConfig(numRuns: 160),
      ).test(
        'cross-field validation rejects exactly the corrupted field',
        (corruption, seed) {
          // Deterministic field corruption: 0 = valid bundle; 1-5 corrupt
          // one validated field each. Padding stripping exercises
          // _normalizeBase64 on every iteration.
          final json = <String, dynamic>{
            'v': corruption == 1 ? 3 + (seed % 7) : 2,
            if (corruption != 2) 'kind': 'provisioned' else 'kind': seed,
            'homeServer': corruption == 5
                ? 'http://matrix-$seed.example.com'
                : 'https://matrix-$seed.example.com',
            'user': corruption == 3
                ? 'alice$seed:example.com'
                : '@alice$seed:example.com',
            'password': 'secret-$seed',
            'roomId': corruption == 4
                ? 'room$seed:example.com'
                : '!room$seed:example.com',
          };
          var encoded = encodeBundle(json);
          if (seed.isEven) {
            // _normalizeBase64 must re-pad stripped base64url input.
            encoded = encoded.replaceAll('=', '');
          }

          final notifier = container.read(
            provisioningControllerProvider.notifier,
          );
          if (corruption == 0) {
            final bundle = notifier.decodeBundle(encoded);
            expect(bundle.user, '@alice$seed:example.com');
            expect(bundle.roomId, '!room$seed:example.com');
            expect(bundle.homeServer, 'https://matrix-$seed.example.com');
            return;
          }

          final expectedMessage = switch (corruption) {
            1 => 'version',
            2 => 'kind',
            3 => 'MXID',
            4 => 'room ID',
            5 => 'https://',
            _ => throw StateError('unreachable'),
          };
          expect(
            () => notifier.decodeBundle(encoded),
            throwsA(
              isA<FormatException>().having(
                (e) => e.message,
                'message',
                contains(expectedMessage),
              ),
            ),
            reason: 'corruption=$corruption seed=$seed',
          );
        },
        tags: 'glados',
      );

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
        verifyNever(
          () => mockOnboardingSyncService.beginInboundPreflight(
            recipientUserId: any(named: 'recipientUserId'),
          ),
        );

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

      test(
        'restores the previous config and reconnects when login fails',
        () async {
          const oldConfig = MatrixConfig(
            homeServer: 'https://old.example.com',
            user: '@old:example.com',
            password: 'old-secret',
          );
          when(
            () => mockMatrixService.loadConfig(),
          ).thenAnswer((_) async => oldConfig);
          when(
            () => mockMatrixService.getRoom(),
          ).thenAnswer((_) async => '!old-room:example.com');
          when(() => mockMatrixService.isLoggedIn()).thenReturn(true);
          when(
            () => mockMatrixService.login(waitForLifecycle: false),
          ).thenAnswer((_) async => false);

          await container
              .read(provisioningControllerProvider.notifier)
              .configureFromBundle(provisionedBundle);

          // setConfig(new) → login fails → setConfig(old) → saveRoom(old)
          // → reconnect login. The user keeps their previous session.
          final configs = verify(
            () => mockMatrixService.setConfig(captureAny()),
          ).captured.cast<MatrixConfig>();
          expect(configs, hasLength(2));
          expect(configs.first.user, provisionedBundle.user);
          expect(configs.last.user, '@old:example.com');
          verify(
            () => mockMatrixService.saveRoom('!old-room:example.com'),
          ).called(1);
          verify(
            () => mockMatrixService.login(waitForLifecycle: false),
          ).called(2);
          verifyNever(() => mockMatrixService.deleteConfig());

          container
              .read(provisioningControllerProvider)
              .maybeWhen(
                error: (error) => expect(error, ProvisioningError.loginFailed),
                orElse: () => fail('Expected error state'),
              );
        },
      );

      test(
        'deletes the config when login fails with no previous session',
        () async {
          when(
            () => mockMatrixService.loadConfig(),
          ).thenAnswer((_) async => null);
          when(
            () => mockMatrixService.getRoom(),
          ).thenAnswer((_) async => null);
          when(
            () => mockMatrixService.login(waitForLifecycle: false),
          ).thenAnswer((_) async => false);

          await container
              .read(provisioningControllerProvider.notifier)
              .configureFromBundle(provisionedBundle);

          verify(() => mockMatrixService.deleteConfig()).called(1);
          verify(
            () => mockMatrixService.login(waitForLifecycle: false),
          ).called(1);
        },
      );

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

        verifyInOrder([
          () => mockOnboardingSyncService.beginInboundPreflight(
            recipientUserId: handoverBundle.user,
          ),
          () => mockMatrixService.clearPersistedRoom(),
          () => mockMatrixService.setConfig(any()),
          () => mockMatrixService.login(waitForLifecycle: false),
        ]);
        verify(
          () => mockMatrixService.joinRoom(handoverBundle.roomId),
        ).called(1);
        verifyNever(
          () => mockMatrixService.changePassword(
            oldPassword: any(named: 'oldPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        );
        verifyNever(
          () => mockOnboardingSyncService.cancelInboundPreflight(any()),
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

      test('cancels the gate before restoring a failed login', () async {
        const oldConfig = MatrixConfig(
          homeServer: 'https://old.example.com',
          user: '@old:example.com',
          password: 'old-secret',
        );
        when(
          () => mockMatrixService.loadConfig(),
        ).thenAnswer((_) async => oldConfig);
        when(
          () => mockMatrixService.getRoom(),
        ).thenAnswer((_) async => '!old-room:example.com');
        var loginCalls = 0;
        when(
          () => mockMatrixService.login(waitForLifecycle: false),
        ).thenAnswer((_) async => loginCalls++ > 0);

        await container
            .read(provisioningControllerProvider.notifier)
            .configureFromBundle(handoverBundle);

        verifyInOrder([
          () => mockOnboardingSyncService.beginInboundPreflight(
            recipientUserId: handoverBundle.user,
          ),
          () => mockMatrixService.login(waitForLifecycle: false),
          () => mockOnboardingSyncService.cancelInboundPreflight('preflight-1'),
          () => mockMatrixService.setConfig(oldConfig),
          () => mockMatrixService.login(waitForLifecycle: false),
        ]);
        container
            .read(provisioningControllerProvider)
            .maybeWhen(
              error: (error) => expect(error, ProvisioningError.loginFailed),
              orElse: () => fail('Expected error state'),
            );
      });

      test('cancels the gate when room setup throws', () async {
        when(
          () => mockMatrixService.joinRoom(any()),
        ).thenThrow(StateError('join failed'));

        await container
            .read(provisioningControllerProvider.notifier)
            .configureFromBundle(handoverBundle);

        verify(
          () => mockOnboardingSyncService.cancelInboundPreflight('preflight-1'),
        ).called(1);
        container
            .read(provisioningControllerProvider)
            .maybeWhen(
              error: (error) =>
                  expect(error, ProvisioningError.configurationError),
              orElse: () => fail('Expected error state'),
            );
      });

      test(
        'leaves the previous session untouched when preflight creation fails',
        () async {
          const oldConfig = MatrixConfig(
            homeServer: 'https://old.example.com',
            user: '@old:example.com',
            password: 'old-secret',
          );
          when(
            () => mockMatrixService.loadConfig(),
          ).thenAnswer((_) async => oldConfig);
          when(
            () => mockMatrixService.getRoom(),
          ).thenAnswer((_) async => '!old-room:example.com');
          when(() => mockMatrixService.isLoggedIn()).thenReturn(true);
          when(
            () => mockOnboardingSyncService.beginInboundPreflight(
              recipientUserId: handoverBundle.user,
            ),
          ).thenThrow(StateError('sync database unavailable'));

          await container
              .read(provisioningControllerProvider.notifier)
              .configureFromBundle(handoverBundle);

          verify(
            () => mockOnboardingSyncService.beginInboundPreflight(
              recipientUserId: handoverBundle.user,
            ),
          ).called(1);
          verifyNever(() => mockMatrixService.logout());
          verifyNever(() => mockMatrixService.clearPersistedRoom());
          verifyNever(() => mockMatrixService.setConfig(any()));
          verifyNever(() => mockMatrixService.login(waitForLifecycle: false));
          verifyNever(() => mockMatrixService.joinRoom(any()));
          container
              .read(provisioningControllerProvider)
              .maybeWhen(
                error: (error) =>
                    expect(error, ProvisioningError.configurationError),
                orElse: () => fail('Expected error state'),
              );
        },
      );

      test(
        'logs preflight cancellation errors after room setup fails',
        () async {
          when(
            () => mockMatrixService.joinRoom(any()),
          ).thenThrow(StateError('join failed'));
          when(
            () => mockOnboardingSyncService.cancelInboundPreflight(
              'preflight-1',
            ),
          ).thenThrow(StateError('cancel failed'));

          await container
              .read(provisioningControllerProvider.notifier)
              .configureFromBundle(handoverBundle);

          verify(
            () => mockLoggingService.error(
              LogDomain.sync,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: 'configureFromBundle.cancelPreflight',
            ),
          ).called(1);
        },
      );
    });

    group('configureFromCredentials (own account, no rotation)', () {
      const credentials = MatrixConfig(
        homeServer: 'https://matrix.example.com',
        user: '@alice:example.com',
        password: 'my-own-password',
      );

      test('logs in, creates the sync room and ends ready', () async {
        final states = <ProvisioningState>[];
        container.listen(
          provisioningControllerProvider,
          (_, next) => states.add(next),
        );

        await container
            .read(provisioningControllerProvider.notifier)
            .configureFromCredentials(credentials);

        expect(states.length, 3);
        expect(states[0], const ProvisioningState.loggingIn());
        expect(states[1], const ProvisioningState.joiningRoom());
        // `ready`, not `done`: this is the account's first device, with no
        // peer to verify against — the same ending a CLI bundle reaches.
        final handover = states[2].maybeWhen(
          ready: (handover) => handover,
          orElse: () => fail('Expected ready, got ${states[2]}'),
        );
        final decoded = SyncProvisioningBundle.fromJson(
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(handover))),
              )
              as Map<String, dynamic>,
        );
        expect(decoded.kind, SyncBundleKind.handover);
        expect(decoded.homeServer, credentials.homeServer);
        expect(decoded.user, credentials.user);
        expect(decoded.password, credentials.password);
        expect(decoded.roomId, '!created:example.com');

        verifyInOrder([
          () => mockMatrixService.clearPersistedRoom(),
          () => mockMatrixService.setConfig(credentials),
          () => mockMatrixService.login(waitForLifecycle: false),
          () => mockMatrixService.createRoom(),
          () => mockMatrixService.saveRoom('!created:example.com'),
        ]);
      });

      test('never rotates the password and never joins a room', () async {
        // The password is the user's own. Rotation exists to spend a one-time
        // CLI bundle; rotating a credential the user manages would lock them
        // out of their own account.
        await container
            .read(provisioningControllerProvider.notifier)
            .configureFromCredentials(credentials);

        verifyNever(
          () => mockMatrixService.changePassword(
            oldPassword: any(named: 'oldPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        );
        verifyNever(() => mockMatrixService.joinRoom(any()));
        // No peer holds history for a brand-new room, so no inbound gate.
        verifyNever(
          () => mockOnboardingSyncService.beginInboundPreflight(
            recipientUserId: any(named: 'recipientUserId'),
          ),
        );
      });

      test('logs out a live session before signing in', () async {
        when(() => mockMatrixService.isLoggedIn()).thenReturn(true);

        await container
            .read(provisioningControllerProvider.notifier)
            .configureFromCredentials(credentials);

        verifyInOrder([
          () => mockMatrixService.logout(),
          () => mockMatrixService.setConfig(credentials),
          () => mockMatrixService.login(waitForLifecycle: false),
        ]);
      });

      test('a rejected login restores the previous session', () async {
        const oldConfig = MatrixConfig(
          homeServer: 'https://old.example.com',
          user: '@old:example.com',
          password: 'old-pw',
        );
        when(
          () => mockMatrixService.loadConfig(),
        ).thenAnswer((_) async => oldConfig);
        when(
          () => mockMatrixService.getRoom(),
        ).thenAnswer((_) async => '!old:example.com');
        when(
          () => mockMatrixService.login(waitForLifecycle: false),
        ).thenAnswer((_) async => false);

        await container
            .read(provisioningControllerProvider.notifier)
            .configureFromCredentials(credentials);

        expect(
          container.read(provisioningControllerProvider),
          const ProvisioningState.error(ProvisioningError.loginFailed),
        );
        verify(() => mockMatrixService.setConfig(oldConfig)).called(1);
        verify(() => mockMatrixService.saveRoom('!old:example.com')).called(1);
        verifyNever(() => mockMatrixService.createRoom());
      });

      test(
        'a rejected login with no previous config clears the config',
        () async {
          when(
            () => mockMatrixService.loadConfig(),
          ).thenAnswer((_) async => null);
          when(() => mockMatrixService.getRoom()).thenAnswer((_) async => null);
          when(
            () => mockMatrixService.login(waitForLifecycle: false),
          ).thenAnswer((_) async => false);

          await container
              .read(provisioningControllerProvider.notifier)
              .configureFromCredentials(credentials);

          // The typed password must not linger in the keychain after the
          // server rejected it.
          verify(() => mockMatrixService.deleteConfig()).called(1);
          expect(
            container.read(provisioningControllerProvider),
            const ProvisioningState.error(ProvisioningError.loginFailed),
          );
        },
      );

      test('a failed room creation is a configuration error', () async {
        when(
          () => mockMatrixService.createRoom(),
        ).thenThrow(Exception('M_FORBIDDEN'));

        await container
            .read(provisioningControllerProvider.notifier)
            .configureFromCredentials(credentials);

        expect(
          container.read(provisioningControllerProvider),
          const ProvisioningState.error(ProvisioningError.configurationError),
        );
        verify(
          () => mockLoggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'configureFromCredentials',
          ),
        ).called(1);
        verifyNever(() => mockMatrixService.saveRoom(any()));
      });

      test('retry re-runs the credentials, not a stale bundle', () async {
        final controller = container.read(
          provisioningControllerProvider.notifier,
        );
        // A bundle attempt first, then credentials: retry must follow the
        // most recent attempt.
        await controller.configureFromBundle(handoverBundle);
        when(
          () => mockMatrixService.login(waitForLifecycle: false),
        ).thenAnswer((_) async => false);
        await controller.configureFromCredentials(credentials);
        expect(
          container.read(provisioningControllerProvider),
          const ProvisioningState.error(ProvisioningError.loginFailed),
        );
        when(
          () => mockMatrixService.login(waitForLifecycle: false),
        ).thenAnswer((_) async => true);
        clearInteractions(mockMatrixService);

        await controller.retry();

        verify(() => mockMatrixService.setConfig(credentials)).called(1);
        verify(() => mockMatrixService.createRoom()).called(1);
        verifyNever(() => mockMatrixService.joinRoom(any()));
        expect(
          container
              .read(provisioningControllerProvider)
              .maybeWhen(
                ready: (_) => true,
                orElse: () => false,
              ),
          isTrue,
        );
      });

      test(
        'a bundle attempt after credentials makes retry use the bundle',
        () async {
          final controller = container.read(
            provisioningControllerProvider.notifier,
          );
          await controller.configureFromCredentials(credentials);
          await controller.configureFromBundle(handoverBundle);
          clearInteractions(mockMatrixService);

          await controller.retry();

          verify(
            () => mockMatrixService.joinRoom(handoverBundle.roomId),
          ).called(1);
          verifyNever(() => mockMatrixService.createRoom());
        },
      );

      test('reset forgets the credentials so retry is a no-op', () async {
        final controller = container.read(
          provisioningControllerProvider.notifier,
        );
        await controller.configureFromCredentials(credentials);
        controller.reset();
        clearInteractions(mockMatrixService);

        await controller.retry();

        verifyNever(() => mockMatrixService.setConfig(any()));
        expect(
          container.read(provisioningControllerProvider),
          const ProvisioningState.initial(),
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
