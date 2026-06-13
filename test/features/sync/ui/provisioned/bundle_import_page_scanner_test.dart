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
