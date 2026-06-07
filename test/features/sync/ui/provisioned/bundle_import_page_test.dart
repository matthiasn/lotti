import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_scanner/src/method_channel/mobile_scanner_method_channel.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Fake MobileScannerPlatform used to prevent platform channel crashes when
// the MobileScanner widget is mounted in tests.
// ---------------------------------------------------------------------------
class _FakeMethodChannelMobileScanner extends MethodChannelMobileScanner {
  final _barcodesController = StreamController<BarcodeCapture?>.broadcast();
  final _torchController = StreamController<TorchState>.broadcast();
  final _zoomController = StreamController<double>.broadcast();

  Stream<BarcodeCapture?> get testBarcodesStream => _barcodesController.stream;

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodesController.stream;

  @override
  Stream<TorchState> get torchStateStream => _torchController.stream;

  @override
  Stream<double> get zoomScaleStateStream => _zoomController.stream;

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(640, 480),
      numberOfCameras: 1,
    );
  }

  @override
  Future<void> stop({bool force = false}) async {}

  @override
  Widget buildCameraView() {
    return const Placeholder(
      fallbackHeight: 100,
      fallbackWidth: 100,
      color: Color(0xFF00AA00),
    );
  }

  Future<void> disposeControllers() async {
    await _barcodesController.close();
    await _torchController.close();
    await _zoomController.close();
  }
}

