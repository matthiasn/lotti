import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_config_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

/// A fake provisioning controller that provides a fixed state.
class _FakeProvisioningController extends ProvisioningController {
  _FakeProvisioningController(this.initialState);

  final ProvisioningState initialState;

  @override
  ProvisioningState build() => initialState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late ValueNotifier<int> pageIndexNotifier;

  setUpAll(() {
    registerFallbackValue(
      const MatrixConfig(homeServer: '', user: '', password: ''),
    );
  });

  setUp(() {
    mockMatrixService = MockMatrixService();
    pageIndexNotifier = ValueNotifier(1);

    when(() => mockMatrixService.setConfig(any())).thenAnswer((_) async {});
    when(() => mockMatrixService.login()).thenAnswer((_) async => true);
    when(() => mockMatrixService.joinRoom(any()))
        .thenAnswer((_) async => '!room:example.com');
    when(() => mockMatrixService.saveRoom(any())).thenAnswer((_) async {});
    when(
      () => mockMatrixService.changePassword(
        oldPassword: any(named: 'oldPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockMatrixService.loadConfig()).thenAnswer(
      (_) async => const MatrixConfig(
        homeServer: 'https://matrix.example.com',
        user: '@alice:example.com',
        password: 'secret123',
      ),
    );
  });

  tearDown(() {
    pageIndexNotifier.dispose();
  });

  group('ProvisionedConfigWidget', () {
    testWidgets('shows progress when in loggingIn state', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            provisioningControllerProvider.overrideWith(
              () => _FakeProvisioningController(
                const ProvisioningState.loggingIn(),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(
        find.text(context.messages.provisionedSyncLoggingIn),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows progress when in joiningRoom state', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            provisioningControllerProvider.overrideWith(
              () => _FakeProvisioningController(
                const ProvisioningState.joiningRoom(),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(
        find.text(context.messages.provisionedSyncJoiningRoom),
        findsOneWidget,
      );
    });

    testWidgets('shows QR code when in ready state', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            provisioningControllerProvider.overrideWith(
              () => _FakeProvisioningController(
                const ProvisioningState.ready('dGVzdC1oYW5kb3Zlci1kYXRh'),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(
        find.text(context.messages.provisionedSyncReady),
        findsOneWidget,
      );
      expect(find.byKey(const Key('provisionedQrImage')), findsOneWidget);
      // The handover data should be displayed as selectable text
      expect(find.text('dGVzdC1oYW5kb3Zlci1kYXRh'), findsOneWidget);
    });

    testWidgets('shows success when in done state', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            provisioningControllerProvider.overrideWith(
              () => _FakeProvisioningController(
                const ProvisioningState.done(),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(
        find.text(context.messages.provisionedSyncDone),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('shows error and retry button in error state', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProvisionedConfigWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            provisioningControllerProvider.overrideWith(
              () => _FakeProvisioningController(
                const ProvisioningState.error('Something went wrong'),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedConfigWidget));
      expect(
        find.text(context.messages.provisionedSyncError),
        findsOneWidget,
      );
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.text(context.messages.provisionedSyncRetry),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
