import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/model/tts_voice.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Selectable list of the Supertonic voices.
///
/// A Female | Male [DsSegmentedToggle] (the same pill control as the Daily OS
/// plan switch and the Time Analysis chart-mode toggle) chooses which gender's
/// five numbered voices (F1–F5 / M1–M5) are shown, so the list stays short
/// instead of stacking all ten with subheaders. The toggle opens on the
/// selected voice's gender and follows it if the selection moves across genders
/// from outside; switching the toggle is a view filter and never changes the
/// persisted selection on its own.
///
/// Each row is a ≥44pt target; the active voice carries a leading accent check
/// (shape, not color alone) and a selected semantics flag. Rendered inside a
/// `SettingsFormSection` card by the page body.
class TtsVoiceSelector extends StatefulWidget {
  const TtsVoiceSelector({
    required this.voiceId,
    required this.onChanged,
    super.key,
  });

  final String voiceId;
  final ValueChanged<String> onChanged;

  /// Localized display label for [voice], e.g. "Female 1".
  static String voiceLabel(BuildContext context, TtsVoice voice) {
    final messages = context.messages;
    final gender = voice.gender == TtsVoiceGender.female
        ? messages.speechVoiceGenderFemale
        : messages.speechVoiceGenderMale;
    return '$gender ${voice.id.substring(1)}';
  }

  @override
  State<TtsVoiceSelector> createState() => _TtsVoiceSelectorState();
}

class _TtsVoiceSelectorState extends State<TtsVoiceSelector> {
  late TtsVoiceGender _gender = ttsVoiceByIdOrDefault(widget.voiceId).gender;

  @override
  void didUpdateWidget(TtsVoiceSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow the selection's gender only when the voice itself changes across
    // genders from outside (e.g. a reset). A manual toggle tap leaves voiceId
    // unchanged, so this never fights the user's chosen tab.
    if (widget.voiceId != oldWidget.voiceId) {
      _gender = ttsVoiceByIdOrDefault(widget.voiceId).gender;
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final voices = kSupertonicVoices.where((v) => v.gender == _gender);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: DsSegmentedToggle<TtsVoiceGender>(
            selected: _gender,
            onChanged: (gender) => setState(() => _gender = gender),
            segments: [
              DsSegment(
                TtsVoiceGender.female,
                messages.speechVoiceGenderFemale,
              ),
              DsSegment(TtsVoiceGender.male, messages.speechVoiceGenderMale),
            ],
          ),
        ),
        SizedBox(height: context.designTokens.spacing.step3),
        for (final voice in voices)
          _VoiceRow(
            label: TtsVoiceSelector.voiceLabel(context, voice),
            selected: voice.id == widget.voiceId,
            onTap: () => widget.onChanged(voice.id),
          ),
      ],
    );
  }
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const double _minTarget = 44;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(tokens.radii.s),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _minTarget),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step2,
                  vertical: tokens.spacing.step2,
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 20,
                      color: selected
                          ? ai.accent
                          : tokens.colors.text.lowEmphasis,
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    Expanded(
                      child: Text(
                        label,
                        style: tokens.typography.styles.body.bodyMedium
                            .copyWith(
                              color: tokens.colors.text.highEmphasis,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
