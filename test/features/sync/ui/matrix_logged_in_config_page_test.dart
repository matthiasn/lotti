import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/ui/matrix_logged_in_config_page.dart';
import 'package:lotti/get_it.dart';
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
    getIt.allowReassignment = true;
    getIt.registerSingleton<MatrixService>(mockMatrixService);
  });

  tearDown(getIt.reset);

  group('LoggedInPageStickyActionBar', () {
    testWidgets('invokes logout and updates page index', (tester) async {
      final pageIndexNotifier = ValueNotifier<int>(1);
      addTearDown(pageIndexNotifier.dispose);
      var logoutCalled = false;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LoggedInPageStickyActionBar(pageIndexNotifier: pageIndexNotifier),
          overrides: [
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
}
