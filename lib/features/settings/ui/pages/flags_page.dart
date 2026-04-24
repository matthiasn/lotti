import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/consts.dart';

class FlagsPage extends ConsumerStatefulWidget {
  const FlagsPage({super.key});

  @override
  ConsumerState<FlagsPage> createState() => _FlagsPageState();
}

class _FlagsPageState extends ConsumerState<FlagsPage> {
  static const List<String> displayedItems = [
    privateFlag,
    enableNotificationsFlag,
    recordLocationFlag,
    enableTooltipFlag,
    enableAiStreamingFlag,
    enableLoggingFlag,
    enableMatrixFlag,
    resendAttachments,
    useCompressedJsonAttachmentsFlag,
    enableHabitsPageFlag,
    enableDashboardsPageFlag,
    enableDailyOsPageFlag,
    enableEventsFlag,
    enableSessionRatingsFlag,
    enableAgentsFlag,
    enableProjectsFlag,
    enableEmbeddingsFlag,
    enableVectorSearchFlag,
    enableSettingsTreeFlag,
  ];

  // Helper to get icon for each flag
  IconData _iconForFlag(String flagName) {
    switch (flagName) {
      case privateFlag:
        return Icons.lock_outline_rounded;
      case enableNotificationsFlag:
        return Icons.notifications_active_rounded;
      case recordLocationFlag:
        return Icons.map_rounded;
      case enableTooltipFlag:
        return Icons.info_outline_rounded;
      case enableAiStreamingFlag:
        return Icons.bolt_rounded;
      case enableLoggingFlag:
        return Icons.bug_report_rounded;
      case enableMatrixFlag:
        return Icons.sync_rounded;
      case resendAttachments:
        return Icons.refresh_rounded;
      case useCompressedJsonAttachmentsFlag:
        return Icons.compress_rounded;
      case enableHabitsPageFlag:
        return Icons.repeat_rounded;
      case enableDashboardsPageFlag:
        return Icons.dashboard_rounded;
      case enableDailyOsPageFlag:
        return Icons.calendar_today_rounded;
      case enableEventsFlag:
        return Icons.event_rounded;
      case enableSessionRatingsFlag:
        return Icons.star_rate_rounded;
      case enableAgentsFlag:
        return Icons.smart_toy_outlined;
      case enableProjectsFlag:
        return Icons.folder_outlined;
      case enableEmbeddingsFlag:
        return Icons.hub_outlined;
      case enableVectorSearchFlag:
        return Icons.manage_search_rounded;
      case enableSettingsTreeFlag:
        return Icons.account_tree_outlined;
      default:
        return Icons.settings;
    }
  }

  // Helper to get subtitle/description for each flag
  String _subtitleForFlag(BuildContext context, ConfigFlag flag) {
    switch (flag.name) {
      case privateFlag:
        return context.messages.configFlagPrivateDescription;
      case enableNotificationsFlag:
        return context.messages.configFlagEnableNotificationsDescription;
      case recordLocationFlag:
        return context.messages.configFlagRecordLocationDescription;
      case enableTooltipFlag:
        return context.messages.configFlagEnableTooltipDescription;
      case enableAiStreamingFlag:
        return context.messages.configFlagEnableAiStreamingDescription;
      case enableLoggingFlag:
        return context.messages.configFlagEnableLoggingDescription;
      case enableMatrixFlag:
        return context.messages.configFlagEnableMatrixDescription;
      case resendAttachments:
        return context.messages.configFlagResendAttachmentsDescription;
      case useCompressedJsonAttachmentsFlag:
        return context
            .messages
            .configFlagUseCompressedJsonAttachmentsDescription;
      case enableHabitsPageFlag:
        return context.messages.configFlagEnableHabitsPageDescription;
      case enableDashboardsPageFlag:
        return context.messages.configFlagEnableDashboardsPageDescription;
      case enableDailyOsPageFlag:
        return context.messages.configFlagEnableDailyOsDescription;
      case enableEventsFlag:
        return context.messages.configFlagEnableEventsDescription;
      case enableSessionRatingsFlag:
        return context.messages.configFlagEnableSessionRatingsDescription;
      case enableAgentsFlag:
        return context.messages.configFlagEnableAgentsDescription;
      case enableProjectsFlag:
        return context.messages.configFlagEnableProjectsDescription;
      case enableEmbeddingsFlag:
        return context.messages.configFlagAttemptEmbeddingDescription;
      case enableVectorSearchFlag:
        return context.messages.configFlagEnableVectorSearchDescription;
      case enableSettingsTreeFlag:
        return context.messages.configFlagEnableSettingsTreeDescription;
      default:
        return flag.description;
    }
  }

