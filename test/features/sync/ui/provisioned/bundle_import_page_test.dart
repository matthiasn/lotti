import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/sync/models/pairing_check_code.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/features/sync/ui/widgets/sync_wizard_progress_track.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/platform.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

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
    registerAllFallbackValues();
    // Not part of the shared inventory: a real instance of a config class
    // only sync tests stub with `any()`.
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
    testWidgets('leads with a live paste action while the field is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(BundleImportWidget));
      expect(find.byType(TextField), findsOneWidget);

      // A disabled full-width slab used to sit here, above the only live
      // control, so the secondary action read as the primary.
      expect(
        find.text(context.messages.provisionedSyncImportButton),
        findsNothing,
      );
      final paste = tester.widget<DesignSystemButton>(
        find.widgetWithText(
          DesignSystemButton,
          context.messages.provisionedSyncPasteClipboard,
        ),
      );
      expect(paste.onPressed, isNotNull);
    });

    testWidgets('promotes the commit action but keeps paste reachable', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pump();

      final context = tester.element(find.byType(BundleImportWidget));
      final commit = tester.widget<DesignSystemButton>(
        find.widgetWithText(
          DesignSystemButton,
          context.messages.provisionedSyncImportButton,
        ),
      );
      expect(commit.onPressed, isNotNull);
      expect(commit.fullWidth, isTrue);

      // Paste stays available, demoted. The malformed-code error tells the
      // user to copy the code again on the other device, and this was the
      // control that disappeared exactly then — leaving a bad payload in the
      // field with no way to overwrite it short of select-all on a phone.
      final paste = tester.widget<DesignSystemButton>(
        find.byKey(const Key('bundle_import_paste_again')),
      );
      expect(paste.label, context.messages.provisionedSyncPasteClipboard);
      expect(paste.variant, DesignSystemButtonVariant.outlined);
      expect(paste.fullWidth, isFalse);
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
      expect(find.text('matrix.example.com'), findsOneWidget);
      expect(find.text('@alice:example.com'), findsOneWidget);
      // The opaque room id no longer competes with the checkable facts.
      expect(find.text('!room123:example.com'), findsNothing);

      // Verify configure button is shown
      expect(
        find.text(context.messages.syncPairConnectButton),
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
        find.text(context.messages.syncPairConnectButton),
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

      // The error comes from the FormatException when JSON parsing fails.
      expect(
        find.text(context.messages.syncPairErrorMalformed),
        findsOneWidget,
      );
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
      expect(
        find.text(context.messages.syncPairErrorMalformed),
        findsOneWidget,
      );

      // Now type something new to clear the error
      await tester.enterText(find.byType(TextField), 'new text');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(context.messages.syncPairErrorMalformed),
        findsNothing,
      );
    });

    testWidgets('a wrong code can be discarded instead of connected', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pump();
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(
        find.text(context.messages.provisionedSyncImportButton),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('@alice:example.com'), findsOneWidget);

      // Confirming something you cannot reject is not a confirmation: before
      // this, a stale or wrong code could only be escaped by dismissing the
      // whole modal.
      await tester.tap(find.byKey(const Key('bundle_import_discard')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('@alice:example.com'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
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
      final importButton = tester.widget<DesignSystemButton>(
        find.widgetWithText(
          DesignSystemButton,
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
      // The room id is an opaque handle nobody can verify by eye; it moved to
      // the diagnostics dump so the card carries only checkable facts.
      expect(find.text('!room123:example.com'), findsNothing);
      expect(
        find.byKey(const Key('bundle_import_check_code')),
        findsOneWidget,
      );
    });

    testWidgets('the context rows survive a large text scale intact', (
      tester,
    ) async {
      // The account and server are the values this screen exists to let the
      // user review. A fixed label + right-aligned value row squeezed the
      // identifier into a sliver (or overflowed) once a long localized
      // label met an accessibility text scale; the pair must stack instead.
      // French, because "Compte de synchronisation" at double scale is what
      // actually exceeded a phone-width sheet.
      tester.view
        ..physicalSize = const Size(390, 2400)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            // Scrollable because the production sheet scrolls; the test
            // scaffold's fixed height is not the surface under test — the
            // horizontal fit of the context rows is.
            child: SingleChildScrollView(
              child: BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
            ),
          ),
          overrides: defaultOverrides(),
          locale: const Locale('fr'),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final context = tester.element(find.byType(BundleImportWidget));
      final importButton = find.text(
        context.messages.provisionedSyncImportButton,
      );
      await tester.ensureVisible(importButton);
      await tester.tap(importButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull, reason: 'no overflow');
      // The identifier is intact, not ellipsized into uncheckability.
      expect(find.text('@alice:example.com'), findsOneWidget);
    });

    testWidgets('the check code matches what the other device derives', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pump();
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(
        find.text(context.messages.provisionedSyncImportButton),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final code = tester.widget<Text>(
        find.byKey(const Key('bundle_import_check_code')),
      );
      // Both devices derive it from account + room, so it is the one value on
      // this screen a person can actually compare.
      expect(
        code.data,
        pairingCheckCode(
          user: '@alice:example.com',
          roomId: '!room123:example.com',
          homeServer: 'https://matrix.example.com',
        ),
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
      expect(find.text('matrix.example.com'), findsOneWidget);
      expect(find.text('@alice:example.com'), findsOneWidget);
    });

    /// Runs [body] with the platform flags forced to desktop — the only
    /// configuration where paste is the single live control on the screen.
    Future<void> onDesktop(Future<void> Function() body) async {
      final wasDesktop = isDesktop;
      final wasMobile = isMobile;
      isDesktop = true;
      isMobile = false;
      try {
        await body();
      } finally {
        isDesktop = wasDesktop;
        isMobile = wasMobile;
      }
    }

    Future<void> pumpWithClipboard(
      WidgetTester tester,
      Future<Object?> Function(MethodCall) handler,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        handler,
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
    }

    testWidgets('an empty clipboard says so instead of doing nothing', (
      tester,
    ) async {
      await onDesktop(() async {
        await pumpWithClipboard(tester, (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': ''};
          }
          return null;
        });

        final context = tester.element(find.byType(BundleImportWidget));
        expect(
          find.text(context.messages.syncPairClipboardEmpty),
          findsOneWidget,
        );
      });
    });

    testWidgets('an unreadable clipboard names the fallback', (tester) async {
      await onDesktop(() async {
        await pumpWithClipboard(tester, (call) async {
          if (call.method == 'Clipboard.getData') {
            throw PlatformException(code: 'unavailable');
          }
          return null;
        });

        final context = tester.element(find.byType(BundleImportWidget));
        expect(
          find.text(context.messages.syncPairClipboardUnavailable),
          findsOneWidget,
        );
      });
    });

    testWidgets('says how the code reaches a machine with no camera', (
      tester,
    ) async {
      await onDesktop(() async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
            overrides: defaultOverrides(),
          ),
        );
        await tester.pump();

        // One line, not two paragraphs: the where-to-find hint carries both
        // where the code appears and how it moves here.
        final context = tester.element(find.byType(BundleImportWidget));
        expect(
          find.text(context.messages.syncPairWhereToFind),
          findsOneWidget,
        );
      });
    });

    testWidgets('offers the honest first-device branch', (tester) async {
      // A from-scratch user has no device that syncs: without this block the
      // screen's instructions cannot be followed and the flow dead-ends in
      // silence.
      await onDesktop(() async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
            overrides: defaultOverrides(),
          ),
        );
        await tester.pump();

        final context = tester.element(find.byType(BundleImportWidget));
        expect(
          find.byKey(const Key('bundle_import_first_device_hint')),
          findsOneWidget,
        );
        expect(
          find.text(context.messages.syncPairFirstDeviceTitle),
          findsOneWidget,
        );
      });
    });
  });

  group('decode errors name a remedy', () {
    Future<void> pumpAndEnter(WidgetTester tester, String code) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), code);
      await tester.pump();
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(
        find.text(context.messages.provisionedSyncImportButton),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    }

    testWidgets('a code from another Lotti version says to update', (
      tester,
    ) async {
      // The code is fine and the two apps disagree — "invalid code" would send
      // the user hunting for a new one that fails identically.
      const oldVersion =
          'eyJ2IjogMSwgImtpbmQiOiAiaGFuZG92ZXIiLCAiaG9tZVNlcnZlciI6ICJodHRwc'
          'zovL21hdHJpeC5leGFtcGxlLmNvbSIsICJ1c2VyIjogIkBhbGljZTpleGFtcGxlLm'
          'NvbSIsICJwYXNzd29yZCI6ICJwIiwgInJvb21JZCI6ICIhcjpleGFtcGxlLmNvbSJ9';
      await pumpAndEnter(tester, oldVersion);

      final context = tester.element(find.byType(BundleImportWidget));
      expect(
        find.text(context.messages.syncPairErrorVersion),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.syncPairErrorMalformed),
        findsNothing,
      );
    });

    testWidgets('a code that fails validation says to copy it again', (
      tester,
    ) async {
      // Decodes cleanly but carries a malformed MXID, so it reaches the
      // typed `malformedPayload` branch rather than the raw FormatException
      // fallback that unparseable input takes.
      const badMxid =
          'eyJ2IjogMiwgImtpbmQiOiAiaGFuZG92ZXIiLCAiaG9tZVNlcnZlciI6ICJodHRwc'
          'zovL21hdHJpeC5leGFtcGxlLmNvbSIsICJ1c2VyIjogImFsaWNlOmV4YW1wbGUuY2'
          '9tIiwgInBhc3N3b3JkIjogInAiLCAicm9vbUlkIjogIiFyOmV4YW1wbGUuY29tIn0';
      await pumpAndEnter(tester, badMxid);

      final context = tester.element(find.byType(BundleImportWidget));
      expect(
        find.text(context.messages.syncPairErrorMalformed),
        findsOneWidget,
      );
      expect(find.text(context.messages.syncPairErrorVersion), findsNothing);
    });

    testWidgets('unparseable input falls back to the same guidance', (
      tester,
    ) async {
      // Invalid Base64 throws a raw FormatException out of `base64Decode`,
      // which `decodeBundle` rethrows untyped — a separate branch that has to
      // land on the same message rather than a bare "invalid code".
      await pumpAndEnter(tester, 'not-a-bundle');

      final context = tester.element(find.byType(BundleImportWidget));
      expect(
        find.text(context.messages.syncPairErrorMalformed),
        findsOneWidget,
      );
    });
  });

  group('wayfinding and step scent', () {
    Future<void> pumpImport(WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pump();
    }

    testWidgets('the track marks Get code before a code has been read', (
      tester,
    ) async {
      await pumpImport(tester);

      final track = tester.widget<SyncWizardProgressTrack>(
        find.byType(SyncWizardProgressTrack),
      );
      expect(track.active, SyncWizardStep.getCode);
      // All three stations stay visible — the track is the wayfinding.
      final context = tester.element(find.byType(BundleImportWidget));
      expect(find.text(context.messages.syncWizardStepGetCode), findsOneWidget);
      expect(find.text(context.messages.syncWizardStepCheck), findsOneWidget);
      expect(
        find.text(context.messages.syncWizardStepConnect),
        findsOneWidget,
      );
    });

    testWidgets('advances the track once a code is decoded', (tester) async {
      await pumpImport(tester);

      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pump();
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(
        find.text(context.messages.provisionedSyncImportButton),
      );
      await tester.pumpAndSettle();

      final track = tester.widget<SyncWizardProgressTrack>(
        find.byType(SyncWizardProgressTrack),
      );
      expect(track.active, SyncWizardStep.check);
    });

    testWidgets('warns which codes are safe to accept', (tester) async {
      // The mirror of the inviting device's warning: scanning someone else's
      // code joins this device, and everything on it, to their account.
      await pumpImport(tester);

      final context = tester.element(find.byType(BundleImportWidget));
      expect(
        find.byKey(const Key('sync_pair_only_own_code')),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.syncPairOnlyOwnCode),
        findsOneWidget,
      );
    });

    testWidgets('the confirm screen leads with the comparison, not a receipt', (
      tester,
    ) async {
      await pumpImport(tester);

      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pump();
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(
        find.text(context.messages.provisionedSyncImportButton),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('bundle_import_compare_heading')),
        findsOneWidget,
      );
      // Naming the consequence is what turns a comparison into a decision.
      expect(
        find.text(context.messages.syncPairMismatchWarning),
        findsOneWidget,
      );
      // The reject branch stays neutral; the accent means "commit" one button
      // above it and cannot also mean "back out".
      final discard = tester.widget<DesignSystemButton>(
        find.byKey(const Key('bundle_import_discard')),
      );
      expect(discard.variant, DesignSystemButtonVariant.secondary);
      // The comparison question sits with the code itself.
      expect(
        find.text(context.messages.syncPairSameCodeQuestion),
        findsOneWidget,
      );
    });

    testWidgets('the first-device branch carries a real manual button', (
      tester,
    ) async {
      // "See the manual" used to end in prose with nothing to tap — two of
      // five test personas abandoned the flow at exactly that sentence.
      await pumpImport(tester);

      final context = tester.element(find.byType(BundleImportWidget));
      final manual = tester.widget<DesignSystemButton>(
        find.byKey(const Key('bundle_import_open_manual')),
      );
      expect(manual.label, context.messages.syncPairOpenManual);
      expect(manual.onPressed, isNotNull);
    });

    testWidgets('the manual button opens the first-device guide, not the '
        'manual root', (tester) async {
      // A root landing still left the user hunting for the one page that
      // explains where a first code comes from.
      final mockUrlLauncher = MockUrlLauncher();
      final originalInstance = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = mockUrlLauncher;
      addTearDown(() => UrlLauncherPlatform.instance = originalInstance);
      when(
        () => mockUrlLauncher.launchUrl(any(), any()),
      ).thenAnswer((_) async => true);

      await pumpImport(tester);
      await tester.ensureVisible(
        find.byKey(const Key('bundle_import_open_manual')),
      );
      await tester.tap(find.byKey(const Key('bundle_import_open_manual')));
      await tester.pump();

      final url =
          verify(
                () => mockUrlLauncher.launchUrl(captureAny(), any()),
              ).captured.single
              as String;
      expect(url, endsWith('sync-and-data/first-device'));
    });

    test('the viewfinder painter compares its look fields for a new '
        'delegate', () {
      // The contract the framework consults when a rebuild hands the render
      // object a new painter delegate: repaint when any of the visual
      // fields (color, corner length, corner radius, stroke width, inset)
      // differs from the previous delegate's, and skip the redraw when the
      // two delegates would paint identically.
      ViewfinderBracketsPainter make({
        Color color = const Color(0xFF00FF00),
        double cornerLength = 24,
        double cornerRadius = 12,
        double strokeWidth = 2,
        double inset = 16,
      }) => ViewfinderBracketsPainter(
        color: color,
        cornerLength: cornerLength,
        cornerRadius: cornerRadius,
        strokeWidth: strokeWidth,
        inset: inset,
      );

      expect(make().shouldRepaint(make()), isFalse);
      expect(
        make(color: const Color(0xFFFF0000)).shouldRepaint(make()),
        isTrue,
      );
      expect(make(cornerLength: 32).shouldRepaint(make()), isTrue);
      expect(make(cornerRadius: 8).shouldRepaint(make()), isTrue);
      expect(make(strokeWidth: 3).shouldRepaint(make()), isTrue);
      expect(make(inset: 20).shouldRepaint(make()), isTrue);
    });

    testWidgets('a provisioning reset clears the stale decoded bundle', (
      tester,
    ) async {
      // "Enter a new code" on the failed connect screen resets the
      // controller and lands back here; without the listener the page still
      // showed the code the user is trying to replace.
      await pumpImport(tester);

      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pump();
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(
        find.text(context.messages.provisionedSyncImportButton),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(context.messages.syncPairConnectButton));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BundleImportWidget)),
      );
      container.read(provisioningControllerProvider.notifier).reset();
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.byKey(const Key('bundle_import_check_code')),
        findsNothing,
      );
    });
  });
}
