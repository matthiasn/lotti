import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_orb_zone.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/services/onboarding_capture_to_task_service.dart';
import 'package:lotti/features/onboarding/ui/pages/onboarding_capture_page.dart';
import 'package:lotti/features/onboarding/ui/widgets/crystallize_hero.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Fake [CaptureController] that lets a test push [CaptureState]s directly,
/// bypassing the real mic / realtime pipeline. `toggle()` is wired to a
/// test-supplied callback so the page's orb-tap is observable; the rest of the
/// public API mirrors the real controller's effect on `state`.
class _FakeCaptureController extends CaptureController {
  VoidCallback? onToggle;

  @override
  CaptureState build() => const CaptureState.idle();

  @override
  Future<void> toggle() async => onToggle?.call();

  @override
  void startTyping() {
    emit(
      const CaptureState(
        phase: CapturePhase.captured,
        transcript: '',
        amplitudes: <double>[],
      ),
    );
  }

  @override
  void updateTranscript(String transcript) {
    emit(state.copyWith(transcript: transcript));
  }

  @override
  void reset() => emit(const CaptureState.idle());

  /// Test seam: push an arbitrary state through the notifier.
  // ignore: use_setters_to_change_properties
  void emit(CaptureState next) => state = next;
}

void main() {
  const categoryId = 'cat-1';
  const categoryLabel = 'Personal';
  const providerName = 'Gemini';
  const transcript = 'call the dentist and book the car service';

  late _FakeCaptureController controller;
  late MockOnboardingCaptureToTaskService service;
  late MockOnboardingMetricsRepository metrics;

  // Reduced motion so the orb breath / shimmer / celebration tickers settle.
  const mq = MediaQueryData(size: Size(390, 844), disableAnimations: true);

  OnboardingCaptureResult realAha() => const OnboardingCaptureResult(
    task: null,
    title: 'Car & health errands',
    checklistItems: ['Call the dentist', 'Book the car service'],
    isRealAha: true,
  );

  setUp(() {
    controller = _FakeCaptureController();
    service = MockOnboardingCaptureToTaskService();
    metrics = MockOnboardingMetricsRepository();
    when(
      () => metrics.recordEvent(
        any(),
        provider: any(named: 'provider'),
        reason: any(named: 'reason'),
        valueBucket: any(named: 'valueBucket'),
      ),
    ).thenAnswer((_) async {});
    if (getIt.isRegistered<OnboardingMetricsRepository>()) {
      getIt.unregister<OnboardingMetricsRepository>();
    }
    getIt.registerSingleton<OnboardingMetricsRepository>(metrics);
  });

  setUpAll(() {
    registerFallbackValue(OnboardingEventName.firstAudioCaptured);
  });

  tearDown(() async {
    if (getIt.isRegistered<OnboardingMetricsRepository>()) {
      getIt.unregister<OnboardingMetricsRepository>();
    }
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    VoidCallback? onDone,
  }) async {
    // The full-screen page uses Spacers (needs a bounded viewport) and pins the
    // "Rather type?" escape hatch near the bottom; size the surface to the
    // 844-tall MediaQuery so the lower controls are on-screen and hit-testable.
    tester.view
      ..physicalSize = const Size(390, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        OnboardingCapturePage(
          categoryId: categoryId,
          categoryLabel: categoryLabel,
          providerName: providerName,
          onDone: onDone ?? () {},
        ),
        mediaQueryData: mq,
        overrides: [
          captureControllerProvider.overrideWith(() => controller),
          onboardingCaptureToTaskServiceProvider.overrideWithValue(service),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the prompt frame at rest', (tester) async {
    await pumpPage(tester);

    expect(find.text("What's on your mind?"), findsOneWidget);
    expect(find.byType(VoiceOrbZone), findsOneWidget);
    expect(find.text('Rather type?'), findsOneWidget);
    // No reveal chrome before a capture.
    expect(find.byType(CrystallizeHero), findsNothing);
    expect(
      find.widgetWithText(DesignSystemButton, 'Looks good'),
      findsNothing,
    );
  });

  testWidgets('orb tap delegates to the controller toggle', (tester) async {
    var toggles = 0;
    controller.onToggle = () => toggles++;
    await pumpPage(tester);

    await tester.tap(find.byType(VoiceButton), warnIfMissed: false);
    expect(toggles, 1);
  });

  testWidgets('listening maps to the live frame', (tester) async {
    await pumpPage(tester);

    controller.emit(
      const CaptureState(
        phase: CapturePhase.listening,
        transcript: '',
        amplitudes: <double>[0.2, 0.6, 0.4],
        dbfs: -20,
      ),
    );
    await tester.pump();

    expect(find.text("Listening… tap when you're done"), findsOneWidget);
    expect(find.byType(VoiceOrbZone), findsOneWidget);
  });

  testWidgets(
    'reaching captured structures once and reveals the returned task',
    (tester) async {
      // Hold the orchestrator open so the thinking frame is observable before
      // the reveal lands.
      final gate = Completer<OnboardingCaptureResult>();
      when(
        () => service.createTaskFromTranscript(
          transcript: any(named: 'transcript'),
          categoryId: any(named: 'categoryId'),
          providerName: any(named: 'providerName'),
        ),
      ).thenAnswer((_) => gate.future);

      await pumpPage(tester);

      // Drive idle → captured with a real transcript.
      controller.emit(
        const CaptureState(
          phase: CapturePhase.captured,
          transcript: transcript,
          amplitudes: <double>[],
        ),
      );
      await tester.pump();

      // Thinking frame while structuring is in flight.
      expect(find.text('Turning your words into a task…'), findsOneWidget);
      expect(find.byType(CrystallizeHero), findsNothing);

      // Resolve the orchestrator and let the reveal land.
      gate.complete(realAha());
      await tester.pump();
      await tester.pump();

      expect(find.text("Here's your first task"), findsOneWidget);
      expect(find.byType(CrystallizeHero), findsOneWidget);
      expect(find.text('Car & health errands'), findsOneWidget);
      expect(find.text('Call the dentist'), findsOneWidget);
      expect(find.text(categoryLabel), findsOneWidget);

      // Exactly one orchestrator call, carrying the right category + provider.
      verify(
        () => service.createTaskFromTranscript(
          transcript: transcript,
          categoryId: categoryId,
          providerName: providerName,
        ),
      ).called(1);

      // firstAudioCaptured was recorded for the capture.
      verify(
        () => metrics.recordEvent(
          OnboardingEventName.firstAudioCaptured,
          provider: providerName,
        ),
      ).called(1);
    },
  );

  testWidgets('does not re-structure when the captured state re-emits', (
    tester,
  ) async {
    when(
      () => service.createTaskFromTranscript(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
        providerName: any(named: 'providerName'),
      ),
    ).thenAnswer((_) async => realAha());

    await pumpPage(tester);

    const captured = CaptureState(
      phase: CapturePhase.captured,
      transcript: transcript,
      amplitudes: <double>[],
    );
    controller.emit(captured);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // Re-emitting an equivalent captured state (e.g. a late meter tick) must
    // not fire a second structuring pass for the same transcript.
    controller.emit(
      captured.copyWith(amplitudes: const [0.1]),
    );
    await tester.pump();

    verify(
      () => service.createTaskFromTranscript(
        transcript: transcript,
        categoryId: categoryId,
        providerName: providerName,
      ),
    ).called(1);
  });

  testWidgets('does not structure an empty transcript', (tester) async {
    await pumpPage(tester);

    controller.emit(
      const CaptureState(
        phase: CapturePhase.captured,
        transcript: '   ',
        amplitudes: <double>[],
      ),
    );
    await tester.pump();
    await tester.pump();

    verifyNever(
      () => service.createTaskFromTranscript(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
        providerName: any(named: 'providerName'),
      ),
    );
  });

  testWidgets('Looks good on the reveal fires onDone', (tester) async {
    when(
      () => service.createTaskFromTranscript(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
        providerName: any(named: 'providerName'),
      ),
    ).thenAnswer((_) async => realAha());

    var done = 0;
    await pumpPage(tester, onDone: () => done++);

    controller.emit(
      const CaptureState(
        phase: CapturePhase.captured,
        transcript: transcript,
        amplitudes: <double>[],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(DesignSystemButton, 'Looks good'));
    expect(done, 1);
  });

  testWidgets('the close affordance fires onDone (escape from any phase)', (
    tester,
  ) async {
    var done = 0;
    await pumpPage(tester, onDone: () => done++);

    // At rest (prompt phase, before any capture) the full-screen page is still
    // dismissable via the always-present close button.
    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(done, 1);
  });

  testWidgets('Rather type? collects typed text and structures it', (
    tester,
  ) async {
    const typed = 'water the plants on the balcony';
    when(
      () => service.createTaskFromTranscript(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
        providerName: any(named: 'providerName'),
      ),
    ).thenAnswer(
      (_) async => const OnboardingCaptureResult(
        task: null,
        title: 'Balcony care',
        checklistItems: ['Water the plants'],
        isRealAha: true,
      ),
    );

    await pumpPage(tester);

    // The orb's breath/shader tickers never settle, so step the dialog
    // route open/close with bounded pumps rather than pumpAndSettle.
    await tester.tap(find.text('Rather type?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The typed-capture dialog opened.
    expect(find.text('Type your thought'), findsOneWidget);
    await tester.enterText(find.byType(TextField), typed);
    // Submit via the keyboard action (the field's onSubmitted), not the OK
    // button, so both confirmation paths are exercised.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    verify(
      () => service.createTaskFromTranscript(
        transcript: typed,
        categoryId: categoryId,
        providerName: providerName,
      ),
    ).called(1);
    expect(find.text('Balcony care'), findsOneWidget);
  });

  testWidgets('Rather type? confirmed via OK structures the typed text', (
    tester,
  ) async {
    const typed = 'review the quarterly budget';
    when(
      () => service.createTaskFromTranscript(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
        providerName: any(named: 'providerName'),
      ),
    ).thenAnswer(
      (_) async => const OnboardingCaptureResult(
        task: null,
        title: 'Budget review',
        checklistItems: [],
        isRealAha: true,
      ),
    );

    await pumpPage(tester);

    await tester.tap(find.text('Rather type?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), typed);
    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    verify(
      () => service.createTaskFromTranscript(
        transcript: typed,
        categoryId: categoryId,
        providerName: providerName,
      ),
    ).called(1);
    expect(find.text('Budget review'), findsOneWidget);
  });

  testWidgets('Rather type? cancelled resets without structuring', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('Rather type?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Cancel the dialog without typing.
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text("What's on your mind?"), findsOneWidget);
    verifyNever(
      () => service.createTaskFromTranscript(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
        providerName: any(named: 'providerName'),
      ),
    );
  });

  testWidgets('error maps back to the prompt frame as a retry affordance', (
    tester,
  ) async {
    await pumpPage(tester);

    controller.emit(
      const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.microphonePermissionDenied,
      ),
    );
    await tester.pump();

    // The prompt frame is shown again so the orb is tappable to retry.
    expect(find.text("What's on your mind?"), findsOneWidget);
    expect(find.byType(VoiceOrbZone), findsOneWidget);
  });
}
