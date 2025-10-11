import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';

class FlagsPage extends StatefulWidget {
  const FlagsPage({super.key});

  @override
  State<FlagsPage> createState() => _FlagsPageState();
}

class _FlagsPageState extends State<FlagsPage> {
  static const List<String> displayedItems = [
    privateFlag,
    enableNotificationsFlag,
    recordLocationFlag,
    enableTooltipFlag,
    enableLoggingFlag,
    enableMatrixFlag,
    enableSyncV2Flag,
    resendAttachments,
    enableHabitsPageFlag,
    enableDashboardsPageFlag,
    enableCalendarPageFlag,
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
      case enableLoggingFlag:
        return Icons.bug_report_rounded;
      case enableMatrixFlag:
        return Icons.sync_rounded;
      case enableSyncV2Flag:
        return Icons.change_circle_rounded;
      case resendAttachments:
        return Icons.refresh_rounded;
      case enableHabitsPageFlag:
        return Icons.repeat_rounded;
      case enableDashboardsPageFlag:
        return Icons.dashboard_rounded;
      case enableCalendarPageFlag:
        return Icons.calendar_today_rounded;
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
      case enableLoggingFlag:
        return context.messages.configFlagEnableLoggingDescription;
      case enableMatrixFlag:
        return context.messages.configFlagEnableMatrixDescription;
      case enableSyncV2Flag:
        return context.messages.configFlagEnableSyncV2Description;
      case resendAttachments:
        return context.messages.configFlagResendAttachmentsDescription;
      case enableHabitsPageFlag:
        return context.messages.configFlagEnableHabitsPageDescription;
      case enableDashboardsPageFlag:
        return context.messages.configFlagEnableDashboardsPageDescription;
      case enableCalendarPageFlag:
        return context.messages.configFlagEnableCalendarPageDescription;
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
      case enableLoggingFlag:
        return context.messages.configFlagEnableLogging;
      case enableMatrixFlag:
        return context.messages.configFlagEnableMatrix;
      case enableSyncV2Flag:
        return context.messages.configFlagEnableSyncV2;
      case resendAttachments:
        return context.messages.configFlagResendAttachments;
      case enableHabitsPageFlag:
        return context.messages.configFlagEnableHabitsPage;
      case enableDashboardsPageFlag:
        return context.messages.configFlagEnableDashboardsPage;
      case enableCalendarPageFlag:
        return context.messages.configFlagEnableCalendarPage;
      default:
        return flag.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<ConfigFlag>>(
      stream: getIt<JournalDb>().watchConfigFlags(),
      builder: (
        BuildContext context,
        AsyncSnapshot<Set<ConfigFlag>> snapshot,
      ) {
        final flagLookup = <String, ConfigFlag>{
          for (final ConfigFlag flag in snapshot.data ?? {}) flag.name: flag,
        };

        final orderedFlags =
            displayedItems.map((name) => flagLookup[name]).nonNulls.toList();

        return SliverBoxAdapterPage(
          title: context.messages.settingsFlagsTitle,
          child: Column(
            children: [
              ...orderedFlags.map(
                (flag) => AnimatedModernSettingsCardWithIcon(
                  title: _titleForFlag(context, flag),
                  showChevron: false,
                  subtitle: _subtitleForFlag(context, flag),
                  icon: _iconForFlag(flag.name),
                  trailing: Switch.adaptive(
                    value: flag.status,
                    onChanged: (bool status) {
                      getIt<JournalDb>()
                          .upsertConfigFlag(flag.copyWith(status: status));
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
