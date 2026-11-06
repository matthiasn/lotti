import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_companion.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_speech_bubble.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// What every voice sample says, word for word: her mouth is timed to these
/// words. English, as the clips are; `tool/onboarding_voice_samples.py`
/// renders them from the same sentence.
const onboardingVoiceSampleText =
    "Hi, I'm Lotti. This is how I sound when I read your summaries aloud.";

/// A voice she can speak with, and its bundled sample.
enum OnboardingVoiceSample {
  /// Supertonic, on the device: free, private, offline once downloaded.
  onDevice('assets/onboarding/voice_samples/on_device.wav'),

  /// Mistral's Voxtral: comes with the recommended key.
  voxtral('assets/onboarding/voice_samples/voxtral.wav'),

  /// ElevenLabs: optional, with a key of its own.
  elevenLabs('assets/onboarding/voice_samples/elevenlabs.wav');

  const OnboardingVoiceSample(this.asset);

  /// The bundled 16-bit PCM WAV of [onboardingVoiceSampleText].
  final String asset;

  String label(AppLocalizations m) => switch (this) {
    onDevice => m.onboardingVoiceOnDeviceName,
    voxtral => m.onboardingVoiceVoxtralName,
    elevenLabs => m.onboardingVoiceElevenLabsName,
  };

  String description(AppLocalizations m) => switch (this) {
    onDevice => m.onboardingVoiceOnDeviceDescription,
    voxtral => m.onboardingVoiceVoxtralDescription,
    elevenLabs => m.onboardingVoiceElevenLabsDescription,
  };
}

/// The optional "hear the voices" step before the key: one card per voice she
/// can have, each playing its sample through her, so she says it with her
/// mouth in time.
///
/// Samples play under her step's own source ([OnboardingCompanionBeat.voices])
/// at their natural speed; starting one stops whatever was speaking, tapping
/// the playing one stops it, and leaving the step ends it with her.
/// [onPlayed] reports each sample that started playing.
class OnboardingVoicesStep extends ConsumerStatefulWidget {
  const OnboardingVoicesStep({
    required this.onContinue,
    required this.onBack,
    required this.onPlayed,
    super.key,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final ValueChanged<OnboardingVoiceSample> onPlayed;

  @override
  ConsumerState<OnboardingVoicesStep> createState() =>
      _OnboardingVoicesStepState();
}

class _OnboardingVoicesStepState extends ConsumerState<OnboardingVoicesStep> {
  /// The sample last started here; it is the one playing while her source
  /// holds the voice.
  OnboardingVoiceSample? _started;

  static final String _sourceId = OnboardingCompanionBeat.voices.sourceId;

  Future<void> _toggle(
    OnboardingVoiceSample sample, {
    required bool playing,
  }) async {
    final voice = ref.read(ttsPlaybackControllerProvider.notifier);
    if (playing) {
      await voice.stop(sourceId: _sourceId);
      return;
    }
    setState(() => _started = sample);
    // Whatever is speaking — her line, another sample — gives way.
    await voice.stop();
    if (!mounted || _started != sample) return;
    await voice.playClip(
      sourceId: _sourceId,
      asset: sample.asset,
      text: onboardingVoiceSampleText,
    );
    // Reported only once it actually plays: a clip that cannot be loaded
    // ends in an error, and that is no sample heard.
    if (!mounted || _started != sample) return;
    final result = ref.read(ttsPlaybackControllerProvider);
    if (result.sourceId == _sourceId &&
        result.status == TtsPlaybackStatus.playing) {
      widget.onPlayed(sample);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(ttsPlaybackControllerProvider);
    final active =
        playback.sourceId == _sourceId &&
        (playback.status == TtsPlaybackStatus.synthesizing ||
            playback.status == TtsPlaybackStatus.playing);
    final messages = context.messages;
    return OnboardingVoicesView(
      title: messages.onboardingVoicesTitle,
      line: messages.onboardingVoicesLine,
      companion: OnboardingCompanion(
        beat: OnboardingCompanionBeat.voices,
        line: messages.onboardingVoicesLine,
        framing: CompanionFraming.bust,
      ),
      playing: active ? _started : null,
      onToggle: _toggle,
      onContinue: widget.onContinue,
      onBack: widget.onBack,
    );
  }
}

/// The "hear the voices" panel, free of providers: her bust beside her
/// bubble, a card per voice with its play control, a note that the samples
/// are English, and the way on.
class OnboardingVoicesView extends StatelessWidget {
  const OnboardingVoicesView({
    required this.title,
    required this.line,
    required this.companion,
    required this.playing,
    required this.onToggle,
    required this.onContinue,
    required this.onBack,
    super.key,
  });

  final String title;
  final String line;
  final Widget companion;

  /// The sample playing now, if any.
  final OnboardingVoiceSample? playing;

  /// Called with a sample and whether it is the one playing now.
  final void Function(OnboardingVoiceSample sample, {required bool playing})
  onToggle;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final spacing = tokens.spacing;
    final textHigh = tokens.colors.text.highEmphasis;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: ColoredBox(
        color: tokens.colors.background.level01,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.step5,
            spacing.step5,
            spacing.step5,
            // Clear the home indicator when flush to the bottom as a sheet.
            spacing.step5 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: onBack,
                  iconSize: spacing.step5,
                  color: textHigh,
                  icon: const Icon(LottiIcons.back),
                ),
              ),
              SizedBox(height: spacing.step2),
              Text(
                title,
                style: tokens.typography.styles.heading.heading3.copyWith(
                  color: textHigh,
                ),
              ),
              SizedBox(height: spacing.step3),
              Row(
                children: [
                  ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: ControlSizes.avatarHero,
                      child: companion,
                    ),
                  ),
                  SizedBox(width: spacing.step2),
                  Expanded(
                    child: OnboardingSpeechBubble(
                      text: line,
                      tail: OnboardingBubbleTail.left,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.step4),
              for (final sample in OnboardingVoiceSample.values)
                Padding(
                  padding: EdgeInsets.only(bottom: spacing.step3),
                  child: _VoiceCard(
                    sample: sample,
                    playing: playing == sample,
                    onToggle: () =>
                        onToggle(sample, playing: playing == sample),
                  ),
                ),
              Text(
                messages.onboardingVoicesEnglishNote,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
              SizedBox(height: spacing.step6),
              DesignSystemButton(
                onPressed: onContinue,
                label: messages.onboardingVoicesContinue,
                leadingIcon: LottiIcons.forward,
                size: DesignSystemButtonSize.large,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One voice: its play (or stop) control, its name and what it costs.
class _VoiceCard extends StatelessWidget {
  const _VoiceCard({
    required this.sample,
    required this.playing,
    required this.onToggle,
  });

  final OnboardingVoiceSample sample;
  final bool playing;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final name = sample.label(messages);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(
          color: playing
              ? tokens.colors.interactive.enabled
              : tokens.colors.decorative.level01,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step3),
        child: Row(
          children: [
            IconButton.filledTonal(
              key: ValueKey('onboarding-voice-${sample.name}'),
              tooltip: playing
                  ? messages.onboardingVoiceStop(name)
                  : messages.onboardingVoicePlay(name),
              onPressed: onToggle,
              icon: Icon(playing ? LottiIcons.stop : LottiIcons.play),
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    sample.description(messages),
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
