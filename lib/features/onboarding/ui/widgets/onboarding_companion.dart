import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_first_task_view.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// A moment of onboarding, and what she does in it.
enum OnboardingCompanionBeat {
  /// The welcome: she waves.
  welcome(surface: 'welcome', cue: GestureName.wave),

  /// The "make me yours" step: she opens her arms to be dressed.
  dressUp(surface: 'make-her-yours', cue: GestureName.openBoth),

  /// The one-key step: she presents the recommended provider.
  recommend(surface: 'connect', cue: GestureName.presentRight),

  /// The first-task prompt: she waves the user on.
  prompt(surface: _firstTask, cue: GestureName.wave),

  /// The mic is open: she listens for as long as it is.
  listening(surface: _firstTask, holding: GestureName.listen),

  /// The words are being structured: she thinks until they are.
  thinking(surface: _firstTask, holding: GestureName.think),

  /// The first task landed: she celebrates.
  created(surface: _firstTask, cue: GestureName.celebrate);

  const OnboardingCompanionBeat({
    required this.surface,
    this.cue,
    this.holding,
  });

  static const _firstTask = 'first-task';

  /// The onboarding step the beat belongs to; the beats of one step share it.
  final String surface;

  /// Played once as the beat begins.
  final GestureName? cue;

  /// Kept up for as long as the beat lasts.
  final GestureName? holding;

  /// The utterance she speaks under on this beat's step.
  ///
  /// Each step has its own: steps crossfade, so the outgoing step is disposed
  /// after the incoming one has started speaking, and ending its own
  /// utterance must leave the new step's alone.
  String get sourceId => '${OnboardingCompanion.sourcePrefix}$surface';

  /// The beat of a first-task frame.
  static OnboardingCompanionBeat of(OnboardingFirstTaskPhase phase) =>
      switch (phase) {
        OnboardingFirstTaskPhase.prompt => prompt,
        OnboardingFirstTaskPhase.listening => listening,
        OnboardingFirstTaskPhase.thinking => thinking,
        OnboardingFirstTaskPhase.created => created,
      };
}

/// The companion in onboarding: she greets, recommends the one key to start
/// with, listens while the user records, thinks while the task is structured,
/// and celebrates when it lands. She leads onboarding whether or not her flag,
/// `enable_companion`, has her anywhere else in the app.
///
/// [line] is what the surface already shows as its headline — her caption.
/// She speaks it only where the voice is on hand: read-aloud on, a device
/// voice, and its model already installed. On a first run the model is not,
/// and the download is not worth a first impression, so there she is silent
/// and the caption carries the words. A null [line] silences her, so she
/// never talks over a recording.
class OnboardingCompanion extends ConsumerStatefulWidget {
  const OnboardingCompanion({
    required this.beat,
    this.line,
    this.framing = CompanionFraming.full,
    super.key,
  });

  final OnboardingCompanionBeat beat;
  final String? line;
  final CompanionFraming framing;

  /// What every onboarding utterance's source id starts with
  /// ([OnboardingCompanionBeat.sourceId]).
  static const sourcePrefix = 'onboarding-companion-';

  /// The subject she is dressed for on every onboarding step.
  static const dressedFor = 'onboarding-companion';

  @override
  ConsumerState<OnboardingCompanion> createState() =>
      _OnboardingCompanionState();
}

class _OnboardingCompanionState extends ConsumerState<OnboardingCompanion> {
  final _controller = CompanionController();
  late final TtsPlaybackController _voice;

  // Bumped by every line, so a slow model check for a line already replaced
  // never speaks it.
  int _lineGeneration = 0;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(ttsPlaybackControllerProvider.notifier);
    _cueAfterFrame();
    _sayLater(widget.line);
  }

  @override
  void didUpdateWidget(OnboardingCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.beat != widget.beat) _cueAfterFrame();
    if (oldWidget.line != widget.line) _sayLater(widget.line);
  }

  @override
  void dispose() {
    // Leaving the surface ends what she was saying on it — after the frame,
    // like every write to the voice from here.
    final sourceId = widget.beat.sourceId;
    Future.microtask(() => _voice.stop(sourceId: sourceId)).ignore();
    super.dispose();
  }

  /// Plays the beat's gesture once her view, built below this one, is
  /// attached to the controller.
  void _cueAfterFrame() {
    final cue = widget.beat.cue;
    if (cue == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.play(cue);
    });
  }

  /// [_say], once the frame in progress is done. The lifecycle methods that
  /// change her line run while the tree builds or tears down, when Riverpod
  /// refuses a provider write: the voice's `stop` would throw before reaching
  /// the player, and she would talk on into the recording.
  void _sayLater(String? line) => Future.microtask(() => _say(line)).ignore();

  /// Speaks [line] when the voice is on hand, or ends her utterance when
  /// [line] is null. Speaking and stopping settle their own failures in the
  /// playback state, so nothing here waits on more than the model check.
  Future<void> _say(String? line) async {
    final generation = ++_lineGeneration;
    final sourceId = widget.beat.sourceId;
    if (line == null) {
      await _voice.stop(sourceId: sourceId);
      return;
    }
    // Deferred from a frame in which she may also have left: `ref` is gone
    // then, and `dispose` has already ended her utterance.
    if (!mounted) return;
    // Still loading on the first frame: the listener in build says the line
    // once the flag arrives.
    final readAloud =
        ref.read(configFlagProvider(enableAiSummaryTtsFlag)).value ?? false;
    if (!readAloud || !ref.read(ttsEngineProvider).isSupported) return;
    final modelId = ref.read(ttsSettingsControllerProvider).modelId;
    final installed = await ref
        .read(ttsModelRepositoryProvider)
        .isInstalled(modelId);
    if (!installed || !mounted || generation != _lineGeneration) return;
    // Her previous line, on this step or the one she just left, gives way to
    // this one; anything else speaking is left alone, and then the voice
    // skips her.
    final playing = ref.read(ttsPlaybackControllerProvider).sourceId;
    if (playing != null &&
        playing.startsWith(OnboardingCompanion.sourcePrefix)) {
      await _voice.stop(sourceId: playing);
    }
    if (!mounted || generation != _lineGeneration) return;
    await _voice.speak(sourceId: sourceId, text: line);
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the read-aloud flag alive and follows it: the current line is
    // spoken once it loads (or turns) on — the first `_say` may have run
    // before it had — and silenced when it turns off, from here or by sync.
    ref.listen(configFlagProvider(enableAiSummaryTtsFlag), (previous, next) {
      if (next.value == true && previous?.value != true) {
        _sayLater(widget.line);
      } else if (next.value == false && previous?.value == true) {
        _sayLater(null);
      }
    });
    return CompanionSpeaker(
      sourceId: widget.beat.sourceId,
      // One outfit for all of onboarding, though each step speaks under its
      // own source: she does not change clothes between steps.
      dressedFor: OnboardingCompanion.dressedFor,
      framing: widget.framing,
      controller: _controller,
      holding: widget.beat.holding,
    );
  }
}
