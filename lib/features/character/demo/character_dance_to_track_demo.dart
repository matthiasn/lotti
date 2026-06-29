import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/character/demo/dance_lip_sync.dart';
import 'package:lotti/features/character/demo/dance_loaders.dart';
import 'package:lotti/features/character/demo/dance_performance.dart';
import 'package:lotti/features/character/demo/dance_playback_stepper.dart';
import 'package:lotti/features/character/demo/dance_stage_view.dart';
import 'package:lotti/features/character/demo/dance_transport_bar.dart';
import 'package:lotti/features/character/model/beat_map.dart';
import 'package:lotti/features/character/runtime/character_painter.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
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
  // The trio: lead plus two backing cats, built once. The clock is the audio
  // position warped through the beat map, not a free-running scalar.
  late final DanceCast _cast = DanceCast.build();

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
  Duration _lastTick = Duration.zero;
  // The stateful half of each frame: the eased singing mouths + the smoothed
  // virtual camera (with cuts). One code path, shared with the offline renderers
  // so the per-frame orchestration can't drift.
  final DancePlaybackStepper _stepper = DancePlaybackStepper();
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
    _stepper.advance(_perf, _cues, pos, dt);
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
    // The director owns the camera; the stepper holds the eased framing and the
    // singing mouths. The whole composite is the generalized DanceStageView,
    // rendered identically by the live app and every offline renderer — there is
    // no second paint path to drift.
    final stageView = DanceStageView(
      boundaryKey: _stageBoundaryKey,
      cast: _cast,
      renderer: _renderer,
      stage: stage,
      shot: _stepper.shot,
      beat: beat,
      backdropTimeSeconds: posSec,
      // Ambient stage lights run on a steady wall clock (decoupled from the
      // looping dance); offline renderers pass the audio position instead so a
      // render is deterministic at a position.
      lightsTimeSeconds: _wallSeconds,
      bpm: _bpm,
      leadMouth: _stepper.leadMouth,
      bgMouth: _stepper.bgMouth,
      leadShape: _stepper.leadShape,
      bgShape: _stepper.bgShape,
      dancerAnchors: _dancerAnchors,
      onDancerAnchors: (a) => _dancerAnchors = a,
      useNewBackdrop: _useNewBackdrop,
      showCaptions: _showCaptions,
      words: _words,
      onBackdropReady: kDanceRenderOnly ? _markBackdropReadyForExport : null,
      backdropImage: _backdrop,
      cloudsImage: _clouds,
      wavesImage: _waves,
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
