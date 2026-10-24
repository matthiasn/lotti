import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/matrix_service_provider.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_handled_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_relaunch_provider.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/auto_verification_launcher.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/incoming_verification_modal.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart' show EventTypes;
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';
import '../../../sync_verification_fixtures.dart';
import '../../provisioned/provisioned_status_page_test_helpers.dart';

/// Reads its list on every build so a test can change what is unverified and
/// invalidate, the way a completed ceremony does in production.
class _MutableUnverifiedController extends MatrixUnverifiedController {
  _MutableUnverifiedController(this.source);

  final List<SyncDeviceInfo> Function() source;

  @override
  Future<List<SyncDeviceInfo>> build() async => source();
}

/// Stands in for a manual or incoming ceremony already owning the lock.
class _HeldLock extends MatrixVerificationModalLock {
  @override
  bool build() => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;

  SyncDeviceInfo deviceNamed(String name, String id) =>
      unverifiedPeerDevice(deviceId: id, displayName: name);

  Future<void> verifyDeviceCall(String deviceId) =>
      mockMatrixService.verifyDevice(
        userId: '@alice:example.com',
        deviceId: deviceId,
      );

  setUp(() {
    mockMatrixService = MockMatrixService();
    when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([]);
    when(
      () => mockMatrixService.outgoingVerifications,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockMatrixService.incomingVerifications,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockMatrixService.outgoingVerification).thenReturn(null);
    when(() => mockMatrixService.incomingVerification).thenReturn(null);
    when(
      () => mockMatrixService.verifyDevice(
        userId: any(named: 'userId'),
        deviceId: any(named: 'deviceId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockMatrixService.acceptVerification(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockMatrixService.cancelVerification(any()),
    ).thenAnswer((_) async {});
  });

  Future<ProviderContainer> pumpLauncher(
    WidgetTester tester,
    List<SyncDeviceInfo> unverified, {
    List<Override> extraOverrides = const [],
    MatrixUnverifiedController Function()? unverifiedController,
    int launchers = 1,
  }) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixUnverifiedControllerProvider.overrideWith(
            unverifiedController ??
                () => FakeMatrixUnverifiedController(unverified),
          ),
          syncDevicesControllerProvider.overrideWith(
            () => FakeSyncDevicesController(const []),
          ),
          ...extraOverrides,
        ],
        child: MaterialApp(
          builder: LegacyMaterialBridge.builder,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: resolveTestTheme(),
          home: Consumer(
            builder: (ctx, ref, _) {
              container = ProviderScope.containerOf(ctx);
              return Scaffold(
                body: Column(
                  children: [
                    for (var i = 0; i < launchers; i++)
                      const AutoVerificationLauncher(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  SyncDeviceInfo shownDevice(WidgetTester tester) =>
      tester.widget<VerificationModal>(find.byType(VerificationModal)).device;

  group('AutoVerificationLauncher device selection', () {
    testWidgets('does not consume devices while another sheet holds the lock', (
      tester,
    ) async {
      // A manual or incoming ceremony owning the lock invalidates the
      // unverified provider repeatedly while its sheet is open. Marking a
      // device handled on a failed acquisition would burn through every peer
      // and leave the newly paired one with no ceremony once the lock freed.
      final container = await pumpLauncher(
        tester,
        [deviceNamed('Stale', 'STALE'), deviceNamed('New phone', 'NEWPHONE')],
        extraOverrides: [
          matrixVerificationModalLockProvider.overrideWith(_HeldLock.new),
        ],
      );

      expect(find.byType(VerificationModal), findsNothing);
      expect(
        container.read(matrixVerificationHandledProvider),
        isEmpty,
        reason: 'a blocked launch must defer, not record',
      );
    });

    testWidgets('records only the device it actually showed', (tester) async {
      final container = await pumpLauncher(tester, [
        deviceNamed('Stale', 'STALE'),
        deviceNamed('New phone', 'NEWPHONE'),
      ]);

      expect(find.byType(VerificationModal), findsOneWidget);
      expect(
        container.read(matrixVerificationHandledProvider),
        {'@alice:example.com/STALE'},
      );
    });

    testWidgets('show-again reopens the device last shown, not the first', (
      tester,
    ) async {
      // Drives the real traversal rather than poking the shared set: the
      // launcher's `_lastOffered` is private, so a test that marks a device
      // handled by hand releases the *wrong* identity and still passes.
      final stale = deviceNamed('Stale', 'STALE');
      final fresh = deviceNamed('New phone', 'NEWPHONE');
      final container = await pumpLauncher(tester, [stale, fresh]);

      Future<void> dismiss() async {
        await tester.tap(find.byIcon(LottiIcons.close));
        await tester.pumpAndSettle();
      }

      // First traversal takes the head of the list.
      expect(shownDevice(tester), same(stale));
      await dismiss();
      // Dismissing invalidates the providers, so the next unshown device is
      // offered on the rebuild.
      await tester.pumpAndSettle();
      expect(shownDevice(tester), same(fresh));
      await dismiss();
      expect(find.byType(VerificationModal), findsNothing);

      container.read(matrixVerificationRelaunchProvider.notifier).request();
      await tester.pumpAndSettle();

      // The one the user was actually looking at — not the stale peer at the
      // head of the list, which is what a full reset would have reopened.
      expect(find.byType(VerificationModal), findsOneWidget);
      expect(shownDevice(tester), same(fresh));
    });

    testWidgets(
      'show-again reopens the device last shown even when a device never '
      'shown sorts ahead of it',
      (tester) async {
        // TLC's `RelaunchHonoured` trace: releasing the last identity is not
        // enough when the list has since grown at the head — the first
        // *unhandled* device is then the newcomer, not the one dismissed.
        final stale = deviceNamed('Stale', 'STALE');
        final fresh = deviceNamed('New phone', 'NEWPHONE');
        var devices = <SyncDeviceInfo>[fresh];
        final container = await pumpLauncher(
          tester,
          const [],
          unverifiedController: () =>
              _MutableUnverifiedController(() => devices),
        );

        expect(shownDevice(tester), same(fresh));
        await tester.tap(find.byIcon(LottiIcons.close));
        await tester.pumpAndSettle();

        // A legacy peer's keys land, and another surface holds the lock when
        // the launcher sees them, so its automatic launch defers.
        final lock = container.read(
          matrixVerificationModalLockProvider.notifier,
        );
        expect(lock.tryAcquire(), isTrue);
        devices = [stale, fresh];
        container.invalidate(matrixUnverifiedControllerProvider);
        await tester.pumpAndSettle();
        expect(find.byType(VerificationModal), findsNothing);
        lock.release();

        container.read(matrixVerificationRelaunchProvider.notifier).request();
        await tester.pumpAndSettle();

        expect(find.byType(VerificationModal), findsOneWidget);
        expect(shownDevice(tester), same(fresh));
      },
    );
  });

  group('AutoVerificationLauncher with two launchers mounted', () {
    testWidgets(
      'show-again reopens the device once and does not offer it again after '
      'the relaunched sheet closes',
      (tester) async {
        // TLC's `ReleaseOnce` trace: the settings pane and the setup sheet
        // each mount a launcher. When each listener released on its own, the
        // second one undid the record the first had just made, and closing
        // the relaunched sheet reopened it.
        final device = deviceNamed('New phone', 'NEWPHONE');
        final container = await pumpLauncher(tester, [device], launchers: 2);
        final identity = MatrixVerificationHandled.identityOf(
          userId: '@alice:example.com',
          deviceId: 'NEWPHONE',
        );

        expect(find.byType(VerificationModal), findsOneWidget);
        await tester.tap(find.byIcon(LottiIcons.close));
        await tester.pumpAndSettle();
        expect(find.byType(VerificationModal), findsNothing);

        container.read(matrixVerificationRelaunchProvider.notifier).request();
        await tester.pumpAndSettle();

        expect(find.byType(VerificationModal), findsOneWidget);
        expect(
          container
              .read(matrixVerificationHandledProvider.notifier)
              .contains(identity),
          isTrue,
        );

        await tester.tap(find.byIcon(LottiIcons.close));
        await tester.pumpAndSettle();

        expect(find.byType(VerificationModal), findsNothing);
        verify(() => verifyDeviceCall('NEWPHONE')).called(2);
      },
    );
  });

  group('AutoVerificationLauncher and a request the target already sent', () {
    /// The peer's unanswered request, as the service holds it.
    SyncVerificationState waitingFrom(
      String deviceId, {
      KeyVerificationOutcome outcome = KeyVerificationOutcome.pending,
    }) => verificationState(
      id: 'incoming-1',
      direction: SyncVerificationDirection.incoming,
      peerDeviceId: deviceId,
      lastStep: EventTypes.KeyVerificationRequest,
      outcome: outcome,
    );

    testWidgets('answers it instead of starting a second ceremony', (
      tester,
    ) async {
      // Two devices starting at each other are two SDK transactions, each
      // sheet waiting on the other's request. The peer's pending one is the
      // ceremony to show; the emoji are the same either way.
      when(
        () => mockMatrixService.incomingVerification,
      ).thenReturn(waitingFrom('NEWPHONE'));

      await pumpLauncher(tester, [deviceNamed('New phone', 'NEWPHONE')]);

      expect(find.byType(IncomingVerificationModal), findsOneWidget);
      expect(find.byType(VerificationModal), findsNothing);
      verifyNever(
        () => mockMatrixService.verifyDevice(
          userId: any(named: 'userId'),
          deviceId: any(named: 'deviceId'),
        ),
      );
    });

    testWidgets("starts its own when the pending request is another device's", (
      tester,
    ) async {
      when(
        () => mockMatrixService.incomingVerification,
      ).thenReturn(waitingFrom('SOMEONE_ELSE'));

      await pumpLauncher(tester, [deviceNamed('New phone', 'NEWPHONE')]);

      expect(find.byType(VerificationModal), findsOneWidget);
      expect(find.byType(IncomingVerificationModal), findsNothing);
    });

    testWidgets("starts its own when the target's request was cancelled", (
      tester,
    ) async {
      when(() => mockMatrixService.incomingVerification).thenReturn(
        waitingFrom('NEWPHONE', outcome: KeyVerificationOutcome.cancelled),
      );

      await pumpLauncher(tester, [deviceNamed('New phone', 'NEWPHONE')]);

      expect(find.byType(VerificationModal), findsOneWidget);
      expect(find.byType(IncomingVerificationModal), findsNothing);
    });

    testWidgets('cancels the answered ceremony, not an own one, when the '
        'sheet closes', (tester) async {
      when(
        () => mockMatrixService.incomingVerification,
      ).thenReturn(waitingFrom('NEWPHONE'));

      await pumpLauncher(tester, [deviceNamed('New phone', 'NEWPHONE')]);
      await tester.tap(find.byIcon(LottiIcons.close));
      await tester.pumpAndSettle();

      verify(
        () => mockMatrixService.cancelVerification('incoming-1'),
      ).called(1);
    });
  });

  group('AutoVerificationLauncher handled-set lifecycle', () {
    testWidgets('clears the handled set when the last device gets verified', (
      tester,
    ) async {
      // The clear runs on the *success* path, so writing the provider inline
      // in build() turned the normal end of verification into a provider
      // modification exception — and the all-verified test could not catch it,
      // because an already-empty set makes clear() a no-op.
      var devices = <SyncDeviceInfo>[deviceNamed('Old laptop', 'OLD')];
      final container = await pumpLauncher(
        tester,
        const [],
        unverifiedController: () => _MutableUnverifiedController(() => devices),
      );

      expect(find.byType(VerificationModal), findsOneWidget);
      expect(container.read(matrixVerificationHandledProvider), isNotEmpty);

      await tester.tap(find.byIcon(LottiIcons.close));
      await tester.pumpAndSettle();

      // The ceremony succeeded: nothing is unverified any more.
      devices = [];
      container.invalidate(matrixUnverifiedControllerProvider);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(container.read(matrixVerificationHandledProvider), isEmpty);
    });
  });

  group('AutoVerificationLauncher', () {
    testWidgets('stays out of the way when every device is verified', (
      tester,
    ) async {
      final container = await pumpLauncher(tester, const []);

      expect(find.byType(VerificationModal), findsNothing);
      // The lock must be free, or no other surface could ever open a ceremony.
      expect(container.read(matrixVerificationModalLockProvider), isFalse);
    });

    testWidgets('opens the ceremony for the first unverified device', (
      tester,
    ) async {
      final first = deviceNamed('New Phone', 'NEWPHONE');
      final second = deviceNamed('Old Laptop', 'OLDLAPTOP');

      final container = await pumpLauncher(tester, [first, second]);

      expect(find.byType(VerificationModal), findsOneWidget);
      expect(shownDevice(tester).deviceId, 'NEWPHONE');
      expect(container.read(matrixVerificationModalLockProvider), isTrue);
    });

    group('when its sheet closes', () {
      Future<void> showThenDismiss(WidgetTester tester) async {
        await pumpLauncher(tester, [deviceNamed('New phone', 'NEWPHONE')]);
        expect(find.byType(VerificationModal), findsOneWidget);
        await tester.tap(find.byIcon(LottiIcons.close));
        await tester.pumpAndSettle();
        expect(find.byType(VerificationModal), findsNothing);
      }

      testWidgets('cancels the ceremony the user walked away from, by id', (
        tester,
      ) async {
        // Dismissing used to leave the SDK ceremony live: the peer's sheet
        // kept waiting on a device that was gone, with nothing to free its
        // lock (TLC's `EventuallyOffered` with `CancelOnDismiss = FALSE`).
        // Whether the ceremony is still live is the service's call.
        when(() => mockMatrixService.outgoingVerification).thenReturn(
          verificationState(
            id: 'own-1',
            peerDeviceId: 'NEWPHONE',
            lastStep: EventTypes.KeyVerificationRequest,
          ),
        );

        await showThenDismiss(tester);

        verify(() => mockMatrixService.cancelVerification('own-1')).called(1);
      });

      testWidgets('cancels nothing when the service holds no ceremony', (
        tester,
      ) async {
        await showThenDismiss(tester);

        verifyNever(() => mockMatrixService.cancelVerification(any()));
      });
    });

    testWidgets('does not stack a second ceremony while one is open', (
      tester,
    ) async {
      final device = deviceNamed('New Phone', 'NEWPHONE');
      await pumpLauncher(tester, [device]);

      expect(find.byType(VerificationModal), findsOneWidget);

      // Further frames must not re-enter: a post-frame callback fires on every
      // rebuild, and re-launching would stack sheets on the same device.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(VerificationModal), findsOneWidget);
    });

    testWidgets('yields when another surface already holds the modal lock', (
      tester,
    ) async {
      final device = deviceNamed('New Phone', 'NEWPHONE');

      // Prime the container before the first frame: a peer surface that got
      // there first already holds the lock when the launcher mounts.
      final container = ProviderContainer(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
          matrixUnverifiedControllerProvider.overrideWith(
            () => FakeMatrixUnverifiedController([device]),
          ),
          syncDevicesControllerProvider.overrideWith(
            () => FakeSyncDevicesController(const []),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container
            .read(matrixVerificationModalLockProvider.notifier)
            .tryAcquire(),
        isTrue,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: LegacyMaterialBridge.builder,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: resolveTestTheme(),
            home: const Scaffold(body: AutoVerificationLauncher()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Two surfaces watch the same provider; only one ceremony may exist.
      expect(find.byType(VerificationModal), findsNothing);
      expect(container.read(matrixVerificationModalLockProvider), isTrue);
    });
  });
}
