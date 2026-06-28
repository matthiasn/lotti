import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/character/demo/dance_lip_sync.dart';
import 'package:lotti/features/character/engine/autonomic.dart';
import 'package:lotti/features/character/model/beat_map.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_painter.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';
import 'package:lotti/features/scenery/layered_backdrop.dart';
import 'package:lotti/features/scenery/model/backdrop_scene.dart';
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

/// Optional word-level lyrics (from `tools/dance_audio/transcribe.py`). Absent →
/// no captions. Original artwork derivative — kept local, never committed.
const String kDanceWordsPath = String.fromEnvironment(
  'DANCE_WORDS',
  defaultValue:
      '/home/parallels/github/lotti/tools/dance_audio/out/moving.words.json',
);

/// Optional lip-sync cue track (from `tools/dance_audio/lipsync.py` — Rhubarb).
/// Absent → no mouth movement. Drives the singers' mouths from the actual vocal
/// phonemes; the lyric voice tags only gate *which* cat shows the cues.
const String kDanceCuesPath = String.fromEnvironment(
  'DANCE_CUES',
  defaultValue:
      '/home/parallels/github/lotti/tools/dance_audio/out/moving.cues.json',
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

/// Time constant (seconds) for easing the dance camera in/out across section
/// changes — bigger = slower, more cinematic zoom (~63% of the way in this long).
const double kCameraRampSeconds = 1.4;

/// Peak dance-camera strength during energetic sections. The painter's full
/// (strength 1) choreography pushes in hard enough (zoom ~2.08) to shove the
/// side dancers off the 16:9 stage box — the "left cat cut off well within the
/// window" bug. Capping the ramp here keeps the push-in/truck energy while
/// holding the whole trio on the locked stage at any window size (at this value
/// the left backup keeps a comfortable margin from the stage edge). The painter
/// keeps its full-strength choreography for other callers/tests.
const double kEnergeticCameraStrength = 0.5;

/// Lip-sync mouth easing: each Rhubarb cue snaps the jaw open fast (attack) and
/// relaxes it shut more slowly (release), so a syllable punches then settles
/// instead of fluttering. The cue carries the target opening; these are just the
/// time constants for following it.
const double kMouthAttackSeconds = 0.045;
const double kMouthReleaseSeconds = 0.12;

typedef _Section = ({double start, double end, String label, bool energetic});
typedef _Word = ({
  double start,
  double end,
  String word,
  String voice,
  String section,
});

/// A Rhubarb mouth-shape cue: shape letter (A-F, G, H, X) active over a span.
typedef _Cue = ({double start, double end, String shape});

/// Sections the whole trio sings (a group hook): the backups' mouths join the
/// frontman on the *lead* words here, not just on the `(...)` ad-libs.
const Set<String> kGroupSections = {'chorus', 'post-chorus', 'outro'};
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

  BeatMap? _map;
  BeatLoopBinding? _binding;
  List<double>? _amplitudes; // full-track waveform, normalized 0..1
  List<_Section> _sections = const [];
  List<_Word> _words = const []; // synced lyrics (optional)
  List<_Cue> _cues = const []; // Rhubarb lip-sync cues (optional)
  double _trackDurationSec = 0;
  double _bpm = 0;
  bool _loop = true;
  bool _showCaptions = true;
  // Dev A/B switch: the new layered blue-hour scene vs. the old single-plate
  // waterfront backdrop.
  bool _useNewBackdrop = true;
  ui.Image? _backdrop;
  ui.Image? _clouds;
  ui.Image? _waves;
  double _cameraStrength = 0; // eased dance-camera ramp (0 = neutral, 1 = full)
  double _wallSeconds = 0; // steady clock for ambient backdrop animation
  double _leadMouth = 0; // eased frontman mouth (lead lyric words)
  double _bgMouth = 0; // eased backup-dancers' mouth (background ad-libs)
  MouthShape _leadShape = MouthShape.singAh; // viseme for the active lead word
  MouthShape _bgShape = MouthShape.singAh; // viseme for the active backup word
  Duration _lastTick = Duration.zero;
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
    _ticker = createTicker(_onTick)..start();
    unawaited(_load());
    // Old-backdrop plate, loaded so the A/B toggle can switch to it instantly.
    unawaited(_loadBackdrop());
  }

  // Per-frame: repaint, and ease the dance-camera strength toward the current
  // section's target (1 = energetic, 0 = calm) so the camera zoom ramps in and
  // out smoothly. Frame-rate independent: uses the real frame dt and a time
  // constant, so the ramp speed is the same regardless of refresh rate.
  void _onTick(Duration elapsed) {
    var dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt < 0) dt = 0;
    if (dt > 0.1) dt = 0.1; // ignore long stalls (tab switch, etc.)
    // Advance the ambient backdrop clock only while playing, so the lights
    // freeze with the dancers when the track is paused.
    if (_player.state.playing) _wallSeconds += dt;
    final pos = _player.state.position.inMicroseconds / 1e6;
    final target = (_sectionAt(pos)?.energetic ?? true)
        ? kEnergeticCameraStrength
        : 0.0;
    var k = dt / kCameraRampSeconds;
    if (k > 1) k = 1;
    // Mouth shape comes from the Rhubarb cue track (the actual vocal phonemes);
    // the lyric voice tags only gate *which* cat shows it. The frontman is gated
    // on lead words; the backups on the `(...)` ad-libs and the group-hook
    // sections (chorus / post-chorus / outro), so the chorus reads as the whole
    // trio. With no lyrics file, the frontman lip-syncs everything.
    final cue = mouthForCue(cueShapeAt(_cues, pos));
    final leadOn =
        _words.isEmpty || _voiceActive(pos, (w) => w.voice == 'lead');
    final bgOn = _voiceActive(
      pos,
      (w) =>
          w.voice == 'background' ||
          (w.voice == 'lead' && kGroupSections.contains(w.section)),
    );
    if (leadOn) _leadShape = cue.shape;
    if (bgOn) _bgShape = cue.shape;
    setState(() {
      _cameraStrength += (target - _cameraStrength) * k;
      _leadMouth = _easeMouth(_leadMouth, leadOn ? cue.open : 0.0, dt);
      _bgMouth = _easeMouth(_bgMouth, bgOn ? cue.open : 0.0, dt);
    });
  }

  /// Eases a mouth-open value toward [target] with a fast attack and slower
  /// release (frame-rate independent), so each sung syllable snaps open and then
  /// relaxes shut instead of fluttering symmetrically.
  double _easeMouth(double current, double target, double dt) {
    final tc = target > current ? kMouthAttackSeconds : kMouthReleaseSeconds;
    var k = dt / tc;
    if (k > 1) k = 1;
    return current + (target - current) * k;
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
      final words = await _loadWords();
      final cues = await _loadCues();

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
        _words = words;
        _cues = cues;
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

  /// Loads the optional word-level lyrics file (absent → no captions).
  Future<List<_Word>> _loadWords() async {
    final file = File(kDanceWordsPath);
    if (!file.existsSync()) return const [];
    try {
      final wj = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      return ((wj['words'] as List?) ?? const [])
          .cast<Map<String, Object?>>()
          .where((w) => w['start_sec'] != null && w['end_sec'] != null)
          .map(
            (w) => (
              start: (w['start_sec']! as num).toDouble(),
              end: (w['end_sec']! as num).toDouble(),
              word: (w['word'] as String?) ?? '',
              // 'lead' | 'background' (from --lyrics); defaults to lead.
              voice: (w['voice'] as String?) ?? 'lead',
              section: (w['section'] as String?) ?? '',
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Loads the optional Rhubarb lip-sync cue track (absent → no mouth movement).
  Future<List<_Cue>> _loadCues() async {
    final file = File(kDanceCuesPath);
    if (!file.existsSync()) return const [];
    try {
      final cj = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      return ((cj['cues'] as List?) ?? const [])
          .cast<Map<String, Object?>>()
          .map(
            (c) => (
              start: (c['start_sec']! as num).toDouble(),
              end: (c['end_sec']! as num).toDouble(),
              shape: (c['shape'] as String?) ?? 'X',
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Index of the lyric word to caption at [pos]: the most recent word that has
  /// started, hidden during instrumental gaps (>2 s after the last word ended).
  int? _captionWordIndex(double pos) {
    int? recent;
    for (var i = 0; i < _words.length; i++) {
      if (_words[i].start <= pos) {
        recent = i;
      } else {
        break;
      }
    }
    if (recent == null) return null;
    if (pos - _words[recent].end > 2.0) return null;
    return recent;
  }

  /// Whether a voice (selected by [test]) is singing at [pos], dilated by
  /// [_voiceSlack] so short gaps between a phrase's words don't make the mouth
  /// flicker shut — it only rests between phrases / when that voice is silent.
  bool _voiceActive(double pos, bool Function(_Word w) test) {
    for (final w in _words) {
      if (test(w) && windowActiveAt(w.start, w.end, pos, _voiceSlack)) {
        return true;
      }
      if (w.start - _voiceSlack > pos) break;
    }
    return false;
  }

  static const double _voiceSlack = 0.3;

  /// A face whose mouth is driven open by [mouth] (lyric-synced) on the [shape]
  /// viseme, falling back to [base] when essentially closed. The upper face sings
  /// too: brows lift and the eyes squint a touch as the mouth opens, so the
  /// performance isn't a dead-eyed mask over a moving mouth. Drives the frontman
  /// on lead words and the backups on background ad-libs / group hooks.
  Expression _singExpression(double mouth, Expression base, MouthShape shape) {
    if (mouth < 0.04) return base;
    final brow = 0.18 + mouth * 0.4; // gentle engagement, not a hard arch
    final eye = 1 - mouth * 0.18; // a whisper of a squint, not a grimace
    return Expression(
      'sing',
      FaceState(
        mouthShape: shape,
        mouthOpen: mouth,
        browRaiseLeft: brow,
        browRaiseRight: brow,
        eyeOpenLeft: eye,
        eyeOpenRight: eye,
      ),
    );
  }

  /// A karaoke caption: a short window of lyric words centred on the current one,
  /// which is highlighted. Empty when there is no active word.
  Widget _caption(double pos) {
    final i = _captionWordIndex(pos);
    if (i == null) return const SizedBox.shrink();
    final from = i - 3 < 0 ? 0 : i - 3;
    final to = i + 4 > _words.length ? _words.length : i + 4;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: RichText(
          text: TextSpan(
            children: [
              for (var j = from; j < to; j++)
                TextSpan(
                  text: '${_words[j].word} ',
                  style: TextStyle(
                    color: j == i ? Colors.white : Colors.white54,
                    fontSize: j == i ? 26 : 21,
                    fontWeight: j == i ? FontWeight.w700 : FontWeight.w400,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// A 0..1 musical pulse that spikes on each detected beat and decays, so the
  /// backdrop lights shimmer with the track. Driven by the audio position, so
  /// it freezes with playback.
  double _beatPulse(double pos) {
    final beats = _map?.beatTimesSec;
    if (beats == null || beats.isEmpty) return 0;
    var lo = 0;
    var hi = beats.length - 1;
    var idx = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (beats[mid] <= pos) {
        idx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    final since = pos - beats[idx];
    if (since < 0) return 0;
    final v = 1 - since / 0.18;
    return v <= 0 ? 0 : v * v;
  }

  /// Picks the clip + clock for the current section: the beat-locked energetic
  /// dance in loud sections, an eased idle (driven by raw playback time) in calm
  /// ones — so the quiet intro stays calm until the beat kicks in. The phrase
  /// loops via clipSecondsAt's own modulo across the track; the camera ramp
  /// ([_onTick] / [CharacterPainter.danceCameraStrength]) glides in on the dance.
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
    final posSec = _player.state.position.inMicroseconds / 1e6;
    final beat = _beatPulse(posSec);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            // Lock the stage to 16:9 so the painted 2560x1440 art maps 1:1
            // (cover == exact fit) and never crops or distorts; the resizable
            // window letterboxes around it. Backdrop, dancers and captions are
            // letterboxed together so the cats stay planted on the painted deck
            // at any window size.
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Match character_demo: size the cast to the available height
                    // (the painter scales uniformly, so this is what keeps the cats
                    // correctly proportioned instead of squat at the default scale 1).
                    final scale = constraints.maxHeight * 0.78 / 300.0;
                    // Parallax the layered scene with the dance camera so it drifts
                    // behind the dancers instead of sitting dead still.
                    final backdropTransform =
                        CharacterPainter.danceParallaxTransform(
                          timeSeconds: stage.seconds,
                          clipDuration: stage.lead.duration,
                          size: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          danceCameraStrength: _cameraStrength,
                          active: stage.lead.name == 'dance',
                        );
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Layered blue-hour scene behind the dancers, driven by the
                        // same audio/dance clock so it moves with the music. Toggle
                        // to the old single-plate waterfront via the panel button.
                        if (_useNewBackdrop)
                          Transform(
                            transform: backdropTransform,
                            filterQuality: FilterQuality.low,
                            child: LayeredBackdrop(
                              scene: BackdropScene.blueHourWaterfront(),
                              // Steady wall clock for blink/flicker timing (not the
                              // looping dance clock); beatPulse makes the windows
                              // shimmer on the beat.
                              timeSeconds: _wallSeconds,
                              beatPulse: beat,
                            ),
                          ),
                        CustomPaint(
                          painter: CharacterPainter(
                            scene: _lead,
                            partnerScene: _left,
                            ensembleScenes: [_left, _right],
                            // Lip-sync: the frontman moves on lead words, the two
                            // backups on background ad-libs.
                            ensembleExpressions: [
                              _singExpression(
                                _leadMouth,
                                Expression.neutral,
                                _leadShape,
                              ),
                              _singExpression(
                                _bgMouth,
                                Expression.content,
                                _bgShape,
                              ),
                              _singExpression(
                                _bgMouth,
                                Expression.happy,
                                _bgShape,
                              ),
                            ],
                            // Section-aware: the energetic dance trio in loud
                            // sections, an eased idle in calm ones.
                            ensembleClips: stage.ensemble,
                            synchronousEnsemble: true,
                            // Heads bob with the music; the singer's head rides the
                            // vocal opening.
                            singingHeadMotion: true,
                            // Enables the multi-member (trio) render path; without
                            // it the painter draws only the lead scene.
                            walkingPair: true,
                            clip: stage.lead,
                            timeSeconds: stage.seconds,
                            danceCameraStrength: _cameraStrength,
                            scale: scale,
                            // New painted scene already has the deck, so drop the
                            // flat grey floor band (it would sit over the painting);
                            // the old plate keeps its band.
                            groundColor: _useNewBackdrop
                                ? null
                                : const Color(0xFF374551),
                            // New scene: LayeredBackdrop draws everything, so the
                            // painter's own backdrop is off. Old scene: the painter
                            // draws the single waterfront plate.
                            backdrop: _useNewBackdrop
                                ? CharacterBackdrop.none
                                : CharacterBackdrop.waterfront,
                            backdropImage: _useNewBackdrop ? null : _backdrop,
                            backdropCloudsImage: _useNewBackdrop
                                ? null
                                : _clouds,
                            backdropWavesImage: _useNewBackdrop ? null : _waves,
                            renderer: _renderer,
                          ),
                          child: const SizedBox.expand(),
                        ),
                        if (_showCaptions && _words.isNotEmpty)
                          Positioned(
                            left: 24,
                            right: 24,
                            bottom: 20,
                            child: Center(child: _caption(posSec)),
                          ),
                      ],
                    );
                  },
                ),
              ),
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
              const SizedBox(width: 4),
              IconButton(
                onPressed: _words.isEmpty
                    ? null
                    : () => setState(() => _showCaptions = !_showCaptions),
                tooltip: _showCaptions ? 'Hide lyrics' : 'Show lyrics',
                icon: Icon(
                  _showCaptions
                      ? Icons.closed_caption
                      : Icons.closed_caption_off,
                  color: _showCaptions && _words.isNotEmpty
                      ? Colors.tealAccent
                      : Colors.white38,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () =>
                    setState(() => _useNewBackdrop = !_useNewBackdrop),
                tooltip: _useNewBackdrop
                    ? 'New blue-hour scene'
                    : 'Old waterfront plate',
                icon: Icon(
                  _useNewBackdrop ? Icons.nightlight_round : Icons.image,
                  color: _useNewBackdrop ? Colors.tealAccent : Colors.white38,
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
