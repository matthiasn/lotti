import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_orb_palette.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
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

    testWidgets('spans its room up to its own width, and fades out at both '
        'ends', (tester) async {
      for (final (room, expected) in [
        (300.0, 300.0),
        (900.0, RecordingLevelLine.maxWidth),
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
    });

    testWidgets('keeps a bounded history of the live level, and holds still '
        'while paused', (tester) async {
      Future<void> show(AudioRecorderState state) =>
          pumpWith(tester, RecordingLevelLine(state: state));
      List<double> levels() =>
          tester.widget<LiveWaveform>(find.byType(LiveWaveform)).amplitudes;

      await show(_state(dbfs: -60));
      expect(levels(), isEmpty, reason: 'no change yet, no sample');
      for (var i = 0; i < RecordingLevelLine.levelWindow + 10; i++) {
        await show(_state(dbfs: -40.0 + (i % 20)));
      }
      expect(levels(), hasLength(RecordingLevelLine.levelWindow));
      expect(levels().every((level) => level >= 0 && level <= 1), isTrue);
      // The newest sample is the last level shown, normalised.
      const newest = -40.0 + ((RecordingLevelLine.levelWindow + 9) % 20);
      expect(levels().last, normaliseDbfs(newest));

      final held = List<double>.of(levels());
      await show(_state(dbfs: -5, status: AudioRecorderStatus.paused));
      expect(levels(), held, reason: 'a paused take adds nothing');
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

    for (final (name, theme) in [
      ('dark', DesignSystemTheme.dark),
      ('light', DesignSystemTheme.light),
    ]) {
      testWidgets('is a regular heading3 in the UI face, with digits that do '
          "not shift, in the neutral ink, read in the host's words ($name)", (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const RecordingClock(
              progress: Duration(seconds: 23),
              semanticsLabel: '23 seconds',
            ),
            theme: theme(),
          ),
        );
        final text = tester.widget<Text>(find.text('0:00:23'));
        final tokens = tester.element(find.text('0:00:23')).designTokens;
        final heading3 = tokens.typography.styles.heading.heading3;
        expect(text.style?.fontFamily, heading3.fontFamily);
        expect(text.style?.fontSize, heading3.fontSize);
        expect(text.style?.fontWeight, tokens.typography.weight.regular);
        expect(text.style?.fontFeatures, const [
          FontFeature.tabularFigures(),
        ]);
        expect(text.style?.color, tokens.colors.text.highEmphasis);
        expect(text.semanticsLabel, '23 seconds');
      });
    }
  });

  group('RecordingStatus', () {
    for (final (paused, word, dotOf) in [
      (false, 'Recording', (DsTokens t) => t.colors.alert.error.defaultColor),
      (true, 'Paused', (DsTokens t) => t.colors.text.lowEmphasis),
    ]) {
      testWidgets('says $word, the dot red only while live', (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(RecordingStatus(paused: paused)),
        );
        expect(find.text(word), findsOneWidget);
        final tokens = tester.element(find.text(word)).designTokens;
        final dot = tester.widget<Container>(
          find.descendant(
            of: find.byType(RecordingStatus),
            matching: find.byType(Container),
          ),
        );
        expect((dot.decoration! as BoxDecoration).color, dotOf(tokens));
      });
    }
  });

  group('RecordingStage', () {
    Future<void> pump(
      WidgetTester tester, {
      AudioRecorderStatus status = AudioRecorderStatus.recording,
      bool showStatus = true,
      Widget? notice,
      Widget? footer,
      bool announceLevel = false,
    }) => pumpWith(
      tester,
      SingleChildScrollView(
        child: RecordingStage(
          state: _state(status: status),
          showStatus: showStatus,
          levelSemanticsLabel: 'Recording live',
          announceLevel: announceLevel,
          notice: notice,
          footer: footer,
          controls: const SizedBox(key: ValueKey('controls'), height: 10),
        ),
      ),
    );

    testWidgets('stacks status, display, time, notice, level line, controls '
        'and footer, top to bottom', (tester) async {
      await pump(
        tester,
        notice: const Text('notice'),
        footer: const Text('footer'),
      );
      final order = [
        find.byType(RecordingStatus),
        find.byType(RecordingLevelVisualizer),
        find.byType(RecordingClock),
        find.text('notice'),
        find.byType(RecordingLevelLine),
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

    testWidgets('says nothing of the take where the host says it, or before '
        'one runs', (tester) async {
      await pump(tester, showStatus: false);
      expect(find.byType(RecordingStatus), findsNothing);
      await pump(tester, status: AudioRecorderStatus.stopped);
      expect(find.byType(RecordingStatus), findsNothing);
      await pump(tester, status: AudioRecorderStatus.paused);
      expect(find.text('Paused'), findsOneWidget);
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

    testWidgets('discard, the red Stop and pause, left to right, each its '
        'own act', (tester) async {
      await pump(tester);
      final discard = tester.getRect(key('cancel_recording'));
      final pause = tester.getRect(key('pause_resume_button'));
      final stop = tester.getRect(key('stop_recording'));
      expect(discard.right, lessThan(stop.left));
      expect(stop.right, lessThan(pause.left));
      // The quiet rings are full 48px targets; Stop is the bigger disc, and
      // all three share a centre line.
      expect(discard.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(pause.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(stop.height, greaterThan(pause.height));
      expect(discard.center.dy, closeTo(stop.center.dy, 0.5));
      expect(pause.center.dy, closeTo(stop.center.dy, 0.5));

      await tester.tap(key('cancel_recording'));
      await tester.tap(key('pause_resume_button'));
      await tester.tap(key('stop_recording'));
      expect(calls, ['discard', 'pause', 'stop']);

      // Stop is the one filled red disc, its square in the alert-fill ink.
      final tokens = tester.element(key('stop_recording')).designTokens;
      final fills = tester
          .widgetList<Container>(
            find.descendant(
              of: key('stop_recording'),
              matching: find.byType(Container),
            ),
          )
          .map((c) => (c.decoration as BoxDecoration?)?.color)
          .toList();
      expect(fills, [
        tokens.colors.alert.error.defaultColor,
        tokens.colors.text.onInteractiveAlert,
      ]);
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

    testWidgets('on a 150px screen the row wraps: nothing overflows and '
        'every control stays on screen and tappable', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Center(
            child: SizedBox(
              width: 150,
              child: RecordingTransportControls(
                paused: false,
                onDiscard: () => calls.add('discard'),
                onTogglePause: () => calls.add('pause'),
                onStop: () => calls.add('stop'),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(
            size: Size(150, 800),
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
