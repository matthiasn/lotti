import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_handled_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/state/matrix_verification_relaunch_provider.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/auto_verification_launcher.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';
import '../../provisioned/provisioned_status_page_test_helpers.dart';

/// Reads its list on every build so a test can change what is unverified and
/// invalidate, the way a completed ceremony does in production.
class _MutableUnverifiedController extends MatrixUnverifiedController {
  _MutableUnverifiedController(this.source);

  final List<DeviceKeys> Function() source;

  @override
  Future<List<DeviceKeys>> build() async => source();
}

/// Stands in for a manual or incoming ceremony already owning the lock.
class _HeldLock extends MatrixVerificationModalLock {
  @override
  bool build() => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;

  setUpAll(() {
    registerFallbackValue(FakeDeviceKeys());
  });

  MockDeviceKeys deviceNamed(String name, String id) {
    final device = MockDeviceKeys();
    when(() => device.deviceDisplayName).thenReturn(name);
    when(() => device.deviceId).thenReturn(id);
    when(() => device.userId).thenReturn('@alice:example.com');
    when(() => mockMatrixService.verifyDevice(device)).thenAnswer((_) async {});
    return device;
  }

  setUp(() {
    mockMatrixService = MockMatrixService();
    when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([]);
    when(
      () => mockMatrixService.keyVerificationStream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockMatrixService.verifyDevice(any())).thenAnswer((_) async {});
  });

  Future<ProviderContainer> pumpLauncher(
    WidgetTester tester,
    List<MockDeviceKeys> unverified, {
    List<Override> extraOverrides = const [],
    MatrixUnverifiedController Function()? unverifiedController,
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
              return const Scaffold(body: AutoVerificationLauncher());
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

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

      DeviceKeys shownDevice() => tester
          .widget<VerificationModal>(find.byType(VerificationModal))
          .deviceKeys;

      // First traversal takes the head of the list.
      expect(shownDevice(), same(stale));
      await dismiss();
      // Dismissing invalidates the providers, so the next unshown device is
      // offered on the rebuild.
      await tester.pumpAndSettle();
      expect(shownDevice(), same(fresh));
      await dismiss();
      expect(find.byType(VerificationModal), findsNothing);

      container.read(matrixVerificationRelaunchProvider.notifier).request();
      await tester.pumpAndSettle();

      // The one the user was actually looking at — not the stale peer at the
      // head of the list, which is what a full reset would have reopened.
      expect(find.byType(VerificationModal), findsOneWidget);
      expect(shownDevice(), same(fresh));
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
      var devices = <DeviceKeys>[deviceNamed('Old laptop', 'OLD')];
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
      final modal = tester.widget<VerificationModal>(
        find.byType(VerificationModal),
      );
      expect(modal.deviceKeys.deviceId, 'NEWPHONE');
      expect(container.read(matrixVerificationModalLockProvider), isTrue);
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
