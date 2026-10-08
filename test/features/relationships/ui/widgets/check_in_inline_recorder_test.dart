import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/capture_state.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_orb_zone.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_inline_recorder.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../helpers/check_in_speech_fakes.dart';

void main() {
  late FakeAudioRecorderController recorder;
  final recorded = <(String, Duration)>[];
  final failed = <CheckInSpeechFailureKind>[];
  var discarded = 0;

  setUp(() {
    recorded.clear();
    failed.clear();
    discarded = 0;
  });

  Future<void> pump(
    WidgetTester tester, {
    AudioRecordingFailure? recordFailure,
    String? stopResult = 'audio-1',
    bool stopThrows = false,
    Completer<void>? stopGate,
    String? runningFor,
    bool adoptRunning = false,
  }) async {
    recorder = FakeAudioRecorderController(
      recordFailure: recordFailure,
      stopResult: stopResult,
      stopThrows: stopThrows,
      runningFor: runningFor,
    )..stopGate = stopGate;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        CheckInInlineRecorder(
          linkedId: 'person-1',
          categoryId: 'category-7',
          adoptRunning: adoptRunning,
          onRecorded: (id, length) => recorded.add((id, length)),
          onDiscarded: () => discarded++,
          onFailed: failed.add,
        ),
        overrides: [
          audioRecorderControllerProvider.overrideWith(() => recorder),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Finder key(String name) => find.byKey(ValueKey(name));

  /// Pumps a confirmation modal's transition through, frame by frame. Not
  /// `pumpAndSettle`: while the take is live the orb's shader and breath
  /// repeat, so the tree never settles — the Capture surface's reality too.
  Future<void> settleModal(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  VoiceButton orb(WidgetTester tester) =>
      tester.widget<VoiceButton>(key('check-in-recorder-orb'));

  testWidgets('starts recording on mount, linked to the person, with '
      'transcription left to the caller, and hides the floating indicator', (
    tester,
  ) async {
    await pump(tester);

    expect(recorder.recordCalls, [
      (linkedId: 'person-1', handledByCaller: true),
    ]);
    expect(recorder.categoryIds, ['category-7']);
    expect(recorder.modalVisibleLog, [true]);
    expect(failed, isEmpty);
    expect(find.byType(LiveWaveform), findsOneWidget);
    expect(find.text('Audio saved to this device as you go'), findsOneWidget);
  });

  group('the voice orb', () {
    testWidgets("is the Capture surface's, listening on the live level, as "
        'wide as the hero avatar', (tester) async {
      await pump(tester);
      recorder.tick(progress: const Duration(seconds: 3), dBFS: -18);
      await tester.pump();

      final button = orb(tester);
      expect(button.phase, CapturePhase.listening);
      expect(button.dbfs, -18);
      final tokens = tester
          .element(find.byType(CheckInInlineRecorder))
          .designTokens;
      expect(button.size, tokens.spacing.step11);
      expect(button.semanticLabel, 'Stop');
    });

    testWidgets('sits under the level strip, then its hint, then the clock — '
        "the voice zone's own order and air", (tester) async {
      await pump(tester);
      final strip = tester.getRect(find.byType(LiveWaveform));
      final field = tester.getRect(find.byKey(VoiceButton.fieldKey));
      final hint = tester.getRect(key('check-in-recorder-orb-hint'));
      final clock = tester.getRect(key('check-in-recorder-clock'));
      final tokens = tester
          .element(find.byType(CheckInInlineRecorder))
          .designTokens;

      expect(field.top - strip.bottom, closeTo(tokens.spacing.step5, 0.5));
      expect(hint.top - field.bottom, closeTo(tokens.spacing.step5, 0.5));
      expect(clock.top - hint.bottom, closeTo(tokens.spacing.step2, 0.5));
      expect(field.center.dx, closeTo(strip.center.dx, 0.5));
    });

    testWidgets('tapped while live it stops, like Capture, and hands back '
        'the take', (tester) async {
      await pump(tester);
      recorder.tick(progress: const Duration(seconds: 23), dBFS: -20);
      await tester.pump();

      await tester.tap(key('check-in-recorder-orb'));
      await tester.pump();
      await tester.pump();

      expect(recorder.stopCalls, 1);
      expect(recorded, [('audio-1', const Duration(seconds: 23))]);
    });

    testWidgets('says nothing under it before the take runs', (tester) async {
      await pump(tester, recordFailure: AudioRecordingFailure.permissionDenied);
      expect(
        tester.widget<Text>(key('check-in-recorder-orb-hint')).data,
        isEmpty,
      );
    });

    testWidgets('says what a tap does, in words under it: stop while live, '
        'resume while paused', (tester) async {
      await pump(tester);
      expect(find.text('Tap to stop'), findsOneWidget);
      final tokens = tester
          .element(find.byType(CheckInInlineRecorder))
          .designTokens;
      final hint = tester.widget<Text>(key('check-in-recorder-orb-hint'));
      expect(hint.style?.color, tokens.colors.text.mediumEmphasis);
      // Under the orb, above the clock — Capture's caption slot.
      final orbRect = tester.getRect(find.byKey(VoiceButton.fieldKey));
      final hintRect = tester.getRect(key('check-in-recorder-orb-hint'));
      final clockRect = tester.getRect(key('check-in-recorder-clock'));
      expect(hintRect.top, greaterThan(orbRect.bottom - 1));
      expect(clockRect.top, greaterThan(hintRect.bottom - 1));

      await tester.tap(key('check-in-recorder-pause'));
      await tester.pump();
      expect(find.text('Tap to resume'), findsOneWidget);
      expect(find.text('Tap to stop'), findsNothing);
    });

    testWidgets('paused, it rests as the idle disc and a tap resumes', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(key('check-in-recorder-pause'));
      await tester.pump();

      final button = orb(tester);
      expect(button.phase, CapturePhase.idle);
      expect(button.semanticLabel, 'Resume');
      expect(button.onTap, isNotNull);

      await tester.tap(key('check-in-recorder-orb'));
      await tester.pump();
      expect(recorder.resumeCalls, 1);
      expect(recorder.stopCalls, 0);
      expect(orb(tester).phase, CapturePhase.listening);
    });

    testWidgets('is inert after a refused start: nothing to stop or resume', (
      tester,
    ) async {
      await pump(tester, recordFailure: AudioRecordingFailure.permissionDenied);
      final button = orb(tester);
      expect(button.phase, CapturePhase.idle);
      expect(button.onTap, isNull);
    });

    testWidgets('goes quiet while a stop is in flight, with the buttons', (
      tester,
    ) async {
      final gate = Completer<void>();
      await pump(tester, stopGate: gate);
      await tester.tap(key('check-in-recorder-orb'));
      await tester.pump();

      expect(orb(tester).onTap, isNull);
      // Dimmed like Capture while it transcribes, so the wait is visible.
      expect(orb(tester).phase, CapturePhase.transcribing);
      gate.complete();
      await tester.pump();
      expect(recorded, hasLength(1));
    });
  });

  testWidgets("a refused start is reported in the composer's own terms", (
    tester,
  ) async {
    await pump(tester, recordFailure: AudioRecordingFailure.permissionDenied);
    expect(failed, [CheckInSpeechFailureKind.microphoneDenied]);
    expect(recorded, isEmpty);
  });

  testWidgets('a start the recorder refuses as busy or failed is a failed '
      'start', (tester) async {
    await pump(tester, recordFailure: AudioRecordingFailure.busy);
    expect(failed, [CheckInSpeechFailureKind.recordingFailed]);
  });

  // `record()` on a running recorder toggles it off; adopting attaches to
  // the take instead, and only hides the indicator.
  testWidgets('adopting a running take never calls record', (tester) async {
    await pump(tester, runningFor: 'person-1', adoptRunning: true);
    expect(recorder.recordCalls, isEmpty);
    expect(recorder.categoryIds, isEmpty);
    expect(recorder.modalVisibleLog, [true]);
    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(key('check-in-recorder-orb'));
    await tester.pump();
    expect(recorded, [('audio-1', Duration.zero)]);
  });

  testWidgets('Stop hands back the entry and the length the clock stood at', (
    tester,
  ) async {
    await pump(tester);
    recorder.tick(progress: const Duration(seconds: 23), dBFS: -20);
    await tester.pump();
    expect(find.text('0:23'), findsOneWidget);

    await tester.tap(key('check-in-recorder-orb'));
    await tester.pump();
    await tester.pump();

    expect(recorder.stopCalls, 1);
    expect(recorded, [('audio-1', const Duration(seconds: 23))]);
  });

  testWidgets('a stop that saves nothing, or throws, is a recording not '
      'saved — never a start that failed', (tester) async {
    await pump(tester, stopResult: null);
    await tester.tap(key('check-in-recorder-orb'));
    await tester.pump();
    expect(failed, [CheckInSpeechFailureKind.recordingNotSaved]);
    expect(recorded, isEmpty);
    // No longer in flight: the host swaps the recorder for its failure
    // card, so the orb only has to stop claiming a stop is under way.
    expect(orb(tester).phase, isNot(CapturePhase.transcribing));

    await pump(tester, stopThrows: true);
    await tester.tap(key('check-in-recorder-orb'));
    await tester.pump();
    expect(failed.last, CheckInSpeechFailureKind.recordingNotSaved);
  });

  testWidgets('the controls go quiet while a stop is in flight', (
    tester,
  ) async {
    final gate = Completer<void>();
    await pump(tester, stopGate: gate);
    await tester.tap(key('check-in-recorder-orb'));
    await tester.pump();

    for (final name in [
      'check-in-recorder-pause',
      'check-in-recorder-discard',
    ]) {
      expect(
        tester.widget<DesignSystemButton>(key(name)).onPressed,
        isNull,
        reason: name,
      );
    }
    expect(orb(tester).onTap, isNull);
    gate.complete();
    await tester.pump();
    expect(recorded, hasLength(1));
  });

  testWidgets('Discard asks first; confirming cancels and says so, backing '
      'out keeps recording', (tester) async {
    await pump(tester);
    await tester.tap(key('check-in-recorder-discard'));
    // Bounded pumps throughout: the orb breathes for as long as the take
    // is live, so nothing here ever "settles".
    await settleModal(tester);
    expect(find.text('Discard recording?'), findsOneWidget);
    // This surface's own words, not the journal recorder's: the audio goes,
    // the check-in stays.
    expect(
      find.text('The audio is deleted. Your check-in stays open.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Keep recording'));
    await settleModal(tester);
    expect(recorder.cancelCalls, 0);
    expect(discarded, 0);

    await tester.tap(key('check-in-recorder-discard'));
    await settleModal(tester);
    // The dialog's confirm, not the recorder's own Discard beneath it. Pump
    // by hand: Stop wears its spinner until the parent takes the recorder
    // down, so nothing here ever "settles".
    await tester.tap(find.text('Discard').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(recorder.cancelCalls, 1);
    expect(discarded, 1);
  });

  testWidgets('Pause and Resume toggle the recorder and the label', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(key('check-in-recorder-pause'));
    await tester.pump();
    expect(recorder.pauseCalls, 1);
    expect(find.text('Resume'), findsOneWidget);
    // The live region says so too, as it says "recording" while live.
    expect(find.bySemanticsLabel('Paused'), findsOneWidget);
    await tester.tap(key('check-in-recorder-pause'));
    await tester.pump();
    expect(recorder.resumeCalls, 1);
    expect(find.text('Pause'), findsOneWidget);
  });

  testWidgets('the clock ticks in place: crossing a digit boundary moves '
      'nothing beneath it', (tester) async {
    await pump(tester);
    recorder.tick(progress: const Duration(seconds: 9));
    await tester.pump();
    final stopBefore = tester.getRect(key('check-in-recorder-orb'));
    final clockBefore = tester.getRect(key('check-in-recorder-clock'));

    recorder.tick(progress: const Duration(minutes: 59, seconds: 59));
    await tester.pump();
    expect(find.text('59:59'), findsOneWidget);
    expect(tester.getRect(key('check-in-recorder-orb')), stopBefore);
    expect(tester.getRect(key('check-in-recorder-clock')), clockBefore);
  });

  testWidgets('the level strip keeps a bounded window of samples', (
    tester,
  ) async {
    await pump(tester);
    for (var i = 0; i < CheckInInlineRecorder.amplitudeWindow + 10; i++) {
      recorder.tick(
        progress: Duration(milliseconds: 20 * i),
        dBFS: -30.0 - i,
      );
      await tester.pump();
    }
    final strip = tester.widget<LiveWaveform>(find.byType(LiveWaveform));
    expect(strip.amplitudes.length, CheckInInlineRecorder.amplitudeWindow);
    expect(strip.amplitudes.every((a) => a >= 0 && a <= 1), isTrue);
  });

  testWidgets("the level strip is Capture's: its width, its height and its "
      'default teal, centred over the orb', (tester) async {
    await pump(tester);
    final strip = tester.widget<LiveWaveform>(find.byType(LiveWaveform));
    expect(strip.width, VoiceOrbZone.waveformWidth);
    expect(strip.height, VoiceOrbZone.waveformSlotHeight);
    expect(strip.color, isNull, reason: 'the widget default — teal');
    expect(
      tester.getRect(find.byType(LiveWaveform)).center.dx,
      closeTo(tester.getRect(find.byKey(VoiceButton.fieldKey)).center.dx, 0.5),
    );
  });

  testWidgets('the clock reads to a screen reader in words', (tester) async {
    await pump(tester);
    recorder.tick(progress: const Duration(seconds: 83));
    await tester.pump();
    final clock = tester.widget<Text>(key('check-in-recorder-clock'));
    expect(clock.data, '1:23');
    expect(clock.semanticsLabel, '1 minute 23 seconds');
  });

  testWidgets('the clock is the UI face with tabular figures — no monospace '
      'left on People', (tester) async {
    await pump(tester);
    final clock = tester.widget<Text>(key('check-in-recorder-clock'));
    final tokens = tester
        .element(find.byType(CheckInInlineRecorder))
        .designTokens;
    expect(clock.style?.fontFamily, isNot('Inconsolata'));
    expect(
      clock.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    // A subtitle, not a heading: the orb is the one large thing here.
    expect(
      clock.style?.fontSize,
      tokens.typography.styles.subtitle.subtitle1.fontSize,
    );
    expect(clock.style?.color, tokens.colors.text.highEmphasis);
  });

  // The sheet brings the indicator back once it has closed; the recorder
  // itself leaves the recording running, the recording sheet's own rule.
  testWidgets('leaving neither stops nor discards the recording', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(recorder.stopCalls, 0);
    expect(recorder.cancelCalls, 0);
  });

  testWidgets('Discard and Pause sit centred under the orb, and there is no '
      'Stop button: the orb is the one Stop', (tester) async {
    await pump(tester);
    final wrap = tester.widget<Wrap>(
      find.ancestor(
        of: key('check-in-recorder-discard'),
        matching: find.byType(Wrap),
      ),
    );
    expect(wrap.alignment, WrapAlignment.center);
    expect(find.byType(DesignSystemButton), findsNWidgets(2));
    expect(find.widgetWithText(DesignSystemButton, 'Stop'), findsNothing);
    // Neither secondary wears the accent: the orb is the way forward.
    expect(
      tester
          .widget<DesignSystemButton>(key('check-in-recorder-discard'))
          .variant,
      DesignSystemButtonVariant.quiet,
    );
    expect(
      tester.widget<DesignSystemButton>(key('check-in-recorder-pause')).variant,
      DesignSystemButtonVariant.outlined,
    );
  });
}
