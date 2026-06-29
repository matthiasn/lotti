import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/character/demo/dance_camera_director.dart';
import 'package:lotti/features/character/demo/dance_camera_rig.dart';
import 'package:lotti/features/character/demo/dance_lip_sync.dart';
import 'package:lotti/features/character/demo/dance_loaders.dart';
import 'package:lotti/features/character/demo/dance_performance.dart';
import 'package:lotti/features/character/demo/dance_transport_bar.dart';
import 'package:lotti/features/character/engine/autonomic.dart';
import 'package:lotti/features/character/model/beat_map.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_painter.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';
import 'package:lotti/features/scenery/layered_backdrop.dart';
import 'package:lotti/features/scenery/model/backdrop_scene.dart';
import 'package:lotti/features/scenery/runtime/stage_lights.dart';
import 'package:lotti/features/scenery/scene_texture_overlay.dart';
import 'package:lotti/features/scenery/stage_lights_overlay.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

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
const String kDefaultDanceAudioPath = String.fromEnvironment(
  'DANCE_AUDIO',
  defaultValue: '/home/parallels/Downloads/Omah_Lay-Moving.mp3',
);
const String kDefaultDanceBeatMapPath = String.fromEnvironment(
  'DANCE_BEATMAP',
  defaultValue:
      '/home/parallels/github/lotti/tools/dance_audio/out/moving.json',
);

/// Optional word-level lyrics (from `tools/dance_audio/transcribe.py`). Absent →
/// no captions. Original artwork derivative — kept local, never committed.
const String kDefaultDanceWordsPath = String.fromEnvironment(
  'DANCE_WORDS',
  defaultValue:
      '/home/parallels/github/lotti/tools/dance_audio/out/moving.words.json',
);

/// Optional lip-sync cue track (from `tools/dance_audio/lipsync.py` — Rhubarb).
/// Absent → no mouth movement. Drives the singers' mouths from the actual vocal
/// phonemes; the lyric voice tags only gate *which* cat shows the cues.
const String kDefaultDanceCuesPath = String.fromEnvironment(
  'DANCE_CUES',
  defaultValue:
      '/home/parallels/github/lotti/tools/dance_audio/out/moving.cues.json',
);

String get kDanceAudioPath =>
    Platform.environment['DANCE_AUDIO'] ?? kDefaultDanceAudioPath;
String get kDanceBeatMapPath =>
    Platform.environment['DANCE_BEATMAP'] ?? kDefaultDanceBeatMapPath;
String get kDanceWordsPath =>
    Platform.environment['DANCE_WORDS'] ?? kDefaultDanceWordsPath;
String get kDanceCuesPath =>
    Platform.environment['DANCE_CUES'] ?? kDefaultDanceCuesPath;

/// Runtime-only capture mode for command-line video export. This avoids the
/// slow test-engine `toImage()` path: the release Linux app renders normally
/// into an X display, and ffmpeg captures that display in real time.
bool get kDanceRenderOnly =>
    Platform.environment['DANCE_RENDER_ONLY'] == '1' ||
    const bool.fromEnvironment('DANCE_RENDER_ONLY');
bool get kDanceRenderCaptions =>
    Platform.environment['DANCE_RENDER_CAPTIONS'] != '0';
int get kDanceRenderWidth =>
    int.tryParse(Platform.environment['DANCE_RENDER_WIDTH'] ?? '') ?? 1920;
int get kDanceRenderHeight =>
    int.tryParse(Platform.environment['DANCE_RENDER_HEIGHT'] ?? '') ?? 1080;
double get kDanceRenderStartSec =>
    double.tryParse(Platform.environment['DANCE_RENDER_START'] ?? '') ?? 0;
String get kDanceRenderReadyFile =>
    Platform.environment['DANCE_RENDER_READY_FILE'] ?? '';
String get kDanceRenderStartFile =>
    Platform.environment['DANCE_RENDER_START_FILE'] ?? '';

