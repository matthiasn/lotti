import 'package:lotti/features/character/demo/dance_camera_director.dart';
import 'package:lotti/features/character/demo/dance_camera_rig.dart';
import 'package:lotti/features/character/demo/dance_lip_sync.dart';
import 'package:lotti/features/character/demo/dance_performance.dart';
import 'package:lotti/features/character/model/face.dart';

/// The stateful, history-dependent half of one dance frame: the singing mouths
/// (eased) and the virtual camera (smoothed, with cuts). The pure half — which
/// move, the warped clock, the beat, the director context — is [DancePerformance].
///
/// Both the live player and every offline renderer own one stepper and call
/// [advance] once per frame, so the per-frame orchestration (voice gating →
/// mouth ease → stage → director → camera cut) is a single code path that cannot
/// drift between them. Because the camera and mouths integrate over `dt`, an
/// offline renderer must **preroll** (advance without rendering) from a lead-in
/// before the first frame it cares about to settle the framing.
class DancePlaybackStepper {
  final DanceCameraRig _cameraRig = DanceCameraRig();

  double _leadMouth = 0;
  double _bgMouth = 0;
  MouthShape _leadShape = MouthShape.singAh;
  MouthShape _bgShape = MouthShape.singAh;
  Shot _shot = (zoom: 1, dx: 0, dy: 0);
  DanceStage? _stage;

  /// How far open the frontman's mouth is (0 = shut), eased toward the cue.
  double get leadMouth => _leadMouth;

  /// How far open the backups' mouths are.
  double get bgMouth => _bgMouth;

  /// The frontman's current viseme.
  MouthShape get leadShape => _leadShape;

  /// The backups' current viseme.
  MouthShape get bgShape => _bgShape;

  /// The framing the camera rig has settled on.
  Shot get shot => _shot;

  /// The stage from the most recent [advance] (null before the first call).
  DanceStage? get stage => _stage;

  /// Advances the mouths and camera by [dt] seconds at audio position [pos].
  ///
  /// [perf] is null before the track loads — the trio then idles and the camera
  /// holds. [cues] is the Rhubarb lip-sync track (empty → mouths rest).
  void advance(
    DancePerformance? perf,
    List<DanceCue> cues,
    double pos,
    double dt,
  ) {
    final cue = mouthForCue(cueShapeAt(cues, pos));
    final words = perf?.words ?? const <DanceWord>[];
    // No lyrics → the frontman lip-syncs every cue; otherwise only on lead words.
    final leadOn =
        words.isEmpty ||
        (perf?.voiceActive(pos, (w) => w.voice == 'lead') ?? false);
    // The backups sing background ad-libs, and join the lead on group hooks.
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
    _leadMouth = easeDanceMouth(_leadMouth, leadOn ? cue.open : 0.0, dt);
    _bgMouth = easeDanceMouth(_bgMouth, bgOn ? cue.open : 0.0, dt);

    final stage = perf?.stageAt(pos) ?? danceIdleStage(pos);
    final ctx = perf?.directorContext(pos, energetic: stage.energetic);
    final target = ctx == null ? _shot : cameraShot(ctx);
    _shot = _cameraRig.update(
      target: target,
      cut:
          ctx != null &&
          (isHardCut(ctx) || isChorusDrop(ctx) || isBridgeCut(ctx)),
      dt: dt,
    );
    _stage = stage;
  }
}
