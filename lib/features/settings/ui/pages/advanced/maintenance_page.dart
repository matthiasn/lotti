import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/ui/settings/embedding_backfill_modal.dart';
import 'package:lotti/features/ai/ui/settings/services/gemini_setup_prompt_service.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/features/sync/ui/fts5_recreate_modal.dart';
import 'package:lotti/features/sync/ui/purge_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';

/// Mobile / legacy wrapper — keeps the `SliverBoxAdapterPage` chrome
/// and delegates content to [MaintenanceBody] so the same widget can
/// render inside the Settings V2 detail pane (plan step 7).
class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsMaintenanceTitle,
      showBackButton: true,
      child: const MaintenanceBody(),
    );
  }
}

/// Content body for the advanced-maintenance page: a grouped list of
/// destructive / diagnostic actions. Extracted so the V2 detail pane
/// can host the same list without the surrounding sliver chrome.
/// Owns its own vertical padding so both hosts (sliver page and V2
/// detail pane) get the same chrome-independent spacing — matching
/// the `LoggingSettingsBody` pattern.
class MaintenanceBody extends ConsumerWidget {
  const MaintenanceBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final maintenance = getIt<Maintenance>();

    final items =
        <({String title, String subtitle, IconData icon, VoidCallback onTap})>[
          (
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
          (
            title: context.messages.settingsResetGeminiTitle,
            subtitle: context.messages.settingsResetGeminiSubtitle,
            icon: Icons.auto_awesome,
            onTap: () async {
              final confirmed = await showConfirmationModal(
                context: context,
                message: context.messages.settingsResetGeminiConfirmQuestion,
                confirmLabel: context.messages.settingsResetGeminiConfirm,
              );
              if (!confirmed) return;
              await ref
                  .read(geminiSetupPromptServiceProvider.notifier)
                  .resetDismissal();
            },
          ),
          (
            title: context.messages.maintenanceDeleteEditorDb,
            subtitle: context.messages.maintenanceDeleteEditorDbDescription,
            icon: Icons.edit_note_rounded,
            onTap: () async {
              final confirmed = await showConfirmationModal(
                context: context,
                message: context.messages.maintenanceDeleteDatabaseQuestion(
                  'Editor',
                ),
                confirmLabel: context.messages.maintenanceDeleteDatabaseConfirm,
              );
              if (confirmed && context.mounted) {
                await maintenance.deleteEditorDb();
              }
            },
          ),
          (
            title: context.messages.maintenanceDeleteAgentDb,
            subtitle: context.messages.maintenanceDeleteAgentDbDescription,
            icon: Icons.smart_toy_outlined,
            onTap: () async {
              final confirmed = await showConfirmationModal(
                context: context,
                message: context.messages.maintenanceDeleteDatabaseQuestion(
                  'Agents',
                ),
                confirmLabel: context.messages.maintenanceDeleteDatabaseConfirm,
              );
              if (confirmed && context.mounted) {
                await maintenance.deleteAgentDb();
                exit(0);
              }
            },
          ),
          (
            title: context.messages.maintenancePurgeDeleted,
            subtitle: context.messages.maintenancePurgeDeletedDescription,
            icon: Icons.delete_forever_rounded,
            onTap: () => PurgeModal.show(context),
          ),
          (
            title: context.messages.maintenanceRecreateFts5,
            subtitle: context.messages.maintenanceRecreateFts5Description,
            icon: Icons.search_rounded,
            onTap: () => Fts5RecreateModal.show(context),
          ),
          if (getIt.isRegistered<EmbeddingStore>())
            (
              title: context.messages.maintenanceGenerateEmbeddings,
              subtitle:
                  context.messages.maintenanceGenerateEmbeddingsDescription,
              icon: Icons.hub_outlined,
              onTap: () => EmbeddingBackfillModal.show(context),
            ),
        ];

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
      child: DesignSystemGroupedList(
        children: [
          for (final (index, item) in items.indexed)
            DesignSystemListItem(
              title: item.title,
              subtitle: item.subtitle,
              leading: SettingsIcon(icon: item.icon),
              trailing: SettingsIcon.trailingChevron(tokens),
              showDivider: index < items.length - 1,
              dividerIndent: SettingsIcon.dividerIndent(tokens),
              onTap: item.onTap,
            ),
        ],
      ),
    );
  }
}
