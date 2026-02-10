import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
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

  setUp(() {
    mockMatrixService = MockMatrixService();
    pageIndexNotifier = ValueNotifier(0);
  });

  tearDown(() {
    pageIndexNotifier.dispose();
  });

  group('BundleImportWidget', () {
    testWidgets('renders text field and import button', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
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
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
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
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
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

    testWidgets('configure button navigates to page 1', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
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
    });
  });
}
