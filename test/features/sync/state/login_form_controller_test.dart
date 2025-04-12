import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formz/formz.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/model/validation/config_form_state.dart';
import 'package:lotti/features/sync/model/validation/homeserver.dart';
import 'package:lotti/features/sync/model/validation/password.dart';
import 'package:lotti/features/sync/model/validation/username.dart';
import 'package:lotti/features/sync/state/login_form_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixService extends Mock implements MatrixService {}

// Custom listener class for testing Riverpod state changes
class StateListener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockMatrixService mockMatrixService;
  late StateListener<AsyncValue<LoginFormState?>> listener;

  const testConfig = MatrixConfig(
    homeServer: 'https://matrix.org',
    user: 'testuser',
    password: 'testpassword',
  );

  setUpAll(() {
    // Register fallback values for Mocktail
    registerFallbackValue(
      const AsyncValue<LoginFormState?>.loading(),
    );

    // Register fallback for MatrixConfig
    registerFallbackValue(testConfig);
  });

  setUp(() {
    mockMatrixService = MockMatrixService();

    // Set up default behavior for loadConfig
    when(() => mockMatrixService.loadConfig())
        .thenAnswer((_) => Future.value(testConfig));

    listener = StateListener<AsyncValue<LoginFormState?>>();

    // Override GetIt to use our mock
    getIt.allowReassignment = true;
    getIt.registerSingleton<MatrixService>(mockMatrixService);

    // Create a provider container
    container = ProviderContainer()
      ..listen(
        loginFormControllerProvider,
        listener.call,
        fireImmediately: true,
      );
  });

  tearDown(() {
    container.dispose();
    getIt.reset();
  });

  group('LoginFormController', () {
    test('initial state is loading', () {
      verify(() => listener(null, const AsyncValue<LoginFormState?>.loading()));
    });

    test('build loads config and sets initial state correctly', () async {
      // Wait for the build method to complete
      await container.read(loginFormControllerProvider.future);

      // Verify loadConfig was called
      verify(() => mockMatrixService.loadConfig()).called(1);

      // Verify state contains the expected values from config
      final state = container.read(loginFormControllerProvider).value;
      expect(state, isNotNull);
      expect(state?.homeServer.value, 'https://matrix.org');
      expect(state?.userName.value, 'testuser');
      expect(state?.password.value, 'testpassword');
      expect(state?.status, FormzSubmissionStatus.success);
    });

    test('build with null config sets empty values and failure status',
        () async {
      // Override loadConfig to return null
      when(() => mockMatrixService.loadConfig())
          .thenAnswer((_) => Future.value());

      // Recreate container to use the new mock behavior
      container.dispose();
      container = ProviderContainer()
        ..listen(
          loginFormControllerProvider,
          listener.call,
          fireImmediately: true,
        );

      // Wait for the build method to complete
      await container.read(loginFormControllerProvider.future);

      // Verify state contains empty values and failure status
      final state = container.read(loginFormControllerProvider).value;
      expect(state, isNotNull);
      expect(state?.homeServer.value, '');
      expect(state?.userName.value, '');
      expect(state?.password.value, '');
      expect(state?.status, FormzSubmissionStatus.failure);
    });

    test('login calls setConfig and login on MatrixService', () async {
      // First, manually set the controller state to a success state
      final loginController =
          container.read(loginFormControllerProvider.notifier)
            ..state = const AsyncData(
              LoginFormState(
                homeServer: HomeServer.dirty('https://matrix.org'),
                userName: UserName.dirty('testuser'),
                password: Password.dirty('testpassword'),
                status: FormzSubmissionStatus.success,
              ),
            );

      // Setup mock behavior for setConfig and login
      when(() => mockMatrixService.setConfig(any()))
          .thenAnswer((_) => Future.value());
      when(() => mockMatrixService.login()).thenAnswer((_) => Future.value());

      // Call login
      await loginController.login();

      // Verify setConfig and login were called
      verify(() => mockMatrixService.setConfig(any())).called(1);
      verify(() => mockMatrixService.login()).called(1);
    });

    test('login does nothing when state is null', () async {
      // Set controller state to null
      final loginController = container
          .read(loginFormControllerProvider.notifier)
        ..state = const AsyncData(null);

      // Setup mock behavior for setConfig and login
      when(() => mockMatrixService.setConfig(any()))
          .thenAnswer((_) => Future.value());
      when(() => mockMatrixService.login()).thenAnswer((_) => Future.value());

      // Call login
      await loginController.login();

      // Verify no methods were called
      verifyNever(() => mockMatrixService.setConfig(any()));
      verifyNever(() => mockMatrixService.login());
    });

    test('login handles errors from MatrixService', () async {
      // First, manually set the controller state to a success state
      final loginController =
          container.read(loginFormControllerProvider.notifier)
            ..state = const AsyncData(
              LoginFormState(
                homeServer: HomeServer.dirty('https://matrix.org'),
                userName: UserName.dirty('testuser'),
                password: Password.dirty('testpassword'),
                status: FormzSubmissionStatus.success,
              ),
            );

      // Setup mock behavior to throw errors
      when(() => mockMatrixService.setConfig(any()))
          .thenThrow(Exception('Failed to set config'));

      // Call login and expect it to throw
      expect(loginController.login, throwsException);

      // Verify setConfig was called but login was not
      verify(() => mockMatrixService.setConfig(any())).called(1);
      verifyNever(() => mockMatrixService.login());
    });

    test(
        'deleteConfig calls deleteConfig on MatrixService and invalidates state',
        () async {
      // Setup mock behavior for deleteConfig
      when(() => mockMatrixService.deleteConfig())
          .thenAnswer((_) => Future.value());

      // First, manually set the controller state to a success state
      final loginController =
          container.read(loginFormControllerProvider.notifier)
            ..state = const AsyncData(
              LoginFormState(
                homeServer: HomeServer.dirty('https://matrix.org'),
                userName: UserName.dirty('testuser'),
                password: Password.dirty('testpassword'),
                status: FormzSubmissionStatus.success,
              ),
            );

      // Clear previous listener calls
      reset(listener);

      // Call deleteConfig
      await loginController.deleteConfig();

      // Verify deleteConfig was called
      verify(() => mockMatrixService.deleteConfig()).called(1);

      // Verify state changed to loading - don't check the specific value
      // as it contains the previous state
      verify(() => listener(any(), any())).called(1);
    });

    // Validation tests
    group('form validation', () {
      test('homeServerChanged updates homeServer and status correctly',
          () async {
        // Wait for initial build
        await container.read(loginFormControllerProvider.future);

        final initialState = container.read(loginFormControllerProvider).value;
        expect(initialState?.status, FormzSubmissionStatus.success);

        // Update with valid value
        container
            .read(loginFormControllerProvider.notifier)
            .homeServerChanged('https://example.com');
        expect(
          container.read(loginFormControllerProvider).value?.homeServer.value,
          'https://example.com',
        );
        expect(
          container.read(loginFormControllerProvider).value?.status,
          FormzSubmissionStatus.success,
        );

        // Update with invalid value
        container
            .read(loginFormControllerProvider.notifier)
            .homeServerChanged('');
        expect(
          container.read(loginFormControllerProvider).value?.homeServer.value,
          '',
        );
        expect(
          container.read(loginFormControllerProvider).value?.status,
          FormzSubmissionStatus.failure,
        );
      });

      test('usernameChanged updates userName and status correctly', () async {
        // Wait for initial build
        await container.read(loginFormControllerProvider.future);

        final initialState = container.read(loginFormControllerProvider).value;
        expect(initialState?.status, FormzSubmissionStatus.success);

        // Update with valid value
        container
            .read(loginFormControllerProvider.notifier)
            .usernameChanged('newuser');
        expect(
          container.read(loginFormControllerProvider).value?.userName.value,
          'newuser',
        );
        expect(
          container.read(loginFormControllerProvider).value?.status,
          FormzSubmissionStatus.success,
        );

        // Update with invalid value
        container
            .read(loginFormControllerProvider.notifier)
            .usernameChanged('');
        expect(
          container.read(loginFormControllerProvider).value?.userName.value,
          '',
        );
        expect(
          container.read(loginFormControllerProvider).value?.status,
          FormzSubmissionStatus.failure,
        );
      });

      test('passwordChanged updates password and status correctly', () async {
        // Wait for initial build
        await container.read(loginFormControllerProvider.future);

        final initialState = container.read(loginFormControllerProvider).value;
        expect(initialState?.status, FormzSubmissionStatus.success);

        // Update with valid value
        container
            .read(loginFormControllerProvider.notifier)
            .passwordChanged('newpassword');
        expect(
          container.read(loginFormControllerProvider).value?.password.value,
          'newpassword',
        );
        expect(
          container.read(loginFormControllerProvider).value?.status,
          FormzSubmissionStatus.success,
        );

        // Update with invalid value
        container
            .read(loginFormControllerProvider.notifier)
            .passwordChanged('');
        expect(
          container.read(loginFormControllerProvider).value?.password.value,
          '',
        );
        expect(
          container.read(loginFormControllerProvider).value?.status,
          FormzSubmissionStatus.failure,
        );
      });
    });

    // Basic field update tests that verify the controller methods work
    test('fieldChanged methods update state', () async {
      // First, manually set the controller state to a success state
      final loginController =
          container.read(loginFormControllerProvider.notifier)
            ..state = const AsyncData(
              LoginFormState(
                homeServer: HomeServer.dirty('https://matrix.org'),
                userName: UserName.dirty('testuser'),
                password: Password.dirty('testpassword'),
                status: FormzSubmissionStatus.success,
              ),
            );

      // Test homeServerChanged
      reset(listener);
      loginController.homeServerChanged('https://example.org');

      // Verify state updated (not testing the validation specifics)
      verify(() => listener(any(), any())).called(1);
      expect(
        container.read(loginFormControllerProvider).value?.homeServer.value,
        'https://example.org',
      );

      // Test usernameChanged
      reset(listener);
      loginController.usernameChanged('newuser');

      // Verify state updated
      verify(() => listener(any(), any())).called(1);
      expect(
        container.read(loginFormControllerProvider).value?.userName.value,
        'newuser',
      );

      // Test passwordChanged
      reset(listener);
      loginController.passwordChanged('newpass');

      // Verify state updated
      verify(() => listener(any(), any())).called(1);
      expect(
        container.read(loginFormControllerProvider).value?.password.value,
        'newpass',
      );
    });
  });
}
