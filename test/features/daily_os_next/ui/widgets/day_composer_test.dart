import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_composer.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_chat_input.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_utils/material_ui_finders.dart';
import '../../../../widget_test_utils.dart';

/// A capture the test drives by hand: [emit] moves it to any state, and the
/// composer's calls into it are recorded.
class _ScriptedCapture extends CaptureController {
  final toggles = <DateTime?>[];
  int resets = 0;

  @override
  CaptureState build() => const CaptureState.idle();

  // ignore: use_setters_to_change_properties
  void emit(CaptureState next) => state = next;

  @override
  Future<void> toggle({
    DateTime? forDate,
    AudioCaptureIntent intent = AudioCaptureIntent.dayPlan,
  }) async => toggles.add(forDate);

  @override
  void reset() {
    resets++;
    state = const CaptureState.idle();
  }
}

void main() {
  final day = DateTime(2026, 5, 26);
  late _ScriptedCapture capture;
  late List<({String words, String? audioId})> submitted;

  setUp(() {
    capture = _ScriptedCapture();
    submitted = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    Future<void> Function()? gate,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget2(
        Material(
          child: DayComposer(
            day: day,
            onSubmit: (words, {audioId}) async {
              submitted.add((words: words, audioId: audioId));
              await gate?.call();
            },
          ),
        ),
        overrides: [captureControllerProvider.overrideWith(() => capture)],
      ),
    );
    await tester.pump();
  }

  String send(WidgetTester tester) =>
      tester.element(find.byType(DayComposer)).messages.chatInputSendTooltip;
  String mic(WidgetTester tester) =>
      tester.element(find.byType(DayComposer)).messages.chatInputRecordVoice;

  /// Starts a take from this composer's own mic.
  Future<void> startTake(WidgetTester tester) async {
    await tester.tap(findMaterialTooltip(mic(tester)));
    await tester.pump();
  }

  CaptureState phase(
    CapturePhase phase, {
    String transcript = '',
    String? audioId,
    CaptureError? error,
  }) => CaptureState(
    phase: phase,
    transcript: transcript,
    amplitudes: const [0.2, 0.6, 0.4],
    audioId: audioId,
    error: error,
  );

  testWidgets('the mic starts recording for the shown day', (tester) async {
    await pump(tester);

    await tester.tap(findMaterialTooltip(mic(tester)));
    await tester.pump();

    expect(capture.toggles, [day]);
  });

  testWidgets("a running recording takes the field's place", (tester) async {
    await pump(tester);

    await startTake(tester);

    capture.emit(phase(CapturePhase.listening));
    await tester.pump();

    expect(
      tester
          .widget<DesignSystemChatInput>(find.byType(DesignSystemChatInput))
          .phase,
      DesignSystemChatInputPhase.recording,
    );
    // The voice runs across the input's row, at the recorder's cadence.
    expect(find.byKey(DesignSystemChatInputKeys.waveform), findsOneWidget);
    expect(
      tester
          .widget<DesignSystemChatInput>(find.byType(DesignSystemChatInput))
          .sampleInterval,
      const Duration(milliseconds: 20),
    );
  });

  testWidgets('a finished transcript lands in the field for review, with '
      'its recording', (tester) async {
    await pump(tester);

    await startTake(tester);

    capture
      ..emit(phase(CapturePhase.listening))
      ..emit(
        phase(
          CapturePhase.captured,
          transcript: ' Finish the launch deck ',
          audioId: 'audio-1',
        ),
      );
    await tester.pump();

    expect(
      tester
          .widget<DesignSystemChatInput>(find.byType(DesignSystemChatInput))
          .phase,
      DesignSystemChatInputPhase.compose,
    );
    expect(find.text('Finish the launch deck'), findsOneWidget);
    // The recorder is back at rest, ready for another take.
    expect(capture.resets, 1);

    await tester.tap(findMaterialTooltip(send(tester)));
    await tester.pump();

    expect(submitted, [(words: 'Finish the launch deck', audioId: 'audio-1')]);
  });

  testWidgets('a take adds to what is already typed, and the mic stays '
      'beside send', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Gym first.');
    await tester.pump();
    expect(find.byKey(DesignSystemChatInputKeys.mic), findsOneWidget);

    await startTake(tester);
    capture
      ..emit(phase(CapturePhase.listening))
      ..emit(
        phase(
          CapturePhase.captured,
          transcript: 'Then the launch deck',
          audioId: 'audio-2',
        ),
      );
    await tester.pump();

    expect(find.text('Gym first. Then the launch deck'), findsOneWidget);
  });

  testWidgets('typed words alone carry no recording', (tester) async {
    await pump(tester);

    // A take, then the field cleared and retyped: that audio no longer
    // stands behind the words.
    await startTake(tester);
    capture
      ..emit(phase(CapturePhase.listening))
      ..emit(
        phase(CapturePhase.captured, transcript: 'Old', audioId: 'audio-1'),
      );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Review the invoices');
    await tester.pump();
    await tester.tap(findMaterialTooltip(send(tester)));
    await tester.pump();

    expect(submitted, [(words: 'Review the invoices', audioId: null)]);
  });

  testWidgets('a capture failure reads under the field', (tester) async {
    await pump(tester);

    await startTake(tester);

    capture.emit(
      phase(
        CapturePhase.error,
        error: CaptureError.microphonePermissionDenied,
      ),
    );
    await tester.pump();

    final messages = tester.element(find.byType(DayComposer)).messages;
    expect(
      find.text(messages.dailyOsNextCaptureErrorMicrophonePermissionDenied),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('a second send while the first runs is ignored', (
    tester,
  ) async {
    final first = Completer<void>();
    await pump(tester, gate: () => first.future);
    await tester.enterText(find.byType(TextField), 'Count the colony');
    await tester.pump();

    await tester.tap(findMaterialTooltip(send(tester)));
    await tester.pump();
    // The field is closed while the check-in is handed over.
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submitted, hasLength(1));

    first.complete();
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });

  testWidgets('Done finishes the take for the day', (
    tester,
  ) async {
    await pump(tester);
    await startTake(tester);
    capture.emit(phase(CapturePhase.listening));
    await tester.pump();

    await tester.tap(find.byKey(DesignSystemChatInputKeys.done));
    await tester.pump();

    // One toggle started the take, the second ends it.
    expect(capture.toggles, [day, day]);
  });

  testWidgets('cancel puts the recorder back to rest', (
    tester,
  ) async {
    await pump(tester);
    await startTake(tester);
    capture.emit(phase(CapturePhase.listening));
    await tester.pump();

    await tester.tap(find.byKey(DesignSystemChatInputKeys.cancel));
    await tester.pump();

    expect(capture.resets, 1);
    expect(
      tester
          .widget<DesignSystemChatInput>(find.byType(DesignSystemChatInput))
          .phase,
      DesignSystemChatInputPhase.compose,
    );
  });

  testWidgets('while transcribing the input shows it is working, with no Done', (
    tester,
  ) async {
    await pump(tester);
    await startTake(tester);
    capture
      ..emit(phase(CapturePhase.listening))
      ..emit(phase(CapturePhase.transcribing));
    await tester.pump();

    expect(find.byKey(DesignSystemChatInputKeys.transcribing), findsOneWidget);
    expect(find.byKey(DesignSystemChatInputKeys.done), findsNothing);
    // Its way out stays: cancel discards the in-flight transcription.
    await tester.tap(find.byKey(DesignSystemChatInputKeys.cancel));
    await tester.pump();
    expect(capture.resets, 1);
  });

  testWidgets('a capture this composer did not start is left alone', (
    tester,
  ) async {
    await pump(tester);

    // The planning sheet's Capture step, open over the day: typing, then a
    // recording that finishes with words, then a failure.
    capture.emit(phase(CapturePhase.captured));
    await tester.pump();
    capture
      ..emit(phase(CapturePhase.listening))
      ..emit(phase(CapturePhase.captured, transcript: 'For the sheet'));
    await tester.pump();
    capture.emit(
      phase(
        CapturePhase.error,
        error: CaptureError.microphonePermissionDenied,
      ),
    );
    await tester.pump();

    final messages = tester.element(find.byType(DayComposer)).messages;
    expect(capture.resets, 0);
    expect(
      tester
          .widget<DesignSystemChatInput>(find.byType(DesignSystemChatInput))
          .phase,
      DesignSystemChatInputPhase.compose,
    );
    expect(find.text('For the sheet'), findsNothing);
    expect(
      find.text(messages.dailyOsNextCaptureErrorMicrophonePermissionDenied),
      findsNothing,
    );
  });

  testWidgets('a cancelled take hands the recorder back', (tester) async {
    await pump(tester);
    await startTake(tester);
    capture
      ..emit(phase(CapturePhase.listening))
      ..emit(const CaptureState.idle());
    await tester.pump();

    // Later captures belong to whoever starts them.
    capture
      ..emit(phase(CapturePhase.listening))
      ..emit(phase(CapturePhase.captured, transcript: 'Not mine'));
    await tester.pump();

    expect(find.text('Not mine'), findsNothing);
  });
}
