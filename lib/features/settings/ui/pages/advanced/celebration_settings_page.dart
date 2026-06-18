import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
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

/// One switch per completion event — habits, checklist items, tasks — turning
/// the celebratory animation on or off. Only the visual celebration is gated
/// (glow / spark burst / pop / strike-through wipe); the completion haptic is
/// left intact (see [CelebrationPreferences]).
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

    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step4),
      child: SettingsFormSection(
        title: messages.settingsCelebrationsSectionTitle,
        description: messages.settingsCelebrationsSectionDescription,
        children: [
          SettingsSwitchRow(
            title: messages.settingsCelebrationsHabitsTitle,
            subtitle: messages.settingsCelebrationsHabitsDescription,
            value: prefs.habits,
            onChanged: (value) => controller.setHabits(enabled: value),
          ),
          SettingsSwitchRow(
            title: messages.settingsCelebrationsChecklistTitle,
            subtitle: messages.settingsCelebrationsChecklistDescription,
            value: prefs.checklistItems,
            onChanged: (value) => controller.setChecklistItems(enabled: value),
          ),
          SettingsSwitchRow(
            title: messages.settingsCelebrationsTasksTitle,
            subtitle: messages.settingsCelebrationsTasksDescription,
            value: prefs.tasks,
            onChanged: (value) => controller.setTasks(enabled: value),
          ),
        ],
      ),
    );
  }
}
