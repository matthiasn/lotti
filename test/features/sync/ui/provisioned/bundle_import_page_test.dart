import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/sync/models/pairing_check_code.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/platform.dart';
import 'package:mocktail/mocktail.dart';

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

        final context = tester.element(find.byType(BundleImportWidget));
        expect(
          find.text(context.messages.syncPairCopyCodeHint),
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

    testWidgets('names the step before a code has been read', (tester) async {
      await pumpImport(tester);

      final context = tester.element(find.byType(BundleImportWidget));
      expect(
        find.text(context.messages.syncPairStepScan),
        findsOneWidget,
      );
      expect(find.text(context.messages.syncPairStepConfirm), findsNothing);
    });

    testWidgets('advances the step once a code is decoded', (tester) async {
      await pumpImport(tester);

      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pump();
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(
        find.text(context.messages.provisionedSyncImportButton),
      );
      await tester.pumpAndSettle();

      expect(find.text(context.messages.syncPairStepConfirm), findsOneWidget);
      expect(find.text(context.messages.syncPairStepScan), findsNothing);
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
      expect(discard.variant, DesignSystemButtonVariant.outlined);
    });
  });
}
