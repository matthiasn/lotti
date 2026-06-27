import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:lotti/features/character/engine/autonomic.dart';
import 'package:lotti/features/character/model/beat_map.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_painter.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';
import 'package:media_kit/media_kit.dart';

/// Beat-synced dance demo with a waveform picker — the first wiring of the
/// offline beat map into live playback (see
/// `docs/implementation_plans/2026-06-27_dance_audio_analysis.md` §15). A dev
/// tool, not a product surface.
///
/// Flow: load a track, render its **full waveform**, drag a **30-second window**
/// anywhere over it, and press **play** to hear just that window while the trio
/// dances **locked to the track's beats**. Each frame, the dance time is the
/// audio playback position warped through [BeatMap.clipSecondsAt], so the looping
/// 32-frame phrase (12 beats = 3 bars at the authored 120 BPM) lands on-beat and
/// follows tempo drift instead of free-running at a guessed BPM.
///
/// Beat detection is the **offline** `tools/dance_audio` tool (Beat This!); it
/// cannot run in-app. This demo loads a **pre-generated full-track beat-map JSON**
/// and the 30 s window just selects a sub-range (re-anchored to the nearest
/// downbeat) — no detection at runtime.
///
/// Deliberately **self-contained**: depends only on packages (`media_kit`,
/// `just_waveform`) + this character feature — no journal/speech code — so it
/// travels cleanly when the feature is ejected into its own repo.
///
/// Run it (defaults to local dev files; override with --dart-define):
/// ```sh
/// fvm flutter run -d linux -t lib/features/character/demo/character_dance_to_track_demo.dart \
///   --dart-define=DANCE_AUDIO=/abs/track.mp3 \
///   --dart-define=DANCE_BEATMAP=/abs/full_track_beatmap.json
/// ```
/// Generate the full-track map first:
/// `python tools/dance_audio/analyze.py track.mp3 -o out/track.json`.
///
/// The audio is original artwork — kept local, never committed; only its derived
/// beat-map JSON is read here (also kept out of VCS).
const String kDanceAudioPath = String.fromEnvironment(
  'DANCE_AUDIO',
  defaultValue: '/home/parallels/Downloads/Omah_Lay-Moving.mp3',
);
const String kDanceBeatMapPath = String.fromEnvironment(
  'DANCE_BEATMAP',
  defaultValue:
      '/home/parallels/github/lotti/tools/dance_audio/out/moving.json',
);

/// Length of the playable selection window, in seconds.
const double kWindowSeconds = 30;

/// Bars the 32-frame [CatClips.dance] phrase spans: `duration 6 s` at
/// `kAuthoredDanceBpm 120` = 12 beats = 3 bars of 4/4.
const int kDancePhraseBars = 3;

double _clampDouble(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

void main() {
  MediaKit.ensureInitialized();
  runApp(const DanceToTrackApp());
}

class DanceToTrackApp extends StatelessWidget {
  const DanceToTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dance to track',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const DanceToTrackPage(),
    );
  }
}

class DanceToTrackPage extends StatefulWidget {
  const DanceToTrackPage({super.key});

  @override
  State<DanceToTrackPage> createState() => _DanceToTrackPageState();
}

