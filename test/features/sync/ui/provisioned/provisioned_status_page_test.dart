import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/features/sync/ui/unverified_devices_page.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/device_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/platform.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class MockClient extends Mock implements Client {}

class MockDeviceKeys extends Mock implements DeviceKeys {}

class MockKeyVerificationRunner extends Mock implements KeyVerificationRunner {}

class MockKeyVerification extends Mock implements KeyVerification {}

class _FakeDeviceKeys extends Fake implements DeviceKeys {}

class _FakeMatrixUnverifiedController extends MatrixUnverifiedController {
  _FakeMatrixUnverifiedController(this.devices);

  final List<DeviceKeys> devices;

  @override
  Future<List<DeviceKeys>> build() async => devices;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late MockClient mockClient;

  setUpAll(() {
    registerFallbackValue(_FakeDeviceKeys());
  });

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockClient = MockClient();

    when(() => mockMatrixService.client).thenReturn(mockClient);
    when(() => mockClient.userID).thenReturn('@alice:example.com');
    when(() => mockMatrixService.syncRoomId).thenReturn('!room123:example.com');
    when(() => mockMatrixService.deleteConfig()).thenAnswer((_) async {});
    when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([]);
    when(() => mockMatrixService.keyVerificationStream)
        .thenAnswer((_) => const Stream.empty());
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
              () => _FakeMatrixUnverifiedController(const []),
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
              () => _FakeMatrixUnverifiedController(const []),
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

    testWidgets('disconnect calls deleteConfig after confirmation',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => _FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      final disconnectFinder =
          find.text(context.messages.provisionedSyncDisconnect);
      await tester.ensureVisible(disconnectFinder);
      await tester.tap(disconnectFinder);
      await tester.pumpAndSettle();

      // Confirmation dialog should be visible
      expect(
        find.text(context.messages.syncDeleteConfigQuestion),
        findsOneWidget,
      );

      // Tap the confirm button
      await tester.tap(find.text(context.messages.syncDeleteConfigConfirm));
      await tester.pumpAndSettle();

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
              () => _FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sync Status'));
      await tester.pumpAndSettle();
      expect(find.byType(ProvisionedStatusWidget), findsOneWidget);

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      final disconnectFinder =
          find.text(context.messages.provisionedSyncDisconnect);
      await tester.ensureVisible(disconnectFinder);
      await tester.tap(disconnectFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text(context.messages.syncDeleteConfigConfirm));
      await tester.pumpAndSettle();

      verify(() => mockMatrixService.deleteConfig()).called(1);
      expect(find.byType(ProvisionedStatusWidget), findsNothing);
      expect(find.text('Open Sync Status'), findsOneWidget);
    });

    testWidgets('disconnect does not call deleteConfig when cancelled',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => _FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      final disconnectFinder =
          find.text(context.messages.provisionedSyncDisconnect);
      await tester.ensureVisible(disconnectFinder);
      await tester.tap(disconnectFinder);
      await tester.pumpAndSettle();

      // Confirmation dialog should be visible
      expect(
        find.text(context.messages.syncDeleteConfigQuestion),
        findsOneWidget,
      );

      // Tap cancel in confirmation dialog
      await tester.tap(find.text(context.messages.settingsMatrixCancel));
      await tester.pumpAndSettle();

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
              () => _FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      expect(
        find.text(context.messages.provisionedSyncVerifyDevicesTitle),
        findsOneWidget,
      );
    });

    testWidgets('shows no-unverified-devices indicator when list is empty',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => _FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UnverifiedDevices), findsOneWidget);
    });

    testWidgets('shows device cards when unverified devices exist',
        (tester) async {
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
              () => _FakeMatrixUnverifiedController([device]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeviceCard), findsOneWidget);
      expect(find.text('Pixel 7'), findsWidgets);
    });
  });

  group('handover QR section (desktop)', () {
    testWidgets('shows QR by default on desktop', (tester) async {
      final wasDesktop = isDesktop;
      isDesktop = true;
      addTearDown(() => isDesktop = wasDesktop);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => _FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      expect(
        find.byKey(const Key('statusHandoverQrImage')),
        findsOneWidget,
      );
      expect(find.text(context.messages.provisionedSyncReady), findsOneWidget);
    });

    testWidgets('hides QR button on mobile', (tester) async {
      final wasDesktop = isDesktop;
      isDesktop = false;
      addTearDown(() => isDesktop = wasDesktop);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => _FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      expect(
        find.text(context.messages.provisionedSyncShowQr),
        findsNothing,
      );
      expect(find.byKey(const Key('statusHandoverQrImage')), findsNothing);
    });

    testWidgets('toggles handover data visibility', (tester) async {
      final wasDesktop = isDesktop;
      isDesktop = true;
      addTearDown(() => isDesktop = wasDesktop);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => _FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('\u2022' * 24), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Toggle reveal
      final toggleFinder =
          find.byKey(const Key('statusToggleHandoverVisibility'));
      await tester.ensureVisible(toggleFinder);
      await tester.pumpAndSettle();
      await tester.tap(toggleFinder);
      await tester.pump();

      // Should now show the base64 string and hide icon
      expect(find.text('\u2022' * 24), findsNothing);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });

  testWidgets('shows retry button when config is null', (tester) async {
    final wasDesktop = isDesktop;
    isDesktop = true;
    addTearDown(() => isDesktop = wasDesktop);

    when(() => mockMatrixService.loadConfig()).thenAnswer(
      (_) async => null,
    );

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ProvisionedStatusWidget(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixUnverifiedControllerProvider.overrideWith(
            () => _FakeMatrixUnverifiedController(const []),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ProvisionedStatusWidget));
    expect(find.byKey(const Key('statusHandoverQrImage')), findsNothing);
    expect(
      find.text(context.messages.provisionedSyncShowQr),
      findsOneWidget,
    );
  });

  testWidgets('copy button copies handover data on desktop', (tester) async {
    final wasDesktop = isDesktop;
    isDesktop = true;
    addTearDown(() => isDesktop = wasDesktop);

    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ProvisionedStatusWidget(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixUnverifiedControllerProvider.overrideWith(
            () => _FakeMatrixUnverifiedController(const []),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final copyFinder = find.byKey(const Key('statusCopyHandoverData'));
    await tester.ensureVisible(copyFinder);
    await tester.pumpAndSettle();
    await tester.tap(copyFinder);
    await tester.pumpAndSettle();

    expect(clipboardText, isNotNull);

    final context = tester.element(find.byType(ProvisionedStatusWidget));
    expect(
      find.text(context.messages.provisionedSyncCopiedToClipboard),
      findsOneWidget,
    );
  });

  testWidgets(
    'auto-verification launcher shows modal for unverified devices',
    (tester) async {
      final mockDevice = MockDeviceKeys();
      when(() => mockDevice.deviceDisplayName).thenReturn('Other Device');
      when(() => mockDevice.deviceId).thenReturn('OTHERDEVICE');
      when(() => mockDevice.userId).thenReturn('@alice:example.com');
      when(() => mockMatrixService.verifyDevice(mockDevice))
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => _FakeMatrixUnverifiedController([mockDevice]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // The auto-verification launcher should trigger a verification modal
      expect(find.text('Other Device'), findsWidgets);
    },
  );
}
