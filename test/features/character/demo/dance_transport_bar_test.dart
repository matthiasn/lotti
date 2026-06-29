import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/demo/dance_transport_bar.dart';

import '../../../widget_test_utils.dart';

/// Records how many times each transport intent fired, plus the last seek.
class _Recorder {
  int play = 0;
  int loop = 0;
  int captions = 0;
  int backdrop = 0;
  double? seek;
}

const _amplitudes = <double>[0.2, 0.6, 0.9, 0.4, 0.7, 0.3, 0.85, 0.5];
const _sections = <DanceWaveformSection>[
  DanceWaveformSection(start: 0, end: 72, label: 'A'),
  DanceWaveformSection(start: 72, end: 144.06, label: 'B'),
];

Future<_Recorder> _pump(
  WidgetTester tester, {
  bool loading = false,
  bool playing = false,
  bool loop = true,
  bool showCaptions = false,
  bool captionsAvailable = true,
  bool useNewBackdrop = true,
  double bpm = 120,
  double positionSec = 93.433,
  double durationSec = 144.06,
  String? sectionLabel = 'B',
  bool energetic = true,
  List<double>? amplitudes = _amplitudes,
  List<DanceWaveformSection> sections = _sections,
  Size size = const Size(1280, 800),
}) async {
  final rec = _Recorder();
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            const Expanded(child: SizedBox()),
            DanceTransportBar(
              loading: loading,
              playing: playing,
              loop: loop,
              showCaptions: showCaptions,
              captionsAvailable: captionsAvailable,
              useNewBackdrop: useNewBackdrop,
              bpm: bpm,
              positionSec: positionSec,
              durationSec: durationSec,
              currentSectionLabel: sectionLabel,
              currentSectionEnergetic: energetic,
              amplitudes: amplitudes,
              sections: sections,
              onPlayPause: () => rec.play++,
              onToggleLoop: () => rec.loop++,
              onToggleCaptions: () => rec.captions++,
              onToggleBackdrop: () => rec.backdrop++,
              onSeekToSeconds: (s) => rec.seek = s,
            ),
          ],
        ),
      ),
      mediaQueryData: MediaQueryData(size: size),
    ),
  );
  await tester.pump();
  return rec;
}

void main() {
  group('formatDancePlaybackTimestamp', () {
    test('formats sub-hour positions as mm:ss.mmm', () {
      expect(formatDancePlaybackTimestamp(0), '00:00.000');
      expect(formatDancePlaybackTimestamp(93.433), '01:33.433');
      expect(formatDancePlaybackTimestamp(144.06), '02:24.060');
    });

    test('rounds to the nearest millisecond and carries into minutes', () {
      expect(formatDancePlaybackTimestamp(59.9996), '01:00.000');
      expect(formatDancePlaybackTimestamp(61.2345), '01:01.235');
    });

    test('uses h:mm:ss.mmm after the first hour', () {
      expect(formatDancePlaybackTimestamp(3661.234), '1:01:01.234');
    });

    test('clamps invalid or negative positions to zero', () {
      expect(formatDancePlaybackTimestamp(-1), '00:00.000');
      expect(formatDancePlaybackTimestamp(double.nan), '00:00.000');
      expect(formatDancePlaybackTimestamp(double.infinity), '00:00.000');
    });
  });

  group('DanceTransportBar', () {
    testWidgets('renders timecode, BPM and the active section', (tester) async {
      await _pump(tester);

      // Timecode shows current / total with millisecond precision.
      expect(
        find.textContaining('01:33.433', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('02:24.060', findRichText: true),
        findsOneWidget,
      );
      // BPM pill and the now-playing section chip.
      expect(find.textContaining('120', findRichText: true), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('DANCE'), findsOneWidget);
    });

    testWidgets('shows CALM for a non-energetic section', (tester) async {
      await _pump(tester, energetic: false);
      expect(find.text('CALM'), findsOneWidget);
      expect(find.text('DANCE'), findsNothing);
    });

    testWidgets('loading hides metadata and disables play', (tester) async {
      final rec = await _pump(tester, loading: true);

      // Metadata cluster is hidden while loading.
      expect(find.text('B'), findsNothing);
      expect(find.textContaining('120', findRichText: true), findsNothing);
      // Play is disabled: tapping it does nothing.
      await tester.tap(
        find.byIcon(Icons.play_arrow_rounded),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(rec.play, 0);
    });

    testWidgets('play / loop / backdrop toggles fire their callbacks', (
      tester,
    ) async {
      final rec = await _pump(tester);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.tap(find.byIcon(Icons.repeat_rounded));
      await tester.tap(find.byIcon(Icons.image_rounded));
      await tester.pump();

      expect(rec.play, 1);
      expect(rec.loop, 1);
      expect(rec.backdrop, 1);
    });

    testWidgets('captions toggle fires when lyrics are available', (
      tester,
    ) async {
      final rec = await _pump(tester);
      await tester.tap(find.byIcon(Icons.closed_caption_off_rounded));
      await tester.pump();
      expect(rec.captions, 1);
    });

    testWidgets('captions toggle is hidden without lyrics', (tester) async {
      await _pump(tester, captionsAvailable: false);
      expect(find.byIcon(Icons.closed_caption_off_rounded), findsNothing);
      expect(find.byIcon(Icons.closed_caption_rounded), findsNothing);
    });

    testWidgets('tapping the timeline seeks proportionally', (tester) async {
      final rec = await _pump(tester);

      await tester.tap(find.byKey(const Key('danceTimeline')));
      await tester.pump();

      // Tapping the horizontal centre seeks to ~half the track.
      expect(rec.seek, isNotNull);
      expect(rec.seek, closeTo(144.06 / 2, 144.06 * 0.08));
    });

    testWidgets('empty waveform shows the regenerate hint', (tester) async {
      await _pump(tester, amplitudes: const []);
      expect(
        find.textContaining('no waveform in beat map'),
        findsOneWidget,
      );
      // No seek surface to tap when there is no waveform.
      expect(find.byKey(const Key('danceTimeline')), findsNothing);
    });

    testWidgets('null amplitudes render the loading placeholder', (
      tester,
    ) async {
      await _pump(tester, amplitudes: null);
      expect(find.byKey(const Key('danceTimeline')), findsNothing);
      expect(find.text('loading…'), findsOneWidget);
    });
  });
}
