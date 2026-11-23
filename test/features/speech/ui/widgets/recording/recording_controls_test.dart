import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_timer_pill.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_voice_waveform.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/utils/recording_levels.dart';
import 'package:lotti/widgets/celebration/celebration_preferences_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../widget_test_utils.dart';

AudioRecorderState _state({
  double dbfs = -30,
  AudioRecorderStatus status = AudioRecorderStatus.recording,
  Duration progress = const Duration(seconds: 3),
}) => AudioRecorderState(
  status: status,
  progress: progress,
  dBFS: dbfs,
  showIndicator: false,
  modalVisible: true,
);

void main() {
  Future<void> pumpWith(
    WidgetTester tester,
    Widget child, {
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(child, theme: theme),
    );
    await tester.pump();
  }

  group('RecordingLevelLine', () {
    DesignSystemVoiceWaveform waveform(WidgetTester tester) =>
        tester.widget(find.byType(DesignSystemVoiceWaveform));

    testWidgets("is the app's one voice waveform at the transport row's "
        "width, fed at the recorder's sample rate", (tester) async {
      for (final wide in [false, true]) {
        await pumpWith(
          tester,
          Center(
            child: SizedBox(
              width: wide ? 700 : 150,
              // Loose inside its room, as in the stage's column.
              child: Center(child: RecordingLevelLine(state: _state())),
            ),
          ),
        );
        final row = RecordingTransportControls.rowWidth(
          tester.element(find.byType(RecordingLevelLine)),
        );
        expect(
          tester.getSize(find.byType(DesignSystemVoiceWaveform)).width,
          wide ? row : 150,
        );
      }
      expect(
        waveform(tester).sampleInterval,
        const Duration(milliseconds: intervalMs),
      );
      expect(waveform(tester).color, isNull, reason: 'the accent, as chat');
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
    List<double> levels(WidgetTester tester) => waveform(tester).levels;

    testWidgets('keeps a bounded window of the live level, one per sample, '
        'and holds still while paused', (tester) async {
      await show(tester, sample(0, -60));
      expect(levels(tester), isEmpty, reason: 'no tick yet, no sample');
      const ticks = RecordingLevelLine.levelWindow + 10;
      for (var i = 1; i <= ticks; i++) {
        await show(tester, sample(i, -40.0 + (i % 20)));
      }
      expect(levels(tester), hasLength(RecordingLevelLine.levelWindow));
      expect(levels(tester).every((level) => level >= 0 && level <= 1), isTrue);
      expect(levels(tester).last, normaliseDbfs(-40.0 + (ticks % 20)));

      final held = List<double>.of(levels(tester));
      await show(
        tester,
        sample(ticks + 1, -5, status: AudioRecorderStatus.paused),
      );
      expect(levels(tester), held, reason: 'a paused take adds nothing');
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
        levels(tester).toSet(),
        {normaliseDbfs(-60)},
        reason: 'the loud start has left the window',
      );
    });

    testWidgets('a stopped take clears the line, so a host that stays up '
        'starts its next take empty', (tester) async {
      await show(tester, sample(0, -60));
      await show(tester, sample(1, -10));
      await show(tester, sample(2, -10));
      expect(levels(tester), isNotEmpty);

      await show(tester, sample(3, -10, status: AudioRecorderStatus.stopped));
      expect(levels(tester), isEmpty);
      await show(tester, sample(1, -20));
      expect(levels(tester), [normaliseDbfs(-20)]);
    });
  });

  group('RecordingStage', () {
    Future<void> pump(
      WidgetTester tester, {
      AudioRecorderStatus status = AudioRecorderStatus.recording,
      Widget? notice,
      Widget? footer,
      bool announceLevel = false,
    }) => pumpWith(
      tester,
      SingleChildScrollView(
        child: RecordingStage(
          state: _state(status: status),
          levelSemanticsLabel: 'Recording live',
          announceLevel: announceLevel,
          notice: notice,
          footer: footer,
          controls: const SizedBox(key: ValueKey('controls'), height: 10),
        ),
      ),
    );

    testWidgets('stacks the level line, notice, controls and footer, top to '
        'bottom — and nothing else: no orb, no meter', (tester) async {
      await pump(
        tester,
        notice: const Text('notice'),
        footer: const Text('footer'),
      );
      final order = [
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
      // The level line is the stage's first and only picture.
      expect(
        order.first.top,
        closeTo(tester.getRect(find.byType(RecordingStage)).top, 0.5),
      );
      expect(
        find.descendant(
          of: find.byType(RecordingStage),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the level line and a transport row share their edges — '
        'one measure, on one axis', (tester) async {
      await pumpWith(
        tester,
        SingleChildScrollView(
          child: RecordingStage(
            state: _state(),
            controls: RecordingTransportControls(
              paused: false,
              progress: const Duration(seconds: 3),
              onDiscard: () {},
              onTogglePause: () {},
              onStop: () {},
            ),
          ),
        ),
      );
      final line = tester.getRect(find.byType(DesignSystemVoiceWaveform));
      final row = tester.getRect(find.byType(RecordingTransportControls));
      final discard = tester.getRect(
        find.byKey(RecordingTransportControls.discardKey),
      );
      final pause = tester.getRect(
        find.byKey(RecordingTransportControls.pauseKey),
      );
      expect(line.left, closeTo(discard.left, 0.5));
      expect(line.right, closeTo(pause.right, 0.5));
      expect(line.center.dx, closeTo(row.center.dx, 0.5));
    });

    testWidgets('one gap between the line, the controls and the footer, in '
        'every host', (tester) async {
      await pump(tester, footer: const Text('footer'));
      final tokens = tester.element(find.byType(RecordingStage)).designTokens;
      final controls = tester.getRect(find.byKey(const ValueKey('controls')));
      expect(
        controls.top - tester.getRect(find.byType(RecordingLevelLine)).bottom,
        closeTo(tokens.spacing.step5, 0.5),
      );
      expect(
        tester.getRect(find.text('footer')).top - controls.bottom,
        closeTo(tokens.spacing.step5, 0.5),
      );
    });

    for (final announce in [true, false]) {
      testWidgets('the level line is one label for a reader — live: '
          '$announce', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, announceLevel: announce);
        final node = tester.getSemantics(find.byType(RecordingLevelLine));
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
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          RecordingTransportControls(
            paused: paused,
            progress: const Duration(seconds: 65),
            busy: busy,
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
      // targets, on one centre line; the solid pause glyph a size below the
      // stroked ✕, so the two rings weigh the same.
      expect(
        tester.widget<Icon>(find.byIcon(LottiIconsFilled.pause)).size,
        IconSizes.m,
      );
      expect(
        tester.widget<Icon>(find.byIcon(LottiIcons.close)).size,
        IconSizes.l,
      );
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
      await pump(tester);
      expect(tester.getSemantics(key('cancel_recording')).label, 'Discard');
      expect(tester.getSemantics(key('pause_resume_button')).label, 'Pause');
      expect(tester.getSemantics(key('stop_recording')).label, 'Stop');

      await pump(tester, paused: true);
      expect(tester.getSemantics(key('pause_resume_button')).label, 'Resume');
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
  });
}
