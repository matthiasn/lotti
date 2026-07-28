import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/device_card.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
    bool onServer = true,
    bool ownAccount = true,
  }) => SyncDeviceInfo(
    deviceId: deviceId,
    displayName: displayName,
    lastSeen: lastSeen,
    isCurrentDevice: isCurrentDevice,
    verified: verified,
    keys: withKeys ? mockDeviceKeys : null,
    onServer: onServer,
    ownAccount: ownAccount,
  );

  setUp(() {
    // The delete path logs the raw exception instead of showing it.
    ensureDomainLoggerRegistered();
    mockMatrixService = MockMatrixService();
    mockDeviceKeys = MockDeviceKeys();

    when(() => mockDeviceKeys.deviceDisplayName).thenReturn('Pixel 7');
    when(() => mockDeviceKeys.deviceId).thenReturn('DEVICE1');
    when(() => mockDeviceKeys.userId).thenReturn('@user:server');
  });

  tearDown(tearDownTestGetIt);

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

  /// Taps the delete button and confirms the deletion in the modal.
  Future<void> tapDeleteAndConfirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('matrix_delete_device')));
    await tester.pumpAndSettle();

    // The confirm button renders the upper-cased delete label.
    await tester.tap(find.text('REMOVE FROM SYNC'));
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

      await tester.tap(find.byKey(const Key('matrix_delete_device')));
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

      await tester.tap(find.text('REMOVE FROM SYNC'));
      await tester.pumpAndSettle();

      verify(() => mockMatrixService.deleteDeviceById('DEVICE1')).called(1);
      expect(refreshed, isTrue);
      expect(find.text('Pixel 7 removed from sync'), findsOneWidget);
    });

    testWidgets('a slow removal shows a spinner, not a frozen glyph', (
      tester,
    ) async {
      // deleteDeviceById can sit in the server's key-refresh timeout for
      // up to 15 seconds. During that window the corner icon must read as
      // "working", and its tooltip — the semantics label — must say so.
      final gate = Completer<void>();
      when(
        () => mockMatrixService.deleteDeviceById('DEVICE1'),
      ).thenAnswer((_) => gate.future);

      await pumpCard(tester, buildDevice(), refreshListCallback: () {});

      await tester.tap(find.byKey(const Key('matrix_delete_device')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('REMOVE FROM SYNC'));
      await tester.pump();
      await tester.pump();

      final busyButton = tester.widget<IconButton>(
        find.byKey(const Key('matrix_delete_device')),
      );
      expect(busyButton.onPressed, isNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('matrix_delete_device')),
          matching: find.byType(DesignSystemSpinner),
        ),
        findsOneWidget,
      );
      final context = tester.element(find.byType(DeviceCard));
      expect(
        busyButton.tooltip,
        context.messages.syncDeviceRemovalInProgress,
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(DesignSystemSpinner), findsNothing);
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

      await tester.tap(find.byKey(const Key('matrix_delete_device')));
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
      // The raw "Exception: boom" belongs in the log, not in a toast.
      expect(
        find.text(
          "The device couldn't be removed. Check your connection and try "
          'again.',
        ),
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
          'The sync server refused this change. Remove this device from sync '
          'on the device itself, or re-pair with a fresh pairing code.',
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
          "The device couldn't be removed. Check your connection and try "
          'again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the current device offers no delete action', (tester) async {
      await pumpCard(
        tester,
        buildDevice(isCurrentDevice: true, verified: true),
      );

      expect(find.byKey(const Key('matrix_delete_device')), findsNothing);
      expect(
        find.byKey(const Key('matrix_remove_device_primary')),
        findsNothing,
      );
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
      expect(find.byKey(const Key('matrix_delete_device')), findsOneWidget);
    });

    testWidgets('an unverified device with keys gets the Unverified chip and '
        'a Verify button', (tester) async {
      await pumpCard(tester, buildDevice());

      expect(find.text('Unverified'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
    });

    testWidgets("a foreign user's device can be verified but never deleted", (
      tester,
    ) async {
      // Legacy one-user-per-device rooms: the peer's device gates sends and
      // is SAS-verifiable, but deletion only works for own sessions.
      await pumpCard(
        tester,
        buildDevice(onServer: false, ownAccount: false),
      );

      expect(find.text('Verify'), findsOneWidget);
      expect(find.byKey(const Key('matrix_delete_device')), findsNothing);
      expect(
        find.byKey(const Key('matrix_remove_device_primary')),
        findsNothing,
      );
    });

    testWidgets('a cache-only session offers removal as the only action', (
      tester,
    ) async {
      // Unverified keys the homeserver no longer lists: verification can
      // never be answered, so removal escalates and Verify disappears.
      await pumpCard(tester, buildDevice(onServer: false));

      expect(find.text('Verify'), findsNothing);
      expect(
        find.byKey(const Key('matrix_remove_device_primary')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('matrix_delete_device')), findsNothing);
    });

    testWidgets('a keyless session cannot be verified, only removed', (
      tester,
    ) async {
      await pumpCard(tester, buildDevice(withKeys: false));

      expect(find.text('Unverified'), findsOneWidget);
      expect(find.text('Verify'), findsNothing);
      expect(find.byKey(const Key('matrix_delete_device')), findsOneWidget);
    });

    testWidgets('a stale unverified device promotes removal to the labeled '
        'primary action and demotes Verify', (tester) async {
      when(
        () => mockMatrixService.deleteDeviceById('DEVICE1'),
      ).thenAnswer((_) async {});

      await pumpCard(
        tester,
        buildDevice(lastSeen: DateTime(2026, 5, 14)),
      );

      // The quiet delete button escalates to the labeled danger primary.
      expect(find.byKey(const Key('matrix_delete_device')), findsNothing);
      expect(
        find.byKey(const Key('matrix_remove_device_primary')),
        findsOneWidget,
      );
      expect(find.text('Remove from sync'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);

      // The labeled button still runs through the confirmation modal.
      await tester.tap(find.byKey(const Key('matrix_remove_device_primary')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('REMOVE FROM SYNC'));
      await tester.pumpAndSettle();

      verify(() => mockMatrixService.deleteDeviceById('DEVICE1')).called(1);
    });

    testWidgets('a stale but verified device keeps the quiet delete button', (
      tester,
    ) async {
      await pumpCard(
        tester,
        buildDevice(verified: true, lastSeen: DateTime(2026, 5, 14)),
      );

      expect(find.byKey(const Key('matrix_delete_device')), findsOneWidget);
      expect(
        find.byKey(const Key('matrix_remove_device_primary')),
        findsNothing,
      );
      // An icon in the card's corner: removing a healthy device is routine
      // cleanup and must not outweigh "Add device" on the page around it.
      // The blocking case keeps its labeled danger fill, because there
      // removal *is* the primary act.
      final delete = tester.widget<IconButton>(
        find.byKey(const Key('matrix_delete_device')),
      );
      expect(delete.onPressed, isNotNull);
      expect(delete.tooltip, isNotNull);
    });

    testWidgets('a blocking device keeps the loud removal button', (
      tester,
    ) async {
      await pumpCard(tester, buildDevice(lastSeen: DateTime(2026, 5, 14)));

      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const Key('matrix_remove_device_primary')),
            )
            .variant,
        DesignSystemButtonVariant.danger,
      );
    });
  });

  group('responsive layout', () {
    Future<void> pumpAtWidth(WidgetTester tester, double width) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: width,
            child: DeviceCard(
              buildDevice(verified: true),
              refreshListCallback: () {},
              now: now,
            ),
          ),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('stacks the name above its badges on a phone card', (
      tester,
    ) async {
      await pumpAtWidth(tester, kDeviceCardWideBreakpoint - 60);

      final name = tester.getRect(find.text('Pixel 7'));
      final badge = tester.getRect(find.text('Verified'));
      expect(badge.top, greaterThanOrEqualTo(name.bottom));
    });

    testWidgets('anchors the card on a device icon tile', (tester) async {
      await pumpAtWidth(tester, kDeviceCardWideBreakpoint + 120);

      // The tile leads the card; the name and its badges stack beside it so
      // the roster reads as a grid of machines rather than rows of prose.
      final name = tester.getRect(find.text('Pixel 7'));
      final badge = tester.getRect(find.text('Verified'));
      final icon = tester.getRect(find.byIcon(Icons.devices_other_rounded));
      expect(icon.right, lessThan(name.left));
      expect(badge.top, greaterThanOrEqualTo(name.bottom));
    });

    testWidgets('wraps badges rather than overflowing at large text', (
      tester,
    ) async {
      // As a plain Row child the badge Wrap got unbounded constraints and laid
      // every badge out in one run, overflowing instead of wrapping.
      tester.view.physicalSize = const Size(2000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
            child: SizedBox(
              width: kDeviceCardWideBreakpoint + 10,
              child: DeviceCard(
                buildDevice(isCurrentDevice: true, verified: true),
                refreshListCallback: () {},
                now: now,
              ),
            ),
          ),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
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

    testWidgets('splits a generated name into a hostname title and a '
        'localized pairing line', (tester) async {
      await pumpCard(
        tester,
        buildDevice(displayName: 'ghost-pixel 2026-05-14T18:22 3f9c01aa'),
      );

      expect(find.text('ghost-pixel'), findsOneWidget);
      expect(
        find.text('Paired May\u00a014,\u00a02026 · 3f9c01aa'),
        findsOneWidget,
      );
      expect(
        find.text('ghost-pixel 2026-05-14T18:22 3f9c01aa'),
        findsNothing,
      );
    });

    testWidgets('shows a formatted last-seen date without a stale hint when '
        'recently active', (tester) async {
      await pumpCard(
        tester,
        buildDevice(lastSeen: DateTime(2026, 7, 24)),
      );

      expect(
        find.text('Last seen Jul\u00a024,\u00a02026'),
        findsOneWidget,
      );
      expect(find.text('Probably no longer in use'), findsNothing);
    });

    testWidgets('flags a device unseen for more than 30 days as probably '
        'dead', (tester) async {
      await pumpCard(
        tester,
        buildDevice(lastSeen: DateTime(2026, 5, 14)),
      );

      // Hint and evidence sit on two deliberate lines on stale cards.
      expect(find.text('Probably no longer in use'), findsOneWidget);
      expect(
        find.text('Last seen May\u00a014,\u00a02026'),
        findsOneWidget,
      );
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
