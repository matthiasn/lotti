import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/features/sync/ui/unverified_devices_page.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/device_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import 'provisioned_status_page_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late MockMatrixClient mockClient;

  setUpAll(() {
    registerFallbackValue(FakeDeviceKeys());
  });

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockClient = MockMatrixClient();

    when(() => mockMatrixService.client).thenReturn(mockClient);
    when(() => mockClient.userID).thenReturn('@alice:example.com');
    when(() => mockMatrixService.syncRoomId).thenReturn('!room123:example.com');
    when(() => mockMatrixService.deleteConfig()).thenAnswer((_) async {});
    when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([]);
    when(
      () => mockMatrixService.keyVerificationStream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockMatrixService.verifyDevice(any())).thenAnswer((_) async {});
    when(() => mockMatrixService.loadConfig()).thenAnswer(
      (_) async => const MatrixConfig(
        homeServer: 'https://matrix.example.com',
        user: '@alice:example.com',
        password: 'rotated-pw',
      ),
    );
  });

  group('ProvisionedStatusWidget', () {
    testWidgets('displays diagnostic info button', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Show Diagnostic Info'), findsOneWidget);
    });

    testWidgets('displays disconnect button', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      expect(
        find.text(context.messages.provisionedSyncDisconnect),
        findsOneWidget,
      );
    });

    testWidgets('disconnect calls deleteConfig after confirmation', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      final disconnectFinder = find.text(
        context.messages.provisionedSyncDisconnect,
      );
      await tester.ensureVisible(disconnectFinder);
      await tester.tap(disconnectFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirmation dialog should be visible
      expect(
        find.text(context.messages.syncDeleteConfigQuestion),
        findsOneWidget,
      );

      // Tap the confirm button
      await tester.tap(find.text(context.messages.syncDeleteConfigConfirm));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => mockMatrixService.deleteConfig()).called(1);
    });

    testWidgets('disconnect closes route after confirmation', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(
                        body: ProvisionedStatusWidget(),
                      ),
                    ),
                  );
                },
                child: const Text('Open Sync Status'),
              ),
            ),
          ),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Sync Status'));
      await tester.pumpAndSettle();
      expect(find.byType(ProvisionedStatusWidget), findsOneWidget);

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      final disconnectFinder = find.text(
        context.messages.provisionedSyncDisconnect,
      );
      await tester.ensureVisible(disconnectFinder);
      await tester.tap(disconnectFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text(context.messages.syncDeleteConfigConfirm));
      await tester.pumpAndSettle();

      verify(() => mockMatrixService.deleteConfig()).called(1);
      expect(find.byType(ProvisionedStatusWidget), findsNothing);
      expect(find.text('Open Sync Status'), findsOneWidget);
    });

    testWidgets('disconnect does not call deleteConfig when cancelled', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      final disconnectFinder = find.text(
        context.messages.provisionedSyncDisconnect,
      );
      await tester.ensureVisible(disconnectFinder);
      await tester.tap(disconnectFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirmation dialog should be visible
      expect(
        find.text(context.messages.syncDeleteConfigQuestion),
        findsOneWidget,
      );

      // Tap cancel in confirmation dialog
      await tester.tap(find.text(context.messages.settingsMatrixCancel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verifyNever(() => mockMatrixService.deleteConfig());
    });
  });

  group('device verification section', () {
    testWidgets('displays verification section title', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      expect(
        find.text(context.messages.provisionedSyncVerifyDevicesTitle),
        findsOneWidget,
      );
    });

    testWidgets('shows no-unverified-devices indicator when list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(UnverifiedDevices), findsOneWidget);
    });

    testWidgets('shows device cards when unverified devices exist', (
      tester,
    ) async {
      final device = MockDeviceKeys();
      final keyVerification = MockKeyVerification();
      final runner = MockKeyVerificationRunner();
      when(() => device.deviceDisplayName).thenReturn('Pixel 7');
      when(() => device.deviceId).thenReturn('DEVICE1');
      when(() => device.userId).thenReturn('@alice:example.com');
      when(() => keyVerification.isDone).thenReturn(false);
      when(() => runner.lastStep).thenReturn('');
      when(() => runner.keyVerification).thenReturn(keyVerification);
      when(() => mockMatrixService.keyVerificationRunner).thenReturn(runner);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => FakeMatrixUnverifiedController([device]),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(DeviceCard), findsOneWidget);
      expect(find.text('Pixel 7'), findsWidgets);
    });
  });
}
