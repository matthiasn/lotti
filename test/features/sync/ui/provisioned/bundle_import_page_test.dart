import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late MockLoggingService mockLoggingService;
  late ValueNotifier<int> pageIndexNotifier;

  const testBundle = SyncProvisioningBundle(
    v: 1,
    homeServer: 'https://matrix.example.com',
    user: '@alice:example.com',
    password: 'secret123',
    roomId: '!room123:example.com',
  );

  final validBase64 =
      base64UrlEncode(utf8.encode(jsonEncode(testBundle.toJson())));

  setUpAll(() {
    registerFallbackValue(
      const MatrixConfig(homeServer: '', user: '', password: ''),
    );
  });

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockLoggingService = MockLoggingService();
    pageIndexNotifier = ValueNotifier(0);

    when(() => mockMatrixService.setConfig(any())).thenAnswer((_) async {});
    when(() => mockMatrixService.login()).thenAnswer((_) async => true);
    when(() => mockMatrixService.joinRoom(any()))
        .thenAnswer((_) async => '!room:example.com');
    when(() => mockMatrixService.saveRoom(any())).thenAnswer((_) async {});
    when(
      () => mockMatrixService.changePassword(
        oldPassword: any(named: 'oldPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockMatrixService.loadConfig()).thenAnswer(
      (_) async => const MatrixConfig(
        homeServer: 'https://matrix.example.com',
        user: '@alice:example.com',
        password: 'secret123',
      ),
    );
  });

  tearDown(() {
    pageIndexNotifier.dispose();
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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      // Enter valid Base64
      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pumpAndSettle();

      // Tap import button
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(find.text(context.messages.provisionedSyncImportButton));
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      // Enter invalid Base64
      await tester.enterText(
        find.byType(TextField),
        'definitely-not-valid-json-in-base64',
      );
      await tester.pumpAndSettle();

      // Tap import button
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(find.text(context.messages.provisionedSyncImportButton));
      await tester.pumpAndSettle();

      // Should not show summary card
      expect(find.text('@alice:example.com'), findsNothing);
    });

    testWidgets('configure button navigates to page 1 and triggers config',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter valid Base64 and import
      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(find.text(context.messages.provisionedSyncImportButton));
      await tester.pumpAndSettle();

      // Tap configure button
      await tester.tap(
        find.text(context.messages.provisionedSyncConfigureButton),
      );
      await tester.pumpAndSettle();

      expect(pageIndexNotifier.value, 1);

      // Verify configureFromBundle was triggered
      verify(() => mockMatrixService.setConfig(any())).called(1);
      verify(() => mockMatrixService.login()).called(1);
    });

    testWidgets('displays error text in TextField for invalid JSON',
        (tester) async {
      final invalidJsonBase64 = base64UrlEncode(utf8.encode('not json'));

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter invalid Base64 that decodes to non-JSON
      await tester.enterText(find.byType(TextField), invalidJsonBase64);
      await tester.pumpAndSettle();

      // Tap import button
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(find.text(context.messages.provisionedSyncImportButton));
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      // Enter invalid data and import to trigger error
      await tester.enterText(find.byType(TextField), invalidJsonBase64);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(find.text(context.messages.provisionedSyncImportButton));
      await tester.pumpAndSettle();

      // Verify error is shown
      var textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.errorText, isNotNull);

      // Now type something new to clear the error
      await tester.enterText(find.byType(TextField), 'new text');
      await tester.pumpAndSettle();

      // Error should be cleared
      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.errorText, isNull);
    });

    testWidgets('import button is disabled when text field is empty',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pumpAndSettle();

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

    testWidgets('import button becomes enabled after entering text',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter some text
      await tester.enterText(find.byType(TextField), 'some-text');
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      // Enter valid Base64 and import
      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(find.text(context.messages.provisionedSyncImportButton));
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
    });

    testWidgets('replaces bundle after re-import with different data',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: defaultOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      // Import first bundle
      await tester.enterText(find.byType(TextField), validBase64);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(BundleImportWidget));
      await tester.tap(find.text(context.messages.provisionedSyncImportButton));
      await tester.pumpAndSettle();

      expect(find.text('@alice:example.com'), findsOneWidget);

      // Import second bundle with different user
      const otherBundle = SyncProvisioningBundle(
        v: 1,
        homeServer: 'https://matrix.example.com',
        user: '@bob:example.com',
        password: 'other-secret',
        roomId: '!room456:example.com',
      );
      final otherBase64 =
          base64UrlEncode(utf8.encode(jsonEncode(otherBundle.toJson())));

      await tester.enterText(find.byType(TextField), otherBase64);
      await tester.pumpAndSettle();
      await tester.tap(find.text(context.messages.provisionedSyncImportButton));
      await tester.pumpAndSettle();

      expect(find.text('@bob:example.com'), findsOneWidget);
      expect(find.text('@alice:example.com'), findsNothing);
    });
  });
}
