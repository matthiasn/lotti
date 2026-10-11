import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_levels.dart';
import 'package:lotti/features/speech/state/recording_style.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/features/speech/ui/widgets/recording/live_waveform.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../widget_test_utils.dart';

AppPrefs _prefs(Future<String?> Function() style) => AppPrefs(
  getBool: (_) async => null,
  setBool: ({required key, required value}) async => true,
  getString: (key) => key == recordingStylePrefsKey ? style() : Future.value(),
  setString: ({required key, required value}) async => true,
);

AudioRecorderState _state({
  double dbfs = -30,
  double vu = -10,
  AudioRecorderStatus status = AudioRecorderStatus.recording,
}) => AudioRecorderState(
  status: status,
  progress: const Duration(seconds: 3),
  vu: vu,
  dBFS: dbfs,
  showIndicator: false,
  modalVisible: true,
);

void main() {
  group('RecordingLevelVisualizer', () {
    Future<void> pump(
      WidgetTester tester, {
      required Future<String?> Function() style,
      double width = 300,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Center(
            child: SizedBox(
              width: width,
              child: RecordingLevelVisualizer(state: _state(dbfs: -18)),
            ),
          ),
          overrides: [
            recordingStyleAppPrefsProvider.overrideWithValue(_prefs(style)),
          ],
        ),
      );
      await tester.pump();
    }

    testWidgets('the modern look is the orb, on the live level, in the '
        'accent', (tester) async {
      await pump(tester, style: () async => 'modern');
      final orb = tester.widget<AiVoiceInputShader>(
        find.byType(AiVoiceInputShader),
      );
      final tokens = tester
          .element(find.byType(AiVoiceInputShader))
          .designTokens;
      expect(orb.dbfs, -18);
      expect(orb.size, RecordingLevelVisualizer.defaultOrbSize);
      expect(orb.primaryColor, tokens.colors.interactive.enabled);
      expect(find.byType(AnalogVuMeter), findsNothing);
    });

    testWidgets('the analogue look is the meter, never wider than its room', (
      tester,
    ) async {
      await pump(tester, style: () async => 'analogue');
      final meter = tester.widget<AnalogVuMeter>(find.byType(AnalogVuMeter));
      expect(meter.size, 300);
      expect(find.byType(AiVoiceInputShader), findsNothing);
    });

    testWidgets('with room to spare the meter keeps its own width', (
      tester,
    ) async {
      await pump(tester, style: () async => 'analogue', width: 600);
      final meter = tester.widget<AnalogVuMeter>(find.byType(AnalogVuMeter));
      expect(meter.size, RecordingLevelVisualizer.defaultMeterWidth);
    });

    for (final (style, inkOf) in [
      ('modern', (DsTokens t) => t.colors.interactive.enabled),
      ('analogue', (DsTokens t) => t.colors.text.highEmphasis),
    ]) {
      testWidgets("pairs the $style look with onboarding's bars, under it", (
        tester,
      ) async {
        await pump(tester, style: () async => style);
        final bars = tester.widget<LiveWaveform>(find.byType(LiveWaveform));
        final tokens = tester.element(find.byType(LiveWaveform)).designTokens;
        expect(bars.color, inkOf(tokens));
        final primary = find.byKey(
          ValueKey(
            style == 'modern'
                ? 'recording-visualizer-orb'
                : 'recording-visualizer-meter',
          ),
        );
        expect(
          tester.getRect(find.byType(LiveWaveform)).top,
          greaterThanOrEqualTo(tester.getRect(primary).bottom),
        );
      });
    }

    testWidgets('the bars keep a bounded history of the live level, and '
        'hold still while paused', (tester) async {
      Future<void> show(AudioRecorderState state) => tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          RecordingLevelVisualizer(state: state),
          overrides: [
            recordingStyleAppPrefsProvider.overrideWithValue(
              _prefs(() async => 'modern'),
            ),
          ],
        ),
      );
      List<double> levels() =>
          tester.widget<LiveWaveform>(find.byType(LiveWaveform)).amplitudes;

      await show(_state(dbfs: -60));
      expect(levels(), isEmpty, reason: 'no change yet, no sample');
      for (var i = 0; i < RecordingLevelVisualizer.levelWindow + 10; i++) {
        await show(_state(dbfs: -40.0 + (i % 20)));
      }
      expect(levels(), hasLength(RecordingLevelVisualizer.levelWindow));
      expect(levels().every((level) => level >= 0 && level <= 1), isTrue);
      // The newest sample is the last level shown, normalised.
      const newest = -40.0 + ((RecordingLevelVisualizer.levelWindow + 9) % 20);
      expect(levels().last, normaliseDbfs(newest));

      final held = List<double>.of(levels());
      await show(_state(dbfs: -5, status: AudioRecorderStatus.paused));
      expect(levels(), held, reason: 'a paused take adds nothing');
    });

    testWidgets('while the preference loads it is the meter, so the orb '
        'never flashes in and out', (tester) async {
      await pump(tester, style: () => Completer<String?>().future);
      expect(find.byType(AnalogVuMeter), findsOneWidget);
      expect(find.byType(AiVoiceInputShader), findsNothing);
    });
  });

  group('RecordingClock', () {
    test('formats as h:mm:ss without the fraction', () {
      expect(
        RecordingClock.format(const Duration(seconds: 42, milliseconds: 730)),
        '0:00:42',
      );
      expect(
        RecordingClock.format(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    testWidgets("is the accent in the monospace face, read in the host's "
        'words', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const RecordingClock(
            progress: Duration(seconds: 23),
            semanticsLabel: '23 seconds',
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('0:00:23'));
      final tokens = tester.element(find.text('0:00:23')).designTokens;
      expect(text.style?.fontFamily, 'Inconsolata');
      expect(text.style?.color, tokens.colors.interactive.enabled);
      expect(text.semanticsLabel, '23 seconds');
    });
  });

  group('RecordingTransportControls', () {
    final calls = <String>[];
    setUp(calls.clear);

    Future<void> pump(
      WidgetTester tester, {
      bool paused = false,
      bool busy = false,
      String? discardLabel,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          RecordingTransportControls(
            paused: paused,
            busy: busy,
            discardLabel: discardLabel,
            onDiscard: () => calls.add('discard'),
            onTogglePause: () => calls.add('pause'),
            onStop: () => calls.add('stop'),
          ),
        ),
      );
      await tester.pump();
    }

    Finder key(String name) => find.byKey(ValueKey(name));

    testWidgets('discard, pause and the red Stop, left to right, each its '
        'own act', (tester) async {
      await pump(tester);
      final discard = tester.getRect(key('cancel_recording'));
      final pause = tester.getRect(key('pause_resume_button'));
      final stop = tester.getRect(key('stop_recording'));
      expect(discard.right, lessThan(pause.left));
      expect(pause.right, lessThan(stop.left));
      // The round controls are full 48px targets.
      expect(discard.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(pause.height, greaterThanOrEqualTo(kMinInteractiveDimension));

      await tester.tap(key('cancel_recording'));
      await tester.tap(key('pause_resume_button'));
      await tester.tap(key('stop_recording'));
      expect(calls, ['discard', 'pause', 'stop']);

      // Stop wears the error ink, the live dot inside it.
      final tokens = tester.element(key('stop_recording')).designTokens;
      expect(
        tester.widget<Text>(find.text('Stop')).style?.color,
        tokens.colors.alert.error.defaultColor,
      );
    });

    testWidgets('each control is one button by its name; paused, the pause '
        'control offers Resume', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, discardLabel: 'Discard');
      expect(tester.getSemantics(key('cancel_recording')).label, 'Discard');
      expect(tester.getSemantics(key('pause_resume_button')).label, 'Pause');
      expect(tester.getSemantics(key('stop_recording')).label, 'Stop');

      await pump(tester, paused: true);
      expect(tester.getSemantics(key('pause_resume_button')).label, 'Resume');
      expect(tester.getSemantics(key('cancel_recording')).label, 'Cancel');
      expect(find.byIcon(LottiIcons.play), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('on a 200px screen at 3x text the row wraps: nothing '
        'overflows and Stop stays on screen and tappable', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Center(
            child: SizedBox(
              width: 200,
              child: RecordingTransportControls(
                paused: false,
                onDiscard: () => calls.add('discard'),
                onTogglePause: () => calls.add('pause'),
                onStop: () => calls.add('stop'),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(
            size: Size(200, 800),
            textScaler: TextScaler.linear(3),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final row = tester.getRect(find.byType(RecordingTransportControls));
      final stop = tester.getRect(key('stop_recording'));
      final pause = tester.getRect(key('pause_resume_button'));
      expect(stop.left, greaterThanOrEqualTo(row.left - 0.5));
      expect(stop.right, lessThanOrEqualTo(row.right + 0.5));
      // Stop took a line of its own beneath the round controls.
      expect(stop.top, greaterThan(pause.bottom - 0.5));
      await tester.tap(key('stop_recording'));
      expect(calls, ['stop']);
    });

    testWidgets('busy, nothing takes a tap', (tester) async {
      await pump(tester, busy: true);
      for (final name in [
        'cancel_recording',
        'pause_resume_button',
        'stop_recording',
      ]) {
        await tester.tap(key(name), warnIfMissed: false);
      }
      expect(calls, isEmpty);
    });

    testWidgets('a host can name the controls its own way', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          RecordingTransportControls(
            paused: false,
            discardKey: const ValueKey('host-discard'),
            pauseKey: const ValueKey('host-pause'),
            stopKey: const ValueKey('host-stop'),
            onDiscard: () {},
            onTogglePause: () {},
            onStop: () => calls.add('stop'),
          ),
        ),
      );
      await tester.tap(key('host-stop'));
      expect(calls, ['stop']);
      expect(key('host-discard'), findsOneWidget);
      expect(key('host-pause'), findsOneWidget);
    });
  });
}
