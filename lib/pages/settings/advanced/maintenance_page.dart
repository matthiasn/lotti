import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/sync/ui/re_sync_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:lotti/widgets/settings/settings_card.dart';

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final maintenance = getIt<Maintenance>();
    final db = getIt<JournalDb>();

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
                title:
                    '${context.messages.maintenanceDeleteTagged}, n = ${snapshot.data}',
                onTap: maintenance.deleteTaggedLinks,
              ),
              SettingsCard(
                title: context.messages.maintenanceDeleteEditorDb,
                onTap: maintenance.deleteEditorDb,
              ),
              SettingsCard(
                title: context.messages.maintenanceDeleteLoggingDb,
                onTap: maintenance.deleteLoggingDb,
              ),
              SettingsCard(
                title: context.messages.maintenanceDeleteSyncDb,
                onTap: maintenance.deleteSyncDb,
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
                onTap: maintenance.syncDefinitions,
              ),
              SettingsCard(
                title: context.messages.maintenanceSyncCategories,
                onTap: maintenance.syncCategories,
              ),
              SettingsCard(
                title: context.messages.maintenancePurgeDeleted,
                onTap: () async {
                  const deleteKey = 'deleteKey';
                  final result = await showModalActionSheet<String>(
                    context: context,
                    title: context.messages.maintenancePurgeDeletedQuestion,
                    actions: [
                      ModalSheetAction(
                        icon: Icons.warning,
                        label: context.messages.maintenancePurgeDeletedConfirm,
                        key: deleteKey,
                        isDestructiveAction: true,
                        isDefaultAction: true,
                        style: settingsCardTextStyle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    cancelLabel: context.messages.cancelButton,
                  );

                  if (result == deleteKey && context.mounted) {
                    await showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext dialogContext) {
                        return StreamBuilder<double>(
                          stream: db.purgeDeleted(),
                          builder: (context, snapshot) {
                            final progress = snapshot.data ?? 0.0;

                            return AlertDialog(
                              title: SingleChildScrollView(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      context.messages.maintenancePurgeDeleted,
                                      style: settingsCardTextStyle.copyWith(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                    ),
                                  ],
                                ),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (progress == 1.0 &&
                                      snapshot.connectionState ==
                                          ConnectionState.done)
                                    Icon(
                                      Icons.delete_forever_outlined,
                                      size: 48,
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    )
                                  else
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 5,
                                            child: LinearProgressIndicator(
                                              value: progress,
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${(progress * 100).toInt()}%',
                                          style: settingsCardTextStyle.copyWith(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 5),
                                ],
                              ),
                            );
                          },
                        );
                      },
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
                onTap: () => getIt<NotificationService>().cancelAll(),
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
              SettingsCard(
                title: context.messages.maintenanceAssignCategoriesToChecklists,
                onTap: maintenance.addCategoriesToChecklists,
              ),
              SettingsCard(
                title: context
                    .messages.maintenanceAssignCategoriesToLinkedFromTasks,
                onTap: maintenance.addCategoriesToLinkedFromTasks,
              ),
              SettingsCard(
                title: context.messages.maintenanceAssignCategoriesToLinked,
                onTap: maintenance.addCategoriesToLinked,
              ),
            ],
          ),
        );
      },
    );
  }
}