/// Exact-frame export mode for the release desktop app. Unlike X11 capture, the
/// app steps a fixed frame clock, captures the stage [RepaintBoundary], and
/// pipes raw RGBA frames to one ffmpeg process. This keeps the live app's render
/// path while avoiding wall-clock duplicated/dropped capture frames.
bool get kDanceAppExport => Platform.environment['DANCE_APP_EXPORT'] == '1';
int get kDanceAppExportFps =>
    int.tryParse(Platform.environment['DANCE_APP_EXPORT_FPS'] ?? '') ?? 60;
double get kDanceAppExportDurationSec =>
    double.tryParse(Platform.environment['DANCE_APP_EXPORT_DURATION'] ?? '') ??
    0;
String get kDanceAppExportOut =>
    Platform.environment['DANCE_APP_EXPORT_OUT'] ??
    'build/character_video_exports/dance_app_export.mp4';
int get kDanceAppExportCrf =>
    int.tryParse(Platform.environment['DANCE_APP_EXPORT_CRF'] ?? '') ?? 18;
int get kDanceAppExportAudioKbps =>
    int.tryParse(Platform.environment['DANCE_APP_EXPORT_AUDIO_KBPS'] ?? '') ??
    320;
String get kDanceAppExportX264Preset =>
    Platform.environment['DANCE_APP_EXPORT_X264_PRESET'] ?? 'veryfast';
double get kDanceAppExportWarmupSec =>
    double.tryParse(Platform.environment['DANCE_APP_EXPORT_WARMUP'] ?? '') ?? 2;

/// Native review window for the audio demo. The content being judged is the
/// stage image, so keep the desktop window itself 16:9 during choreography and
/// scenery review. If the WM still letterboxes, those bars are intentionally
/// plain black.
const Size kDanceDemoWindowSize = Size(1600, 900);
const double kDanceDemoAspectRatio = 16 / 9;

// The beat-synced choreography derivation (which move, warped clock, beat,
// camera context), its data types, the track-config constants and the side-file
// loaders all live in the shared dance-core modules so the live player and the
// offline frame composer derive identical content from one source of truth.

final class _AppFrameEncoder {
  _AppFrameEncoder._(
    this._process,
    this._stdoutDone,
    this._stderrDone,
    this._stderrBuffer,
  );

  static Future<_AppFrameEncoder> start({
    required int width,
    required int height,
    required int fps,
    required double startSec,
    required double durationSec,
    required String outputPath,
    required String audioPath,
    required int crf,
    required int audioKbps,
    required String x264Preset,
  }) async {
    final outputFile = File(outputPath);
    outputFile.parent.createSync(recursive: true);
    final args = [
      '-y',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgba',
      '-s:v',
      '${width}x$height',
      '-framerate',
      '$fps',
      '-i',
      'pipe:0',
      '-ss',
      startSec.toStringAsFixed(6),
      '-t',
      durationSec.toStringAsFixed(6),
      '-i',
      audioPath,
      '-map',
      '0:v:0',
      '-map',
      '1:a:0',
      '-c:v',
      'libx264',
      '-preset',
      x264Preset,
      '-crf',
      '$crf',
      '-pix_fmt',
      'yuv420p',
      '-profile:v',
      'high',
      '-level',
      '4.2',
      '-r',
      '$fps',
      '-g',
      '${math.max(1, (fps / 2).round())}',
      '-bf',
      '2',
      '-colorspace',
      'bt709',
      '-color_primaries',
      'bt709',
      '-color_trc',
      'bt709',
      '-c:a',
      'aac',
      '-b:a',
      '${audioKbps}k',
      '-ar',
      '48000',
      '-movflags',
      '+faststart',
      '-shortest',
      outputFile.path,
    ];
    final process = await Process.start('ffmpeg', args);
    final stderrBuffer = StringBuffer();
    final stdoutDone = process.stdout.drain<void>();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .forEach(stderrBuffer.write);
    return _AppFrameEncoder._(
      process,
      stdoutDone,
      stderrDone,
      stderrBuffer,
    );
  }

  final Process _process;
  final Future<void> _stdoutDone;
  final Future<void> _stderrDone;
  final StringBuffer _stderrBuffer;
  bool _killed = false;

