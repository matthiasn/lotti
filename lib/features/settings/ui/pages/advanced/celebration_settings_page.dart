import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/celebration_preview_stage.dart';
import 'package:lotti/features/settings/ui/widgets/celebration_style_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:lotti/widgets/settings/settings_switch_row.dart';

/// Mobile / Beamer wrapper: adds the [SliverBoxAdapterPage] chrome and delegates
/// content to [CelebrationSettingsBody]. The same body is embedded directly in
/// the Settings V2 detail pane via the panel registry — that host supplies its
/// own header, so it uses [CelebrationSettingsBody] without this wrapper.
class CelebrationSettingsPage extends StatelessWidget {
  const CelebrationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsCelebrationsTitle,
      showBackButton: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const CelebrationSettingsBody(),
    );
  }
}

/// The Animations settings: a master switch over the per-event switches and an
/// independent completion-haptics switch, a [CelebrationStyleSection] to assign a
/// style per content type, and a [CelebrationPreviewStage] to try it on dummy
/// controls.
///
/// The master switch gates the *visual* celebration everywhere — glow / spark
/// burst / pop / strike-through wipe — and greys the per-event switches, the
/// style section, and the preview when off. The completion haptic has its own
/// switch, independent of the visuals.
class CelebrationSettingsBody extends ConsumerWidget {
  const CelebrationSettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final prefs = ref.watch(celebrationPreferencesControllerProvider);
    final controller = ref.read(
      celebrationPreferencesControllerProvider.notifier,
    );
    // The per-event switches and the style/preview are meaningless while the
    // master switch is off, so they grey out and stop responding. Haptics keep
    // their own switch, alive regardless of the visual master.
    final visualsOn = prefs.enabled;

    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsFormSection(
            title: messages.settingsCelebrationsSectionTitle,
            description: messages.settingsCelebrationsSectionDescription,
            children: [
              SettingsSwitchRow(
                title: messages.settingsCelebrationsEnabledTitle,
                subtitle: messages.settingsCelebrationsEnabledDescription,
                value: prefs.enabled,
                onChanged: (value) => controller.setEnabled(enabled: value),
              ),
              SettingsSwitchRow(
                title: messages.settingsCelebrationsHabitsTitle,
                subtitle: messages.settingsCelebrationsHabitsDescription,
                value: prefs.habits,
                enabled: visualsOn,
                onChanged: (value) => controller.setHabits(enabled: value),
              ),
              SettingsSwitchRow(
                title: messages.settingsCelebrationsChecklistTitle,
                subtitle: messages.settingsCelebrationsChecklistDescription,
                value: prefs.checklistItems,
                enabled: visualsOn,
                onChanged: (value) =>
                    controller.setChecklistItems(enabled: value),
              ),
              SettingsSwitchRow(
                title: messages.settingsCelebrationsTasksTitle,
                subtitle: messages.settingsCelebrationsTasksDescription,
                value: prefs.tasks,
                enabled: visualsOn,
                onChanged: (value) => controller.setTasks(enabled: value),
              ),
              SettingsSwitchRow(
                title: messages.settingsCelebrationsHapticsTitle,
                subtitle: messages.settingsCelebrationsHapticsDescription,
                value: prefs.haptics,
                onChanged: (value) => controller.setHaptics(enabled: value),
              ),
            ],
          ),
          SettingsFormSection(
            title: messages.settingsCelebrationsStyleTitle,
            description: messages.settingsCelebrationsStyleDescription,
            children: [CelebrationStyleSection(enabled: visualsOn)],
          ),
          SettingsFormSection(
            title: messages.settingsCelebrationsPreviewTitle,
            description: messages.settingsCelebrationsPreviewDescription,
            children: [CelebrationPreviewStage(enabled: visualsOn)],
          ),
        ],
      ),
    );
  }
}
