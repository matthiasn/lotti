import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/sync/ui/re_sync_modal.dart';
import 'package:lotti/features/sync/ui/sync_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final maintenance = getIt<Maintenance>();
    final db = getIt<JournalDb>();
    final notificationService = getIt<NotificationService>();

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
              SettingsCard(
                title: context.messages.maintenanceDeleteEditorDb,
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
              SettingsCard(
                title: context.messages.maintenanceDeleteLoggingDb,
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
              SettingsCard(
                title: context.messages.maintenanceDeleteSyncDb,
                onTap: () async {
                  final confirmed = await showConfirmationModal(
                    context: context,
                    message: context.messages
                        .maintenanceDeleteDatabaseQuestion('Sync'),
                    confirmLabel:
                        context.messages.maintenanceDeleteDatabaseConfirm,
                  );
                  if (confirmed && context.mounted) {
                    await maintenance.deleteSyncDb();
                  }
                },
              ),
              SettingsCard(
                title: context.messages.maintenanceRecreateTagged,
                onTap: maintenance.recreateTaggedLinks,
              ),
              SettingsCard(
                title: context.messages.maintenanceStories,
                onTap: maintenance.recreateStoryAssignment,
              ),
              SettingsCard(
                title: context.messages.maintenanceSyncDefinitions,
                onTap: () => SyncModal.show(context),
              ),
              SettingsCard(
                title: context.messages.maintenancePurgeDeleted,
                onTap: () async {
                  final confirmed = await showConfirmationModal(
                    context: context,
                    message: context.messages.maintenancePurgeDeletedMessage,
                    confirmLabel:
                        context.messages.maintenancePurgeDeletedConfirm,
                  );
                  if (confirmed && context.mounted) {
                    await WoltModalSheet.show<void>(
                      context: context,
                      pageListBuilder: (modalSheetContext) {
                        return [
                          WoltModalSheetPage(
                            backgroundColor: const Color(0xFF544F72),
                            hasSabGradient: false,
                            navBarHeight: 35,
                            isTopBarLayerAlwaysVisible: false,
                            trailingNavBarWidget: IconButton(
                              padding: WoltModalConfig.pagePadding,
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            child: Padding(
                              padding: WoltModalConfig.pagePadding,
                              child: StreamBuilder<double>(
                                stream: db.purgeDeleted(),
                                builder: (context, snapshot) {
                                  final progress = snapshot.data ?? 0.0;

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 16),
                                      if (progress == 1.0 &&
                                          snapshot.connectionState ==
                                              ConnectionState.done)
                                        Icon(
                                          Icons.delete_forever_outlined,
                                          size: 48,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline,
                                        )
                                      else
                                        Row(
                                          children: [
                                            Expanded(
                                              child: SizedBox(
                                                height: 5,
                                                child: LinearProgressIndicator(
                                                  value: progress,
                                                  backgroundColor: Theme.of(
                                                    context,
                                                  )
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 16),
                                      Text(
                                        context
                                            .messages.maintenancePurgeDeleted,
                                        style: settingsCardTextStyle,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ];
                      },
                      modalTypeBuilder: ModalUtils.modalTypeBuilder,
                    );
                  }
                },
              ),
              SettingsCard(
                title: context.messages.maintenancePurgeAudioModels,
                onTap: maintenance.purgeAudioModels,
              ),
              SettingsCard(
                title: context.messages.maintenanceCancelNotifications,
                onTap: notificationService.cancelAll,
              ),
              SettingsCard(
                title: context.messages.maintenanceRecreateFts5,
                onTap: maintenance.recreateFts5,
              ),
              SettingsCard(
                title: context.messages.maintenancePersistTaskCategories,
                onTap: maintenance.persistTaskCategories,
              ),
              SettingsCard(
                title: context.messages.maintenanceReSync,
                onTap: () => ReSyncModal.show(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
