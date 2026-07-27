import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_sync_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late MockMatrixClient mockClient;

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockClient = MockMatrixClient();

    when(mockMatrixService.isLoggedIn).thenReturn(false);
    when(() => mockMatrixService.syncRoomId).thenReturn(null);
    when(() => mockMatrixService.client).thenReturn(mockClient);
    when(() => mockClient.userID).thenReturn(null);
    when(() => mockMatrixService.loadConfig()).thenAnswer(
      (_) async => const MatrixConfig(
        homeServer: 'https://matrix.example.com',
        user: '@alice:example.com',
        password: 'rotated-pw',
      ),
    );
  });

  Future<void> pumpEmptyState(WidgetTester tester) {
    return tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SyncSetupEmptyState(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );
  }

  group('SyncSetupEmptyState', () {
    testWidgets('explains sync and leads with the one setup action', (
      tester,
    ) async {
      await pumpEmptyState(tester);

      final context = tester.element(find.byType(SyncSetupEmptyState));
      // The value proposition, not an echo of the navigation entry: the old
      // card repeated "Devices" under a header reading "Devices" and said
      // nothing about what sync is.
      expect(
        find.text(context.messages.syncSetupEmptyTitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.syncSetupEmptyHint),
        findsOneWidget,
      );
      expect(find.byKey(const Key('sync_setup_cta')), findsOneWidget);
      // Composes the design system's one empty-state grammar rather than a
      // hand-rolled icon/text ramp.
      expect(find.byType(DesignSystemEmptyState), findsOneWidget);
    });

    group('smart page detection', () {
      testWidgets(
        'opens the wizard at the import page when not logged in',
        (tester) async {
          when(mockMatrixService.isLoggedIn).thenReturn(false);
          when(() => mockMatrixService.syncRoomId).thenReturn(null);

          await pumpEmptyState(tester);

          await tester.tap(find.byKey(const Key('sync_setup_cta')));
          await tester.pumpAndSettle();

          // Should show page 0 (import page) content
          final context = tester.element(find.byType(SyncSetupEmptyState));
          expect(
            find.text(context.messages.provisionedSyncImportTitle),
            findsWidgets,
          );
          expect(find.byType(BundleImportWidget), findsOneWidget);
        },
      );

      testWidgets(
        'opens the devices sheet when logged in with a room',
        (tester) async {
          when(mockMatrixService.isLoggedIn).thenReturn(true);
          when(
            () => mockMatrixService.syncRoomId,
          ).thenReturn('!room123:example.com');
          when(() => mockClient.userID).thenReturn('@alice:example.com');

          await pumpEmptyState(tester);

          await tester.tap(find.byKey(const Key('sync_setup_cta')));
          await tester.pumpAndSettle();

          final context = tester.element(find.byType(SyncSetupEmptyState));

          // Should open directly to status page (no provisioning input page)
          expect(find.text('Technical details'), findsOneWidget);
          // Keyed rather than by text: the roster's refresh action is unique
          // to the status page and renders even while the list is loading.
          expect(find.byKey(const Key('sync_devices_refresh')), findsOneWidget);
          expect(
            find.text(context.messages.settingsMatrixPreviousPage),
            findsNothing,
          );
          expect(find.byType(BundleImportWidget), findsNothing);
        },
      );

      testWidgets(
        'opens at import page when logged in but no room',
        (tester) async {
          when(mockMatrixService.isLoggedIn).thenReturn(true);
          when(() => mockMatrixService.syncRoomId).thenReturn(null);

          await pumpEmptyState(tester);

          await tester.tap(find.byKey(const Key('sync_setup_cta')));
          await tester.pumpAndSettle();

          final context = tester.element(find.byType(SyncSetupEmptyState));
          expect(
            find.text(context.messages.provisionedSyncImportTitle),
            findsWidgets,
          );
        },
      );

      testWidgets(
        'opens at import page when not logged in but has room',
        (tester) async {
          when(mockMatrixService.isLoggedIn).thenReturn(false);
          when(
            () => mockMatrixService.syncRoomId,
          ).thenReturn('!room123:example.com');

          await pumpEmptyState(tester);

          await tester.tap(find.byKey(const Key('sync_setup_cta')));
          await tester.pumpAndSettle();

          // Setup needs both conditions — a room without a session still
          // goes through the import page.
          final context = tester.element(find.byType(SyncSetupEmptyState));
          expect(
            find.text(context.messages.provisionedSyncImportTitle),
            findsWidgets,
          );
        },
      );
    });
  });
}
