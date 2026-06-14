import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_model_selector.dart';
import 'package:lotti/features/tts/ui/widgets/tts_speed_selector.dart';
import 'package:lotti/features/tts/ui/widgets/tts_voice_selector.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:lotti/widgets/settings/settings_page_layout.dart';

/// Headerless body for the Speech settings, shared by the mobile page and the
/// desktop Settings-v2 detail panel (mirrors how ThemingBody / category bodies
/// are reused). Reuses the entity-definition `SettingsFormSection` design
/// language: Voice, Model, and Reading-speed sections, each wired to the
/// persisted [TtsSettingsController].
class SpeechSettingsBody extends ConsumerWidget {
  const SpeechSettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(ttsSettingsControllerProvider);
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
              title: messages.speechSettingsVoiceLabel,
              description: messages.speechSettingsVoiceDescription,
              children: [
                TtsVoiceSelector(
                  voiceId: settings.voiceId,
                  onChanged: controller.setVoice,
                ),
              ],
            ),
            SettingsFormSection(
              title: messages.speechSettingsModelLabel,
              description: messages.speechSettingsModelDescription,
              children: [
                TtsModelSelector(
                  modelId: settings.modelId,
                  onChanged: controller.setModel,
                ),
              ],
            ),
            SettingsFormSection(
              title: messages.speechSettingsSpeedLabel,
              description: messages.speechSettingsSpeedDescription,
              children: [
                TtsSpeedSelector(
                  value: settings.speed,
                  onChanged: controller.setSpeed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
