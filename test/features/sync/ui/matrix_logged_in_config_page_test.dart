import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/ui/matrix_logged_in_config_page.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

class _FakeMatrixLoginController extends MatrixLoginController {
  _FakeMatrixLoginController({this.onLogout});

  VoidCallback? onLogout;

  @override
  Future<LoginState?> build() async => null;

  @override
  Future<void> logout() async {
    onLogout?.call();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;

  setUp(() {
    mockMatrixService = MockMatrixService();
    // Provide a default empty invite stream for widgets that subscribe
    // during initState. Individual tests can override as needed.
    when(() => mockMatrixService.inviteRequests)
        .thenAnswer((_) => Stream<SyncRoomInvite>.empty());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('LoggedInPageStickyActionBar', () {
    testWidgets('invokes logout and updates page index', (tester) async {
      final pageIndexNotifier = ValueNotifier<int>(1);
      addTearDown(pageIndexNotifier.dispose);
      var logoutCalled = false;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LoggedInPageStickyActionBar(pageIndexNotifier: pageIndexNotifier),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixLoginControllerProvider.overrideWith(
              () => _FakeMatrixLoginController(
                onLogout: () => logoutCalled = true,
              ),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      expect(logoutCalled, isTrue);
      expect(pageIndexNotifier.value, 0);

      await tester.tap(find.text('Next Page'));
      await tester.pumpAndSettle();
      expect(pageIndexNotifier.value, 2);
    });
  });

  group('HomeserverLoggedInWidget', () {
    testWidgets('shows QR code when user id is available', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const HomeserverLoggedInWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            loggedInUserIdProvider.overrideWith(
              (ref) => Future.value('@user:matrix.org'),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('QrImage')), findsOneWidget);
      expect(find.text('@user:matrix.org'), findsOneWidget);
    });

    testWidgets('shows progress indicator when user id is null',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const HomeserverLoggedInWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            loggedInUserIdProvider.overrideWith(
              (ref) => Future.value(),
            ),
          ],
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows circular progress indicator while loading',
        (tester) async {
      final completer = Completer<String?>();

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const HomeserverLoggedInWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            loggedInUserIdProvider.overrideWith((ref) => completer.future),
          ],
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error text when loading fails', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const HomeserverLoggedInWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            loggedInUserIdProvider.overrideWith(
              (ref) => Future<String?>.error('boom'),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('null'), findsOneWidget);
    });
  });

  group('DiagnosticInfoButton', () {
    testWidgets('shows diagnostics dialog and copies to clipboard',
        (tester) async {
      final diagnostics = {'roomId': '!room:server'};
      when(() => mockMatrixService.getDiagnosticInfo())
          .thenAnswer((_) async => diagnostics);

      String? clipboardText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final arguments = methodCall.arguments as Map<dynamic, dynamic>?;
            clipboardText = arguments?['text'] as String?;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DiagnosticInfoButton(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      await tester.tap(find.text('Show Diagnostic Info'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('"roomId"'), findsOneWidget);

      await tester.tap(find.text('Copy to Clipboard'));
      await tester.pumpAndSettle();

      expect(clipboardText, contains('!room:server'));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
