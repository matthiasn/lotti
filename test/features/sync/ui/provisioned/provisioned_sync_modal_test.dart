import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_sync_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
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

    when(() => mockMatrixService.isLoggedIn()).thenReturn(false);
    when(() => mockMatrixService.syncRoomId).thenReturn(null);
    when(() => mockMatrixService.client).thenReturn(mockClient);
    when(() => mockClient.userID).thenReturn(null);
  });

  group('ProvisionedSyncSettingsCard', () {
    testWidgets('displays correct title and subtitle', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedSyncSettingsCard(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      final context = tester.element(find.byType(ProvisionedSyncSettingsCard));
      expect(
        find.text(context.messages.provisionedSyncTitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.provisionedSyncSubtitle),
        findsOneWidget,
      );
    });

    testWidgets('displays QR code scanner icon', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedSyncSettingsCard(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      expect(find.byIcon(Icons.qr_code_scanner), findsWidgets);
    });

    testWidgets('card is tappable', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedSyncSettingsCard(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      final card = find.byType(ProvisionedSyncSettingsCard);
      expect(card, findsOneWidget);

      expect(
        find.descendant(
          of: card,
          matching: find.byType(GestureDetector),
        ),
        findsWidgets,
      );
    });

    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedSyncSettingsCard(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      expect(find.byType(ProvisionedSyncSettingsCard), findsOneWidget);
    });

    group('smart page detection', () {
      testWidgets(
        'opens modal at import page when not logged in',
        (tester) async {
          when(() => mockMatrixService.isLoggedIn()).thenReturn(false);
          when(() => mockMatrixService.syncRoomId).thenReturn(null);

          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              const ProvisionedSyncSettingsCard(),
              overrides: [
                matrixServiceProvider.overrideWithValue(mockMatrixService),
              ],
            ),
          );

          // Tap the card to open the modal
          await tester.tap(find.byType(ProvisionedSyncSettingsCard));
          await tester.pumpAndSettle();

          // Should show page 0 (import page) content
          final context =
              tester.element(find.byType(ProvisionedSyncSettingsCard));
          expect(
            find.text(context.messages.provisionedSyncImportTitle),
            findsWidgets,
          );
        },
      );

      testWidgets(
        'opens modal at status page when logged in with room',
        (tester) async {
          when(() => mockMatrixService.isLoggedIn()).thenReturn(true);
          when(() => mockMatrixService.syncRoomId)
              .thenReturn('!room123:example.com');
          when(() => mockClient.userID).thenReturn('@alice:example.com');

          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              const ProvisionedSyncSettingsCard(),
              overrides: [
                matrixServiceProvider.overrideWithValue(mockMatrixService),
              ],
            ),
          );

          // Tap the card to open the modal
          await tester.tap(find.byType(ProvisionedSyncSettingsCard));
          await tester.pumpAndSettle();

          // Should show page 2 (status page) content with user ID and room ID
          expect(find.text('@alice:example.com'), findsOneWidget);
          expect(find.text('!room123:example.com'), findsOneWidget);
        },
      );

      testWidgets(
        'opens at import page when logged in but no room',
        (tester) async {
          when(() => mockMatrixService.isLoggedIn()).thenReturn(true);
          when(() => mockMatrixService.syncRoomId).thenReturn(null);

          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              const ProvisionedSyncSettingsCard(),
              overrides: [
                matrixServiceProvider.overrideWithValue(mockMatrixService),
              ],
            ),
          );

          // Tap the card to open the modal
          await tester.tap(find.byType(ProvisionedSyncSettingsCard));
          await tester.pumpAndSettle();

          // Should show page 0 (import page)
          final context =
              tester.element(find.byType(ProvisionedSyncSettingsCard));
          expect(
            find.text(context.messages.provisionedSyncImportTitle),
            findsWidgets,
          );
        },
      );

      testWidgets(
        'opens at import page when not logged in but has room',
        (tester) async {
          when(() => mockMatrixService.isLoggedIn()).thenReturn(false);
          when(() => mockMatrixService.syncRoomId)
              .thenReturn('!room123:example.com');

          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              const ProvisionedSyncSettingsCard(),
              overrides: [
                matrixServiceProvider.overrideWithValue(mockMatrixService),
              ],
            ),
          );

          // Tap the card to open the modal
          await tester.tap(find.byType(ProvisionedSyncSettingsCard));
          await tester.pumpAndSettle();

          // Should show page 0 (import page) - needs both conditions
          final context =
              tester.element(find.byType(ProvisionedSyncSettingsCard));
          expect(
            find.text(context.messages.provisionedSyncImportTitle),
            findsWidgets,
          );
        },
      );
    });
  });
}
