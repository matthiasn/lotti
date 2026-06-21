import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_navigation_service.dart';
import 'package:lotti/features/ai/ui/settings/embedding_backfill_modal.dart';
import 'package:lotti/features/ai/ui/settings/services/gemini_setup_prompt_service.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/onboarding_welcome_modal.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/features/sync/ui/fts5_recreate_modal.dart';
import 'package:lotti/features/sync/ui/purge_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:lotti/services/debug_overlays.dart';
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
            title: 'Show onboarding welcome',
            subtitle: 'Preview the FTUE welcome + provider tiles (debug)',
            icon: Icons.auto_awesome_motion_rounded,
            onTap: () => unawaited(
              OnboardingWelcomeModal.show(
                context,
                onProviderSelected: (type) =>
                    const AiSettingsNavigationService()
                        .navigateToCreateProvider(
                          context,
                          preselectedType: type,
                        ),
                onDismiss: () {},
              ),
            ),
          ),
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
                context.showToast(
                  tone: DesignSystemToastTone.success,
                  title: context.messages.settingsResetHintsResult(removed),
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
          for (final item in items)
            DesignSystemListItem(
              title: item.title,
              subtitle: item.subtitle,
              leading: SettingsIcon(icon: item.icon),
              trailing: SettingsIcon.trailingChevron(tokens),
              // Always draw a divider; the diagnostic
              // [_RepaintRainbowTile] below is the new last item and
              // owns the bottom-of-list (no-divider) slot.
              showDivider: true,
              dividerIndent: SettingsIcon.dividerIndent(tokens),
              onTap: item.onTap,
            ),
          const _RepaintRainbowTile(),
        ],
      ),
    );
  }
}

/// In-memory toggle for Flutter's repaint-rainbow overlay. Sits at the
/// bottom of the Maintenance list because it's a diagnostic, not a
/// regular maintenance action: when on, every region that repaints
/// flashes through a colour cycle, making it trivial to spot widgets
/// that are redrawing every frame at idle. The state is kept in
/// [repaintRainbowEnabled], which mirrors the value into Flutter's
/// `debugRepaintRainbowEnabled` global and schedules a forced frame so
/// the change is visible immediately. Resets to off on every relaunch
/// — the flag is never persisted.
class _RepaintRainbowTile extends StatelessWidget {
  const _RepaintRainbowTile();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return ValueListenableBuilder<bool>(
      valueListenable: repaintRainbowEnabled,
      builder: (context, enabled, _) {
        return DesignSystemListItem(
          title: 'Repaint rainbow overlay',
          subtitle:
              'Flash a colour cycle over every region that repaints '
              '— diagnoses widgets redrawing every frame at idle.',
          leading: const SettingsIcon(icon: Icons.bug_report_outlined),
          trailing: Switch.adaptive(
            value: enabled,
            onChanged: (value) => repaintRainbowEnabled.value = value,
          ),
          dividerIndent: SettingsIcon.dividerIndent(tokens),
          onTap: () => repaintRainbowEnabled.value = !enabled,
        );
      },
    );
  }
}
