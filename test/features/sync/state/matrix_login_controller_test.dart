import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

// Listener for state changes
class StateListener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockMatrixService mockMatrixService;
  late MockMatrixClient mockClient;

  // Use a real StreamController for the loginStateStream
  late StreamController<LoginState> loginStateController;

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockClient = MockMatrixClient();
    loginStateController = StreamController<LoginState>.broadcast();

    // Basic setup for the mock services
    when(() => mockMatrixService.client).thenReturn(mockClient);
    when(() => mockClient.userID).thenReturn('@testuser:matrix.org');

    // Create a ProviderContainer that overrides the loginStateStreamProvider
    container =
        ProviderContainer(
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
              // Override the loginStateStream provider to use our test stream
              loginStateStreamProvider.overrideWith(
                (ref) => loginStateController.stream,
              ),
            ],
          )
          // Keep the login-state stream subscribed for the whole test: awaiting
          // a StreamProvider's `.future` with no listener hangs until timeout.
          ..listen(
            loginStateStreamProvider,
            (_, _) {},
            fireImmediately: true,
          );
  });

  tearDown(() {
    loginStateController.close();
    container.dispose();
  });

  group('isLoggedIn provider', () {
    test('returns true when logged in', () async {
      // Add the loggedIn state to the stream
      loginStateController.add(LoginState.loggedIn);

      // Wait for the state to propagate
      await Future.microtask(() {});

      // Check that isLoggedIn returns true
      expect(
        await container.read(isLoggedInProvider.future),
        isTrue,
      );
    });

    test('returns false when logged out', () async {
      // Add the loggedOut state to the stream
      loginStateController.add(LoginState.loggedOut);

      // Wait for the state to propagate
      await Future.microtask(() {});

      // Check that isLoggedIn returns false
      expect(
        await container.read(isLoggedInProvider.future),
        isFalse,
      );
    });
  });

  group('loggedInUserId provider', () {
    test('returns userId when logged in', () async {
      // Add the loggedIn state to the stream
      loginStateController.add(LoginState.loggedIn);

      // Wait for the state to propagate
      await Future.microtask(() {});

      // Check that loggedInUserId returns the userID
      expect(
        await container.read(loggedInUserIdProvider.future),
        equals('@testuser:matrix.org'),
      );
    });

    test('returns null when logged out', () async {
      // Add the loggedOut state to the stream
      loginStateController.add(LoginState.loggedOut);

      // Wait for the state to propagate
      await Future.microtask(() {});

      // Check that loggedInUserId returns null
      expect(
        await container.read(loggedInUserIdProvider.future),
        isNull,
      );
    });
  });
}
