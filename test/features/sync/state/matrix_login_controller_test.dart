import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixService extends Mock implements MatrixService {}

class MockClient extends Mock implements Client {}

// Listener for state changes
class StateListener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockMatrixService mockMatrixService;
  late MockClient mockClient;
  late StateListener<AsyncValue<LoginState?>> listener;

  // Use a real StreamController for the loginStateStream
  late StreamController<LoginState> loginStateController;

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockClient = MockClient();
    loginStateController = StreamController<LoginState>.broadcast();

    // Basic setup for the mock services
    when(() => mockMatrixService.client).thenReturn(mockClient);
    when(() => mockClient.userID).thenReturn('@testuser:matrix.org');

    listener = StateListener<AsyncValue<LoginState?>>();

    // Create a ProviderContainer that overrides the loginStateStreamProvider
    container = ProviderContainer(
      overrides: [
        matrixServiceProvider.overrideWithValue(mockMatrixService),
        // Override the loginStateStream provider to use our test stream
        loginStateStreamProvider.overrideWith(
          (ref) => loginStateController.stream,
        ),
      ],
    )..listen(
        matrixLoginControllerProvider,
        listener.call,
        fireImmediately: true,
      );
  });

  tearDown(() {
    loginStateController.close();
    container.dispose();
  });

  group('MatrixLoginController', () {
    test('initial state is loading', () {
      verify(() => listener(null, const AsyncValue<LoginState?>.loading()));
    });

    test('login calls login on MatrixService', () async {
      // Setup mock behavior for login
      when(() => mockMatrixService.login())
          .thenAnswer((_) => Future.value(true));

      // Call login
      await container.read(matrixLoginControllerProvider.notifier).login();

      // Verify login was called
      verify(() => mockMatrixService.login()).called(1);
    });

    test('logout calls logout on MatrixService', () async {
      // Setup mock behavior for logout
      when(() => mockMatrixService.logout()).thenAnswer((_) => Future.value());

      // Call logout
      await container.read(matrixLoginControllerProvider.notifier).logout();

      // Verify logout was called
      verify(() => mockMatrixService.logout()).called(1);
    });

    test('controller state updates when login state changes', () async {
      // Add the loggedOut state to the stream
      loginStateController.add(LoginState.loggedOut);

      // Wait for the state to propagate
      await Future.microtask(() {});

      // Wait for the state to update
      final result1 =
          await container.read(matrixLoginControllerProvider.future);
      expect(result1, equals(LoginState.loggedOut));

      // Add the loggedIn state to the stream
      loginStateController.add(LoginState.loggedIn);

      // Wait for the state to propagate
      await Future.microtask(() {});

      // Wait for the state to update
      final result2 =
          await container.read(matrixLoginControllerProvider.future);
      expect(result2, equals(LoginState.loggedIn));
    });
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
