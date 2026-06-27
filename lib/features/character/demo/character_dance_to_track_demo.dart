import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/character/engine/autonomic.dart';
import 'package:lotti/features/character/model/beat_map.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_painter.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';
import 'package:media_kit/media_kit.dart';

/// Beat-synced dance demo — the first wiring of the offline beat map into live
/// playback (see `docs/implementation_plans/2026-06-27_dance_audio_analysis.md`
/// §15). A dev tool, not a product surface.
///
/// It plays a track (looped) and locks the looping dance phrase to the detected
/// beats/downbeats: each frame the dance time is the audio playback position
/// warped through [BeatMap.clipSecondsAt], so the 32-frame phrase (12 beats =
/// 3 bars at the authored 120 BPM) lands on-beat and follows tempo drift for the
/// whole track instead of free-running at a guessed BPM. The waveform below is a
/// seek bar — tap or drag to scrub.
///
/// Beat detection is the **offline** `tools/dance_audio` tool (Beat This!); it
/// cannot run in-app. This demo loads a **pre-generated full-track beat-map JSON**
/// (no detection at runtime), including the offline-computed waveform.
///
/// Deliberately **self-contained**: depends only on the `media_kit` package +
/// this character feature — no journal/speech code — so it travels cleanly when
/// the feature is ejected into its own repo.
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

/// Bars the 32-frame [CatClips.dance] phrase spans: `duration 6 s` at
/// `kAuthoredDanceBpm 120` = 12 beats = 3 bars of 4/4.
const int kDancePhraseBars = 3;

/// Section-aware choreography: a section below this fraction of the energy range
/// (and long enough, see [kMinCalmSeconds]) is "calm" — the trio eases into idle
/// instead of the energetic beat-locked dance.
const double kSectionEnergyThreshold = 0.5;

/// Calm sections shorter than this stay energetic, to avoid flicker on the short
/// transition sections between routines.
const double kMinCalmSeconds = 4;

