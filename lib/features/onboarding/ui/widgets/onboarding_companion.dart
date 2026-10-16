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

/// Whether the companion takes part in onboarding: her own flag,
/// `enable_companion`. Off, every onboarding surface is as it was.
bool watchOnboardingCompanionEnabled(WidgetRef ref) =>
    ref.watch(configFlagProvider(enableCompanionFlag)).value ?? false;

/// A moment of onboarding, and what she does in it.
enum OnboardingCompanionBeat {
  /// The welcome: she waves.
  welcome(cue: GestureName.wave),

  /// The first-task prompt: she waves the user on.
  prompt(cue: GestureName.wave),

  /// The mic is open: she listens for as long as it is.
  listening(holding: GestureName.listen),

  /// The words are being structured: she thinks until they are.
  thinking(holding: GestureName.think),

  /// The first task landed: she celebrates.
  created(cue: GestureName.celebrate);

  const OnboardingCompanionBeat({this.cue, this.holding});

  /// Played once as the beat begins.
  final GestureName? cue;

  /// Kept up for as long as the beat lasts.
  final GestureName? holding;

  /// The beat of a first-task frame.
  static OnboardingCompanionBeat of(OnboardingFirstTaskPhase phase) =>
      switch (phase) {
        OnboardingFirstTaskPhase.prompt => prompt,
        OnboardingFirstTaskPhase.listening => listening,
        OnboardingFirstTaskPhase.thinking => thinking,
        OnboardingFirstTaskPhase.created => created,
      };
}

/// The companion in onboarding: she greets, listens while the user records,
/// thinks while the task is structured, and celebrates when it lands.
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

  /// The utterance she speaks under: one for all of onboarding, since only
  /// one onboarding surface is ever on screen.
  static const sourceId = 'onboarding-companion';

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
    Future.microtask(
      () => _voice.stop(sourceId: OnboardingCompanion.sourceId),
    ).ignore();
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
    if (line == null) {
      await _voice.stop(sourceId: OnboardingCompanion.sourceId);
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
    // Her previous line, if it is still playing, gives way to this one;
    // anything else speaking is left alone, and then the voice skips her.
    await _voice.stop(sourceId: OnboardingCompanion.sourceId);
    if (!mounted || generation != _lineGeneration) return;
    await _voice.speak(sourceId: OnboardingCompanion.sourceId, text: line);
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
      sourceId: OnboardingCompanion.sourceId,
      framing: widget.framing,
      controller: _controller,
      holding: widget.beat.holding,
    );
  }
}
