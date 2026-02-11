import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/features/sync/ui/unverified_devices_page.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/device_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/platform.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

class MockClient extends Mock implements Client {}

class MockDeviceKeys extends Mock implements DeviceKeys {}

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

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockClient = MockClient();

    when(() => mockMatrixService.client).thenReturn(mockClient);
    when(() => mockClient.userID).thenReturn('@alice:example.com');
    when(() => mockMatrixService.syncRoomId).thenReturn('!room123:example.com');
    when(() => mockMatrixService.deleteConfig()).thenAnswer((_) async {});
  });

  group('ProvisionedStatusWidget', () {
    testWidgets('displays user ID from Matrix client', (tester) async {
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

      expect(find.text('@alice:example.com'), findsOneWidget);
    });

    testWidgets('displays sync room ID', (tester) async {
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

      expect(find.text('!room123:example.com'), findsOneWidget);
    });

    testWidgets('displays labels for user and room', (tester) async {
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
        find.text(context.messages.provisionedSyncSummaryUser),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.provisionedSyncSummaryRoom),
        findsOneWidget,
      );
    });

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
      await tester.tap(find.text(context.messages.provisionedSyncDisconnect));
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
      await tester.tap(find.text(context.messages.provisionedSyncDisconnect));
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
      await tester.tap(find.text(context.messages.provisionedSyncDisconnect));
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

    testWidgets('handles null user ID gracefully', (tester) async {
      when(() => mockClient.userID).thenReturn(null);

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

      // Should show empty string when user ID is null
      expect(find.byType(ProvisionedStatusWidget), findsOneWidget);
    });

    testWidgets('handles null room ID gracefully', (tester) async {
      when(() => mockMatrixService.syncRoomId).thenReturn(null);

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

      // Should show empty string when room ID is null
      expect(find.byType(ProvisionedStatusWidget), findsOneWidget);
    });

    testWidgets('user ID and room ID are selectable', (tester) async {
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

      // SelectableText widgets for the values
      final selectableTexts = find.byType(SelectableText);
      expect(selectableTexts, findsAtLeast(2));
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
      when(() => device.deviceDisplayName).thenReturn('Pixel 7');
      when(() => device.deviceId).thenReturn('DEVICE1');
      when(() => device.userId).thenReturn('@alice:example.com');

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
      expect(find.text('Pixel 7'), findsOneWidget);
    });
  });

  group('handover QR section (desktop)', () {
    testWidgets('shows QR button on desktop', (tester) async {
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
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      expect(
        find.text(context.messages.provisionedSyncShowQr),
        findsOneWidget,
      );
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
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      expect(
        find.text(context.messages.provisionedSyncShowQr),
        findsNothing,
      );
    });

    testWidgets('generates and displays QR on tap', (tester) async {
      final wasDesktop = isDesktop;
      isDesktop = true;
      addTearDown(() => isDesktop = wasDesktop);

      when(() => mockMatrixService.loadConfig()).thenAnswer(
        (_) async => const MatrixConfig(
          homeServer: 'https://matrix.example.com',
          user: '@alice:example.com',
          password: 'rotated-pw',
        ),
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
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      await tester.tap(find.text(context.messages.provisionedSyncShowQr));
      await tester.pumpAndSettle();

      // QR image should be visible
      expect(find.byKey(const Key('statusHandoverQrImage')), findsOneWidget);
      // Ready text should be visible
      expect(
        find.text(context.messages.provisionedSyncReady),
        findsOneWidget,
      );
    });

    testWidgets('toggles handover data visibility', (tester) async {
      final wasDesktop = isDesktop;
      isDesktop = true;
      addTearDown(() => isDesktop = wasDesktop);

      when(() => mockMatrixService.loadConfig()).thenAnswer(
        (_) async => const MatrixConfig(
          homeServer: 'https://matrix.example.com',
          user: '@alice:example.com',
          password: 'rotated-pw',
        ),
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
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      await tester.tap(find.text(context.messages.provisionedSyncShowQr));
      await tester.pumpAndSettle();

      // Initially masked
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

  testWidgets('QR button stays when config is null', (tester) async {
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
    await tester.pump();

    final context = tester.element(find.byType(ProvisionedStatusWidget));
    await tester.tap(find.text(context.messages.provisionedSyncShowQr));
    await tester.pumpAndSettle();

    // regenerateHandover returns null, so QR should not appear
    expect(find.byKey(const Key('statusHandoverQrImage')), findsNothing);
    // Button should still be visible for retry
    expect(
      find.text(context.messages.provisionedSyncShowQr),
      findsOneWidget,
    );
  });

  group('ProvisionedStatusPage action bar', () {
    testWidgets('back button navigates to page 0', (tester) async {
      final pageIndexNotifier = ValueNotifier<int>(2);
      addTearDown(pageIndexNotifier.dispose);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          _StatusActionBarTestWrapper(
            pageIndexNotifier: pageIndexNotifier,
          ),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => _FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(_StatusActionBarTestWrapper));
      await tester.tap(
        find.text(context.messages.settingsMatrixPreviousPage),
      );
      await tester.pump();

      expect(pageIndexNotifier.value, 0);
    });

    testWidgets('close button is rendered with correct label', (tester) async {
      final pageIndexNotifier = ValueNotifier<int>(2);
      addTearDown(pageIndexNotifier.dispose);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          _StatusActionBarTestWrapper(
            pageIndexNotifier: pageIndexNotifier,
          ),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixUnverifiedControllerProvider.overrideWith(
              () => _FakeMatrixUnverifiedController(const []),
            ),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(_StatusActionBarTestWrapper));
      expect(
        find.text(context.messages.tasksLabelsDialogClose),
        findsOneWidget,
      );
    });
  });
}

/// Wrapper to test navigation via pageIndexNotifier. Since _StatusActionBar
/// is private, we replicate its button logic through the notifier.
class _StatusActionBarTestWrapper extends StatelessWidget {
  const _StatusActionBarTestWrapper({required this.pageIndexNotifier});

  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ProvisionedStatusWidget(),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => pageIndexNotifier.value = 0,
              child: Text(context.messages.settingsMatrixPreviousPage),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.messages.tasksLabelsDialogClose),
            ),
          ],
        ),
      ],
    );
  }
}
