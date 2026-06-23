import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_orb_zone.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/services/onboarding_capture_to_task_service.dart';
import 'package:lotti/features/onboarding/ui/pages/onboarding_capture_page.dart';
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

  // Reduced motion so the orb breath / shimmer tickers settle.
  const mq = MediaQueryData(size: Size(390, 844), disableAnimations: true);

  // A real (in-progress) task landed; `task` carries the id the page hands to
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
      ),
    ).thenAnswer((_) async => result);
  }

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
    void Function(String taskId)? onTaskCreated,
    List<OnboardingCaptureCategory>? categories,
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
          categories:
              categories ??
              const [
                OnboardingCaptureCategory(id: categoryId, label: categoryLabel),
              ],
          providerName: providerName,
          onDone: onDone ?? () {},
          onTaskCreated: onTaskCreated ?? (_) {},
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
    'reaching captured structures once and hands the new task to the host',
    (tester) async {
      final gate = Completer<OnboardingCaptureResult>();
      when(
        () => service.createTaskFromTranscript(
          transcript: any(named: 'transcript'),
          categoryId: any(named: 'categoryId'),
          providerName: any(named: 'providerName'),
        ),
      ).thenAnswer((_) => gate.future);

      final created = <String>[];
      await pumpPage(tester, onTaskCreated: created.add);

      controller.emit(
        const CaptureState(
          phase: CapturePhase.captured,
          transcript: transcript,
          amplitudes: <double>[],
        ),
      );
      await tester.pump();

      // The thinking frame holds while structuring is in flight; no task yet.
      expect(find.text('Turning your words into a task…'), findsOneWidget);
      expect(created, isEmpty);

      gate.complete(realAha());
      await tester.pump();
      await tester.pump();

      // The page hands the new task's id to the host (which navigates to it).
      expect(created, ['task-1']);
      verify(
        () => service.createTaskFromTranscript(
          transcript: transcript,
          categoryId: categoryId,
          providerName: providerName,
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
    await pumpPage(
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

  testWidgets('does not re-structure when the captured state re-emits', (
    tester,
  ) async {
    stubStructuring(realAha());
    await pumpPage(tester);

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

  testWidgets('the close affordance fires onDone (escape from any phase)', (
    tester,
  ) async {
    var done = 0;
    await pumpPage(tester, onDone: () => done++);

    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(done, 1);
  });

  testWidgets('Rather type? collects typed text and structures it', (
    tester,
  ) async {
    const typed = 'water the plants on the balcony';
    stubStructuring(realAha());
    final created = <String>[];
    await pumpPage(tester, onTaskCreated: created.add);

    // The orb's breath/shader tickers never settle, so step the dialog
    // route open/close with bounded pumps rather than pumpAndSettle.
    await tester.tap(find.text('Rather type?'));
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
      ),
    ).called(1);
    expect(created, ['task-1']);
  });

  testWidgets('Rather type? confirmed via OK structures the typed text', (
    tester,
  ) async {
    const typed = 'review the quarterly budget';
    stubStructuring(realAha(taskId: 'budget-task'));
    final created = <String>[];
    await pumpPage(tester, onTaskCreated: created.add);

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
    expect(created, ['budget-task']);
  });

  testWidgets('Rather type? cancelled resets without structuring', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('Rather type?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
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

    expect(find.text("What's on your mind?"), findsOneWidget);
    expect(find.byType(VoiceOrbZone), findsOneWidget);
  });

  testWidgets('a single area shows no destination picker', (tester) async {
    await pumpPage(tester);

    expect(find.text('Where should this land?'), findsNothing);
  });

  testWidgets(
    'with more than one area the picker routes the task to the chosen area',
    (tester) async {
      stubStructuring(realAha());
      final created = <String>[];
      await pumpPage(
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

      await tester.tap(find.text('Family'));
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
        ),
      ).called(1);
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
      ),
    ).thenAnswer((_) => gate.future);

    await pumpPage(
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
