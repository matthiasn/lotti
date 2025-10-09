import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/ui/login/login_sticky_action_bar.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
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

  const testConfig = MatrixConfig(
    homeServer: 'https://matrix.org',
    user: 'testuser',
    password: 'testpassword',
  );

  setUpAll(() {
    // Register fallback values for Mocktail
    registerFallbackValue(testConfig);
  });

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockClient = MockClient();
    pageIndexNotifier = ValueNotifier<int>(0);

    // Set up mock client behavior
    when(() => mockMatrixService.client).thenReturn(mockClient);
    when(() => mockClient.userID).thenReturn('@testuser:matrix.org');

    // Set up default behavior for MatrixService methods
    when(() => mockMatrixService.loadConfig())
        .thenAnswer((_) => Future.value());
    when(() => mockMatrixService.setConfig(any())).thenAnswer((_) async {});
    when(() => mockMatrixService.login()).thenAnswer((_) async {
      return false;
    });
    when(() => mockMatrixService.deleteConfig()).thenAnswer((_) async {});
  });

  tearDown(() {
    pageIndexNotifier.dispose();
  });

  group('LoginStickyActionBar Widget', () {
    testWidgets('renders correctly with login button initially disabled',
        (tester) async {
      // Set up the mock to return null config (no existing config)
      when(() => mockMatrixService.loadConfig())
          .thenAnswer((_) => Future.value());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
          child: WidgetTestBench(
            child: LoginStickyActionBar(pageIndexNotifier: pageIndexNotifier),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that the login button is rendered but disabled initially
      // (since the form starts in an invalid state)
      final loginButton = find.byKey(const Key('matrix_login'));
      expect(loginButton, findsOneWidget);

      // The button should be disabled because the form is initially invalid
      expect(tester.widget<LottiPrimaryButton>(loginButton).onPressed, isNull);

      // Verify that the delete button is not rendered when config is null
      expect(find.byKey(const Key('matrix_config_delete')), findsNothing);
    });

    testWidgets('renders delete button when config is not null',
        (tester) async {
      // Set up the mock to return a config
      when(() => mockMatrixService.loadConfig())
          .thenAnswer((_) => Future.value(testConfig));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
          child: WidgetTestBench(
            child: LoginStickyActionBar(pageIndexNotifier: pageIndexNotifier),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that the delete button is rendered
      expect(find.byKey(const Key('matrix_config_delete')), findsOneWidget);
      final spacing = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((box) => box.width == 8 && box.height == null);
      expect(spacing, isNotEmpty);
    });

    testWidgets('delete button shows confirmation dialog when pressed',
        (tester) async {
      // Set up the mock to return a config
      when(() => mockMatrixService.loadConfig())
          .thenAnswer((_) => Future.value(testConfig));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
          child: WidgetTestBench(
            child: LoginStickyActionBar(pageIndexNotifier: pageIndexNotifier),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the delete button
      final deleteButton = find.byKey(const Key('matrix_config_delete'));
      expect(deleteButton, findsOneWidget);

      // Tap the delete button
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      // Verify that the confirmation dialog is shown
      expect(
        find.text('Do you want to delete the sync configuration?'),
        findsOneWidget,
      );
      expect(find.text("YES, I'M SURE"), findsOneWidget);

      // Tap the Delete button in the dialog
      await tester.tap(find.text("YES, I'M SURE"));
      await tester.pumpAndSettle();

      // Verify that deleteConfig was called on the MatrixService
      verify(() => mockMatrixService.deleteConfig()).called(1);
    });

    testWidgets('omits spacing when no config is present', (tester) async {
      when(() => mockMatrixService.loadConfig())
          .thenAnswer((_) => Future.value());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
          child: WidgetTestBench(
            child: LoginStickyActionBar(pageIndexNotifier: pageIndexNotifier),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final spacing = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((box) => box.width == 8 && box.height == null);
      expect(spacing, isEmpty);
    });
  });
}
