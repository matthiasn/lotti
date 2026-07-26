import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/device_card.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

/// A pre-acquired lock so the Verify button's tryAcquire() returns false.
class _PreAcquiredLock extends MatrixVerificationModalLock {
  @override
  bool build() => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 7, 26, 12);

  late MockMatrixService mockMatrixService;
  late MockDeviceKeys mockDeviceKeys;

  SyncDeviceInfo buildDevice({
    String deviceId = 'DEVICE1',
    String? displayName = 'Pixel 7',
    DateTime? lastSeen,
    bool isCurrentDevice = false,
    bool verified = false,
    bool withKeys = true,
  }) => SyncDeviceInfo(
    deviceId: deviceId,
    displayName: displayName,
    lastSeen: lastSeen,
    isCurrentDevice: isCurrentDevice,
    verified: verified,
    keys: withKeys ? mockDeviceKeys : null,
  );

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockDeviceKeys = MockDeviceKeys();

    when(() => mockDeviceKeys.deviceDisplayName).thenReturn('Pixel 7');
    when(() => mockDeviceKeys.deviceId).thenReturn('DEVICE1');
    when(() => mockDeviceKeys.userId).thenReturn('@user:server');
  });

  Future<void> pumpCard(
    WidgetTester tester,
    SyncDeviceInfo device, {
    VoidCallback? refreshListCallback,
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DeviceCard(
          device,
          refreshListCallback: refreshListCallback ?? () {},
          now: now,
        ),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          ...overrides,
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Taps the trash icon and confirms the deletion in the modal that opens.
  Future<void> tapDeleteAndConfirm(WidgetTester tester) async {
    await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
    await tester.pumpAndSettle();

    // The confirm button renders the upper-cased delete label.
    await tester.tap(find.text('DELETE DEVICE'));
    await tester.pumpAndSettle();
  }

  group('deletion', () {
    testWidgets('deletes device after confirmation and shows success '
        'feedback', (tester) async {
      when(
        () => mockMatrixService.deleteDeviceById('DEVICE1'),
      ).thenAnswer((_) async {});

      var refreshed = false;
      await pumpCard(
        tester,
        buildDevice(),
        refreshListCallback: () => refreshed = true,
      );

      await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
      await tester.pumpAndSettle();

      // Nothing is deleted while the confirmation is open.
      verifyNever(() => mockMatrixService.deleteDeviceById(any()));
      expect(
        find.text(
          'Remove Pixel 7 from your sync account? It will be signed out and '
          'will need to be paired again before it can sync.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('DELETE DEVICE'));
      await tester.pumpAndSettle();

      verify(() => mockMatrixService.deleteDeviceById('DEVICE1')).called(1);
      expect(refreshed, isTrue);
      expect(
        find.text('Device Pixel 7 deleted successfully'),
        findsOneWidget,
      );
    });

    testWidgets('cancelling the confirmation leaves the device alone', (
      tester,
    ) async {
      var refreshed = false;
      await pumpCard(
        tester,
        buildDevice(),
        refreshListCallback: () => refreshed = true,
      );

      await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => mockMatrixService.deleteDeviceById(any()));
      expect(refreshed, isFalse);
    });

    testWidgets('shows error feedback when deletion fails', (tester) async {
      when(
        () => mockMatrixService.deleteDeviceById('DEVICE1'),
      ).thenThrow(Exception('boom'));

      var refreshed = false;
      await pumpCard(
        tester,
        buildDevice(),
        refreshListCallback: () => refreshed = true,
      );

      await tapDeleteAndConfirm(tester);

      verify(() => mockMatrixService.deleteDeviceById('DEVICE1')).called(1);
      expect(refreshed, isFalse);
      expect(
        find.text('Failed to delete device: Exception: boom'),
        findsOneWidget,
      );
    });

    testWidgets('explains a rejected password instead of dumping the raw '
        'error', (tester) async {
      when(() => mockMatrixService.deleteDeviceById('DEVICE1')).thenThrow(
        MatrixException.fromJson(
          const {'errcode': 'M_FORBIDDEN', 'error': 'Invalid password'},
        ),
      );

      await pumpCard(tester, buildDevice());
      await tapDeleteAndConfirm(tester);

      expect(
        find.text(
          'The homeserver rejected the stored password, so the device '
          "couldn't be removed. Re-pair this device with a fresh QR code "
          'and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a non-forbidden MatrixException falls back to the generic '
        'error toast', (tester) async {
      when(() => mockMatrixService.deleteDeviceById('DEVICE1')).thenThrow(
        MatrixException.fromJson(
          const {'errcode': 'M_LIMIT_EXCEEDED', 'error': 'Too many requests'},
        ),
      );

      await pumpCard(tester, buildDevice());
      await tapDeleteAndConfirm(tester);

      expect(
        find.text(
          'Failed to delete device: M_LIMIT_EXCEEDED: Too many requests',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the current device offers no delete action', (tester) async {
      await pumpCard(
        tester,
        buildDevice(isCurrentDevice: true, verified: true),
      );

      expect(find.byIcon(MdiIcons.trashCanOutline), findsNothing);
    });
  });

  group('trust state', () {
    testWidgets('the current device is chipped as this device, without a '
        'Verify button', (tester) async {
      await pumpCard(
        tester,
        buildDevice(isCurrentDevice: true, verified: true),
      );

      expect(find.text('This device'), findsOneWidget);
      expect(find.text('Verify'), findsNothing);
    });

    testWidgets('a verified device is chipped Verified without a Verify '
        'button, but keeps the delete action', (tester) async {
      await pumpCard(tester, buildDevice(verified: true));

      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Verify'), findsNothing);
      expect(find.byIcon(MdiIcons.trashCanOutline), findsOneWidget);
    });

    testWidgets('an unverified device with keys gets the Unverified chip and '
        'a Verify button', (tester) async {
      await pumpCard(tester, buildDevice());

      expect(find.text('Unverified'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
    });

    testWidgets('a keyless session cannot be verified, only removed', (
      tester,
    ) async {
      await pumpCard(tester, buildDevice(withKeys: false));

      expect(find.text('Unverified'), findsOneWidget);
      expect(find.text('Verify'), findsNothing);
      expect(find.byIcon(MdiIcons.trashCanOutline), findsOneWidget);
    });
  });

  group('identity and last-seen', () {
    testWidgets('renders the display name', (tester) async {
      await pumpCard(tester, buildDevice());
      expect(find.text('Pixel 7'), findsOneWidget);
    });

    testWidgets('falls back to the device id when the display name is '
        'missing', (tester) async {
      await pumpCard(tester, buildDevice(displayName: null));
      expect(find.text('DEVICE1'), findsOneWidget);
    });

    testWidgets('shows a formatted last-seen date without a stale hint when '
        'recently active', (tester) async {
      await pumpCard(
        tester,
        buildDevice(lastSeen: DateTime(2026, 7, 24)),
      );

      expect(find.text('Last seen Jul 24, 2026'), findsOneWidget);
      expect(find.text('Probably no longer in use'), findsNothing);
    });

    testWidgets('flags a device unseen for more than 30 days as probably '
        'dead', (tester) async {
      await pumpCard(
        tester,
        buildDevice(lastSeen: DateTime(2026, 5, 14)),
      );

      expect(find.text('Last seen May 14, 2026'), findsOneWidget);
      expect(find.text('Probably no longer in use'), findsOneWidget);
    });

    testWidgets('omits the last-seen line when the homeserver reports no '
        'timestamp', (tester) async {
      await pumpCard(tester, buildDevice());
      expect(find.textContaining('Last seen'), findsNothing);
    });
  });

  group('verification', () {
    testWidgets('tapping Verify opens verification modal, releases lock and '
        'calls refreshListCallback after close', (tester) async {
      when(
        () => mockMatrixService.verifyDevice(mockDeviceKeys),
      ).thenAnswer((_) async {});
      when(
        () => mockMatrixService.keyVerificationStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockMatrixService.getUnverifiedDevices(),
      ).thenReturn([]);

      var refreshed = false;
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
          child: MaterialApp(
            theme: resolveTestTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (ctx, ref, _) {
                container = ProviderScope.containerOf(ctx);
                return Scaffold(
                  body: SingleChildScrollView(
                    child: DeviceCard(
                      buildDevice(),
                      refreshListCallback: () => refreshed = true,
                      now: now,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Lock starts released.
      expect(container.read(matrixVerificationModalLockProvider), isFalse);

      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Modal is open and lock is acquired.
      expect(find.byType(VerificationModal), findsOneWidget);
      expect(container.read(matrixVerificationModalLockProvider), isTrue);

      // Close the modal via the close button.
      final closeButton = find.byIcon(Icons.close_rounded);
      await tester.ensureVisible(closeButton);
      await tester.tap(closeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Lock is released and refreshListCallback was called.
      expect(find.byType(VerificationModal), findsNothing);
      expect(container.read(matrixVerificationModalLockProvider), isFalse);
      expect(refreshed, isTrue);
    });

    testWidgets('tapping Verify when lock is already acquired does nothing', (
      tester,
    ) async {
      when(
        () => mockMatrixService.keyVerificationStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockMatrixService.getUnverifiedDevices(),
      ).thenReturn([]);

      await pumpCard(
        tester,
        buildDevice(),
        overrides: [
          matrixVerificationModalLockProvider.overrideWith(
            _PreAcquiredLock.new,
          ),
        ],
      );

      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Lock was pre-acquired so tryAcquire() returns false → no modal shown
      // and the verification service call is short-circuited.
      expect(find.byType(VerificationModal), findsNothing);
      verifyNever(() => mockMatrixService.verifyDevice(mockDeviceKeys));
    });
  });
}
