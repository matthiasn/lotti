import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/platform.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

class MockClient extends Mock implements Client {}

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

    testWidgets('disconnect does not call deleteConfig when cancelled',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
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

      // Dismiss the dialog by tapping outside (scrim)
      await tester.tapAt(Offset.zero);
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
          ],
        ),
      );
      await tester.pump();

      // SelectableText widgets for the values
      final selectableTexts = find.byType(SelectableText);
      expect(selectableTexts, findsAtLeast(2));
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
      await tester.tap(find.byKey(const Key('statusToggleHandoverVisibility')));
      await tester.pump();

      // Should now show the base64 string and hide icon
      expect(find.text('\u2022' * 24), findsNothing);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('copies handover data to clipboard', (tester) async {
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
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      await tester.tap(find.text(context.messages.provisionedSyncShowQr));
      await tester.pumpAndSettle();

      // Tap the copy button
      await tester.tap(find.byKey(const Key('statusCopyHandoverData')));
      await tester.pumpAndSettle();

      // Verify clipboard has data
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      expect(data?.text, isNotNull);
      expect(data!.text, isNotEmpty);

      // Snackbar should appear
      expect(find.text('Copied to clipboard'), findsOneWidget);
    });
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