  // Helper to get title for each flag
  String _titleForFlag(BuildContext context, ConfigFlag flag) {
    switch (flag.name) {
      case privateFlag:
        return context.messages.configFlagPrivate;
      case enableNotificationsFlag:
        return context.messages.configFlagEnableNotifications;
      case recordLocationFlag:
        return context.messages.configFlagRecordLocation;
      case enableTooltipFlag:
        return context.messages.configFlagEnableTooltip;
      case enableAiStreamingFlag:
        return context.messages.configFlagEnableAiStreaming;
      case enableLoggingFlag:
        return context.messages.configFlagEnableLogging;
      case enableMatrixFlag:
        return context.messages.configFlagEnableMatrix;
      case resendAttachments:
        return context.messages.configFlagResendAttachments;
      case useCompressedJsonAttachmentsFlag:
        return context.messages.configFlagUseCompressedJsonAttachments;
      case enableHabitsPageFlag:
        return context.messages.configFlagEnableHabitsPage;
      case enableDashboardsPageFlag:
        return context.messages.configFlagEnableDashboardsPage;
      case enableDailyOsPageFlag:
        return context.messages.configFlagEnableDailyOs;
      case enableEventsFlag:
        return context.messages.configFlagEnableEvents;
      case enableSessionRatingsFlag:
        return context.messages.configFlagEnableSessionRatings;
      case enableAgentsFlag:
        return context.messages.configFlagEnableAgents;
      case enableProjectsFlag:
        return context.messages.configFlagEnableProjects;
      case enableEmbeddingsFlag:
        return context.messages.configFlagEnableEmbeddings;
      case enableVectorSearchFlag:
        return context.messages.configFlagEnableVectorSearch;
      case enableSettingsTreeFlag:
        return context.messages.configFlagEnableSettingsTree;
      default:
        return flag.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return StreamBuilder<Set<ConfigFlag>>(
      stream: getIt<JournalDb>().watchConfigFlags(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Set<ConfigFlag>> snapshot,
          ) {
            final flagLookup = <String, ConfigFlag>{
              for (final ConfigFlag flag in snapshot.data ?? {})
                flag.name: flag,
            };

            final orderedFlags = displayedItems
                .map((name) => flagLookup[name])
                .nonNulls
                .toList();

            return SliverBoxAdapterPage(
              title: context.messages.settingsFlagsTitle,
              showBackButton: true,
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step5,
                vertical: tokens.spacing.step4,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.colors.background.level02,
                  borderRadius: BorderRadius.circular(tokens.radii.m),
                  border: Border.all(color: tokens.colors.decorative.level01),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radii.m),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (index, flag) in orderedFlags.indexed)
                        DesignSystemListItem(
                          title: _titleForFlag(context, flag),
                          subtitle: _subtitleForFlag(context, flag),
                          leading: SettingsIcon(
                            icon: _iconForFlag(flag.name),
                          ),
                          trailing: Switch.adaptive(
                            value: flag.status,
                            onChanged: (bool status) {
                              getIt<PersistenceLogic>().setConfigFlag(
                                flag.copyWith(status: status),
                              );
                            },
                          ),
                          onTap: () {
                            getIt<PersistenceLogic>().setConfigFlag(
                              flag.copyWith(status: !flag.status),
                            );
                          },
                          showDivider: index < orderedFlags.length - 1,
                          dividerIndent: SettingsIcon.dividerIndent(tokens),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
    );
  }
}
