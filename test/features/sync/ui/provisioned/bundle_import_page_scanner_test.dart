import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/platform.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
    kind: SyncBundleKind.provisioned,
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
    pageIndexNotifier.dispose();
    await tearDownTestGetIt();
  });

  List<Override> defaultOverrides() => [
    matrixServiceProvider.overrideWithValue(mockMatrixService),
    loggingServiceProvider.overrideWithValue(mockLoggingService),
  ];

  group('mobile scanner', () {
    testWidgets('opens the camera immediately on mobile', (tester) async {
      setUpMobileScanner();

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      // Scanning is what a new phone is here for: no tap should be needed,
      // and the base64 field must not be the first thing on screen.
      expect(find.byType(MobileScanner), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      // The screen leads with its own imperative; the prerequisite about a
      // *different* device is supporting copy below the viewfinder.
      final context = tester.element(find.byType(BundleImportWidget));
      expect(find.text(context.messages.syncPairScanTitle), findsOneWidget);
      expect(
        find.text(context.messages.syncPairWhereToFind),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text(context.messages.syncPairScanTitle)).dy,
        lessThan(
          tester.getTopLeft(find.text(context.messages.syncPairWhereToFind)).dy,
        ),
      );
    });

    testWidgets('desktop stays on manual entry with no camera', (
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

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
      expect(find.byType(MobileScanner), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('hides import form after successful import', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
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
            BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
            overrides: defaultOverrides(),
          ),
        );
        await tester.pump();

        expect(find.byType(MobileScanner), findsOneWidget);

        final manualFinder = find.byKey(
          const Key('bundle_import_enter_manually'),
        );
        await tester.ensureVisible(manualFinder);
        await tester.tap(manualFinder);
        await tester.pump();

        expect(find.byType(MobileScanner), findsNothing);
        expect(find.byType(TextField), findsOneWidget);

        final scanFinder = find.byKey(const Key('bundle_import_scan_instead'));
        await tester.ensureVisible(scanFinder);
        await tester.tap(scanFinder);
        await tester.pump();

        expect(find.byType(MobileScanner), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
      },
    );
  });

  group('mobile scanner barcode handling', () {
    testWidgets('a denied camera explains itself and offers a way back', (
      tester,
    ) async {
      // The copy names a remedy the user performs in system settings, so the
      // flow has to offer a route back without closing the sheet — and the
      // retry has to reach the live state, not a rebuilt one.
      setUpMobileScanner();

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      final scannerBefore = find.byKey(const ValueKey('scanner_0'));
      expect(scannerBefore, findsOneWidget);

      // Drive the scanner's own error path rather than faking the widget, so
      // the callback under test is the one production wires up.
      final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      final denied = scanner.errorBuilder!(
        tester.element(find.byType(MobileScanner)),
        const MobileScannerException(
          errorCode: MobileScannerErrorCode.permissionDenied,
        ),
      );

      // Same override count — Riverpod forbids changing it between pumps.
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(denied, overrides: defaultOverrides()),
      );
      await tester.pump();

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

    testWidgets('retrying the camera recreates the scanner subtree', (
      tester,
    ) async {
      setUpMobileScanner();

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('scanner_0')), findsOneWidget);

      // Invoke the retry the live scanner would hand to its error view. The
      // widget stays mounted, so this runs against the real State.
      final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      final denied = scanner.errorBuilder!(
        tester.element(find.byType(MobileScanner)),
        const MobileScannerException(
          errorCode: MobileScannerErrorCode.permissionDenied,
        ),
      );
      ((denied as dynamic).onRetry as VoidCallback)();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // A new generation key means the MobileScanner subtree is rebuilt from
      // scratch, so it cannot cache the failed start.
      expect(find.byKey(const ValueKey('scanner_0')), findsNothing);
      expect(find.byKey(const ValueKey('scanner_1')), findsOneWidget);
    });

    testWidgets('a declined *pasted* code is remembered too', (tester) async {
      // Only _handleBarcode used to record the payload, so a code that
      // arrived by clipboard or typing was never added to the rejected set —
      // switching to the camera with that QR still up reopened the very
      // confirmation the user had just declined.
      //
      // Mobile explicitly: this group inherits the host platform, and the
      // camera fallback only exists there.
      final wasDesktop = isDesktop;
      final wasMobile = isMobile;
      isDesktop = false;
      isMobile = true;
      addTearDown(() {
        isDesktop = wasDesktop;
        isMobile = wasMobile;
      });
      setUpMobileScanner();

      // Taller surface: the manual-entry fallback sits below the viewfinder
      // and misses the tap on the default 600pt canvas.
      tester.view
        ..physicalSize = const Size(900, 1800)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

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

      await tester.tap(find.byKey(const Key('bundle_import_scan_instead')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
        BarcodeCapture(barcodes: [Barcode(rawValue: validBase64)]),
      );
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
      // The camera is started from an async call. If the page goes away while
      // that is in flight, the controller is disposed underneath it and the
      // start rejects. Left to `MobileScanner`'s own un-awaited initializer
      // that lands as an unhandled async error nothing can catch, which is
      // what broke every mobile manual capture (lotti3-82s).
      setUpMobileScanner();
      final gated = _GatedStartScanner();
      MobileScannerPlatform.instance = gated;
      addTearDown(gated.disposeControllers);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();
      expect(find.byType(MobileScanner), findsOneWidget);
      // The camera really is mid-startup, so what follows is the race and not
      // a page that never tried.
      expect(gated.started, isTrue);
      expect(gated.gate.isCompleted, isFalse);

      // The user moves on before the camera has finished coming up.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // ...and only now does the camera answer.
      gated.gate.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a camera that refuses to start leaves the page usable', (
      tester,
    ) async {
      // The start now happens in a future this page owns, so its failure has
      // to be handled here rather than escaping as an unhandled async error.
      setUpMobileScanner();
      final failing = _FailingStartScanner();
      MobileScannerPlatform.instance = failing;
      addTearDown(failing.disposeControllers);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The way out of a dead camera stays on screen.
      final context = tester.element(find.byType(BundleImportWidget));
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
      setUpMobileScanner();
      scannerPreviewOverride = (context, side) =>
          const ColoredBox(key: Key('stand_in'), color: Color(0xFF00FF00));
      addTearDown(() => scannerPreviewOverride = null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stand_in')), findsOneWidget);
      expect(find.byType(MobileScanner), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('declining a scanned code lands on the field and stays there', (
      tester,
    ) async {
      setUpMobileScanner();

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      void scan() {
        tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
          BarcodeCapture(barcodes: [Barcode(rawValue: validBase64)]),
        );
      }

      scan();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('bundle_import_discard')), findsOneWidget);

      await tester.tap(find.byKey(const Key('bundle_import_discard')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // "Enter a different pairing code" has to land on a field. It used to
      // return to the viewfinder, contradicting its own label.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(MobileScanner), findsNothing);

      // And the rejected code must not come back. The QR is still on the
      // other device's screen, so before this the very next frame re-decoded
      // it and bounced the user into the confirmation they just refused. It
      // says so rather than going quietly inert.
      await tester.tap(find.byKey(const Key('bundle_import_scan_instead')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      scan();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final context = tester.element(find.byType(BundleImportWidget));
      expect(find.byKey(const Key('bundle_import_discard')), findsNothing);
      expect(find.byType(MobileScanner), findsOneWidget);
      expect(
        find.text(context.messages.syncPairScannerRejected),
        findsOneWidget,
      );
    });

    testWidgets(
      'handles barcode detection: valid bundle shows summary and hides scanner',
      (tester) async {
        setUpMobileScanner();

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
            overrides: defaultOverrides(),
          ),
        );
        await tester.pump();

        expect(find.byType(MobileScanner), findsOneWidget);

        // Simulate a barcode being scanned by calling onDetect directly
        final scanner = tester.widget<MobileScanner>(
          find.byType(MobileScanner),
        );
        scanner.onDetect!(
          BarcodeCapture(
            barcodes: [Barcode(rawValue: validBase64)],
          ),
        );
        // Process the setState rebuild, then advance past the 220 ms
        // AnimatedSwitcher transition so the old child is fully removed.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        // Scanner should be hidden and summary card should appear
        expect(find.byType(MobileScanner), findsNothing);
        expect(find.text('matrix.example.com'), findsOneWidget);
        expect(find.text('@alice:example.com'), findsOneWidget);
      },
    );

    testWidgets(
      'ignores duplicate barcode scan — second identical code does not re-decode',
      (tester) async {
        setUpMobileScanner();

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
            overrides: defaultOverrides(),
          ),
        );
        await tester.pump();

        expect(find.byType(MobileScanner), findsOneWidget);

        final scanner = tester.widget<MobileScanner>(
          find.byType(MobileScanner),
        );

        // First scan — invalid bundle triggers error
        const invalidCode = 'not-a-valid-bundle';
        scanner.onDetect!(
          const BarcodeCapture(barcodes: [Barcode(rawValue: invalidCode)]),
        );
        await tester.pump();

        // Error is shown beside the viewfinder; the camera stays up because
        // the bundle was invalid and the user should just scan again.
        final errorFinder = find.byKey(const Key('bundle_import_scan_error'));
        expect(errorFinder, findsOneWidget);
        expect(find.byType(MobileScanner), findsOneWidget);
        final errorBefore = tester.widget<Text>(errorFinder).data;

        // Second scan with the same code — deduplication prevents re-decode.
        scanner.onDetect!(
          const BarcodeCapture(barcodes: [Barcode(rawValue: invalidCode)]),
        );
        await tester.pump();

        expect(tester.widget<Text>(errorFinder).data, errorBefore);
      },
    );

    testWidgets('ignores barcode capture with null or empty rawValue', (
      tester,
    ) async {
      setUpMobileScanner();

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));

      // Null rawValue — should be ignored
      scanner.onDetect!(const BarcodeCapture(barcodes: [Barcode()]));
      await tester.pump();

      // Empty rawValue — should also be ignored
      scanner.onDetect!(
        const BarcodeCapture(barcodes: [Barcode(rawValue: '')]),
      );
      await tester.pump();

      // Neither triggered a decode, so the camera is still up and no bundle
      // summary appeared.
      expect(find.byType(MobileScanner), findsOneWidget);
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
            BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
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
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
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

/// A camera that refuses to start, standing in for a device where the platform
/// rejects the request outright.
class _FailingStartScanner extends FakeMethodChannelMobileScanner {
  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    throw const FormatException('camera refused');
  }
}

/// A camera whose start hangs until released, so a test can tear the page down
/// while initialisation is still in flight.
class _GatedStartScanner extends FakeMethodChannelMobileScanner {
  final Completer<void> gate = Completer<void>();

  /// Whether the page ever asked for the camera. Without this the test would
  /// pass just as happily if startup never began at all.
  bool started = false;

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    started = true;
    await gate.future;
    return super.start(startOptions);
  }
}
