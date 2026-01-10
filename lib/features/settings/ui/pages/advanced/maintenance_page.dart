import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';
import 'package:lotti/features/sync/ui/fts5_recreate_modal.dart';
import 'package:lotti/features/sync/ui/purge_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final maintenance = getIt<Maintenance>();
    final db = getIt<JournalDb>();
    Theme.of(context);

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
              AnimatedModernSettingsCardWithIcon(
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
              AnimatedModernSettingsCardWithIcon(
                title: 'Reset Gemini Setup Prompt',
                subtitle:
                    'Show the Gemini AI setup prompt again on next app start',
                icon: Icons.auto_awesome,
                onTap: () async {
                  final confirmed = await showConfirmationModal(
                    context: context,
                    message: 'This will show the Gemini setup prompt again the '
                        'next time you open the app. Continue?',
                    confirmLabel: 'Reset',
                  );
                  if (!confirmed) return;
                  final removed =
                      await clearPrefsByPrefix('gemini_setup_prompt_');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          removed > 0
                              ? 'Gemini setup prompt will show on next app start'
                              : 'Gemini setup prompt was already reset',
                        ),
                      ),
                    );
                  }
                },
              ),
              AnimatedModernSettingsCardWithIcon(
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
              AnimatedModernSettingsCardWithIcon(
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
              AnimatedModernSettingsCardWithIcon(
                title: context.messages.maintenancePurgeDeleted,
                subtitle: context.messages.maintenancePurgeDeletedDescription,
                icon: Icons.delete_forever_rounded,
                onTap: () => PurgeModal.show(context),
              ),
              AnimatedModernSettingsCardWithIcon(
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
