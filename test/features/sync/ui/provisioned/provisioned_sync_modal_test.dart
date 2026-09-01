import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart'
    hide isLinux, isMacOS, isWindows;
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/features/sync/ui/provisioned/manual_credentials_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_sync_modal.dart';
import 'package:lotti/features/sync/ui/widgets/sync_device_pair_motif.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/platform.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late MockMatrixClient mockClient;

  setUp(() {
    scannerPreviewOverride = (context, side) => const SizedBox.shrink();
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

  tearDown(() => scannerPreviewOverride = null);

  /// Pins the platform flags for one test and restores them afterwards.
  void pinPlatform({required bool linux}) {
    final wasDesktop = isDesktop;
    final wasMobile = isMobile;
    final wasWindows = isWindows;
    final wasLinux = isLinux;
    final wasMacOS = isMacOS;
    isDesktop = true;
    isMobile = false;
    isWindows = !linux;
    isLinux = linux;
    isMacOS = false;
    addTearDown(() {
      isDesktop = wasDesktop;
      isMobile = wasMobile;
      isWindows = wasWindows;
      isLinux = wasLinux;
      isMacOS = wasMacOS;
    });
  }

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
      // The two-device motif anchors the pane — the same figure the connect
      // step and the verified celebration carry — with its gap still open.
      final motif = tester.widget<SyncDevicePairMotif>(
        find.byType(SyncDevicePairMotif),
      );
      expect(motif.state, SyncDevicePairMotifState.idle);
      // And the quiet trust line closes the pitch.
      expect(
        find.text(context.messages.syncSetupEmptyFootnote),
        findsOneWidget,
      );
    });

    group('account sign-in entry (Linux only)', () {
      testWidgets('is absent off Linux', (tester) async {
        pinPlatform(linux: false);

        await pumpEmptyState(tester);

        expect(find.byKey(const Key('sync_setup_use_account')), findsNothing);
      });

      testWidgets('opens the sheet on the credentials page on Linux', (
        tester,
      ) async {
        pinPlatform(linux: true);

        await pumpEmptyState(tester);
        final context = tester.element(find.byType(SyncSetupEmptyState));
        expect(
          find.text(context.messages.syncSetupUseAccountLink),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('sync_setup_use_account')));
        await tester.pumpAndSettle();

        // Straight to the form — not the pairing-code page with one more
        // tap to find.
        expect(find.byType(ManualCredentialsWidget), findsOneWidget);
        expect(find.byType(BundleImportWidget), findsNothing);
        expect(
          find.text(context.messages.syncCredentialsTitle),
          findsOneWidget,
        );
      });

      testWidgets('the pairing-code page can hand over to the form on Linux', (
        tester,
      ) async {
        pinPlatform(linux: true);

        await pumpEmptyState(tester);
        await tester.tap(find.byKey(const Key('sync_setup_cta')));
        await tester.pumpAndSettle();
        expect(find.byType(BundleImportWidget), findsOneWidget);

        final signIn = find.byKey(const Key('bundle_import_sign_in_account'));
        await tester.ensureVisible(signIn);
        await tester.pump();
        await tester.tap(signIn, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.byType(ManualCredentialsWidget), findsOneWidget);

        // And back again: the form's own link returns to the code page.
        final useCode = find.byKey(const Key('sync_credentials_use_code'));
        await tester.ensureVisible(useCode);
        await tester.pump();
        await tester.tap(useCode, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(BundleImportWidget), findsOneWidget);
      });

      testWidgets('the pairing-code page has no hand-over off Linux', (
        tester,
      ) async {
        pinPlatform(linux: false);

        await pumpEmptyState(tester);
        await tester.tap(find.byKey(const Key('sync_setup_cta')));
        await tester.pumpAndSettle();

        expect(find.byType(BundleImportWidget), findsOneWidget);
        expect(
          find.byKey(const Key('bundle_import_sign_in_account')),
          findsNothing,
        );
      });
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
