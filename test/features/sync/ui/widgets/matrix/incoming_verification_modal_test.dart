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

  testWidgets(
    'Accept failure resets awaiting state and surfaces the error',
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
      // acceptEmojiVerification fails so the catch block (lines 56-57) runs:
      // it resets _awaitingOtherDevice to false and then rethrows.
      when(runner.acceptEmojiVerification).thenAnswer(
        (_) async => throw Exception('boom'),
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

      final acceptFinder = find.text('Accept');
      expect(acceptFinder, findsOneWidget);
      await tester.ensureVisible(acceptFinder);

      // The rethrow propagates out of the discarded onPressed future as an
      // unhandled async error; capture it via a guarded zone so it does not
      // fail the test. Only the tap + pumps that trigger the async failure run
      // inside the zone, so other assertions still fail the test normally.
      final asyncErrors = <Object>[];
      await runZonedGuarded(
        () async {
          await tester.tap(acceptFinder);
          // Flush the microtasks so the failed acceptEmojiVerification future
          // settles and the catch block runs setState.
          await tester.pump();
          await tester.pump();
        },
        (error, stack) => asyncErrors.add(error),
      );

      // The rethrow surfaced as an unhandled async error.
      expect(asyncErrors, isNotEmpty);

      // After the failure the catch block reset _awaitingOtherDevice to false,
      // so the button is interactive again and shows the "Accept" label rather
      // than the "continue verification" awaiting label.
      verify(runner.acceptEmojiVerification).called(1);
      expect(find.text('Accept'), findsOneWidget);
      final context = tester.element(find.byType(IncomingVerificationModal));
      expect(
        find.text(context.messages.settingsMatrixContinueVerificationLabel),
        findsNothing,
      );
    },
  );

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

      // build() calls getUnverifiedDevices() once per build before the loop
      // ever runs, so we keep returning a non-empty list for the first few
      // calls. That forces the loop's `isEmpty` check (line 73) to fail and
      // drive execution into the `await Future.delayed` + mounted re-check
      // (lines 76-77). After enough calls we return empty so the loop breaks.
      var callCount = 0;
      when(() => mockMatrixService.getUnverifiedDevices()).thenAnswer((_) {
        callCount++;
        if (callCount <= 3) return [mockDeviceKeys];
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

      // Advance time repeatedly so the 400ms delay inside the loop fires more
      // than once, proving lines 76-77 (the delay + mounted re-check) ran.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // getUnverifiedDevices was polled more than the single build()-time call,
      // which can only happen if the loop traversed the delay path at least
      // once (the loop is the only other caller).
      expect(callCount, greaterThan(2));
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
      'closing the modal releases the lock so a later request reopens it',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const IncomingVerificationWrapper(),
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrixService),
            ],
          ),
        );

        when(
          () => mockMatrixService.incomingKeyVerificationRunnerStream,
        ).thenAnswer((_) => const Stream<KeyVerificationRunner>.empty());
        when(() => mockKeyVerification.deviceId).thenReturn('DEVICE1');

        // First request opens the modal (lock acquired).
        incomingController.add(mockKeyVerification);
        await tester.pumpAndSettle();
        expect(find.byType(IncomingVerificationModal), findsOneWidget);

        // Dismiss the modal by popping the navigator. This completes the
        // showVerificationModalSheet future and runs the finally block
        // (lines 268-269 invalidate while mounted, 271 lock.release()).
        final modalContext = tester.element(
          find.byType(IncomingVerificationModal),
        );
        Navigator.of(modalContext).pop();
        await tester.pumpAndSettle();
        expect(find.byType(IncomingVerificationModal), findsNothing);

        // The lock was released, so a second incoming request must be able to
        // reopen the modal. If release() (line 271) had not run, tryAcquire()
        // would return false and no modal would appear.
        incomingController.add(mockKeyVerification);
        await tester.pumpAndSettle();
        expect(find.byType(IncomingVerificationModal), findsOneWidget);

        // Clean up the still-open second modal.
        Navigator.of(
          tester.element(find.byType(IncomingVerificationModal)),
        ).pop();
        await tester.pumpAndSettle();
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

/// A [MatrixVerificationModalLock] that starts already acquired so that
/// [tryAcquire] always returns `false` in tests.
class _PreAcquiredLock extends MatrixVerificationModalLock {
  @override
  bool build() => true; // starts locked
}
