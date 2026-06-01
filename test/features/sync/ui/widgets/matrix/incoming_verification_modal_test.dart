import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_verification_modal_lock_provider.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/incoming_verification_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

class MockKeyVerificationRunner extends Mock implements KeyVerificationRunner {}

class MockKeyVerification extends Mock implements KeyVerification {}

class FakeKeyVerificationEmoji extends Fake implements KeyVerificationEmoji {
  FakeKeyVerificationEmoji(this.emoji, this.name);

  @override
  final String emoji;

  @override
  final String name;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late MockKeyVerification mockKeyVerification;
  late StreamController<KeyVerificationRunner> controller;

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockKeyVerification = MockKeyVerification();
    controller = StreamController<KeyVerificationRunner>.broadcast();

    when(
      () => mockMatrixService.incomingKeyVerificationRunnerStream,
    ).thenAnswer((_) => controller.stream);
    when(() => mockMatrixService.getUnverifiedDevices()).thenReturn([]);
    when(() => mockKeyVerification.deviceId).thenReturn('DEVICE1');
    when(() => mockKeyVerification.isDone).thenReturn(false);
  });

  tearDown(() async {
    await controller.close();
  });

  testWidgets('shows verify action before emoji step', (tester) async {
    final runner = MockKeyVerificationRunner();

    when(() => runner.lastStep).thenReturn('');
    when(() => runner.emojis).thenReturn(null);
    when(() => runner.keyVerification).thenReturn(mockKeyVerification);
    when(runner.acceptVerification).thenAnswer((_) async {});

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        IncomingVerificationModal(mockKeyVerification),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    controller.add(runner);
    await tester.pump();

    expect(find.text('Verify'), findsOneWidget);
    verify(runner.acceptVerification).called(1);
  });

  testWidgets('shows cancel label in emoji verification step', (tester) async {
    final runner = MockKeyVerificationRunner();
    final emojis = List.generate(
      8,
      (index) => FakeKeyVerificationEmoji('😀', 'emoji$index'),
    );

    when(() => runner.lastStep).thenReturn('m.key.verification.key');
    when(() => runner.emojis).thenReturn(emojis);
    when(() => runner.keyVerification).thenReturn(mockKeyVerification);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        IncomingVerificationModal(mockKeyVerification),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    controller.add(runner);
    await tester.pump();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.byKey(const Key('matrix_cancel_verification')), findsOneWidget);
  });

  testWidgets('shows success state when verification is done', (tester) async {
    final runner = MockKeyVerificationRunner();

    when(() => runner.lastStep).thenReturn('m.key.verification.done');
    when(() => runner.emojis).thenReturn(null);
    when(() => runner.keyVerification).thenReturn(mockKeyVerification);
    when(() => mockKeyVerification.isDone).thenReturn(true);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        IncomingVerificationModal(mockKeyVerification),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    controller.add(runner);
    await tester.pump();

    expect(find.byIcon(MdiIcons.shieldCheck), findsOneWidget);
    final context = tester.element(find.byType(IncomingVerificationModal));
    expect(
      find.text(context.messages.settingsMatrixVerificationSuccessConfirm),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping Accept transitions to awaiting other device state',
    (tester) async {
      final runner = MockKeyVerificationRunner();
      final emojis = List.generate(
        8,
        (index) => FakeKeyVerificationEmoji('😀', 'emoji$index'),
      );

      when(() => runner.lastStep).thenReturn('m.key.verification.key');
      when(() => runner.emojis).thenReturn(emojis);
      when(() => runner.keyVerification).thenReturn(mockKeyVerification);
      when(runner.cancelVerification).thenAnswer((_) async {});
      when(runner.acceptEmojiVerification).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          IncomingVerificationModal(mockKeyVerification),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      controller.add(runner);
      await tester.pump();

      await tester.tap(find.text('Accept'));
      await tester.pump();

      verify(runner.acceptEmojiVerification).called(1);
      final context = tester.element(find.byType(IncomingVerificationModal));
      expect(
        find.text(context.messages.settingsMatrixContinueVerificationLabel),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'cancel button calls runner cancellation',
    (tester) async {
      final runner = MockKeyVerificationRunner();
      final emojis = List.generate(
        8,
        (index) => FakeKeyVerificationEmoji('😀', 'emoji$index'),
      );

      when(() => runner.lastStep).thenReturn('m.key.verification.key');
      when(() => runner.emojis).thenReturn(emojis);
      when(() => runner.keyVerification).thenReturn(mockKeyVerification);
      when(runner.cancelVerification).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          IncomingVerificationModal(mockKeyVerification),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      controller.add(runner);
      await tester.pump();

      expect(
        find.byKey(const Key('matrix_cancel_verification')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('matrix_cancel_verification')));
      await tester.pump();

      verify(runner.cancelVerification).called(1);
    },
  );

  testWidgets('displays device display name from unverified list', (
    tester,
  ) async {
    final runner = MockKeyVerificationRunner();
    final mockDeviceKeys = MockDeviceKeys();

    when(() => mockDeviceKeys.deviceId).thenReturn('DEVICE1');
    when(() => mockDeviceKeys.deviceDisplayName).thenReturn('My Pixel');
    when(
      () => mockMatrixService.getUnverifiedDevices(),
    ).thenReturn([mockDeviceKeys]);
    when(() => runner.lastStep).thenReturn('');
    when(() => runner.emojis).thenReturn(null);
    when(() => runner.keyVerification).thenReturn(mockKeyVerification);
    when(runner.acceptVerification).thenAnswer((_) async {});

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        IncomingVerificationModal(mockKeyVerification),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );

    controller.add(runner);
    await tester.pump();

    expect(find.text('My Pixel'), findsOneWidget);
  });

  testWidgets(
    'auto-accept failure keeps verify button visible',
    (tester) async {
      final runner = MockKeyVerificationRunner();

      when(() => runner.lastStep).thenReturn('');
      when(() => runner.emojis).thenReturn(null);
      when(() => runner.keyVerification).thenReturn(mockKeyVerification);
      when(runner.acceptVerification).thenThrow(Exception('network error'));

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          IncomingVerificationModal(mockKeyVerification),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      controller.add(runner);
      await tester.pump();

      // Verify button should still be visible as fallback
      expect(find.text('Verify'), findsOneWidget);
    },
  );

  // Lines 56-57: the catch block inside _acceptEmojiVerification resets
  // _awaitingOtherDevice when acceptEmojiVerification() throws.  Verifying
  // the full round-trip (tap → awaiting → error → reset) requires the
  // unhandled Future error from rethrow to be suppressed — which is not
  // supported by the standard testWidgets Zone.  Instead we verify the
  // *awaiting* state transition (tap → button disabled) and that
  // acceptEmojiVerification was actually called, which is the meaningful
  // precondition for the catch path.
  testWidgets(
    'tapping Accept while not awaiting calls acceptEmojiVerification and sets awaiting state',
    (tester) async {
      final runner = MockKeyVerificationRunner();
      final emojis = List.generate(
        8,
        (index) => FakeKeyVerificationEmoji('😀', 'emoji$index'),
      );

      // Use a completer that never completes so the awaiting state stays true.
      final completer = Completer<void>();
      addTearDown(completer.future.ignore);

      when(() => runner.lastStep).thenReturn('m.key.verification.key');
      when(() => runner.emojis).thenReturn(emojis);
      when(() => runner.keyVerification).thenReturn(mockKeyVerification);
      when(runner.cancelVerification).thenAnswer((_) async {});
      when(runner.acceptEmojiVerification).thenAnswer(
        (_) => completer.future,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          IncomingVerificationModal(mockKeyVerification),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      controller.add(runner);
      await tester.pump();

      // Tap Accept — sets _awaitingOtherDevice = true.
      final acceptFinder = find.text('Accept');
      expect(acceptFinder, findsOneWidget);
      await tester.ensureVisible(acceptFinder);
      await tester.tap(acceptFinder);
      await tester.pump();

      // While in the awaiting state the button label changes, proving
      // _awaitingOtherDevice was set to true (line 52).
      final context = tester.element(find.byType(IncomingVerificationModal));
      expect(
        find.text(context.messages.settingsMatrixContinueVerificationLabel),
        findsWidgets,
      );
      // acceptEmojiVerification was called (line 54).
      verify(runner.acceptEmojiVerification).called(1);
    },
  );

  testWidgets(
    'success confirm button calls stopTimer and closes the modal',
    (tester) async {
      final runner = MockKeyVerificationRunner();

      when(() => runner.lastStep).thenReturn('m.key.verification.done');
      when(() => runner.emojis).thenReturn(null);
      when(() => runner.keyVerification).thenReturn(mockKeyVerification);
      when(() => mockKeyVerification.isDone).thenReturn(true);
      when(() => mockKeyVerification.deviceId).thenReturn('DEVICE1');
      when(runner.stopTimer).thenReturn(null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          IncomingVerificationModal(mockKeyVerification),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      controller.add(runner);
      await tester.pump();

      expect(find.byIcon(MdiIcons.shieldCheck), findsOneWidget);

      final confirmFinder = find.text('Got it');
      expect(confirmFinder, findsOneWidget);
      await tester.ensureVisible(confirmFinder);
      await tester.tap(confirmFinder);
      await tester.pump();

      verify(runner.stopTimer).called(1);
    },
  );

  testWidgets(
    'refreshUnverifiedDevices loops through delay when devices initially non-empty',
    (tester) async {
      final runner = MockKeyVerificationRunner();
      final mockDeviceKeys = MockDeviceKeys();

      when(() => mockDeviceKeys.deviceId).thenReturn('OTHER_DEVICE');
      when(() => mockDeviceKeys.deviceDisplayName).thenReturn('Other Device');

      // Return non-empty first, then empty to end the loop.
      var callCount = 0;
      when(() => mockMatrixService.getUnverifiedDevices()).thenAnswer((_) {
        callCount++;
        if (callCount <= 1) return [mockDeviceKeys];
        return [];
      });

      when(() => runner.lastStep).thenReturn('m.key.verification.done');
      when(() => runner.emojis).thenReturn(null);
      when(() => runner.keyVerification).thenReturn(mockKeyVerification);
      when(() => mockKeyVerification.isDone).thenReturn(true);
      when(() => mockKeyVerification.deviceId).thenReturn('DEVICE1');
      when(runner.stopTimer).thenReturn(null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          IncomingVerificationModal(mockKeyVerification),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      controller.add(runner);
      await tester.pump();

      // Advance time to allow the delay in refreshUnverifiedDevices loop to fire.
      await tester.pump(const Duration(milliseconds: 500));

      // Should have called getUnverifiedDevices at least twice — once while
      // non-empty (triggering the delay path, lines 76-77), and once returning
      // empty to break out.
      expect(callCount, greaterThanOrEqualTo(2));
    },
  );

  group('IncomingVerificationWrapper', () {
    late StreamController<KeyVerification> incomingController;

    setUp(() {
      incomingController = StreamController<KeyVerification>.broadcast();
      when(
        () => mockMatrixService.getIncomingKeyVerificationStream(),
      ).thenAnswer((_) => incomingController.stream);
    });

    tearDown(() async {
      await incomingController.close();
    });

    testWidgets(
      'renders without error and listens to incoming stream',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const IncomingVerificationWrapper(),
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
            ],
          ),
        );

        // The wrapper renders as SizedBox.shrink when idle.
        expect(find.byType(IncomingVerificationWrapper), findsOneWidget);
        // getIncomingKeyVerificationStream must have been called once during
        // initState to set up the subscription.
        verify(
          () => mockMatrixService.getIncomingKeyVerificationStream(),
        ).called(1);
      },
    );

    testWidgets(
      'shows verification modal when incoming stream emits and lock is free',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const IncomingVerificationWrapper(),
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
            ],
          ),
        );

        // Stub the runner stream so IncomingVerificationModal doesn't crash.
        when(
          () => mockMatrixService.incomingKeyVerificationRunnerStream,
        ).thenAnswer((_) => const Stream<KeyVerificationRunner>.empty());

        when(
          () => mockKeyVerification.deviceId,
        ).thenReturn('DEVICE1');

        incomingController.add(mockKeyVerification);
        await tester.pumpAndSettle();

        // The modal content (IncomingVerificationModal) should now be visible.
        expect(find.byType(IncomingVerificationModal), findsOneWidget);
      },
    );

    testWidgets(
      'lock prevents a second modal from opening while first is open',
      (tester) async {
        // Override the lock provider with one that starts already acquired so
        // tryAcquire() returns false and the modal is never shown.
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const IncomingVerificationWrapper(),
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
              matrixVerificationModalLockProvider.overrideWith(
                _PreAcquiredLock.new,
              ),
            ],
          ),
        );

        when(
          () => mockMatrixService.incomingKeyVerificationRunnerStream,
        ).thenAnswer((_) => const Stream<KeyVerificationRunner>.empty());
        when(
          () => mockKeyVerification.deviceId,
        ).thenReturn('DEVICE1');

        incomingController.add(mockKeyVerification);
        await tester.pump();

        // No modal should open because the lock is already held.
        expect(find.byType(IncomingVerificationModal), findsNothing);
      },
    );
  });
}

class MockDeviceKeys extends Mock implements DeviceKeys {}

/// A [MatrixVerificationModalLock] that starts already acquired so that
/// [tryAcquire] always returns `false` in tests.
class _PreAcquiredLock extends MatrixVerificationModalLock {
  @override
  bool build() => true; // starts locked
}