typedef _Section = ({double start, double end, String label, bool energetic});
typedef _Stage = ({
  Clip lead,
  List<Clip> ensemble,
  double seconds,
  _Section? section,
  bool energetic,
});

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

  // Cached clips: rebuilding CatClips.dance compiles the whole DancePhrase, so
  // build the trio once instead of every frame.
  late final Clip _danceLead = CatClips.dance;
  late final List<Clip> _danceEnsemble = [
    CatClips.dance,
    CatClips.danceBackupLeft,
    CatClips.danceBackupRight,
  ];
  late final Clip _idle = CatClips.idle;
  late final List<Clip> _idleEnsemble = [_idle, _idle, _idle];

  late final Ticker _ticker; // 60 fps repaint pump; time comes from the player.

  ui.Image? _backdrop;
  ui.Image? _clouds;
  ui.Image? _waves;

  BeatMap? _map;
  BeatLoopBinding? _binding;
  List<double>? _amplitudes; // full-track waveform, normalized 0..1
  List<_Section> _sections = const [];
  double _trackDurationSec = 0;
  double _bpm = 0;
  bool _loop = true;
  String? _error;

  AutonomicLayer _danceAutonomic(int seed) => AutonomicLayer(
    seed: seed,
    blinkIntervalBase: 1.7,
    blinkIntervalJitter: 1.1,
    eyeDartInterval: 1.05,
    eyeDartAmplitude: 0.75,
  );

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
      await _player.setPlaylistMode(
        _loop ? PlaylistMode.loop : PlaylistMode.none,
      );

      // The waveform is computed offline by tools/dance_audio and embedded in the
      // beat map — no in-app audio decoding (just_waveform has no Linux plugin).
      final amplitudes =
          (json['waveform'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const <double>[];
      final rawSections = ((json['sections'] as List?) ?? const [])
          .cast<Map<String, Object?>>()
          .map(
            (s) => (
              start: (s['start_sec']! as num).toDouble(),
              end: (s['end_sec']! as num).toDouble(),
              label: (s['label'] as String?) ?? '',
            ),
          )
          .toList();
      final sections = _classifySections(rawSections, amplitudes, duration);

      if (!mounted) return;
      setState(() {
        _map = map;
        _trackDurationSec = duration;
        _bpm = (tempo?['global_bpm'] as num?)?.toDouble() ?? 0;
        // Anchor the looping phrase on the first downbeat and span whole bars;
        // the 3-bar loop then stays beat-locked for the entire track.
        _binding = BeatLoopBinding.barAligned(map, bars: kDancePhraseBars);
        _amplitudes = amplitudes;
        _sections = sections;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Tags each detected section energetic/calm by its mean waveform energy
  /// (relative to the track's energy range). Calm only when genuinely low-energy
  /// AND long enough — short transition sections stay energetic to avoid flicker.
  List<_Section> _classifySections(
    List<({double start, double end, String label})> raw,
    List<double> amplitudes,
    double duration,
  ) {
    if (raw.isEmpty || amplitudes.isEmpty || duration <= 0) {
      return [
        for (final s in raw)
          (start: s.start, end: s.end, label: s.label, energetic: true),
      ];
    }
    final n = amplitudes.length;
    double energyOf(double start, double end) {
      var i0 = (start / duration * n).floor();
      var i1 = (end / duration * n).ceil();
      if (i0 < 0) i0 = 0;
      if (i0 >= n) i0 = n - 1;
      if (i1 > n) i1 = n;
      if (i1 <= i0) i1 = i0 + 1;
      var sum = 0.0;
      for (var i = i0; i < i1; i++) {
        sum += amplitudes[i];
      }
      return sum / (i1 - i0);
    }

    final energies = [for (final s in raw) energyOf(s.start, s.end)];
    var minE = energies.first;
    var maxE = energies.first;
    for (final e in energies) {
      if (e < minE) minE = e;
      if (e > maxE) maxE = e;
    }
    final threshold = minE + kSectionEnergyThreshold * (maxE - minE);
    return [
      for (var i = 0; i < raw.length; i++)
        (
          start: raw[i].start,
          end: raw[i].end,
          label: raw[i].label,
          energetic:
              !(energies[i] < threshold &&
                  (raw[i].end - raw[i].start) >= kMinCalmSeconds),
        ),
    ];
  }

  _Section? _sectionAt(double pos) {
    for (final s in _sections) {
      if (pos >= s.start && pos < s.end) return s;
    }
    return _sections.isEmpty ? null : _sections.last;
  }

  /// Picks the clip + clock for the current section: the beat-locked energetic
  /// dance in loud sections, an eased idle (driven by raw playback time) in calm
  /// ones. The phrase loops via clipSecondsAt's own modulo across the track.
  _Stage _stageNow() {
    final pos = _player.state.position.inMicroseconds / 1e6;
    final section = _sectionAt(pos);
    final map = _map;
    final binding = _binding;
    if ((section?.energetic ?? true) && map != null && binding != null) {
      return (
        lead: _danceLead,
        ensemble: _danceEnsemble,
        seconds: map.clipSecondsAt(
          pos,
          clipDuration: _danceLead.duration,
          binding: binding,
        ),
        section: section,
        energetic: true,
      );
    }
    return (
      lead: _idle,
      ensemble: _idleEnsemble,
      seconds: pos,
      section: section,
      energetic: false,
    );
  }

  Future<void> _togglePlay() async {
    if (_player.state.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleLoop() async {
    _loop = !_loop;
    await _player.setPlaylistMode(
      _loop ? PlaylistMode.loop : PlaylistMode.none,
    );
    if (mounted) setState(() {});
  }

  void _seekToTime(double tSec) {
    if (_trackDurationSec <= 0) return;
    final t = tSec < 0
        ? 0.0
        : (tSec > _trackDurationSec ? _trackDurationSec : tSec);
    unawaited(_player.seek(Duration(microseconds: (t * 1e6).round())));
    if (mounted) setState(() {});
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

    final stage = _stageNow();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Match character_demo: size the cast to the available height
                // (the painter scales uniformly, so this is what keeps the cats
                // correctly proportioned instead of squat at the default scale 1).
                final scale = constraints.maxHeight * 0.78 / 300.0;
                return CustomPaint(
                  painter: CharacterPainter(
                    scene: _lead,
                    partnerScene: _left,
                    ensembleScenes: [_left, _right],
                    ensembleExpressions: const [
                      Expression.neutral,
                      Expression.content,
                      Expression.happy,
                    ],
                    // Section-aware: the energetic dance trio in loud sections,
                    // an eased idle in calm ones.
                    ensembleClips: stage.ensemble,
                    synchronousEnsemble: true,
                    // Enables the multi-member (trio) render path; without it the
                    // painter draws only the lead scene.
                    walkingPair: true,
                    clip: stage.lead,
                    timeSeconds: stage.seconds,
                    scale: scale,
                    groundColor: const Color(0xFF374551),
                    backdrop: CharacterBackdrop.waterfront,
                    backdropImage: _backdrop,
                    backdropCloudsImage: _clouds,
                    backdropWavesImage: _waves,
                    renderer: _renderer,
                  ),
                  child: const SizedBox.expand(),
                );
              },
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
    final section = _sectionAt(posSec);
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
              const SizedBox(width: 4),
              IconButton(
                onPressed: _map == null ? null : _toggleLoop,
                tooltip: _loop ? 'Looping track' : 'Play once',
                icon: Icon(
                  Icons.repeat,
                  color: _loop ? Colors.tealAccent : Colors.white38,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _map == null
                      ? 'loading…'
                      : '${_bpm.toStringAsFixed(0)} BPM   ·   '
                            'pos ${posSec.toStringAsFixed(1)} / '
                            '${_trackDurationSec.toStringAsFixed(0)} s   ·   '
                            'section ${section?.label ?? '–'} · '
                            '${(section?.energetic ?? true) ? 'dance' : 'calm'}',
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Text(
                'tap / drag the waveform to seek',
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
                  return const Center(child: Text('loading…'));
                }
                if (amplitudes.isEmpty) {
                  return const Center(
                    child: Text(
                      'no waveform in beat map — regenerate with analyze.py',
                    ),
                  );
                }
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _seekToTime(
                    d.localPosition.dx / width * _trackDurationSec,
                  ),
                  onHorizontalDragUpdate: (d) => _seekToTime(
                    d.localPosition.dx / width * _trackDurationSec,
                  ),
                  child: CustomPaint(
                    size: Size(width, constraints.maxHeight),
                    painter: _WaveformPainter(
                      amplitudes: amplitudes,
                      sections: _sections,
                      trackDurationSec: _trackDurationSec,
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

/// Paints the full-track waveform as a seek bar with the live playhead.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.amplitudes,
    required this.sections,
    required this.trackDurationSec,
    required this.positionSec,
    required this.playing,
  });

  final List<double> amplitudes;
  final List<_Section> sections;
  final double trackDurationSec;
  final double positionSec;
  final bool playing;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty || trackDurationSec <= 0) return;
    final mid = size.height / 2;
    final px = positionSec / trackDurationSec * size.width;

    // Section bands (rung-4 structure) behind the bars: a faint hue per label
    // (recurring sections share a colour), a boundary line, and the label.
    for (final s in sections) {
      final sx0 = s.start / trackDurationSec * size.width;
      final sx1 = s.end / trackDurationSec * size.width;
      final active = positionSec >= s.start && positionSec < s.end;
      canvas
        ..drawRect(
          Rect.fromLTRB(sx0, 0, sx1, size.height),
          Paint()..color = _sectionColor(s.label),
        )
        ..drawLine(
          Offset(sx0, 0),
          Offset(sx0, size.height),
          Paint()
            ..color = const Color(0x33FFFFFF)
            ..strokeWidth = 1,
        );
      if (active) {
        // Brighten the current section + a top accent bar.
        canvas
          ..drawRect(
            Rect.fromLTRB(sx0, 0, sx1, size.height),
            Paint()..color = const Color(0x14FFFFFF),
          )
          ..drawRect(
            Rect.fromLTRB(sx0, 0, sx1, 3),
            Paint()..color = Colors.white70,
          );
      }
      TextPainter(
          text: TextSpan(
            text: s.label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white60,
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        )
        ..layout()
        ..paint(canvas, Offset(sx0 + 2, 1));
    }

    // Bars: brighter up to the playhead (played), dim ahead.
    final barWidth = size.width / amplitudes.length;
    final played = Paint()..color = const Color(0xFF8FD0FF);
    final ahead = Paint()..color = const Color(0xFF3A4654);
    for (var i = 0; i < amplitudes.length; i++) {
      final x = i * barWidth;
      final h = _atLeast1(amplitudes[i] * (size.height - 2));
      canvas.drawRect(
        Rect.fromLTWH(x, mid - h / 2, _barWidth(barWidth), h),
        x <= px ? played : ahead,
      );
    }

    // Playhead (always shown so a paused seek is visible).
    canvas.drawLine(
      Offset(px, 0),
      Offset(px, size.height),
      Paint()
        ..color = playing ? Colors.white : Colors.white70
        ..strokeWidth = 1.5,
    );
  }

  static double _atLeast1(double v) => v < 1 ? 1 : v;
  static double _barWidth(double w) => w - 0.5 < 1 ? 1 : w - 0.5;

  static Color _sectionColor(String label) {
    const palette = <String, Color>{
      'A': Color(0x22FF6B6B),
      'B': Color(0x2245C7B8),
      'C': Color(0x22FFD166),
      'D': Color(0x22A78BFA),
      'E': Color(0x2206D6A0),
      'F': Color(0x22EF476F),
    };
    return palette[label] ?? const Color(0x18FFFFFF);
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.positionSec != positionSec ||
      old.playing != playing ||
      !identical(old.amplitudes, amplitudes) ||
      !identical(old.sections, sections);
}
