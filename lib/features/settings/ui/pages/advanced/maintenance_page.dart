import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/ai/ui/settings/services/gemini_setup_prompt_service.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';
import 'package:lotti/features/sync/ui/fts5_recreate_modal.dart';
import 'package:lotti/features/sync/ui/purge_modal.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:lotti/widgets/gamey/gamey_settings_card.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';

class MaintenancePage extends ConsumerWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maintenance = getIt<Maintenance>();
    final db = getIt<JournalDb>();
    final themingState = ref.watch(themingControllerProvider);
    final useGamey = themingState.isUsingGameyTheme;

    Widget settingsCard({
      required String title,
      required String subtitle,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      if (useGamey) {
        return GameySettingsCard(
          title: title,
          subtitle: subtitle,
          icon: icon,
          onTap: onTap,
        );
      }
      return AnimatedModernSettingsCardWithIcon(
        title: title,
        subtitle: subtitle,
        icon: icon,
        onTap: onTap,
      );
    }

    return FutureBuilder<int>(
      future: db.getTaggedCount(),
      builder: (
        BuildContext context,
        AsyncSnapshot<int> snapshot,
      ) {
        return SliverBoxAdapterPage(
          title: context.messages.settingsMaintenanceTitle,
          showBackButton: true,
          child: Column(
            children: [
              settingsCard(
                title: context.messages.settingsResetHintsTitle,
                subtitle: context.messages.settingsResetHintsSubtitle,
                icon: Icons.tips_and_updates_outlined,
                onTap: () async {
                  final confirmed = await showConfirmationModal(
                    context: context,
                    message: context.messages.settingsResetHintsConfirmQuestion,
                    confirmLabel: context.messages.settingsResetHintsConfirm,
                  );
                  if (!confirmed) return;
                  final removed = await clearPrefsByPrefix('seen_');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.messages.settingsResetHintsResult(removed),
                        ),
                      ),
                    );
                  }
                },
              ),
              settingsCard(
                title: context.messages.settingsResetGeminiTitle,
                subtitle: context.messages.settingsResetGeminiSubtitle,
                icon: Icons.auto_awesome,
                onTap: () async {
                  final confirmed = await showConfirmationModal(
                    context: context,
                    message:
                        context.messages.settingsResetGeminiConfirmQuestion,
                    confirmLabel: context.messages.settingsResetGeminiConfirm,
                  );
                  if (!confirmed) return;
                  await ref
                      .read(geminiSetupPromptServiceProvider.notifier)
                      .resetDismissal();
                },
              ),
              settingsCard(
                title: context.messages.maintenanceDeleteEditorDb,
                subtitle: context.messages.maintenanceDeleteEditorDbDescription,
                icon: Icons.edit_note_rounded,
                onTap: () async {
                  final confirmed = await showConfirmationModal(
                    context: context,
                    message: context.messages
                        .maintenanceDeleteDatabaseQuestion('Editor'),
                    confirmLabel:
                        context.messages.maintenanceDeleteDatabaseConfirm,
                  );
                  if (confirmed && context.mounted) {
                    await maintenance.deleteEditorDb();
                  }
                },
              ),
              settingsCard(
                title: context.messages.maintenanceDeleteLoggingDb,
                subtitle:
                    context.messages.maintenanceDeleteLoggingDbDescription,
                icon: Icons.article_rounded,
                onTap: () async {
                  final confirmed = await showConfirmationModal(
                    context: context,
                    message: context.messages
                        .maintenanceDeleteDatabaseQuestion('Logging'),
                    confirmLabel:
                        context.messages.maintenanceDeleteDatabaseConfirm,
                  );
                  if (confirmed && context.mounted) {
                    await maintenance.deleteLoggingDb();
                  }
                },
              ),
              settingsCard(
                title: context.messages.maintenancePurgeDeleted,
                subtitle: context.messages.maintenancePurgeDeletedDescription,
                icon: Icons.delete_forever_rounded,
                onTap: () => PurgeModal.show(context),
              ),
              settingsCard(
                title: context.messages.maintenanceRecreateFts5,
                subtitle: context.messages.maintenanceRecreateFts5Description,
                icon: Icons.search_rounded,
                onTap: () => Fts5RecreateModal.show(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