/// Pins the platform flags to mobile and installs a fresh fake scanner
/// platform, registering all restores/teardowns — the shared preamble of
/// every scan-flow test.
void setUpMobileScanner() {
  final wasDesktop = isDesktop;
  final wasMobile = isMobile;
  isDesktop = false;
  isMobile = true;
  addTearDown(() {
    isDesktop = wasDesktop;
    isMobile = wasMobile;
  });

  final fakePlatform = _FakeMethodChannelMobileScanner();
  MobileScannerPlatform.instance = fakePlatform;
  addTearDown(fakePlatform.disposeControllers);
}

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

  group('BundleImportWidget', () {
    testWidgets('renders text field and import button', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(BundleImportWidget));
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text(context.messages.provisionedSyncImportButton),
        findsOneWidget,
      );
    });

    testWidgets('shows summary card after valid Base64 paste', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      // Enter valid Base64
      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap import button
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(find.text(context.messages.provisionedSyncImportButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify summary card is shown
      expect(find.text('https://matrix.example.com'), findsOneWidget);
      expect(find.text('@alice:example.com'), findsOneWidget);
      expect(find.text('!room123:example.com'), findsOneWidget);

      // Verify configure button is shown
      expect(
        find.text(context.messages.provisionedSyncConfigureButton),
        findsOneWidget,
      );
    });

    testWidgets('shows error for invalid Base64 paste', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      // Enter invalid Base64
      await tester.enterText(
        find.byType(TextField),
        'definitely-not-valid-json-in-base64',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap import button
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(find.text(context.messages.provisionedSyncImportButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should not show summary card
      expect(find.text('@alice:example.com'), findsNothing);
    });

    testWidgets('configure button navigates to page 1 and triggers config', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      // Enter valid Base64 and import
      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(find.text(context.messages.provisionedSyncImportButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap configure button
      await tester.tap(
        find.text(context.messages.provisionedSyncConfigureButton),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(pageIndexNotifier.value, 1);

      // Verify configureFromBundle was triggered
      verify(() => mockMatrixService.setConfig(any())).called(1);
      verify(() => mockMatrixService.login(waitForLifecycle: false)).called(1);
    });

    testWidgets('displays error text in TextField for invalid JSON', (
      tester,
    ) async {
      final invalidJsonBase64 = base64UrlEncode(utf8.encode('not json'));

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      // Enter invalid Base64 that decodes to non-JSON
      await tester.enterText(find.byType(TextField), invalidJsonBase64);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap import button
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(find.text(context.messages.provisionedSyncImportButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show error text in the TextField decoration
      // The error comes from FormatException when JSON parsing fails
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.errorText, isNotNull);
    });

    testWidgets('clears error text when text field changes', (tester) async {
      final invalidJsonBase64 = base64UrlEncode(utf8.encode('not json'));

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      // Enter invalid data and import to trigger error
      await tester.enterText(find.byType(TextField), invalidJsonBase64);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(find.text(context.messages.provisionedSyncImportButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify error is shown
      var textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.errorText, isNotNull);

      // Now type something new to clear the error
      await tester.enterText(find.byType(TextField), 'new text');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Error should be cleared
      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.errorText, isNull);
    });

    testWidgets('import button is disabled when text field is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      // With empty text field, the import button's onPressed should be null
      final context = tester.element(find.byType(BundleImportWidget));
      final importButton = tester.widget<LottiPrimaryButton>(
        find.widgetWithText(
          LottiPrimaryButton,
          context.messages.provisionedSyncImportButton,
        ),
      );
      expect(importButton.onPressed, isNull);
    });

    testWidgets('import button becomes enabled after entering text', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      // Enter some text
      await tester.enterText(find.byType(TextField), 'some-text');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Button should now be enabled (onPressed != null)
      final context = tester.element(find.byType(BundleImportWidget));
      final importButton = tester.widget<LottiPrimaryButton>(
        find.widgetWithText(
          LottiPrimaryButton,
          context.messages.provisionedSyncImportButton,
        ),
      );
      expect(importButton.onPressed, isNotNull);
    });

    testWidgets('summary card shows homeserver label', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      // Enter valid Base64 and import
      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(find.text(context.messages.provisionedSyncImportButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify all summary labels are shown
      expect(
        find.text(context.messages.provisionedSyncSummaryHomeserver),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.provisionedSyncSummaryUser),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.provisionedSyncSummaryRoom),
        findsOneWidget,
      );
    });
  });

  group('desktop paste button', () {
    testWidgets('paste button appears on desktop', (tester) async {
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

      final context = tester.element(find.byType(BundleImportWidget));
      expect(
        find.text(context.messages.provisionedSyncPasteClipboard),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.content_paste), findsOneWidget);
    });

    testWidgets('paste button imports from clipboard', (tester) async {
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
            return <String, dynamic>{'text': validBase64};
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
      await tester.pump(const Duration(milliseconds: 300));

      // Should show the decoded bundle summary
      expect(find.text('https://matrix.example.com'), findsOneWidget);
      expect(find.text('@alice:example.com'), findsOneWidget);
    });
  });

  group('mobile scanner', () {
    testWidgets('shows scan button on mobile', (tester) async {
      final wasDesktop = isDesktop;
      final wasMobile = isMobile;
      isDesktop = false;
      isMobile = true;
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

      final context = tester.element(find.byType(BundleImportWidget));
      expect(
        find.text(context.messages.provisionedSyncScanButton),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    });

    testWidgets('hides scan button on desktop', (tester) async {
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
      'shows scan button and scanner on mobile, hides on second tap',
      (tester) async {
        setUpMobileScanner();

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
            overrides: defaultOverrides(),
          ),
        );
        await tester.pump();

        final context = tester.element(find.byType(BundleImportWidget));

        // Tap scan button — scanner should appear
        final scanButtonFinder = find.text(
          context.messages.provisionedSyncScanButton,
        );
        await tester.ensureVisible(scanButtonFinder);
        await tester.tap(scanButtonFinder);
        await tester.pump();

        expect(find.byType(MobileScanner), findsOneWidget);

        // Tap scan button again — scanner should disappear
        await tester.ensureVisible(scanButtonFinder);
        await tester.tap(scanButtonFinder);
        await tester.pump();

        expect(find.byType(MobileScanner), findsNothing);
      },
    );
  });

  group('mobile scanner barcode handling', () {
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

        final context = tester.element(find.byType(BundleImportWidget));

        // Show the scanner
        final scanButtonFinder = find.text(
          context.messages.provisionedSyncScanButton,
        );
        await tester.ensureVisible(scanButtonFinder);
        await tester.tap(scanButtonFinder);
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
        expect(find.text('https://matrix.example.com'), findsOneWidget);
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

        final context = tester.element(find.byType(BundleImportWidget));

        // Show the scanner
        final scanButtonFinder = find.text(
          context.messages.provisionedSyncScanButton,
        );
        await tester.ensureVisible(scanButtonFinder);
        await tester.tap(scanButtonFinder);
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

        // Error is shown; scanner still visible because bundle was invalid
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.decoration?.errorText, isNotNull);

        // Second scan with same code — deduplication prevents re-decode
        // We verify the error text did NOT change (no second setState call)
        final errorTextBefore = textField.decoration?.errorText;
        scanner.onDetect!(
          const BarcodeCapture(barcodes: [Barcode(rawValue: invalidCode)]),
        );
        await tester.pump();

        final textFieldAfter = tester.widget<TextField>(find.byType(TextField));
        expect(textFieldAfter.decoration?.errorText, errorTextBefore);
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

      final context = tester.element(find.byType(BundleImportWidget));

      // Show scanner
      final scanButtonFinder = find.text(
        context.messages.provisionedSyncScanButton,
      );
      await tester.ensureVisible(scanButtonFinder);
      await tester.tap(scanButtonFinder);
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

      // Neither triggered a decode, so the input form is still shown
      expect(find.byType(TextField), findsOneWidget);
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
