import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/model/tts_voice.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Selectable list of the Supertonic voices, grouped Female (F1–F5) then
/// Male (M1–M5). Each row is a ≥44pt target; the active voice carries a
/// leading accent check (shape, not color alone) and a selected semantics
/// flag. Rendered inside a `SettingsFormSection` card by the page body.
class TtsVoiceSelector extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final female = kSupertonicVoices.where(
      (v) => v.gender == TtsVoiceGender.female,
    );
    final male = kSupertonicVoices.where(
      (v) => v.gender == TtsVoiceGender.male,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupLabel(context.messages.speechVoiceGenderFemale),
        for (final voice in female) _row(context, voice),
        SizedBox(height: context.designTokens.spacing.step3),
        _GroupLabel(context.messages.speechVoiceGenderMale),
        for (final voice in male) _row(context, voice),
      ],
    );
  }

  Widget _row(BuildContext context, TtsVoice voice) => _VoiceRow(
    label: voiceLabel(context, voice),
    selected: voice.id == voiceId,
    onTap: () => onChanged(voice.id),
  );
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
      child: Text(
        text,
        style: tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
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
