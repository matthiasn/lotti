import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_speed_selector.dart';
import 'package:lotti/features/tts/ui/widgets/tts_voice_selector.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:material_ui/material_ui.dart';

/// The on-device voice, under its heading: one of the Supertonic voices,
/// picked as the user's own ([TtsSettingsController.setVoice]).
///
/// One of the speech settings every page that hosts them composes — the
/// Speech page and the Voice tab of the companion's settings — so a setting
/// is wired once.
class TtsVoiceSection extends ConsumerWidget {
  const TtsVoiceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceId = ref.watch(
      ttsSettingsControllerProvider.select((settings) => settings.voiceId),
    );
    final messages = context.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Heading only: the voice list is a grouped list of its own, so
        // its rows are not inset twice by a form card.
        SettingsFormSection(
          title: messages.speechSettingsVoiceLabel,
          description: messages.speechSettingsVoiceDescription,
          children: const [],
        ),
        Padding(
          padding: EdgeInsets.only(
            bottom: context.designTokens.spacing.sectionGap,
          ),
          child: TtsVoiceSelector(
            voiceId: voiceId,
            onChanged: ref
                .read(ttsSettingsControllerProvider.notifier)
                .setVoice,
          ),
        ),
      ],
    );
  }
}

/// How fast she reads, under its heading
/// ([TtsSettingsController.setSpeed]).
class TtsSpeedSection extends ConsumerWidget {
  const TtsSpeedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(
      ttsSettingsControllerProvider.select((settings) => settings.speed),
    );
    final messages = context.messages;
    return SettingsFormSection(
      title: messages.speechSettingsSpeedLabel,
      description: messages.speechSettingsSpeedDescription,
      children: [
        TtsSpeedSelector(
          value: speed,
          onChanged: ref.read(ttsSettingsControllerProvider.notifier).setSpeed,
        ),
      ],
    );
  }
}

/// The checkbox for preparing new chat replies' audio ahead
/// ([TtsSettingsController.setAutoPrepareChatAudio]). [described] where no
/// section heading around it says what that means.
class TtsAutoPrepareRow extends ConsumerWidget {
  const TtsAutoPrepareRow({this.described = false, super.key});

  /// Whether the row explains itself in a subtitle.
  final bool described;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      ttsSettingsControllerProvider.select(
        (settings) => settings.autoPrepareChatAudio,
      ),
    );
    final messages = context.messages;
    return DesignSystemSelectionRow(
      title: messages.speechSettingsAutoPrepareChatAudio,
      subtitle: described ? messages.speechSettingsChatAudioDescription : null,
      titleMaxLines: 2,
      subtitleMaxLines: 3,
      type: DesignSystemSelectionRowType.multiSelect,
      selected: enabled,
      showSelectedBackground: false,
      onTap: () => ref
          .read(ttsSettingsControllerProvider.notifier)
          .setAutoPrepareChatAudio(enabled: !enabled),
    );
  }
}
