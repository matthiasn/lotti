import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_orb_palette.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_timer_pill.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_levels.dart';
import 'package:lotti/features/speech/state/recording_style.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/features/speech/ui/widgets/recording/live_waveform.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:lotti/widgets/celebration/celebration_preferences_controller.dart';
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
  Duration progress = const Duration(seconds: 3),
}) => AudioRecorderState(
  status: status,
  progress: progress,
  vu: vu,
  dBFS: dbfs,
  showIndicator: false,
  modalVisible: true,
);

void main() {
  Future<void> pumpWith(
    WidgetTester tester,
    Widget child, {
    Future<String?> Function()? style,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        child,
        theme: theme,
        overrides: [
          recordingStyleAppPrefsProvider.overrideWithValue(
            _prefs(style ?? () async => 'modern'),
          ),
        ],
      ),
    );
    await tester.pump();
  }

  group('RecordingLevelVisualizer', () {
    Future<void> pump(
      WidgetTester tester, {
      required Future<String?> Function() style,
      double width = 300,
      ThemeData? theme,
    }) => pumpWith(
      tester,
      Center(
        child: SizedBox(
          width: width,
          child: RecordingLevelVisualizer(state: _state(dbfs: -18)),
        ),
      ),
      style: style,
      theme: theme,
    );

    const pool = ValueKey('recording-visualizer-pool');

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
      expect(orb.palette, AiVoiceOrbPalette.fromTokens(tokens));
      expect(find.byType(AnalogVuMeter), findsNothing);
    });

    testWidgets('on dark the orb glows on the surface itself, no pool', (
      tester,
    ) async {
      await pump(
        tester,
        style: () async => 'modern',
        theme: DesignSystemTheme.dark(),
      );
      expect(find.byType(AiVoiceInputShader), findsOneWidget);
      expect(find.byKey(pool), findsNothing);
    });

    testWidgets('on light the orb sits on a lit pool: the brightest surface '
        'at its centre, its glint at the ring, fading to nothing', (
      tester,
    ) async {
      await pump(
        tester,
        style: () async => 'modern',
        theme: DesignSystemTheme.light(),
      );
      expect(
        find.descendant(
          of: find.byKey(pool),
          matching: find.byType(AiVoiceInputShader),
        ),
        findsOneWidget,
      );
      final tokens = tester.element(find.byKey(pool)).designTokens;
      final palette = AiVoiceOrbPalette.fromTokens(tokens);
      final decoration =
          tester.widget<DecoratedBox>(find.byKey(pool)).decoration
              as BoxDecoration;
      final gradient = decoration.gradient! as RadialGradient;
      expect(
        gradient.colors.first.withValues(alpha: 1),
        tokens.colors.background.level01.withValues(alpha: 1),
      );
      expect(
        gradient.colors[1].withValues(alpha: 1),
        palette.glint.withValues(alpha: 1),
      );
      expect(gradient.colors.last.a, 0);
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

    testWidgets('while the preference loads it is the meter, so the orb '
        'never flashes in and out', (tester) async {
      await pump(tester, style: () => Completer<String?>().future);
      expect(find.byType(AnalogVuMeter), findsOneWidget);
      expect(find.byType(AiVoiceInputShader), findsNothing);
    });
  });

  group('RecordingLevelLine', () {
    for (final (style, inkOf) in [
      ('modern', (DsTokens t) => t.colors.interactive.enabled),
      ('analogue', (DsTokens t) => t.colors.text.highEmphasis),
    ]) {
      testWidgets("pairs the $style look with onboarding's ink", (
        tester,
      ) async {
        await pumpWith(
          tester,
          RecordingLevelLine(state: _state()),
          style: () async => style,
        );
        final bars = tester.widget<LiveWaveform>(find.byType(LiveWaveform));
        final tokens = tester.element(find.byType(LiveWaveform)).designTokens;
        expect(bars.color, inkOf(tokens));
        expect(bars.barCount, RecordingLevelLine.barCount);
      });
    }

    testWidgets("spans its room up to the orb's diameter, and fades out "
        'at its oldest end', (tester) async {
      for (final (room, expected) in [
        (150.0, 150.0),
        (900.0, RecordingLevelVisualizer.defaultOrbSize),
      ]) {
        await pumpWith(
          tester,
          Center(
            child: SizedBox(
              width: room,
              child: RecordingLevelLine(state: _state()),
            ),
          ),
        );
        expect(
          tester.widget<LiveWaveform>(find.byType(LiveWaveform)).width,
          expected,
        );
      }
      final mask = tester.widget<ShaderMask>(
        find.ancestor(
          of: find.byType(LiveWaveform),
          matching: find.byType(ShaderMask),
        ),
      );
      expect(mask.blendMode, BlendMode.dstIn);
      // Only the oldest end fades: from transparent at the left to opaque,
      // and opaque from there to the newest bar at the right.
      final tokens = tester.element(find.byType(LiveWaveform)).designTokens;
      final fade = RecordingLevelLine.fadeOf(tokens);
      expect(fade.colors.first.a, 0);
      expect(fade.colors.last.a, tokens.colors.text.highEmphasis.a);
      expect(fade.stops!.last, lessThan(0.5));
      expect(fade.begin, Alignment.centerLeft);
      expect(
        mask.shaderCallback(const Rect.fromLTWH(0, 0, 100, 10)),
        isNotNull,
      );
      // Silence lies flat on a hairline in the rings' decorative tone.
      expect(
        tester.widget<LiveWaveform>(find.byType(LiveWaveform)).baselineColor,
        tokens.colors.decorative.level02,
      );
    });

    // A sample per recorder tick, as the controller advances progress on
    // every one: the 20 ms cadence the recorder samples at.
    AudioRecorderState sample(
      int tick,
      double dbfs, {
      AudioRecorderStatus status = AudioRecorderStatus.recording,
    }) => _state(
      dbfs: dbfs,
      status: status,
      progress: Duration(milliseconds: 20 * tick),
    );

    Future<void> show(WidgetTester tester, AudioRecorderState state) =>
        pumpWith(tester, RecordingLevelLine(state: state));
    List<double> bars(WidgetTester tester) =>
        tester.widget<LiveWaveform>(find.byType(LiveWaveform)).amplitudes;

    testWidgets("under the meter it takes the meter's width, one measure "
        'with the look above it', (tester) async {
      await pumpWith(
        tester,
        Center(
          child: SizedBox(
            width: 900,
            child: RecordingLevelLine(state: _state()),
          ),
        ),
        style: () async => 'analogue',
      );
      expect(
        tester.widget<LiveWaveform>(find.byType(LiveWaveform)).width,
        RecordingLevelVisualizer.defaultMeterWidth,
      );
    });

    testWidgets('keeps a bounded window of the live level, drawn as one bar '
        'per pair of samples, and holds still while paused', (tester) async {
      await show(tester, sample(0, -60));
      expect(bars(tester), isEmpty, reason: 'no tick yet, no sample');
      const ticks = RecordingLevelLine.levelWindow + 10;
      for (var i = 1; i <= ticks; i++) {
        await show(tester, sample(i, -40.0 + (i % 20)));
      }
      // The whole window is drawn: every retained sample reaches a bar.
      expect(bars(tester), hasLength(RecordingLevelLine.barCount));
      expect(bars(tester).every((level) => level >= 0 && level <= 1), isTrue);
      // The newest bar is the louder of the newest two samples.
      expect(
        bars(tester).last,
        normaliseDbfs(-40.0 + (ticks % 20)),
        reason: 'tick $ticks is louder than tick ${ticks - 1}',
      );

      final held = List<double>.of(bars(tester));
      await show(
        tester,
        sample(ticks + 1, -5, status: AudioRecorderStatus.paused),
      );
      expect(bars(tester), held, reason: 'a paused take adds nothing');
    });

    testWidgets('a steady level is still a sample, so silence ages the loud '
        'bars out', (tester) async {
      await show(tester, sample(0, -60));
      await show(tester, sample(1, -5));
      await show(tester, sample(2, -5));
      for (var i = 3; i < 3 + RecordingLevelLine.levelWindow; i++) {
        await show(tester, sample(i, -60));
      }
      expect(
        bars(tester).toSet(),
        {normaliseDbfs(-60)},
        reason: 'the loud start has left the window',
      );
    });

    testWidgets('a stopped take clears the line, so a host that stays up '
        'starts its next take empty', (tester) async {
      await show(tester, sample(0, -60));
      await show(tester, sample(1, -10));
      await show(tester, sample(2, -10));
      expect(bars(tester), isNotEmpty);

      await show(tester, sample(3, -10, status: AudioRecorderStatus.stopped));
      expect(bars(tester), isEmpty);
      await show(tester, sample(1, -20));
      expect(bars(tester), [normaliseDbfs(-20)]);
    });

    test('pairs samples from the newest back, the louder of each', () {
      expect(RecordingLevelLine.barsOf(const <double>[]), isEmpty);
      expect(RecordingLevelLine.barsOf(const [0.3]), [0.3]);
      expect(RecordingLevelLine.barsOf(const [0.1, 0.5, 0.4, 0.2, 0.9]), [
        0.1,
        0.5,
        0.9,
      ]);
    });
  });

  group('RecordingStage', () {
    Future<void> pump(
      WidgetTester tester, {
      AudioRecorderStatus status = AudioRecorderStatus.recording,
      bool compact = false,
      Widget? notice,
      Widget? footer,
      bool announceLevel = false,
    }) => pumpWith(
      tester,
      SingleChildScrollView(
        child: RecordingStage(
          state: _state(status: status),
          compact: compact,
          levelSemanticsLabel: 'Recording live',
          announceLevel: announceLevel,
          notice: notice,
          footer: footer,
          controls: const SizedBox(key: ValueKey('controls'), height: 10),
        ),
      ),
    );

    testWidgets('stacks display, level line, notice, controls and footer, '
        'top to bottom', (tester) async {
      await pump(
        tester,
        notice: const Text('notice'),
        footer: const Text('footer'),
      );
      final order = [
        find.byType(RecordingLevelVisualizer),
        find.byType(RecordingLevelLine),
        find.text('notice'),
        find.byKey(const ValueKey('controls')),
        find.text('footer'),
      ].map(tester.getRect).toList();
      for (var i = 1; i < order.length; i++) {
        expect(
          order[i].top,
          greaterThanOrEqualTo(order[i - 1].bottom - 0.5),
          reason: 'item $i',
        );
      }
    });

    testWidgets("the level line takes the orb's measure, on its axis", (
      tester,
    ) async {
      await pump(tester);
      final orb = tester.getRect(find.byType(AiVoiceInputShader));
      final line = tester.getRect(find.byType(LiveWaveform));
      expect(line.width, closeTo(orb.width, 0.5));
      expect(line.center.dx, closeTo(orb.center.dx, 0.5));
    });

    testWidgets('one column no wider than the level line, centred in a wide '
        'host', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, footer: const SizedBox(width: 2000, height: 4));
      final column = tester.getRect(
        find
            .descendant(
              of: find.byType(RecordingStage),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(column.width, RecordingLevelLine.maxWidth);
      expect(column.center.dx, closeTo(600, 0.5));
    });

    testWidgets('compact leaves the pictures out and lets the level line '
        'speak for them', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, compact: true);
      expect(find.byType(RecordingLevelVisualizer), findsNothing);
      expect(
        tester.getSemantics(find.byType(RecordingLevelLine)).label,
        'Recording live',
      );
      semantics.dispose();
    });

    testWidgets('compact tightens the gaps between the line, controls and '
        'footer by a step', (tester) async {
      double gapBelowLine() =>
          tester.getRect(find.byKey(const ValueKey('controls'))).top -
          tester.getRect(find.byType(RecordingLevelLine)).bottom;

      await pump(tester, footer: const Text('footer'));
      final tokens = tester.element(find.byType(RecordingStage)).designTokens;
      expect(gapBelowLine(), closeTo(tokens.spacing.step6, 0.5));
      await pump(tester, compact: true, footer: const Text('footer'));
      expect(gapBelowLine(), closeTo(tokens.spacing.step4, 0.5));
    });

    for (final announce in [true, false]) {
      testWidgets('the pictures are one label for a reader — live: '
          '$announce', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, announceLevel: announce);
        final node = tester.getSemantics(
          find.byType(RecordingLevelVisualizer),
        );
        expect(node.label, 'Recording live');
        expect(node.flagsCollection.isLiveRegion, announce);
        semantics.dispose();
      });
    }
  });

  group('RecordingOption', () {
    testWidgets('its name in the caption voice, then a small toggle; the '
        'whole row flips it, and a reader hears one switch by its name', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final changes = <bool>[];
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          RecordingOption(
            label: 'Transcribe',
            value: true,
            onChanged: changes.add,
          ),
        ),
      );
      final toggle = tester.widget<DesignSystemToggle>(
        find.byType(DesignSystemToggle),
      );
      expect(toggle.size, DesignSystemToggleSize.small);
      expect(toggle.value, isTrue);
      expect(
        tester.getRect(find.text('Transcribe')).right,
        lessThan(tester.getRect(find.byType(DesignSystemToggle)).left),
      );
      final tokens = tester.element(find.byType(RecordingOption)).designTokens;
      expect(
        tester.widget<Text>(find.text('Transcribe')).style,
        recordingCaptionStyle(tokens),
      );

      await tester.tap(find.text('Transcribe'));
      await tester.tap(find.byType(DesignSystemToggle));
      expect(changes, [false, false]);

      expect(find.bySemanticsLabel('Transcribe'), findsOneWidget);
      semantics.dispose();
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
            progress: const Duration(seconds: 65),
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

    testWidgets('discard, the red Stop and pause, left to right, each its '
        'own act', (tester) async {
      await pump(tester);
      final discard = tester.getRect(key('cancel_recording'));
      final pause = tester.getRect(key('pause_resume_button'));
      final stop = tester.getRect(key('stop_recording'));
      expect(discard.right, lessThan(stop.left));
      expect(stop.right, lessThan(pause.left));
      // The quiet rings and the Stop pill are one height, full 48px
      // targets, on one centre line.
      expect(discard.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(pause.height, closeTo(discard.height, 0.5));
      expect(stop.height, closeTo(discard.height, 0.5));
      expect(discard.center.dy, closeTo(stop.center.dy, 0.5));
      expect(pause.center.dy, closeTo(stop.center.dy, 0.5));

      await tester.tap(key('cancel_recording'));
      await tester.tap(key('pause_resume_button'));
      await tester.tap(key('stop_recording'));
      expect(calls, ['discard', 'pause', 'stop']);

      // Stop is the app's running-clock pill — a task's Track time — with
      // the take's time inside it.
      final pill = tester.widget<DesignSystemTimerPill>(
        find.descendant(
          of: key('stop_recording'),
          matching: find.byType(DesignSystemTimerPill),
        ),
      );
      expect(pill.running, isTrue);
      expect(pill.label, '01:05');
      expect(find.text('01:05'), findsOneWidget);
    });

    testWidgets('Stop is one button named Stop whose value is the time, in '
        "the host's words when it has them", (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      expect(tester.getSemantics(key('stop_recording')).label, 'Stop');
      expect(tester.getSemantics(key('stop_recording')).value, '01:05');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          RecordingTransportControls(
            paused: false,
            progress: const Duration(seconds: 65),
            progressSemanticsLabel: '1 minute 5 seconds',
            onDiscard: () {},
            onTogglePause: () {},
            onStop: () {},
          ),
        ),
      );
      expect(
        tester.getSemantics(key('stop_recording')).value,
        '1 minute 5 seconds',
      );
      semantics.dispose();
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
      expect(find.byIcon(LottiIconsFilled.play), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('on a 280px screen at 3x text the row wraps: nothing '
        'overflows and every control stays on screen and tappable', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Center(
            child: SizedBox(
              width: 280,
              child: RecordingTransportControls(
                paused: false,
                progress: const Duration(seconds: 65),
                onDiscard: () => calls.add('discard'),
                onTogglePause: () => calls.add('pause'),
                onStop: () => calls.add('stop'),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(
            size: Size(280, 800),
            textScaler: TextScaler.linear(3),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final row = tester.getRect(find.byType(RecordingTransportControls));
      final stop = tester.getRect(key('stop_recording'));
      final pause = tester.getRect(key('pause_resume_button'));
      for (final control in [stop, pause]) {
        expect(control.left, greaterThanOrEqualTo(row.left - 0.5));
        expect(control.right, lessThanOrEqualTo(row.right + 0.5));
      }
      // Pause took a line of its own beneath discard and Stop.
      expect(pause.top, greaterThan(stop.bottom - 0.5));
      await tester.tap(key('stop_recording'));
      await tester.tap(key('pause_resume_button'));
      expect(calls, ['stop', 'pause']);
    });

    for (final (haptics, expected) in [
      (
        true,
        ['HapticFeedbackType.lightImpact', 'HapticFeedbackType.mediumImpact'],
      ),
      (false, <String>[]),
    ]) {
      testWidgets('a tap is felt — firmer on Stop — only with haptics on '
          '(haptics: $haptics)', (tester) async {
        final felt = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              felt.add(call.arguments as String);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            RecordingTransportControls(
              paused: false,
              progress: const Duration(seconds: 65),
              onDiscard: () => calls.add('discard'),
              onTogglePause: () => calls.add('pause'),
              onStop: () => calls.add('stop'),
            ),
            overrides: [
              celebrationPreferencesProvider.overrideWithValue(
                const CelebrationPreferences.allEnabled().copyWith(
                  haptics: haptics,
                ),
              ),
            ],
          ),
        );
        await tester.tap(key('pause_resume_button'));
        await tester.tap(key('stop_recording'));
        expect(calls, ['pause', 'stop']);
        expect(felt, expected);
      });
    }

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
            progress: const Duration(seconds: 65),
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
