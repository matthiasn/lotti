import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart' show CameraException;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart'
    hide isLinux, isMacOS, isWindows;
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/features/sync/ui/provisioned/qr_scanner.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/platform.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import 'bundle_import_page_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late MockLoggingService mockLoggingService;
  late ValueNotifier<int> pageIndexNotifier;

  const testBundle = SyncProvisioningBundle(
    v: 2,
    kind: SyncBundleKind.handover,
    homeServer: 'https://matrix.example.com',
    user: '@alice:example.com',
    password: 'secret123',
    roomId: '!room123:example.com',
  );

  final validBase64 = base64UrlEncode(
    utf8.encode(jsonEncode(testBundle.toJson())),
  );

  setUpAll(() {
    registerFallbackValue(
      const MatrixConfig(homeServer: '', user: '', password: ''),
    );
  });

  setUp(() {
    final wasDesktop = isDesktop;
    final wasMobile = isMobile;
    final wasWindows = isWindows;
    final wasLinux = isLinux;
    final wasMacOS = isMacOS;
    isDesktop = true;
    isMobile = false;
    isWindows = true;
    isLinux = false;
    isMacOS = false;
    addTearDown(() {
      isDesktop = wasDesktop;
      isMobile = wasMobile;
      isWindows = wasWindows;
      isLinux = wasLinux;
      isMacOS = wasMacOS;
    });

    mockMatrixService = MockMatrixService();
    mockLoggingService = MockLoggingService();
    pageIndexNotifier = ValueNotifier(0);
    ensureDomainLoggerRegistered();

    when(() => mockMatrixService.setConfig(any())).thenAnswer((_) async {});
    when(
      () => mockMatrixService.login(
        waitForLifecycle: any(named: 'waitForLifecycle'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => mockMatrixService.joinRoom(any()),
    ).thenAnswer((_) async => '!room:example.com');
    when(() => mockMatrixService.saveRoom(any())).thenAnswer((_) async {});
    when(() => mockMatrixService.clearPersistedRoom()).thenAnswer((_) async {});
    when(
      () => mockMatrixService.getRoom(),
    ).thenAnswer((_) async => '!room:example.com');
    when(
      () => mockMatrixService.changePassword(
        oldPassword: any(named: 'oldPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockMatrixService.isLoggedIn()).thenReturn(false);
    when(() => mockMatrixService.logout()).thenAnswer((_) async {});
    when(() => mockMatrixService.deleteConfig()).thenAnswer((_) async {});
    when(() => mockMatrixService.loadConfig()).thenAnswer(
      (_) async => const MatrixConfig(
        homeServer: 'https://matrix.example.com',
        user: '@alice:example.com',
        password: 'secret123',
      ),
    );
  });

  tearDown(() async {
    qrCameraFactoryOverride = null;
    pageIndexNotifier.dispose();
    await tearDownTestGetIt();
  });

  List<Override> defaultOverrides() => [
    matrixServiceProvider.overrideWithValue(mockMatrixService),
    loggingServiceProvider.overrideWithValue(mockLoggingService),
  ];

  Future<void> tapScanInstead(WidgetTester tester) async {
    final action = find.byKey(const Key('bundle_import_scan_instead'));
    await tester.ensureVisible(action);
    await tester.pump();

    final inkTarget = find.descendant(
      of: action,
      matching: find.byType(InkWell),
    );
    expect(inkTarget, findsOneWidget);
    await tester.tap(inkTarget);
  }

  group('scanner platforms', () {
    testWidgets('opens the camera immediately on mobile', (tester) async {
      final camera = setUpMobileScanner();

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          ),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      // Scanning is what a new phone is here for: no tap should be needed,
      // and the base64 field must not be the first thing on screen.
      expect(find.byType(QrScanner), findsOneWidget);
      expect(camera.started, isTrue);
      expect(find.byType(TextField), findsNothing);

      // The screen leads with its own imperative; the prerequisite about a
      // *different* device is supporting copy below the viewfinder.
      final context = tester.element(find.byType(BundleImportWidget));
      expect(find.text(context.messages.syncPairScanTitle), findsOneWidget);
      expect(
        find.text(context.messages.syncPairScanHint),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text(context.messages.syncPairScanTitle)).dy,
        lessThan(
          tester.getTopLeft(find.text(context.messages.syncPairScanHint)).dy,
        ),
      );
    });

    testWidgets('Windows stays on manual entry until its scanner is added', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          ),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      expect(find.byIcon(LottiIcons.scanQr), findsNothing);
      expect(find.byType(QrScanner), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('macOS opens the camera scanner immediately', (
      tester,
    ) async {
      final camera = setUpMacOsScanner();

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          ),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      expect(find.byType(QrScanner), findsOneWidget);
      expect(camera.started, isTrue);
      expect(find.byType(TextField), findsNothing);
      final context = tester.element(find.byType(BundleImportWidget));
      expect(find.text(context.messages.syncPairScanTitle), findsOneWidget);
    });

    testWidgets('Linux opens the camera scanner immediately', (
      tester,
    ) async {
      final camera = FakeQrCamera();
      qrCameraFactoryOverride = () async => camera;
      isWindows = false;
      isLinux = true;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          ),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      expect(find.byType(QrScanner), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(camera.started, isTrue);
    });

    testWidgets(
      'Linux camera failure keeps retry and manual recovery visible',
      (
        tester,
      ) async {
        qrCameraFactoryOverride = () async =>
            throw const FormatException('no camera');
        isWindows = false;
        isLinux = true;

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            SingleChildScrollView(
              child: BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
            ),
            overrides: defaultOverrides(),
          ),
        );
        await tester.pump();

        final context = tester.element(find.byType(BundleImportWidget));
        expect(
          find.text(context.messages.syncPairCameraDenied),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('bundle_import_camera_retry')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('bundle_import_enter_manually')),
          findsOneWidget,
        );
      },
    );

    testWidgets('hides import form after successful import', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          ),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      // Import first bundle
      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(find.text(context.messages.provisionedSyncImportButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('@alice:example.com'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(
        find.text(context.messages.provisionedSyncImportButton),
        findsNothing,
      );
    });

    testWidgets(
      'mobile can fall back to manual entry and return to the camera',
      (tester) async {
        setUpMobileScanner();

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            SingleChildScrollView(
              child: BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
            ),
            overrides: defaultOverrides(),
          ),
        );
        await tester.pump();

        expect(find.byType(QrScanner), findsOneWidget);

        final manualFinder = find.byKey(
          const Key('bundle_import_enter_manually'),
        );
        await tester.ensureVisible(manualFinder);
        await tester.tap(manualFinder);
        await tester.pump();

        expect(find.byType(QrScanner), findsNothing);
        expect(find.byType(TextField), findsOneWidget);

        await tapScanInstead(tester);
        await tester.pump();

        expect(find.byType(QrScanner), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
      },
    );

    testWidgets(
      'a provisioning reset preserves manual mode on scanner platforms',
      (tester) async {
        final camera = FakeQrCamera();
        qrCameraFactoryOverride = () async => camera;
        isWindows = false;
        isLinux = true;

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            SingleChildScrollView(
              child: BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
            ),
            overrides: defaultOverrides(),
          ),
        );
        await tester.pump();

        final manualEntry = find.byKey(
          const Key('bundle_import_enter_manually'),
        );
        await tester.ensureVisible(manualEntry);
        await tester.tap(manualEntry);
        await tester.pump();
        expect(find.byType(TextField), findsOneWidget);

        await tester.enterText(find.byType(TextField), validBase64);
        await tester.pump();
        final context = tester.element(find.byType(BundleImportWidget));
        await tester.tap(
          find.text(context.messages.provisionedSyncImportButton),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(BundleImportWidget)),
        );
        container.read(provisioningControllerProvider.notifier).reset();
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(QrScanner), findsNothing);
      },
    );
  });

  group('scanned code handling', () {
    Future<void> pumpImportPage(WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          ),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();
    }

    testWidgets('a denied camera explains itself and offers a way back', (
      tester,
    ) async {
      // The copy names a remedy the user performs in system settings, so the
      // flow has to offer a route back without closing the sheet.
      setUpMobileScanner();
      installQrCameraFactory(
        () async => throw CameraException('permission', 'denied'),
      );

      await pumpImportPage(tester);

      final context = tester.element(
        find.byKey(const Key('bundle_import_camera_denied')),
      );
      expect(
        find.text(context.messages.syncPairCameraDenied),
        findsOneWidget,
      );
      final retry = tester.widget<DesignSystemButton>(
        find.byKey(const Key('bundle_import_camera_retry')),
      );
      expect(retry.label, context.messages.syncPairCameraRetry);
      expect(retry.onPressed, isNotNull);
    });

    testWidgets('retrying the camera mounts a fresh scanner that recovers', (
      tester,
    ) async {
      setUpMobileScanner();
      var attempts = 0;
      final camera = FakeQrCamera();
      installQrCameraFactory(() async {
        attempts++;
        if (attempts == 1) throw CameraException('permission', 'denied');
        return camera;
      });

      await pumpImportPage(tester);
      expect(find.byKey(const ValueKey('scanner_0')), findsOneWidget);
      expect(
        find.byKey(const Key('bundle_import_camera_denied')),
        findsOneWidget,
      );

      // The user granted access in system settings and comes back.
      final retry = find.byKey(const Key('bundle_import_camera_retry'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // A new generation key mounts the scanner from scratch, so it asks for
      // the camera again instead of staying on its failed fallback.
      expect(find.byKey(const ValueKey('scanner_0')), findsNothing);
      expect(find.byKey(const ValueKey('scanner_1')), findsOneWidget);
      expect(attempts, 2);
      expect(camera.started, isTrue);
      expect(
        find.byKey(const Key('bundle_import_camera_denied')),
        findsNothing,
      );
      expect(find.byKey(const Key('fake_camera_preview')), findsOneWidget);
    });

    testWidgets('a declined *pasted* code is remembered too', (tester) async {
      // Only the camera path used to record the payload, so a code that
      // arrived by clipboard or typing was never added to the rejected set —
      // switching to the camera with that QR still up reopened the very
      // confirmation the user had just declined.
      setUpMobileScanner();

      // Taller surface: the manual-entry fallback sits below the viewfinder
      // and misses the tap on the default 600pt canvas.
      tester.view
        ..physicalSize = const Size(900, 1800)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpImportPage(tester);

      await tester.tap(find.byKey(const Key('bundle_import_enter_manually')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pump();
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(
        find.text(context.messages.provisionedSyncImportButton),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('bundle_import_discard')), findsOneWidget);

      await tester.tap(find.byKey(const Key('bundle_import_discard')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tapScanInstead(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      scanCode(tester, validBase64);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byKey(const Key('bundle_import_discard')), findsNothing);
      expect(
        find.text(context.messages.syncPairScannerRejected),
        findsOneWidget,
      );
    });

    testWidgets('leaving the scanner mid-initialisation reports no error', (
      tester,
    ) async {
      // The camera opens asynchronously. If the page goes away while that is
      // in flight, the camera that finally arrives must be released rather
      // than started against an unmounted scanner (lotti3-82s).
      setUpMobileScanner();
      final camera = FakeQrCamera();
      final gate = Completer<QrCamera>();
      installQrCameraFactory(() => gate.future);

      await pumpImportPage(tester);
      expect(find.byType(QrScanner), findsOneWidget);

      // The user moves on before the camera has finished coming up.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // ...and only now does the camera answer.
      gate.complete(camera);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(camera.disposed, isTrue);
      expect(camera.started, isFalse);
    });

    testWidgets('a camera that refuses to start leaves the page usable', (
      tester,
    ) async {
      setUpMobileScanner();
      final failing = FakeQrCamera(
        startError: CameraException('start', 'camera refused'),
      );
      installQrCameraFactory(() async => failing);

      await pumpImportPage(tester);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(failing.started, isTrue);
      expect(failing.disposed, isTrue);
      // The dead camera says so, and the way out stays on screen.
      final context = tester.element(find.byType(BundleImportWidget));
      expect(
        find.text(context.messages.syncPairCameraDenied),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.syncPairEnterManually),
        findsOneWidget,
      );
    });

    testWidgets('scannerPreviewOverride replaces the live camera', (
      tester,
    ) async {
      // The seam the manual captures rely on: a headless run has no camera
      // plugin, so the real scanner must not be mounted at all.
      final camera = setUpMobileScanner();
      scannerPreviewOverride = (context, side) =>
          const ColoredBox(key: Key('stand_in'), color: Color(0xFF00FF00));
      addTearDown(() => scannerPreviewOverride = null);

      await pumpImportPage(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stand_in')), findsOneWidget);
      expect(find.byType(QrScanner), findsNothing);
      expect(camera.started, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('declining a scanned code lands on the field and stays there', (
      tester,
    ) async {
      setUpMobileScanner();

      await pumpImportPage(tester);

      scanCode(tester, validBase64);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('bundle_import_discard')), findsOneWidget);

      await tester.tap(find.byKey(const Key('bundle_import_discard')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // "Enter a different pairing code" has to land on a field. It used to
      // return to the viewfinder, contradicting its own label.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(QrScanner), findsNothing);

      // And the rejected code must not come back. The QR is still on the
      // other device's screen, so before this the very next frame re-decoded
      // it and bounced the user into the confirmation they just refused. It
      // says so rather than going quietly inert.
      await tapScanInstead(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      scanCode(tester, validBase64);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final context = tester.element(find.byType(BundleImportWidget));
      expect(find.byKey(const Key('bundle_import_discard')), findsNothing);
      expect(find.byType(QrScanner), findsOneWidget);
      expect(
        find.text(context.messages.syncPairScannerRejected),
        findsOneWidget,
      );
    });

    testWidgets(
      'a valid scanned bundle shows its summary and hides the camera',
      (
        tester,
      ) async {
        setUpMobileScanner();

        await pumpImportPage(tester);
        expect(find.byType(QrScanner), findsOneWidget);

        scanCode(tester, validBase64);
        // Process the setState rebuild, then advance past the 220 ms
        // AnimatedSwitcher transition so the old child is fully removed.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.byType(QrScanner), findsNothing);
        expect(find.text('matrix.example.com'), findsOneWidget);
        expect(find.text('@alice:example.com'), findsOneWidget);
      },
    );

    testWidgets('an invalid scanned code explains itself beside the camera', (
      tester,
    ) async {
      setUpMobileScanner();

      await pumpImportPage(tester);

      scanCode(tester, 'not-a-valid-bundle');
      await tester.pump();

      // The camera stays up: the code was unreadable, and the user should
      // simply point it at the right one.
      final context = tester.element(find.byType(BundleImportWidget));
      final errorFinder = find.byKey(const Key('bundle_import_scan_error'));
      expect(
        tester.widget<Text>(errorFinder).data,
        context.messages.syncPairErrorMalformed,
      );
      expect(find.byType(QrScanner), findsOneWidget);
      expect(find.byKey(const Key('bundle_import_discard')), findsNothing);
    });

    testWidgets('ignores an empty scan', (tester) async {
      setUpMobileScanner();

      await pumpImportPage(tester);

      scanCode(tester, '');
      await tester.pump();

      // Nothing was decoded, so the camera is still up and no bundle summary
      // or error appeared.
      expect(find.byType(QrScanner), findsOneWidget);
      expect(find.text('@alice:example.com'), findsNothing);
      expect(find.byKey(const Key('bundle_import_scan_error')), findsNothing);
    });
  });

  group('desktop paste clipboard error handling', () {
    testWidgets(
      'paste button handles PlatformException from clipboard gracefully',
      (tester) async {
        final wasDesktop = isDesktop;
        final wasMobile = isMobile;
        isDesktop = true;
        isMobile = false;
        addTearDown(() {
          isDesktop = wasDesktop;
          isMobile = wasMobile;
        });

        // Make clipboard throw a PlatformException
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.getData') {
              throw PlatformException(code: 'clipboard_error');
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
            SingleChildScrollView(
              child: BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
            ),
            overrides: defaultOverrides(),
          ),
        );
        await tester.pump();

        final context = tester.element(find.byType(BundleImportWidget));

        // Should not throw — PlatformException is silently swallowed
        await tester.tap(
          find.text(context.messages.provisionedSyncPasteClipboard),
        );
        await tester.pump();

        // No summary card shown; input form still present
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('@alice:example.com'), findsNothing);
      },
    );

    testWidgets('paste button does nothing when clipboard text is empty', (
      tester,
    ) async {
      final wasDesktop = isDesktop;
      final wasMobile = isMobile;
      isDesktop = true;
      isMobile = false;
      addTearDown(() {
        isDesktop = wasDesktop;
        isMobile = wasMobile;
      });

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': ''};
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
          SingleChildScrollView(
            child: BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          ),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(
        find.text(context.messages.provisionedSyncPasteClipboard),
      );
      await tester.pump();

      // Empty text — no import triggered, form still shown
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('@alice:example.com'), findsNothing);
    });
  });
}
