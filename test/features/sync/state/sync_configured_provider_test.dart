import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/state/sync_configured_provider.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockMatrixService service;
  late StreamController<LoginState> loginStates;
  late StreamController<String?> roomIds;

  /// Mutable backing values so a test can change what the service reports and
  /// then push the signal that is supposed to make the provider notice.
  late bool loggedIn;
  late String? roomId;

  setUp(() {
    service = MockMatrixService();
    loginStates = StreamController<LoginState>.broadcast();
    roomIds = StreamController<String?>.broadcast();
    loggedIn = true;
    roomId = '!room:server';

    when(service.isLoggedIn).thenAnswer((_) => loggedIn);
    when(() => service.syncRoomId).thenAnswer((_) => roomId);
    when(() => service.syncRoomIdChanges).thenAnswer((_) => roomIds.stream);
  });

  tearDown(() async {
    await loginStates.close();
    await roomIds.close();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        matrixServiceProvider.overrideWithValue(service),
        // Overridden rather than stubbed through the Matrix client: the real
        // provider reads `service.client.onLoginStateChanged`, which is not
        // what this composition is about.
        loginStateStreamProvider.overrideWith((_) => loginStates.stream),
      ],
    );
    addTearDown(container.dispose);
    // autoDispose providers need a listener to stay alive between reads.
    container.listen(syncConfiguredProvider, (_, _) {});
    return container;
  }

  group('syncConfiguredProvider', () {
    test('is true only when logged in with a room', () {
      expect(makeContainer().read(syncConfiguredProvider), isTrue);
    });

    test('is false when logged in without a room', () {
      roomId = null;
      expect(makeContainer().read(syncConfiguredProvider), isFalse);
    });

    test('is false when a room is persisted but the session is logged out', () {
      loggedIn = false;
      expect(makeContainer().read(syncConfiguredProvider), isFalse);
    });

    test('flips to false when the room is cleared after login', () async {
      // The regression this exists for: `SyncSessionManager.connect()` drops a
      // room the account can no longer join *after* the login event has
      // fired, so a login-only signal left the device roster on screen for a
      // room that no longer exists.
      final container = makeContainer();
      expect(container.read(syncConfiguredProvider), isTrue);

      roomId = null;
      roomIds.add(null);
      await pumpEventQueue();

      expect(container.read(syncConfiguredProvider), isFalse);
    });

    test(
      'flips to true when a room arrives on an already-logged-in session',
      () async {
        // Pairing completes mid-session: login state does not change, only the
        // room does.
        roomId = null;
        final container = makeContainer();
        expect(container.read(syncConfiguredProvider), isFalse);

        roomId = '!fresh:server';
        roomIds.add('!fresh:server');
        await pumpEventQueue();

        expect(container.read(syncConfiguredProvider), isTrue);
      },
    );

    test(
      'flips to false when the session logs out with the room intact',
      () async {
        final container = makeContainer();
        expect(container.read(syncConfiguredProvider), isTrue);

        loggedIn = false;
        loginStates.add(LoginState.loggedOut);
        await pumpEventQueue();

        expect(container.read(syncConfiguredProvider), isFalse);
      },
    );
  });

  group('syncRoomChangesProvider', () {
    test('forwards the service stream, including the clear', () async {
      final container = makeContainer();
      final seen = <String?>[];
      container.listen(
        syncRoomChangesProvider,
        (_, next) {
          if (next case AsyncData(:final value)) seen.add(value);
        },
        fireImmediately: true,
      );

      roomIds
        ..add('!room:server')
        ..add(null);
      await pumpEventQueue();

      expect(seen, ['!room:server', null]);
    });
  });
}
