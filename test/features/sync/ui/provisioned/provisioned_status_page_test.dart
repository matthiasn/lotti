import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/device_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:material_ui/material_ui.dart';
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
    when(() => mockMatrixService.getSyncDevices()).thenAnswer((_) async => []);
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

      expect(find.text('Technical details'), findsOneWidget);
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
      await tester.tap(
        find.text(context.messages.syncDeleteConfigConfirm),
      );
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
      await tester.tap(
        find.text(context.messages.syncDeleteConfigConfirm),
      );
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

  group('devices section', () {
    testWidgets('carries no section title of its own', (tester) async {
      // Every host already says "Devices" one rung up (the settings header
      // or the sheet title); the in-list title made it the journey's most
      // visible double heading.
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
      await tester.pump();

      // Literal: the label was removed from the catalogs with the heading.
      expect(
        find.text('Devices'),
        findsNothing,
      );
    });

    testWidgets('notes when only this device is signed in', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => FakeMatrixUnverifiedController(const []),
            ),
            syncDevicesControllerProvider.overrideWith(
              () => FakeSyncDevicesController(const [
                SyncDeviceInfo(
                  deviceId: 'THIS',
                  displayName: 'This desktop',
                  isCurrentDevice: true,
                  verified: true,
                ),
              ]),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(DeviceCard), findsOneWidget);
      expect(find.text('No other devices are signed in.'), findsOneWidget);
      final context = tester.element(find.byType(ProvisionedStatusWidget));
      expect(
        find.text(context.messages.syncDevicesPausedBanner(1)),
        findsNothing,
      );
    });

    testWidgets('shows device cards and the paused banner when an unverified '
        'device blocks sync', (tester) async {
      final keys = MockDeviceKeys();
      when(() => keys.deviceDisplayName).thenReturn('Pixel 7');
      when(() => keys.deviceId).thenReturn('DEVICE1');
      when(() => keys.userId).thenReturn('@alice:example.com');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => FakeMatrixUnverifiedController(const []),
            ),
            syncDevicesControllerProvider.overrideWith(
              () => FakeSyncDevicesController([
                const SyncDeviceInfo(
                  deviceId: 'THIS',
                  displayName: 'This desktop',
                  isCurrentDevice: true,
                  verified: true,
                ),
                SyncDeviceInfo(
                  deviceId: 'DEVICE1',
                  displayName: 'Pixel 7',
                  isCurrentDevice: false,
                  verified: false,
                  keys: keys,
                ),
              ]),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(DeviceCard), findsNWidgets(2));
      expect(find.text('Pixel 7'), findsWidgets);
      final context = tester.element(find.byType(ProvisionedStatusWidget));
      expect(
        find.text(context.messages.syncDevicesPausedBanner(1)),
        findsOneWidget,
      );
    });
  });
}
