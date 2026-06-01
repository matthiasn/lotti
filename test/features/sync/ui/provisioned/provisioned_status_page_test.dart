import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/features/sync/ui/unverified_devices_page.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/device_card.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
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

/// Counts how many times [build] runs so tests can assert that the provider
/// was invalidated (re-built) by code under test.
class _CountingMatrixUnverifiedController extends MatrixUnverifiedController {
  _CountingMatrixUnverifiedController(this.devices, this.buildCount);

  final List<DeviceKeys> devices;
  final List<int> buildCount;

  @override
  Future<List<DeviceKeys>> build() async {
    buildCount[0]++;
    return devices;
  }
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

    testWidgets('disconnect calls deleteConfig after confirmation', (
      tester,
    ) async {
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
      final disconnectFinder = find.text(
        context.messages.provisionedSyncDisconnect,
      );
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
              () => _FakeMatrixUnverifiedController(const []),
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
              () => _FakeMatrixUnverifiedController(const []),
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
              () => _FakeMatrixUnverifiedController([device]),
            ),
          ],
        ),
      );
      await tester.pump();

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
      await tester.pump();

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
      await tester.pump();

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
      await tester.pump();

      expect(find.text('\u2022' * 24), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Toggle reveal
      final toggleFinder = find.byKey(
        const Key('statusToggleHandoverVisibility'),
      );
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
    await tester.pump();

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
    await tester.pump();

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
      when(
        () => mockMatrixService.verifyDevice(mockDevice),
      ).thenAnswer((_) async {});

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
      await tester.pump();

      // The auto-verification launcher should trigger a verification modal
      expect(find.text('Other Device'), findsWidgets);
    },
  );

  group('_StatusActionBar close button', () {
    // Covers lines 61, 63-64: the close button's onPressed resets the page
    // index notifier to 0 and pops the current route.
    testWidgets(
      'resets page index notifier to 0 and pops the route',
      (tester) async {
        final pageIndexNotifier = ValueNotifier<int>(3);
        addTearDown(pageIndexNotifier.dispose);

        // Build the real page via the public factory and extract the private
        // _StatusActionBar from its stickyActionBar so we can drive it inside a
        // navigator and observe the pop.
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            Builder(
              builder: (outerContext) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(outerContext).push(
                      MaterialPageRoute<void>(
                        builder: (routeContext) {
                          final page = provisionedStatusPage(
                            context: routeContext,
                            pageIndexNotifier: pageIndexNotifier,
                          );
                          return Scaffold(
                            body: page.stickyActionBar,
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('Open Action Bar'),
                ),
              ),
            ),
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
            ],
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Open Action Bar'));
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(LottiSecondaryButton));
        final closeFinder = find.text(
          context.messages.tasksLabelsDialogClose,
        );
        expect(closeFinder, findsOneWidget);

        await tester.tap(closeFinder);
        await tester.pumpAndSettle();

        // Notifier was reset and the action-bar route was popped.
        expect(pageIndexNotifier.value, 0);
        expect(find.byType(LottiSecondaryButton), findsNothing);
        expect(find.text('Open Action Bar'), findsOneWidget);
      },
    );
  });

  group('_AutoVerificationLauncher finally block', () {
    // Covers lines 174-175, 177-178: after the verification sheet closes, the
    // finally block invalidates the unverified provider and releases the lock.
    testWidgets(
      'releases lock and invalidates unverified provider after modal closes',
      (tester) async {
        final wasDesktop = isDesktop;
        isDesktop = false;
        addTearDown(() => isDesktop = wasDesktop);

        final mockDevice = MockDeviceKeys();
        when(() => mockDevice.deviceDisplayName).thenReturn('Other Device');
        when(() => mockDevice.deviceId).thenReturn('OTHERDEVICE');
        when(() => mockDevice.userId).thenReturn('@alice:example.com');
        when(
          () => mockMatrixService.verifyDevice(mockDevice),
        ).thenAnswer((_) async {});

        // build() is called once for the initial load; the finally block's
        // ref.invalidate triggers a second build.
        final buildCount = [0];

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
              matrixUnverifiedControllerProvider.overrideWith(
                () => _CountingMatrixUnverifiedController(
                  [mockDevice],
                  buildCount,
                ),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: resolveTestTheme(),
              home: Consumer(
                builder: (ctx, ref, _) {
                  container = ProviderScope.containerOf(ctx);
                  return const Scaffold(body: ProvisionedStatusWidget());
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The auto-launcher opened the verification modal and acquired the lock.
        expect(find.byType(VerificationModal), findsOneWidget);
        expect(container.read(matrixVerificationModalLockProvider), isTrue);
        final buildsBeforeClose = buildCount[0];

        // Close the modal via the top-bar close (X) button so the awaited
        // sheet future completes and the finally block runs.
        final closeButton = find.byIcon(Icons.close_rounded);
        await tester.ensureVisible(closeButton);
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        // Modal gone, lock released, and the provider was invalidated/re-built.
        expect(find.byType(VerificationModal), findsNothing);
        expect(container.read(matrixVerificationModalLockProvider), isFalse);
        expect(buildCount[0], greaterThan(buildsBeforeClose));
      },
    );
  });
}