class _DanceToTrackPageState extends State<DanceToTrackPage>
    with SingleTickerProviderStateMixin {
  // The trio, matching character_demo.dart so the look is identical; only the
  // clock differs (audio position instead of a free-running scalar).
  late final CharacterScene _lead = CharacterScene(
    buildCatInSuitRig(
      legWidthScale: kDanceLeadLegWidthScale,
      armWidthScale: kDanceLeadArmWidthScale,
    ),
    autonomic: _danceAutonomic(11),
  );
  late final CharacterScene _left = CharacterScene(
    buildCatInSuitRig(palette: CatInSuitPalette.silverTabby),
    autonomic: _danceAutonomic(29),
  );
  late final CharacterScene _right = CharacterScene(
    buildCatInSuitRig(palette: CatInSuitPalette.darkBrown),
    autonomic: _danceAutonomic(47),
  );

  final CharacterRenderer _renderer = CharacterRenderer();
  final Player _player = Player();
  final Clip _clip = CatClips.dance;

  late final Ticker _ticker; // 60 fps repaint pump; time comes from the player.

  ui.Image? _backdrop;
  ui.Image? _clouds;
  ui.Image? _waves;

  BeatMap? _map; // full-track beat map
  BeatLoopBinding? _binding; // re-anchored when the window moves
  List<double>? _amplitudes; // full-track waveform, normalized 0..1
  double _trackDurationSec = 0;
  double _windowStartSec = 0;
  double _bpm = 0;
  bool _loopSeeking = false;
  String? _error;

  AutonomicLayer _danceAutonomic(int seed) => AutonomicLayer(
    seed: seed,
    blinkIntervalBase: 1.7,
    blinkIntervalJitter: 1.1,
    eyeDartInterval: 1.05,
    eyeDartAmplitude: 0.75,
  );

  double get _maxWindowStart {
    final m = _trackDurationSec - kWindowSeconds;
    return m < 0 ? 0 : m;
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => setState(() {}))..start();
    unawaited(_loadBackdrop());
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final mapFile = File(kDanceBeatMapPath);
      if (!mapFile.existsSync()) {
        throw StateError('beat map not found: $kDanceBeatMapPath');
      }
      final json =
          jsonDecode(await mapFile.readAsString()) as Map<String, Object?>;
      final map = BeatMap.fromJson(json);
      final audio = json['audio'] as Map<String, Object?>?;
      final tempo = json['tempo'] as Map<String, Object?>?;
      final duration =
          (audio?['duration_sec'] as num?)?.toDouble() ?? map.beatTimesSec.last;

      await _player.open(Media(kDanceAudioPath), play: false);
      final maxStart = duration - kWindowSeconds;
      final start = _clampDouble(
        duration / 2 - kWindowSeconds / 2,
        0,
        maxStart < 0 ? 0 : maxStart,
      );
      await _player.seek(Duration(microseconds: (start * 1e6).round()));

      final amplitudes = await _extractAmplitudes(kDanceAudioPath);

      if (!mounted) return;
      setState(() {
        _map = map;
        _trackDurationSec = duration;
        _bpm = (tempo?['global_bpm'] as num?)?.toDouble() ?? 0;
        _windowStartSec = start;
        _binding = _bindingForWindow(map, start);
        _amplitudes = amplitudes;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Re-anchor the looping phrase on the first detected downbeat at/after the
  /// window start (falls back to a beat-level binding if no downbeats exist).
  BeatLoopBinding _bindingForWindow(BeatMap map, double windowStart) {
    if (map.downbeatIndices.isEmpty) {
      return BeatLoopBinding.beatAligned(
        loopLengthBeats: kDancePhraseBars * map.timeSignatureNumerator,
      );
    }
    var ordinal = map.downbeatIndices.length - 1;
    for (var k = 0; k < map.downbeatIndices.length; k++) {
      if (map.beatTimesSec[map.downbeatIndices[k]] >= windowStart - 1e-3) {
        ordinal = k;
        break;
      }
    }
    return BeatLoopBinding.barAligned(
      map,
      bars: kDancePhraseBars,
      fromDownbeat: ordinal,
    );
  }

  /// Audio position → dance-clip seconds, looping the audio inside the window so
  /// audio and dance stay in lockstep (the audio clock is the source of truth).
  double _danceSecondsNow() {
    final map = _map;
    final binding = _binding;
    if (map == null || binding == null) return 0;
    final posSec = _player.state.position.inMicroseconds / 1e6;
    if (_player.state.playing &&
        posSec >= _windowStartSec + kWindowSeconds &&
        !_loopSeeking) {
      _loopSeeking = true;
      _player
          .seek(Duration(microseconds: (_windowStartSec * 1e6).round()))
          .whenComplete(() => _loopSeeking = false);
    }
    return map.clipSecondsAt(
      posSec,
      clipDuration: _clip.duration,
      binding: binding,
    );
  }

  void _moveWindowTo(double startSec) {
    final map = _map;
    if (map == null) return;
    setState(() {
      _windowStartSec = _clampDouble(startSec, 0, _maxWindowStart);
      _binding = _bindingForWindow(map, _windowStartSec);
    });
    // Keep playback inside the (possibly moved) window.
    final posSec = _player.state.position.inMicroseconds / 1e6;
    if (_player.state.playing &&
        (posSec < _windowStartSec ||
            posSec >= _windowStartSec + kWindowSeconds)) {
      unawaited(
        _player.seek(Duration(microseconds: (_windowStartSec * 1e6).round())),
      );
    }
  }

  Future<void> _togglePlay() async {
    if (_player.state.playing) {
      await _player.pause();
    } else {
      final posSec = _player.state.position.inMicroseconds / 1e6;
      if (posSec < _windowStartSec ||
          posSec >= _windowStartSec + kWindowSeconds) {
        await _player.seek(
          Duration(microseconds: (_windowStartSec * 1e6).round()),
        );
      }
      await _player.play();
    }
    if (mounted) setState(() {});
  }

  Future<List<double>> _extractAmplitudes(
    String path, {
    int buckets = 800,
  }) async {
    final out = File(
      '${Directory.systemTemp.path}/lotti_dance_wave_${path.hashCode}.wave',
    );
    Waveform? waveform;
    await for (final progress in JustWaveform.extract(
      audioInFile: File(path),
      waveOutFile: out,
    )) {
      waveform = progress.waveform ?? waveform;
    }
    try {
      if (out.existsSync()) out.deleteSync();
    } catch (_) {
      // ignore cleanup failure
    }
    final w = waveform;
    if (w == null || w.length == 0) return const [];
    final maxAmp = w.flags == 0 ? 32768.0 : 128.0;
    double pixel(int i) => math.min(
      1,
      math.max(w.getPixelMin(i).abs(), w.getPixelMax(i).abs()) / maxAmp,
    );
    final n = w.length;
    if (n <= buckets) return [for (var i = 0; i < n; i++) pixel(i)];
    final bucketSize = n / buckets;
    return List<double>.generate(buckets, (b) {
      final start = (b * bucketSize).floor();
      final end = math.min(n, ((b + 1) * bucketSize).ceil());
      var peak = 0.0;
      for (var i = start; i < end; i++) {
        final v = pixel(i);
        if (v > peak) peak = v;
      }
      return peak;
    });
  }

  Future<void> _loadBackdrop() async {
    final images = await Future.wait([
      _loadUiImage(kCharacterWaterfrontBackdropAsset),
      _loadUiImage(kCharacterWaterfrontCloudsAsset),
      _loadUiImage(kCharacterWaterfrontWavesAsset),
    ]);
    if (!mounted) {
      for (final image in images) {
        image.dispose();
      }
      return;
    }
    setState(() {
      _backdrop = images[0];
      _clouds = images[1];
      _waves = images[2];
    });
  }

  Future<ui.Image> _loadUiImage(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_player.dispose());
    _backdrop?.dispose();
    _clouds?.dispose();
    _waves?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not start beat-synced demo:\n\n$_error\n\n'
              'Point DANCE_AUDIO / DANCE_BEATMAP at local files '
              '(see the file header).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final seconds = _danceSecondsNow();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: CharacterPainter(
                scene: _lead,
                partnerScene: _left,
                ensembleScenes: [_left, _right],
                ensembleExpressions: const [
                  Expression.neutral,
                  Expression.content,
                  Expression.happy,
                ],
                ensembleClips: [
                  CatClips.dance,
                  CatClips.danceBackupLeft,
                  CatClips.danceBackupRight,
                ],
                synchronousEnsemble: true,
                clip: _clip,
                timeSeconds: seconds,
                groundColor: const Color(0xFF374551),
                backdrop: CharacterBackdrop.waterfront,
                backdropImage: _backdrop,
                backdropCloudsImage: _clouds,
                backdropWavesImage: _waves,
                renderer: _renderer,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          _waveformPanel(),
        ],
      ),
    );
  }

  Widget _waveformPanel() {
    final posSec = _player.state.position.inMicroseconds / 1e6;
    final playing = _player.state.playing;
    final windowEnd = _windowStartSec + kWindowSeconds;
    return Container(
      color: const Color(0xFF14181D),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _map == null ? null : _togglePlay,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _map == null
                      ? 'loading…'
                      : 'window ${_windowStartSec.toStringAsFixed(1)}–'
                            '${windowEnd.toStringAsFixed(1)} s   ·   '
                            '${_bpm.toStringAsFixed(0)} BPM   ·   '
                            'pos ${posSec.toStringAsFixed(1)} s',
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Text(
                'drag / tap the waveform to move the 30s window',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final amplitudes = _amplitudes;
                if (amplitudes == null || _trackDurationSec <= 0) {
                  return const Center(child: Text('extracting waveform…'));
                }
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _moveWindowTo(
                    d.localPosition.dx / width * _trackDurationSec -
                        kWindowSeconds / 2,
                  ),
                  onHorizontalDragUpdate: (d) => _moveWindowTo(
                    _windowStartSec + d.delta.dx / width * _trackDurationSec,
                  ),
                  child: CustomPaint(
                    size: Size(width, constraints.maxHeight),
                    painter: _WaveformPainter(
                      amplitudes: amplitudes,
                      trackDurationSec: _trackDurationSec,
                      windowStartSec: _windowStartSec,
                      windowSeconds: kWindowSeconds,
                      positionSec: posSec,
                      playing: playing,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the full-track waveform with the selected 30 s window highlighted and
/// the live playback position marked.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.amplitudes,
    required this.trackDurationSec,
    required this.windowStartSec,
    required this.windowSeconds,
    required this.positionSec,
    required this.playing,
  });

  final List<double> amplitudes;
  final double trackDurationSec;
  final double windowStartSec;
  final double windowSeconds;
  final double positionSec;
  final bool playing;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty || trackDurationSec <= 0) return;
    final mid = size.height / 2;
    final x0 = windowStartSec / trackDurationSec * size.width;
    final x1 = (windowStartSec + windowSeconds) / trackDurationSec * size.width;

    // Window highlight band.
    final band = Paint()..color = const Color(0x3354B4FF);
    canvas.drawRect(Rect.fromLTRB(x0, 0, x1, size.height), band);

    // Bars: dim outside the window, bright inside.
    final barWidth = size.width / amplitudes.length;
    final dim = Paint()..color = const Color(0xFF3A4654);
    final bright = Paint()..color = const Color(0xFF8FD0FF);
    for (var i = 0; i < amplitudes.length; i++) {
      final x = i * barWidth;
      final double h = math.max(1, amplitudes[i] * (size.height - 2));
      final inWindow = x >= x0 && x <= x1;
      canvas.drawRect(
        Rect.fromLTWH(x, mid - h / 2, math.max(1, barWidth - 0.5), h),
        inWindow ? bright : dim,
      );
    }

    // Window borders.
    final border = Paint()
      ..color = const Color(0xCC54B4FF)
      ..strokeWidth = 2;
    canvas
      ..drawLine(Offset(x0, 0), Offset(x0, size.height), border)
      ..drawLine(Offset(x1, 0), Offset(x1, size.height), border);

    // Live playback position.
    if (playing) {
      final px = positionSec / trackDurationSec * size.width;
      canvas.drawLine(
        Offset(px, 0),
        Offset(px, size.height),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.windowStartSec != windowStartSec ||
      old.positionSec != positionSec ||
      old.playing != playing ||
      !identical(old.amplitudes, amplitudes);
}
