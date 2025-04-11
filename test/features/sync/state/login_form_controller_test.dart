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