  Future<void> writeFrame(Uint8List rgba) async {
    _process.stdin.add(rgba);
    await _process.stdin.flush();
  }

  Future<void> finish() async {
    await _process.stdin.close();
    final exitCode = await _process.exitCode;
    await _stdoutDone;
    await _stderrDone;
    if (exitCode != 0) {
      throw StateError('ffmpeg failed with exit $exitCode\n$_stderrBuffer');
    }
  }

  void kill() {
    if (_killed) return;
    _killed = true;
    _process.kill();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await _configureDanceDemoWindow();
  runApp(const DanceToTrackApp());
}

Future<void> _configureDanceDemoWindow() async {
  if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) return;
  await windowManager.ensureInitialized();
  await windowManager.setAspectRatio(kDanceDemoAspectRatio);
  await windowManager.setTitle(
    kDanceRenderOnly ? 'Lotti dance export' : 'Dance to track',
  );
  final size = kDanceRenderOnly
      ? Size(kDanceRenderWidth.toDouble(), kDanceRenderHeight.toDouble())
      : kDanceDemoWindowSize;
  await windowManager.setMinimumSize(
    kDanceRenderOnly ? size : const Size(960, 540),
  );
  await windowManager.setSize(size);
  await windowManager.center();
}

class DanceToTrackApp extends StatelessWidget {
  const DanceToTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Inter (a bundled family) across the transport chrome for a crisp,
    // consistent console look; falls back to the platform font if absent.
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: kDanceRenderOnly ? 'Lotti dance export' : 'Dance to track',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: 'Inter'),
        primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Inter'),
      ),
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
  // The trio: lead plus two backing cats. The clock is the audio position warped
  // through the beat map, not a free-running scalar.
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
  final GlobalKey _stageBoundaryKey = GlobalKey();

  late final Ticker _ticker; // 60 fps repaint pump; time comes from the player.

  BeatMap? _map;
  // The shared per-frame derivation (which move, warped clock, beat, camera
  // context). Null until the beat map loads; the player then delegates every
  // frame to it so the offline composer renders identically. It also holds the
  // beat-loop binding and structural sections, so the State keeps no copies.
  DancePerformance? _perf;
  List<double>? _amplitudes; // full-track waveform, normalized 0..1
  // Section bands for the transport timeline, mapped from the structural
  // sections once on load so the bar doesn't re-allocate the list every frame.
  List<DanceWaveformSection> _waveformSections = const [];
  List<DanceWord> _words = const []; // synced lyrics (optional)
  // Contiguous semantic-section spans (chorus/verse/bridge/...) collapsed from the
  // per-word section tags; the virtual director reads the section label, progress
  // within it, and bar-from-its-downbeat here. Empty without a lyrics file.
  List<DanceSectionSpan> _sectionSpans = const [];
  List<DanceCue> _cues = const []; // Rhubarb lip-sync cues (optional)
  double _trackDurationSec = 0;
  double _bpm = 0;
  bool _loop = true;
  late bool _showCaptions = kDanceRenderOnly && kDanceRenderCaptions;
  // Dev A/B switch: the new layered blue-hour scene vs. the old single-plate
  // waterfront backdrop.
  bool _useNewBackdrop = true;
  ui.Image? _backdrop;
  ui.Image? _clouds;
  ui.Image? _waves;
  double _wallSeconds = 0; // steady clock for ambient backdrop animation
  // Live dancer screen anchors (normalized, left→right), published by the
  // CharacterPainter each frame so the stage lights can follow the cats.
  List<Offset> _dancerAnchors = const [];
  double _leadMouth = 0; // eased frontman mouth (lead lyric words)
  double _bgMouth = 0; // eased backup-dancers' mouth (background ad-libs)
  MouthShape _leadShape = MouthShape.singAh; // viseme for the active lead word
  MouthShape _bgShape = MouthShape.singAh; // viseme for the active backup word
  Duration _lastTick = Duration.zero;
  // The dolly operator: the director emits a per-frame target framing and this
  // rig eases the live camera toward it, so section/home changes read as motivated
  // dolly moves rather than snaps. Section predicates can request genre cuts;
  // currently the chorus downbeat and bridge singer-feature cuts use that path.
  final DanceCameraRig _cameraRig = DanceCameraRig();
  Shot _liveShot = (zoom: 1, dx: 0, dy: 0);
  String? _error;
  bool _renderReadySignaled = false;
  bool _renderStarted = false;
  double _renderClockSeconds = 0;
  bool _appExportStarted = false;
  bool _backdropReadyForExport = false;

  double get _positionSec {
    if (!kDanceRenderOnly) {
      return _player.state.position.inMicroseconds / 1e6;
    }
    final max = _trackDurationSec <= 0 ? double.infinity : _trackDurationSec;
    return (kDanceRenderStartSec + _renderClockSeconds).clamp(0.0, max);
  }

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
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    _ticker = createTicker(_onTick);
    if (!kDanceAppExport) _ticker.start();
    unawaited(_load());
    // Old-backdrop plate, loaded so the A/B toggle can switch to it instantly.
    unawaited(_loadBackdrop());
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (kDanceRenderOnly || kDanceAppExport) return false;
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.space) return false;
    if (_map != null) unawaited(_togglePlay());
    return true;
  }

  bool _advanceRenderClock(double dt) {
    if (!kDanceRenderOnly) return true;
    _signalRenderReadyIfNeeded();
    if (_map == null) return false;
    if (!_renderStarted) {
      final startFile = kDanceRenderStartFile;
      if (startFile.isNotEmpty && !File(startFile).existsSync()) {
        return false;
      }
      _renderStarted = true;
      return true;
    }
    _renderClockSeconds += dt;
    return true;
  }

  void _signalRenderReadyIfNeeded() {
    if (!kDanceRenderOnly || _renderReadySignaled || _map == null) return;
    if (!_renderBackdropReady) return;
    final path = kDanceRenderReadyFile;
    if (path.isNotEmpty) {
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('ready\n');
    }
    _renderReadySignaled = true;
  }

  bool get _renderBackdropReady => !_useNewBackdrop || _backdropReadyForExport;

  void _markBackdropReadyForExport() {
    if (_backdropReadyForExport) return;
    _backdropReadyForExport = true;
    _signalRenderReadyIfNeeded();
  }

  // Per-frame: repaint and ease the singing mouths. The dance camera is no longer
  // a single eased strength — the virtual director ([_directorContext]) computes the
  // whole shot (zoom/pan, with cuts) from the audio position in [build]. Frame-
  // rate independent: uses the real frame dt and a time constant for the mouths.
  void _onTick(Duration elapsed) {
    var dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt < 0) dt = 0;
    if (dt > 0.1) dt = 0.1; // ignore long stalls (tab switch, etc.)
    final clockRunning = _advanceRenderClock(dt);
    if (!clockRunning) {
      if (mounted) setState(() {});
      return;
    }
    // Steady wall clock for ambient backdrop animation + the stage-light gel
    // cycle/sweep (independent of the looping dance clock).
    _wallSeconds += dt;
    final pos = _positionSec;
    setState(() {
      _advancePerformance(pos: pos, dt: dt);
    });
  }

  void _advancePerformance({required double pos, required double dt}) {
    final perf = _perf;
    final cue = mouthForCue(cueShapeAt(_cues, pos));
    final leadOn =
        _words.isEmpty ||
        (perf?.voiceActive(pos, (w) => w.voice == 'lead') ?? false);
    final bgOn =
        perf?.voiceActive(
          pos,
          (w) =>
              w.voice == 'background' ||
              (w.voice == 'lead' && kGroupSections.contains(w.section)),
        ) ??
        false;
    if (leadOn) _leadShape = cue.shape;
    if (bgOn) _bgShape = cue.shape;
    final stage = perf?.stageAt(pos) ?? danceIdleStage(pos);
    final ctx = perf?.directorContext(pos, energetic: stage.energetic);
    final target = ctx == null ? _liveShot : cameraShot(ctx);
    _liveShot = _cameraRig.update(
      target: target,
      cut:
          ctx != null &&
          (isHardCut(ctx) || isChorusDrop(ctx) || isBridgeCut(ctx)),
      dt: dt,
    );
    _leadMouth = easeDanceMouth(_leadMouth, leadOn ? cue.open : 0.0, dt);
    _bgMouth = easeDanceMouth(_bgMouth, bgOn ? cue.open : 0.0, dt);
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

      if (!kDanceRenderOnly) {
        await _player.open(Media(kDanceAudioPath), play: false);
        await _player.setPlaylistMode(
          _loop ? PlaylistMode.loop : PlaylistMode.none,
        );
      }

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
      final sections = classifyDanceSections(rawSections, amplitudes, duration);
      final words = await loadDanceWords(kDanceWordsPath);
      final cues = await loadDanceCues(kDanceCuesPath);
      final spans = buildDanceSectionSpans(words, duration);
      // Anchor the looping phrase on the first downbeat and span whole bars; the
      // 3-bar loop then stays beat-locked for the entire track.
      final binding = BeatLoopBinding.barAligned(map, bars: kDancePhraseBars);
      // The single source of truth for the per-frame derivation; the offline
      // composer builds the same object so its renders match this player.
      final perf = DancePerformance(
        map: map,
        binding: binding,
        sections: sections,
        sectionSpans: spans,
        trackDurationSec: duration,
        words: words,
      );

      if (!mounted) return;
      setState(() {
        _map = map;
        _trackDurationSec = duration;
        _bpm = (tempo?['global_bpm'] as num?)?.toDouble() ?? 0;
        _perf = perf;
        _amplitudes = amplitudes;
        _waveformSections = _buildWaveformSections(spans, sections, duration);
        _words = words;
        _sectionSpans = spans;
        _cues = cues;
      });
      if (kDanceAppExport) unawaited(_exportFramesFromApp());
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _exportFramesFromApp() async {
    if (_appExportStarted) return;
    _appExportStarted = true;
    try {
      if (kDanceAppExportFps <= 0) {
        throw StateError('DANCE_APP_EXPORT_FPS must be positive');
      }
      final start = kDanceRenderStartSec.clamp(0.0, _trackDurationSec);
      final duration = kDanceAppExportDurationSec > 0
          ? math.min(kDanceAppExportDurationSec, _trackDurationSec - start)
          : _trackDurationSec - start;
      if (duration <= 0) throw StateError('export duration is empty');

      await _waitForExportReadiness();

      final frameCount = math.max(1, (duration * kDanceAppExportFps).ceil());
      final dt = 1 / kDanceAppExportFps;
      final encoder = await _AppFrameEncoder.start(
        width: kDanceRenderWidth,
        height: kDanceRenderHeight,
        fps: kDanceAppExportFps,
        startSec: start,
        durationSec: duration,
        outputPath: kDanceAppExportOut,
        audioPath: kDanceAudioPath,
        crf: kDanceAppExportCrf,
        audioKbps: kDanceAppExportAudioKbps,
        x264Preset: kDanceAppExportX264Preset,
      );
      var encoderFinished = false;
      try {
        _prerollExportClock(start: start, dt: dt);
        final progressEvery = math.max(1, kDanceAppExportFps);
        for (var frame = 0; frame < frameCount; frame++) {
          final pos = start + frame * dt;
          await _renderExportFrame(pos: pos, dt: dt);
          await encoder.writeFrame(await _captureStageRgba());
          if (frame % progressEvery == 0 || frame == frameCount - 1) {
            stdout.writeln('rendered ${frame + 1}/$frameCount frames');
          }
        }
        await encoder.finish();
        encoderFinished = true;
      } finally {
        if (!encoderFinished) encoder.kill();
      }
      stdout.writeln('wrote $kDanceAppExportOut');
      exit(0);
    } on Object catch (e, st) {
      stderr
        ..writeln('dance app export failed: $e')
        ..writeln(st);
      exit(1);
    }
  }

  Future<void> _waitForExportReadiness() async {
    // Let the first frame build, then give LayeredBackdrop's async image/shader
    // loads time to settle. This avoids exporting the CPU fallback / empty image
    // state that can exist immediately after the widget tree is mounted.
    await SchedulerBinding.instance.endOfFrame;
    final timeout = math.max(kDanceAppExportWarmupSec, 30);
    final deadline = Stopwatch()..start();
    while (!_renderBackdropReady &&
        deadline.elapsed < Duration(milliseconds: (timeout * 1000).round())) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await SchedulerBinding.instance.endOfFrame;
    }
    if (!_renderBackdropReady) {
      throw StateError('timed out waiting for layered backdrop resources');
    }
    await SchedulerBinding.instance.endOfFrame;
  }

  void _prerollExportClock({required double start, required double dt}) {
    final prerollStart = start <= 2 ? 0.0 : start - 2.0;
    for (var t = prerollStart; t < start; t += dt) {
      _renderClockSeconds = t - kDanceRenderStartSec;
      _wallSeconds = t;
      _advancePerformance(pos: t, dt: dt);
    }
  }

  Future<void> _renderExportFrame({
    required double pos,
    required double dt,
  }) async {
    if (!mounted) throw StateError('export widget unmounted');
    setState(() {
      _renderClockSeconds = pos - kDanceRenderStartSec;
      _wallSeconds = pos;
      _advancePerformance(pos: pos, dt: dt);
    });
    await SchedulerBinding.instance.endOfFrame;
  }

  Future<Uint8List> _captureStageRgba() async {
    final context = _stageBoundaryKey.currentContext;
    if (context == null) throw StateError('stage boundary is not mounted');
    final boundary = context.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('stage boundary is not a RenderRepaintBoundary');
    }
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData();
      if (data == null) throw StateError('failed to read raw RGBA frame');
      return Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  }

  /// The transport timeline's section bands: the musical (lyric) sections when
  /// available — labelled Verse/Chorus/Bridge/… with a leading Intro for any
  /// pre-vocal gap — else the structural energy sections (A/B/C/D). Musical
  /// names give the markers real information scent instead of recycled letters.
  static List<DanceWaveformSection> _buildWaveformSections(
    List<DanceSectionSpan> spans,
    List<DanceSection> structural,
    double duration,
  ) {
    if (spans.isEmpty) {
      return [
        for (final s in structural)
          DanceWaveformSection(start: s.start, end: s.end, label: s.label),
      ];
    }
    final out = <DanceWaveformSection>[];
    final first = spans.first.start;
    if (first > 0.5) {
      out.add(DanceWaveformSection(start: 0, end: first, label: 'Intro'));
    }
    for (final s in spans) {
      out.add(
        DanceWaveformSection(
          start: s.start,
          end: s.end,
          label: danceSectionDisplayName(s.section),
        ),
      );
    }
    return out;
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
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
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

    final posSec = _positionSec;
    final stage = _perf?.stageAt(posSec) ?? danceIdleStage(posSec);
    final beat = _perf?.beatPulse(posSec) ?? 0;
    // The virtual director owns the camera, but the rig OWNS the move: the live
    // shot is the rig's eased framing (advanced each tick toward the director's
    // target), so refrains/feature shots can cut onto committed homes while the
    // rest rides as a dolly. Applied by the painter and lagged behind the
    // dancers by the backdrop parallax.
    final shot = _liveShot;
    // Concert lighting gels: one rig drives BOTH the coloured rim/halo on each
    // cat (CharacterPainter.memberBacklights) and the floor pools
    // (StageLightsOverlay), so the body glow and its pool always share a colour.
    // Gels rotate on the tempo; the beat pulses brightness. New scene only.
    final stageRig = StageLightRig(
      colorPeriod: _bpm > 0 ? 60 / _bpm : 0.5,
      // Lock the centre (lead) lane to the hero gold every frame; flankers cycle.
      leadGoldIndex: 1,
    );
    final stageSamples = _useNewBackdrop
        ? stageRig.sample(time: _wallSeconds, beat: beat)
        : const <StageLightSample>[];
    // Screen order (left→center→right). Alpha scales the halo with the beat;
    // the painter splits this across a soft bloom + a tight rim pass. The centre
    // (lead) rim runs a touch hotter and the flankers near full, so the hero
    // owns the frame by light without starving the backups of glow.
    const heroWeight = [0.9, 1.1, 0.9];
    final catBacklights = [
      for (final (i, s) in stageSamples.indexed)
        s.color.withValues(
          alpha: (s.intensity * heroWeight[i % heroWeight.length]).clamp(
            0.0,
            1.0,
          ),
        ),
    ];
    // The cat bodies are NEVER pulsed with the beat — a full-figure luminance
    // flash on every beat is a photosensitive-epilepsy risk (large area, high
    // contrast, near the 3 Hz threshold at fast tempos). Only the stage lighting
    // around the cats animates: the rim halo and the floor pools. The performers
    // stay lit; the rig pulses around them, exactly like real concert footage.
    final stageView = RepaintBoundary(
      key: _stageBoundaryKey,
      child: Center(
        // Lock the stage to 16:9 so the painted 2560x1440 art maps 1:1
        // (cover == exact fit) and never crops or distorts; the resizable
        // window letterboxes around it. Backdrop, dancers and captions are
        // letterboxed together so the cats stay planted on the painted deck
        // at any window size.
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Size the cast to the available height (the painter scales
              // uniformly, so this keeps the cats correctly proportioned instead
              // of squat at the default scale 1).
              final scale = constraints.maxHeight * 0.78 / 300.0;
              // Parallax the layered scene with the director's shot so it
              // drifts behind the dancers (lagged) instead of sitting dead
              // still, matching the foreground camera the painter applies.
              final backdropTransform =
                  CharacterPainter.danceParallaxTransformForShot(
                    shot: shot,
                    size: Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    ),
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
                        // Use raw audio position, not wall time: scenery
                        // pauses/seeks with the track, while the dance can
                        // still run on the beat-locked phrase clock.
                        timeSeconds: posSec,
                        beatPulse: beat,
                        onReady: kDanceRenderOnly
                            ? _markBackdropReadyForExport
                            : null,
                      ),
                    ),
                  // Aerial-perspective haze band at the waterline: a soft
                  // cool veil that lifts the distant city/water and
                  // separates the foreground cat plane (fades out above the
                  // dancers' feet so they stay crisp). Cheap atmospheric DoF
                  // stand-in. Frame-fixed (not parallaxed with the plate).
                  if (_useNewBackdrop)
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x005E7088),
                            Color(0x005E7088),
                            Color(0x2C5E7088),
                            Color(0x185E7088),
                            Color(0x005E7088),
                          ],
                          stops: [0.0, 0.40, 0.52, 0.64, 0.76],
                        ),
                      ),
                      child: SizedBox.expand(),
                    ),
                  // Floor pools UNDER the dancers' feet, grounding each
                  // cat in its gel without ever masking limbs or creating
                  // foreground occluder strips. The matching rim/halo is
                  // painted by CharacterPainter on the cat silhouettes.
                  if (_useNewBackdrop)
                    StageLightsOverlay(
                      timeSeconds: _wallSeconds,
                      beat: beat,
                      dancerAnchors: _dancerAnchors,
                      rig: stageRig,
                    ),
                  // Screen-fixed finishing grain over the full frame.
                  // The backdrop itself parallax-transforms with the
                  // camera; this pass stays in viewport space so the
                  // side bands get the same texture as the middle.
                  if (_useNewBackdrop) const SceneTextureOverlay(),
                  // Full-colour cats are the stars; the concert rig rings
                  // each one in its gel via memberBacklights (rim/halo) and
                  // grounds it with a floor pool below — no dimming, so the
                  // performers pop off the blue-hour deck.
                  CustomPaint(
                    painter: CharacterPainter(
                      scene: _lead,
                      partnerScene: _left,
                      ensembleScenes: [_left, _right],
                      // Lip-sync: the frontman moves on lead words, the two
                      // backups on background ad-libs.
                      ensembleExpressions: [
                        danceSingExpression(
                          _leadMouth,
                          Expression.neutral,
                          _leadShape,
                        ),
                        danceSingExpression(
                          _bgMouth,
                          Expression.content,
                          _bgShape,
                        ),
                        danceSingExpression(
                          _bgMouth,
                          Expression.happy,
                          _bgShape,
                        ),
                      ],
                      // Section-aware: the energetic dance trio in loud
                      // sections, an eased idle in calm ones.
                      ensembleClips: stage.ensemble,
                      synchronousEnsemble: stage.synchronous,
                      // Heads bob with the music; the singer's head rides the
                      // vocal opening.
                      singingHeadMotion: true,
                      // Enables the multi-member (trio) render path; without
                      // it the painter draws only the lead scene.
                      walkingPair: true,
                      clip: stage.lead,
                      timeSeconds: stage.seconds,
                      // The virtual director supplies the whole shot; the
                      // painter applies it verbatim (cuts and all) instead of
                      // the built-in eased push-in.
                      cameraOverride: shot,
                      // Publish live dancer positions so the stage lights
                      // can track them (new scene only).
                      onDancerAnchors: _useNewBackdrop
                          ? (a) => _dancerAnchors = a
                          : null,
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
                      backdropCloudsImage: _useNewBackdrop ? null : _clouds,
                      backdropWavesImage: _useNewBackdrop ? null : _waves,
                      // Each cat ringed in its gel (rim/halo hugging the
                      // silhouette), tracked through the camera for free.
                      // The body itself is never dimmed/pulsed — only this
                      // edge halo and the floor pools animate (see above).
                      memberBacklights: catBacklights,
                      // Grade the cats INTO the twilight plate (static, not
                      // beat-driven): a cool sky wrap up top fading to a
                      // warm deck/city bounce down low, plus stronger deck
                      // shadows so the trio is planted, not floating.
                      bodyGrade: _useNewBackdrop
                          ? const (
                              skyWrap: Color(0x2E1F3354),
                              // Lighter warm deck bounce: the old 0x2E washed the
                              // shins/feet up into the warm-lit deck so they read
                              // as translucent ghost-legs.
                              deckWrap: Color(0x1E3A2616),
                            )
                          : null,
                      // Hero-stage the trio (lead bigger/downstage) so the
                      // frontman owns the frame — new scene only.
                      heroStaging: _useNewBackdrop,
                      renderer: _renderer,
                    ),
                    child: const SizedBox.expand(),
                  ),
                  if (_showCaptions && _words.isNotEmpty)
                    Positioned(
                      left: 24,
                      right: 24,
                      top: 20,
                      child: Center(child: _caption(posSec)),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
    final section = _perf?.sectionAt(posSec);
    // Prefer the musical section name (Verse/Chorus/…) for the now-playing chip
    // when lyrics are loaded; fall back to the structural label otherwise.
    final musicalLabel = _sectionSpans.isNotEmpty
        ? danceSectionDisplayName(_perf?.sectionInfoAt(posSec).section ?? '')
        : section?.label;
    return Scaffold(
      backgroundColor: Colors.black,
      body: kDanceRenderOnly
          ? stageView
          : Column(
              children: [
                Expanded(child: stageView),
                DanceTransportBar(
                  loading: _map == null,
                  playing: _player.state.playing,
                  loop: _loop,
                  showCaptions: _showCaptions,
                  captionsAvailable: _words.isNotEmpty,
                  useNewBackdrop: _useNewBackdrop,
                  bpm: _bpm,
                  positionSec: posSec,
                  durationSec: _trackDurationSec,
                  currentSectionLabel: musicalLabel,
                  amplitudes: _amplitudes,
                  sections: _waveformSections,
                  onPlayPause: () => unawaited(_togglePlay()),
                  onToggleLoop: () => unawaited(_toggleLoop()),
                  onToggleCaptions: () =>
                      setState(() => _showCaptions = !_showCaptions),
                  onToggleBackdrop: () =>
                      setState(() => _useNewBackdrop = !_useNewBackdrop),
                  onSeekToSeconds: _seekToTime,
                ),
              ],
            ),
    );
  }
}
