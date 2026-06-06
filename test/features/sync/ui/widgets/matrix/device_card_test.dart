import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/device_card.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
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

  late MockMatrixService mockMatrixService;
  late MockDeviceKeys mockDeviceKeys;

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockDeviceKeys = MockDeviceKeys();

    when(() => mockDeviceKeys.deviceDisplayName).thenReturn('Pixel 7');
    when(() => mockDeviceKeys.deviceId).thenReturn('DEVICE1');
    when(() => mockDeviceKeys.userId).thenReturn('@user:server');
  });

  testWidgets('deletes device and shows success feedback', (tester) async {
    when(
      () => mockMatrixService.deleteDevice(mockDeviceKeys),
    ).thenAnswer((_) async {});

    var refreshed = false;

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DeviceCard(
          mockDeviceKeys,
          refreshListCallback: () {
            refreshed = true;
          },
        ),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    await tester.pump();

    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    verify(() => mockMatrixService.deleteDevice(mockDeviceKeys)).called(1);
    expect(refreshed, isTrue);
    expect(
      find.text('Device Pixel 7 deleted successfully'),
      findsOneWidget,
    );
  });

  testWidgets('shows error feedback when deletion fails', (tester) async {
    when(
      () => mockMatrixService.deleteDevice(mockDeviceKeys),
    ).thenThrow(Exception('boom'));

    var refreshed = false;

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DeviceCard(
          mockDeviceKeys,
          refreshListCallback: () {
            refreshed = true;
          },
        ),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    await tester.pump();

    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    verify(() => mockMatrixService.deleteDevice(mockDeviceKeys)).called(1);
    expect(refreshed, isFalse);
    expect(
      find.text('Failed to delete device: Exception: boom'),
      findsOneWidget,
    );
  });

  testWidgets('renders device name and user ID', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DeviceCard(
          mockDeviceKeys,
          refreshListCallback: () {},
        ),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    await tester.pump();

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Pixel 7'), findsOneWidget);
    expect(find.text('@user:server'), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);
  });

  testWidgets('shows device ID when display name is null', (tester) async {
    when(() => mockDeviceKeys.deviceDisplayName).thenReturn(null);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DeviceCard(
          mockDeviceKeys,
          refreshListCallback: () {},
        ),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    await tester.pump();

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('DEVICE1'), findsOneWidget);
  });

  testWidgets(
    'shows empty string when both display name and device ID are null',
    (tester) async {
      // Line 55: the `?? 'unknown'` fallback in the delete handler, and the
      // `?? ''` in the display Text both exercise the null-device-id branch.
      when(() => mockDeviceKeys.deviceDisplayName).thenReturn(null);
      when(() => mockDeviceKeys.deviceId).thenReturn(null);
      when(
        () => mockMatrixService.deleteDevice(mockDeviceKeys),
      ).thenAnswer((_) async {});

      var refreshed = false;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DeviceCard(
            mockDeviceKeys,
            refreshListCallback: () {
              refreshed = true;
            },
          ),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      // Both display name and id are null → the Text widget shows ''
      // (empty string), which means no named device text is present.
      expect(find.text('Pixel 7'), findsNothing);
      expect(find.text('DEVICE1'), findsNothing);

      // Tapping delete with null name/id falls back to 'unknown' in the toast.
      await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => mockMatrixService.deleteDevice(mockDeviceKeys)).called(1);
      expect(refreshed, isTrue);
      expect(
        find.text('Device unknown deleted successfully'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tapping Verify opens verification modal, releases lock and '
    'calls refreshListCallback after close',
    (tester) async {
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (ctx, ref, _) {
                container = ProviderScope.containerOf(ctx);
                return Scaffold(
                  body: SingleChildScrollView(
                    child: DeviceCard(
                      mockDeviceKeys,
                      refreshListCallback: () {
                        refreshed = true;
                      },
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
    },
  );

  testWidgets(
    'tapping Verify when lock is already acquired does nothing',
    (tester) async {
      when(
        () => mockMatrixService.keyVerificationStream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockMatrixService.getUnverifiedDevices(),
      ).thenReturn([]);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DeviceCard(
            mockDeviceKeys,
            refreshListCallback: () {},
          ),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixVerificationModalLockProvider.overrideWith(
              _PreAcquiredLock.new,
            ),
          ],
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Lock was pre-acquired so tryAcquire() returns false → no modal shown
      // and the verification service call is short-circuited.
      expect(find.byType(VerificationModal), findsNothing);
      verifyNever(() => mockMatrixService.verifyDevice(mockDeviceKeys));
    },
  );
}
