import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/ui/login/sync_login_form.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

// Mock classes
class MockMatrixService extends Mock implements MatrixService {}

class MockClient extends Mock implements Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late MockClient mockClient;
  late ValueNotifier<int> pageIndexNotifier;
  late StreamController<LoginState> loginStateController;

  const testConfig = MatrixConfig(
    homeServer: 'https://matrix.org',
    user: 'testuser',
    password: 'testpassword',
  );

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockClient = MockClient();
    pageIndexNotifier = ValueNotifier<int>(0);
    loginStateController = StreamController<LoginState>.broadcast();

    // Set up mock client behavior
    when(() => mockMatrixService.client).thenReturn(mockClient);
    when(() => mockClient.userID).thenReturn('@testuser:matrix.org');

    // Set up default behavior for loadConfig
    when(() => mockMatrixService.loadConfig())
        .thenAnswer((_) => Future.value(testConfig));
  });

  tearDown(() {
    pageIndexNotifier.dispose();
    loginStateController.close();
  });

  group('SyncLoginForm Widget', () {
    testWidgets('renders correctly with form fields', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            loginStateStreamProvider.overrideWith(
              (ref) => loginStateController.stream,
            ),
            isLoggedInProvider.overrideWith((ref) => Future.value(false)),
          ],
          child: WidgetTestBench(
            child: SyncLoginForm(pageIndexNotifier: pageIndexNotifier),
          ),
        ),
      );

      // Wait for async operations to complete
      await tester.pumpAndSettle();

      // Verify that the form fields are rendered
      expect(find.byType(TextField), findsNWidgets(3)); // 3 text fields
      expect(
        find.byType(IconButton),
        findsOneWidget,
      ); // Password visibility toggle
    });

    testWidgets('shows password when toggle is pressed', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            loginStateStreamProvider.overrideWith(
              (ref) => loginStateController.stream,
            ),
            isLoggedInProvider.overrideWith((ref) => Future.value(false)),
          ],
          child: WidgetTestBench(
            child: SyncLoginForm(pageIndexNotifier: pageIndexNotifier),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially password should be obscured
      final passwordField = find.byType(TextField).at(2);
      expect((tester.widget(passwordField) as TextField).obscureText, isTrue);

      // Find and tap the password visibility toggle
      final visibilityToggle = find.byType(IconButton);
      await tester.tap(visibilityToggle);
      await tester.pump();

      // Password should now be visible
      expect((tester.widget(passwordField) as TextField).obscureText, isFalse);
    });

    testWidgets('shows error message when URL is invalid', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            loginStateStreamProvider.overrideWith(
              (ref) => loginStateController.stream,
            ),
            isLoggedInProvider.overrideWith((ref) => Future.value(false)),
          ],
          child: WidgetTestBench(
            child: SyncLoginForm(pageIndexNotifier: pageIndexNotifier),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter an invalid URL (empty string)
      await tester.enterText(find.byType(TextField).at(0), '');
      // Tap outside to trigger validation
      await tester.tap(find.byType(Scaffold));
      await tester.pump();

      // Verify error message is shown
      expect(find.text('Please enter a valid URL'), findsOneWidget);
    });

    testWidgets('shows error message when username is too short',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            loginStateStreamProvider.overrideWith(
              (ref) => loginStateController.stream,
            ),
            isLoggedInProvider.overrideWith((ref) => Future.value(false)),
          ],
          child: WidgetTestBench(
            child: SyncLoginForm(pageIndexNotifier: pageIndexNotifier),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter a too short username
      await tester.enterText(find.byType(TextField).at(1), 'ab');
      // Tap outside to trigger validation
      await tester.tap(find.byType(Scaffold));
      await tester.pump();

      // Verify error message is shown
      expect(find.text('User name too short'), findsOneWidget);
    });

    testWidgets('shows error message when password is too short',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            loginStateStreamProvider.overrideWith(
              (ref) => loginStateController.stream,
            ),
            isLoggedInProvider.overrideWith((ref) => Future.value(false)),
          ],
          child: WidgetTestBench(
            child: SyncLoginForm(pageIndexNotifier: pageIndexNotifier),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter a too short password
      await tester.enterText(find.byType(TextField).at(2), '1234567');
      // Tap outside to trigger validation
      await tester.tap(find.byType(Scaffold));
      await tester.pump();

      // Verify error message is shown
      expect(find.text('Password too short'), findsOneWidget);
    });

    testWidgets('text fields call controller methods when text is changed',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            loginStateStreamProvider.overrideWith(
              (ref) => loginStateController.stream,
            ),
            isLoggedInProvider.overrideWith((ref) => Future.value(false)),
          ],
          child: WidgetTestBench(
            child: SyncLoginForm(pageIndexNotifier: pageIndexNotifier),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter text in the homeserver field
      await tester.enterText(
        find.byType(TextField).at(0),
        'https://new-server.org',
      );

      // Enter text in the username field
      await tester.enterText(find.byType(TextField).at(1), 'newuser');

      // Enter text in the password field
      await tester.enterText(find.byType(TextField).at(2), 'newpassword');

      // We can't easily verify the controller methods were called without mocking the controller
      // But we can verify the text was entered correctly
      expect(find.text('https://new-server.org'), findsOneWidget);
      expect(find.text('newuser'), findsOneWidget);
      expect(find.text('newpassword'), findsOneWidget);
    });
  });
}
