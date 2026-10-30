import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/tts/model/tts_voice.dart';
import 'package:lotti/features/tts/ui/widgets/tts_gender_filter.dart';
import 'package:lotti/features/tts/ui/widgets/tts_voice_radio_row.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Selectable list of the Supertonic voices.
///
/// A Female | Male [TtsGenderFilter] (the same filter as the cloud voice
/// picker, a `DsSegmentedToggle` underneath) chooses which gender's
/// five numbered voices (F1–F5 / M1–M5) are shown, so the list stays short
/// instead of stacking all ten with subheaders. The toggle opens on the
/// selected voice's gender and follows it if the selection moves across genders
/// from outside; switching the toggle is a view filter and never changes the
/// persisted selection on its own.
///
/// Each row is a [TtsVoiceRadioRow], the same row the cloud voice picker
/// uses, in a grouped list of its own — the same list grammar as the Cloud
/// voices section above it. The page body sets only the heading above it.
class TtsVoiceSelector extends StatefulWidget {
  const TtsVoiceSelector({
    required this.voiceId,
    required this.onChanged,
    super.key,
  });

  /// Currently selected voice id; also seeds the gender tab.
  final String voiceId;

  /// Called with the tapped voice's id.
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
    final voices = kSupertonicVoices.where((v) => v.gender == _gender);

    return DesignSystemGroupedList(
      padding: EdgeInsets.zero,
      children: [
        TtsGenderFilter<TtsVoiceGender>(
          selected: _gender,
          female: TtsVoiceGender.female,
          male: TtsVoiceGender.male,
          onChanged: (gender) => setState(() => _gender = gender),
        ),
        for (final voice in voices)
          TtsVoiceRadioRow(
            title: TtsVoiceSelector.voiceLabel(context, voice),
            selected: voice.id == widget.voiceId,
            onTap: () => widget.onChanged(voice.id),
          ),
      ],
    );
  }
}
