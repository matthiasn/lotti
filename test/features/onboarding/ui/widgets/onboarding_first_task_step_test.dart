import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_orb_zone.dart';
import 'package:lotti/features/onboarding/model/onboarding_capture_category.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/services/onboarding_capture_to_task_service.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_first_task_step.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// In-memory [AppPrefs] backing the recording-style provider, so the step's
/// style resolution never touches SharedPreferences.
AppPrefs _fakePrefs({Future<String?>? styleValue}) => AppPrefs(
  getBool: (_) async => null,
  setBool: ({required key, required value}) async => true,
  getString: (_) => styleValue ?? Future.value(),
  setString: ({required key, required value}) async => true,
);

void main() {
  const categoryId = 'cat-1';
  const categoryLabel = 'Personal';
  const providerName = 'Gemini';
  const transcript = 'call the dentist and book the car service';

  late FakeCaptureController controller;
  late MockOnboardingCaptureToTaskService service;
  late MockOnboardingMetricsRepository metrics;

  // Reduced motion so the orb breath / shimmer tickers settle.
  const mq = MediaQueryData(size: Size(390, 844), disableAnimations: true);

  // A real (in-progress) task landed; `task` carries the id the step hands to
  // onTaskCreated.
  OnboardingCaptureResult realAha({String taskId = 'task-1'}) =>
      OnboardingCaptureResult(
        task: MockTask(id: taskId),
        title: 'Car & health errands',
        checklistItems: const ['Call the dentist', 'Book the car service'],
        isRealAha: true,
      );

  void stubStructuring(OnboardingCaptureResult result) {
    when(
      () => service.createTaskFromTranscript(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
        providerName: any(named: 'providerName'),
        audioId: any(named: 'audioId'),
      ),
    ).thenAnswer((_) async => result);
  }

  /// Once structuring lands, the created beat owns the panel — the task card
  /// (titled by [realAha]) must be tapped to hand the task to the host.
  Future<void> tapCreatedCard(WidgetTester tester) async {
    expect(find.text('Your first task is ready'), findsOneWidget);
    await tester.tap(find.text('Car & health errands'), warnIfMissed: false);
    await tester.pump();
  }

  setUp(() {
    controller = FakeCaptureController();
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

  Future<void> pumpStep(
    WidgetTester tester, {
    VoidCallback? onDone,
    void Function(String taskId)? onTaskCreated,
    List<OnboardingCaptureCategory>? categories,
    Future<String?>? styleValue,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        Material(
          type: MaterialType.transparency,
          child: SizedBox(
            width: 390,
            child: OnboardingFirstTaskStep(
              categories:
                  categories ??
                  const [
                    OnboardingCaptureCategory(
                      id: categoryId,
                      label: categoryLabel,
                    ),
                  ],
              providerName: providerName,
              onDone: onDone ?? () {},
              onTaskCreated: onTaskCreated ?? (_) {},
            ),
          ),
        ),
        mediaQueryData: mq,
        overrides: [
          captureControllerProvider.overrideWith(() => controller),
          onboardingCaptureToTaskServiceProvider.overrideWithValue(service),
          recordingStyleAppPrefsProvider.overrideWithValue(
            _fakePrefs(styleValue: styleValue),
          ),
        ],
      ),
    );
    await tester.pump();
  }

  group('recording style resolution', () {
    testWidgets('the persisted analogue pick drives the VU meter visual', (
      tester,
    ) async {
      await pumpStep(tester, styleValue: Future.value('analogue'));
      // Let the style preference future resolve into the provider.
      await tester.pump();

      expect(find.byType(AnalogVuMeter), findsOneWidget);
      expect(find.byType(VoiceOrbZone), findsNothing);
    });

    testWidgets('falls back to the orb while the preference is unresolved', (
      tester,
    ) async {
      // A never-completing preference load: the step must not blank out — the
      // signature orb stands in until the style resolves.
      await pumpStep(tester, styleValue: Completer<String?>().future);

      expect(find.byType(VoiceOrbZone), findsOneWidget);
      expect(find.byType(AnalogVuMeter), findsNothing);
    });
  });

  testWidgets('renders the prompt frame with guided suggestions at rest', (
    tester,
  ) async {
    await pumpStep(tester);

    expect(find.text('Create your first task'), findsOneWidget);
    expect(find.byType(VoiceOrbZone), findsOneWidget);
    expect(find.text('Plan my week'), findsOneWidget);
    expect(find.text('Book a dentist appointment'), findsOneWidget);
    expect(find.text("Prepare for Monday's meeting"), findsOneWidget);
    expect(find.text('Rather type?'), findsOneWidget);
  });

  testWidgets('record tap delegates to the controller toggle', (tester) async {
    var toggles = 0;
    controller.onToggle = () => toggles++;
    await pumpStep(tester);

    await tester.tap(find.byType(VoiceButton), warnIfMissed: false);
    expect(toggles, 1);
  });

  testWidgets('listening maps to the live frame', (tester) async {
    await pumpStep(tester);

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
    'reaching captured structures once, reveals the created beat, and hands '
    'the task to the host on tap',
    (tester) async {
      final gate = Completer<OnboardingCaptureResult>();
      when(
        () => service.createTaskFromTranscript(
          transcript: any(named: 'transcript'),
          categoryId: any(named: 'categoryId'),
          providerName: any(named: 'providerName'),
          audioId: any(named: 'audioId'),
        ),
      ).thenAnswer((_) => gate.future);

      final created = <String>[];
      await pumpStep(tester, onTaskCreated: created.add);

      controller.emit(
        const CaptureState(
          phase: CapturePhase.captured,
          transcript: transcript,
          amplitudes: <double>[],
          audioId: 'audio-1',
        ),
      );
      await tester.pump();

      // The thinking frame holds while structuring is in flight; no task yet.
      expect(find.text('Turning your words into a task…'), findsOneWidget);
      expect(created, isEmpty);

      gate.complete(realAha());
      await tester.pump();
      await tester.pump();

      // The created beat shows the task inside the panel — the host has not
      // been handed anything yet. The card is title-only; the structured
      // checklist surfaces as proposals on the task page, not here.
      expect(find.text('Your first task is ready'), findsOneWidget);
      expect(find.text('Car & health errands'), findsOneWidget);
      expect(find.text('Call the dentist'), findsNothing);
      expect(find.text('Book the car service'), findsNothing);
      expect(created, isEmpty);

      // Tapping the card is the handoff.
      await tapCreatedCard(tester);
      expect(created, ['task-1']);

      // The spoken capture's audio entry travelled with the transcript so the
      // service can link it under the task.
      verify(
        () => service.createTaskFromTranscript(
          transcript: transcript,
          categoryId: categoryId,
          providerName: providerName,
          audioId: 'audio-1',
        ),
      ).called(1);
      verify(
        () => metrics.recordEvent(
          OnboardingEventName.firstAudioCaptured,
          provider: providerName,
        ),
      ).called(1);
    },
  );

  testWidgets('a tapped suggestion rides the typed path into structuring', (
    tester,
  ) async {
    stubStructuring(realAha(taskId: 'suggested-task'));
    final created = <String>[];
    await pumpStep(tester, onTaskCreated: created.add);

    await tester.tap(find.text('Plan my week'), warnIfMissed: false);
    await tester.pump();
    await tester.pump();

    verify(
      () => service.createTaskFromTranscript(
        transcript: 'Plan my week',
        categoryId: categoryId,
        providerName: providerName,
        // The typed path has no recording, so no audio entry travels along.
        // ignore: avoid_redundant_argument_values
        audioId: null,
      ),
    ).called(1);
    // The typed path is not a voice capture: it records typedCaptureUsed, not
    // firstAudioCaptured, so the voice-adoption funnel metric isn't inflated.
    verify(
      () => metrics.recordEvent(
        OnboardingEventName.typedCaptureUsed,
        provider: providerName,
      ),
    ).called(1);
    verifyNever(
      () => metrics.recordEvent(
        OnboardingEventName.firstAudioCaptured,
        provider: any(named: 'provider'),
      ),
    );
    await tapCreatedCard(tester);
    expect(created, ['suggested-task']);
  });

  testWidgets('a double-tap on the created card hands off only once', (
    tester,
  ) async {
    stubStructuring(realAha());
    final created = <String>[];
    await pumpStep(tester, onTaskCreated: created.add);

    controller.emit(
      const CaptureState(
        phase: CapturePhase.captured,
        transcript: transcript,
        amplitudes: <double>[],
        audioId: 'audio-1',
      ),
    );
    await tester.pump();
    await tester.pump();

    // Two rapid taps before the host can tear the panel down — the latch means
    // only the first reaches onTaskCreated (a second pop would tear down the
    // route beneath the modal).
    final card = find.text('Car & health errands');
    await tester.tap(card, warnIfMissed: false);
    await tester.tap(card, warnIfMissed: false);
    await tester.pump();

    expect(created, ['task-1']);
  });

  testWidgets('a total structuring failure (no task) finishes onboarding', (
    tester,
  ) async {
    stubStructuring(
      const OnboardingCaptureResult(
        task: null,
        title: '',
        checklistItems: [],
        isRealAha: false,
      ),
    );
    var dones = 0;
    final created = <String>[];
    await pumpStep(
      tester,
      onDone: () => dones++,
      onTaskCreated: created.add,
    );

    controller.emit(
      const CaptureState(
        phase: CapturePhase.captured,
        transcript: transcript,
        amplitudes: <double>[],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(created, isEmpty);
    expect(dones, 1);
  });

  testWidgets('a thrown structuring error re-arms the prompt for a retry', (
    tester,
  ) async {
    when(
      () => service.createTaskFromTranscript(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
        providerName: any(named: 'providerName'),
        audioId: any(named: 'audioId'),
      ),
    ).thenThrow(Exception('structuring backend down'));
    final created = <String>[];
    var dones = 0;
    await pumpStep(
      tester,
      onTaskCreated: created.add,
      onDone: () => dones++,
    );

    controller.emit(
      const CaptureState(
        phase: CapturePhase.captured,
        transcript: transcript,
        amplitudes: <double>[],
      ),
    );
    await tester.pump();
    await tester.pump();

    // The throw is swallowed: no task handed up, onboarding not finished, and
    // the step falls back to the prompt frame so the user can try again.
    expect(created, isEmpty);
    expect(dones, 0);
    expect(find.text('Create your first task'), findsOneWidget);
    expect(find.byType(VoiceOrbZone), findsOneWidget);

    // A fresh capture re-runs structuring (the in-flight guard was cleared).
    stubStructuring(realAha());
    controller.emit(
      const CaptureState(
        phase: CapturePhase.captured,
        transcript: transcript,
        amplitudes: <double>[],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tapCreatedCard(tester);
    expect(created, ['task-1']);
  });

  testWidgets('does not re-structure when the captured state re-emits', (
    tester,
  ) async {
    stubStructuring(realAha());
    await pumpStep(tester);

    const captured = CaptureState(
      phase: CapturePhase.captured,
      transcript: transcript,
      amplitudes: <double>[],
    );
    controller.emit(captured);
    await tester.pump();
    await tester.pump();

    controller.emit(captured.copyWith(amplitudes: const [0.1]));
    await tester.pump();

    verify(
      () => service.createTaskFromTranscript(
        transcript: transcript,
        categoryId: categoryId,
        providerName: providerName,
        // ignore: avoid_redundant_argument_values
        audioId: null,
      ),
    ).called(1);
  });

  testWidgets('does not structure an empty transcript', (tester) async {
    await pumpStep(tester);

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
        audioId: any(named: 'audioId'),
      ),
    );
  });

  testWidgets(
    'an empty mic capture re-arms the prompt instead of stranding thinking',
    (tester) async {
      await pumpStep(tester);

      // Mic path: listening → transcribing → captured with an empty
      // transcript (silence). The step must reset back to the prompt — the
      // thinking frame has no retry affordance.
      controller.emit(
        const CaptureState(
          phase: CapturePhase.listening,
          transcript: '',
          amplitudes: <double>[],
        ),
      );
      await tester.pump();
      controller.emit(
        const CaptureState(
          phase: CapturePhase.transcribing,
          transcript: '',
          amplitudes: <double>[],
        ),
      );
      await tester.pump();
      controller.emit(
        const CaptureState(
          phase: CapturePhase.captured,
          transcript: '',
          amplitudes: <double>[],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Create your first task'), findsOneWidget);
      expect(find.text('Turning your words into a task…'), findsNothing);
      verifyNever(
        () => service.createTaskFromTranscript(
          transcript: any(named: 'transcript'),
          categoryId: any(named: 'categoryId'),
          providerName: any(named: 'providerName'),
          audioId: any(named: 'audioId'),
        ),
      );
    },
  );

  testWidgets(
    'disposal during the metrics await does not touch ref afterwards',
    (tester) async {
      // Gate the funnel-event write so the step is parked on the await when
      // the modal is dismissed. Using `ref` after disposal throws in
      // Riverpod — the step must bail out instead.
      final gate = Completer<void>();
      when(
        () => metrics.recordEvent(
          any(),
          provider: any(named: 'provider'),
          reason: any(named: 'reason'),
          valueBucket: any(named: 'valueBucket'),
        ),
      ).thenAnswer((_) => gate.future);
      stubStructuring(realAha());
      await pumpStep(tester);

      controller.emit(
        const CaptureState(
          phase: CapturePhase.captured,
          transcript: transcript,
          amplitudes: <double>[],
        ),
      );
      await tester.pump();

      // Dismiss (dispose) the step mid-await, then let the write resolve.
      await tester.pumpWidget(const SizedBox.shrink());
      gate.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      verifyNever(
        () => service.createTaskFromTranscript(
          transcript: any(named: 'transcript'),
          categoryId: any(named: 'categoryId'),
          providerName: any(named: 'providerName'),
          audioId: any(named: 'audioId'),
        ),
      );
    },
  );

  testWidgets('a metrics write failure does not cost the user the task', (
    tester,
  ) async {
    // The funnel event write throws (e.g. metrics DB closed) — telemetry is
    // best-effort and the capture must still structure into a real task.
    when(
      () => metrics.recordEvent(
        any(),
        provider: any(named: 'provider'),
        reason: any(named: 'reason'),
        valueBucket: any(named: 'valueBucket'),
      ),
    ).thenThrow(Exception('metrics db closed'));
    stubStructuring(realAha());
    final created = <String>[];
    await pumpStep(tester, onTaskCreated: created.add);

    controller.emit(
      const CaptureState(
        phase: CapturePhase.captured,
        transcript: transcript,
        amplitudes: <double>[],
      ),
    );
    await tester.pump();
    await tester.pump();

    await tapCreatedCard(tester);
    expect(created, ['task-1']);
  });

  testWidgets('Rather type? collects typed text and structures it', (
    tester,
  ) async {
    const typed = 'water the plants on the balcony';
    stubStructuring(realAha());
    final created = <String>[];
    await pumpStep(tester, onTaskCreated: created.add);

    // The orb's breath/shader tickers never settle, so step the dialog
    // route open/close with bounded pumps rather than pumpAndSettle.
    await tester.tap(find.text('Rather type?'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Type your thought'), findsOneWidget);
    await tester.enterText(find.byType(TextField), typed);
    // Submit via the keyboard action (the field's onSubmitted).
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    verify(
      () => service.createTaskFromTranscript(
        transcript: typed,
        categoryId: categoryId,
        providerName: providerName,
        // ignore: avoid_redundant_argument_values
        audioId: null,
      ),
    ).called(1);
    await tapCreatedCard(tester);
    expect(created, ['task-1']);
  });

  testWidgets('Rather type? confirmed via OK structures the typed text', (
    tester,
  ) async {
    const typed = 'review the quarterly budget';
    stubStructuring(realAha(taskId: 'budget-task'));
    final created = <String>[];
    await pumpStep(tester, onTaskCreated: created.add);

    await tester.tap(find.text('Rather type?'), warnIfMissed: false);
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
        // ignore: avoid_redundant_argument_values
        audioId: null,
      ),
    ).called(1);
    await tapCreatedCard(tester);
    expect(created, ['budget-task']);
  });

  testWidgets('the type dialog opens over the prompt frame, not a fake '
      'thinking frame', (tester) async {
    await pumpStep(tester);

    await tester.tap(find.text('Rather type?'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The controller is untouched until text is submitted, so the panel
    // behind the dialog still shows the prompt — not "Turning your words
    // into a task…" over an empty quote.
    expect(find.text('Type your thought'), findsOneWidget);
    expect(find.text('Create your first task'), findsOneWidget);
    expect(find.text('Turning your words into a task…'), findsNothing);
  });

  testWidgets('Rather type? cancelled resets without structuring', (
    tester,
  ) async {
    await pumpStep(tester);

    await tester.tap(find.text('Rather type?'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Create your first task'), findsOneWidget);
    verifyNever(
      () => service.createTaskFromTranscript(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
        providerName: any(named: 'providerName'),
        audioId: any(named: 'audioId'),
      ),
    );
  });

  testWidgets('error maps back to the prompt frame as a retry affordance', (
    tester,
  ) async {
    await pumpStep(tester);

    controller.emit(
      const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.microphonePermissionDenied,
      ),
    );
    await tester.pump();

    expect(find.text('Create your first task'), findsOneWidget);
    expect(find.byType(VoiceOrbZone), findsOneWidget);
  });

  testWidgets('a single area shows no destination picker', (tester) async {
    await pumpStep(tester);

    expect(find.text('Where should this land?'), findsNothing);
  });

  testWidgets(
    'with more than one area the picker routes the task to the chosen area',
    (tester) async {
      stubStructuring(realAha());
      final created = <String>[];
      await pumpStep(
        tester,
        onTaskCreated: created.add,
        categories: const [
          OnboardingCaptureCategory(id: 'cat-work', label: 'Work'),
          OnboardingCaptureCategory(id: 'cat-family', label: 'Family'),
        ],
      );

      expect(find.text('Where should this land?'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);

      await tester.tap(find.text('Family'), warnIfMissed: false);
      await tester.pump();

      controller.emit(
        const CaptureState(
          phase: CapturePhase.captured,
          transcript: transcript,
          amplitudes: <double>[],
        ),
      );
      await tester.pump();
      await tester.pump();

      verify(
        () => service.createTaskFromTranscript(
          transcript: transcript,
          categoryId: 'cat-family',
          providerName: providerName,
          // ignore: avoid_redundant_argument_values
          audioId: null,
        ),
      ).called(1);
      await tapCreatedCard(tester);
      expect(created, ['task-1']);
    },
  );

  testWidgets('the destination picker is hidden once structuring starts', (
    tester,
  ) async {
    final gate = Completer<OnboardingCaptureResult>();
    when(
      () => service.createTaskFromTranscript(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
        providerName: any(named: 'providerName'),
        audioId: any(named: 'audioId'),
      ),
    ).thenAnswer((_) => gate.future);

    await pumpStep(
      tester,
      categories: const [
        OnboardingCaptureCategory(id: 'cat-work', label: 'Work'),
        OnboardingCaptureCategory(id: 'cat-family', label: 'Family'),
      ],
    );
    expect(find.text('Where should this land?'), findsOneWidget);

    controller.emit(
      const CaptureState(
        phase: CapturePhase.captured,
        transcript: transcript,
        amplitudes: <double>[],
      ),
    );
    await tester.pump();

    expect(find.text('Turning your words into a task…'), findsOneWidget);
    expect(find.text('Where should this land?'), findsNothing);

    gate.complete(realAha());
    await tester.pump();
  });
}
