import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_cloud_voices_section.dart';
import 'package:lotti/features/tts/ui/widgets/tts_model_selector.dart';
import 'package:lotti/features/tts/ui/widgets/tts_settings_sections.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:lotti/widgets/settings/settings_page_layout.dart';
import 'package:material_ui/material_ui.dart';

/// Headerless body for the Speech settings, shared by the mobile page and the
/// desktop Settings-v2 detail panel (mirrors how ThemingBody / category bodies
/// are reused). Reuses the entity-definition `SettingsFormSection` design
/// language: Chat audio, Cloud voices, the on-device Voice and Model, and
/// Reading speed, each wired to the persisted [TtsSettingsController]. The
/// sections shared with the companion's Voice tab are the widgets of
/// `tts_settings_sections.dart`.
class SpeechSettingsBody extends ConsumerWidget {
  const SpeechSettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelId = ref.watch(
      ttsSettingsControllerProvider.select((settings) => settings.modelId),
    );
    final controller = ref.read(ttsSettingsControllerProvider.notifier);
    final messages = context.messages;
    final spacing = context.designTokens.spacing;

    // Anchor on the shared settings content grid (responsive horizontal
    // insets, capped + centered on wide panes) so the sections line up with
    // every other settings detail page instead of stretching flush to the
    // pane edges. The leaf-panel host adds no padding of its own.
    return SettingsContentArea(
      child: Padding(
        padding: EdgeInsets.only(top: spacing.step5, bottom: spacing.step6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsFormSection(
              title: messages.speechSettingsChatAudioLabel,
              description: messages.speechSettingsChatAudioDescription,
              children: const [
                TtsAutoPrepareRow(),
              ],
            ),
            const TtsCloudVoicesSection(),
            const TtsVoiceSection(),
            SettingsFormSection(
              title: messages.speechSettingsModelLabel,
              description: messages.speechSettingsModelDescription,
              children: [
                TtsModelSelector(
                  modelId: modelId,
                  onChanged: controller.setModel,
                ),
              ],
            ),
            const TtsSpeedSection(),
          ],
        ),
      ),
    );
  }
}
