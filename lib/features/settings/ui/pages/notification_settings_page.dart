import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_toggle_list.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Mobile / Beamer wrapper: adds the [SliverBoxAdapterPage] chrome and
/// delegates content to [NotificationSettingsBody]. The Settings V2 detail
/// pane embeds the body directly through the panel registry — that host
/// supplies its own header.
class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsNotificationsTitle,
      showBackButton: true,
      child: const NotificationSettingsBody(),
    );
  }
}

/// One per-kind preference: the flag it writes and how its row reads.
typedef _KindRow = ({
  String flag,
  IconData icon,
  String title,
  String subtitle,
});

/// The Notifications settings: the master switch that lets anything reach the
/// OS at all, beneath it one switch per kind of alert — plus, where the
/// platform has an icon badge, the task count on it — and last the wording
/// switch that lets an agent re-word an alert in its banner's own words.
///
/// Every switch is a config flag, read from the same stream the flags page
/// watches and written through [PersistenceLogic.setConfigFlag], whose hook
/// makes the change take effect at once. A kind's rows keep landing in the
/// bell whatever its switch says: the preference decides whether the OS is
/// told, not whether Lotti remembers.
class NotificationSettingsBody extends StatelessWidget {
  const NotificationSettingsBody({super.key});

  /// The kinds, in the order the page lists them. The badge row is last and
  /// only where there is an icon to put a count on.
  static List<_KindRow> _kindRows(AppLocalizations m) => [
    (
      flag: notifyTaskSuggestionsFlag,
      icon: LottiIcons.tip,
      title: m.settingsNotificationsTaskSuggestionsTitle,
      subtitle: m.settingsNotificationsTaskSuggestionsDescription,
    ),
    (
      flag: notifyCheckInRemindersFlag,
      icon: LottiIcons.people,
      title: m.settingsNotificationsCheckInRemindersTitle,
      subtitle: m.settingsNotificationsCheckInRemindersDescription,
    ),
    (
      flag: notifyGoalAlertsFlag,
      icon: LottiIcons.focus,
      title: m.settingsNotificationsGoalAlertsTitle,
      subtitle: m.settingsNotificationsGoalAlertsDescription,
    ),
    (
      flag: notifyHabitRemindersFlag,
      icon: LottiIcons.repeat,
      title: m.settingsNotificationsHabitRemindersTitle,
      subtitle: m.settingsNotificationsHabitRemindersDescription,
    ),
    (
      flag: notifyHabitAutoCompletionsFlag,
      icon: LottiIcons.checkAll,
      title: m.settingsNotificationsHabitAutoCompletionsTitle,
      subtitle: m.settingsNotificationsHabitAutoCompletionsDescription,
    ),
    (
      flag: notifyDayPlanOutcomesFlag,
      icon: LottiIcons.today,
      title: m.settingsNotificationsDayPlanOutcomesTitle,
      subtitle: m.settingsNotificationsDayPlanOutcomesDescription,
    ),
    (
      flag: notifySyncConflictsFlag,
      icon: LottiIcons.merge,
      title: m.settingsNotificationsSyncConflictsTitle,
      subtitle: m.settingsNotificationsSyncConflictsDescription,
    ),
    if (NotificationService.supportsIconBadge)
      (
        flag: showTaskBadgeFlag,
        icon: LottiIcons.notification,
        title: m.settingsNotificationsBadgeTitle,
        subtitle: m.settingsNotificationsBadgeDescription,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final noteStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

    return StreamBuilder<Set<ConfigFlag>>(
      stream: getIt<JournalDb>().watchConfigFlags(),
      builder: (context, snapshot) {
        final flags = <String, ConfigFlag>{
          for (final flag in snapshot.data ?? <ConfigFlag>{}) flag.name: flag,
        };
        // Nothing to switch before the first snapshot; the flags are seeded
        // at startup, so afterwards the master row is always there.
        final master = flags[enableNotificationsFlag];
        if (master == null) return const SizedBox.shrink();

        SettingsToggleRow rowFor(
          ConfigFlag flag, {
          required IconData icon,
          required String title,
          required String subtitle,
          required bool enabled,
        }) => SettingsToggleRow(
          key: ValueKey(flag.name),
          title: title,
          subtitle: subtitle,
          icon: icon,
          value: flag.status,
          enabled: enabled,
          onChanged: (status) => getIt<PersistenceLogic>().setConfigFlag(
            flag.copyWith(status: status),
          ),
        );

        final kindRows = [
          for (final row in _kindRows(messages))
            if (flags[row.flag] case final flag?)
              rowFor(
                flag,
                icon: row.icon,
                title: row.title,
                subtitle: row.subtitle,
                // Greyed rather than hidden while the master switch is off,
                // so the user can see what turning it on would let through.
                enabled: master.status,
              ),
        ];

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step5,
            vertical: tokens.spacing.step4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(messages.settingsNotificationsExplanation, style: noteStyle),
              SizedBox(height: tokens.spacing.step4),
              SettingsToggleList(
                rows: [
                  rowFor(
                    master,
                    icon: LottiIcons.notificationActive,
                    title: messages.settingsNotificationsAllowTitle,
                    subtitle: messages.configFlagEnableNotificationsDescription,
                    enabled: true,
                  ),
                ],
              ),
              if (kindRows.isNotEmpty) ...[
                SizedBox(height: tokens.spacing.sectionGap),
                Text(
                  messages.settingsNotificationsKindsHeading,
                  style: tokens.typography.styles.subtitle.subtitle2,
                ),
                SizedBox(height: tokens.spacing.step3),
                SettingsToggleList(rows: kindRows),
                SizedBox(height: tokens.spacing.step3),
                Text(messages.settingsNotificationsKindsNote, style: noteStyle),
              ],
              // The agent's own words on an alert: opt-in, because a banner
              // brief can carry details and an alert lands on the lock
              // screen (ADR 0063). Greyed with the kinds while the master
              // switch is off.
              if (flags[notifyAgentCopyFlag] case final wording?) ...[
                SizedBox(height: tokens.spacing.sectionGap),
                Text(
                  messages.settingsNotificationsWordingHeading,
                  style: tokens.typography.styles.subtitle.subtitle2,
                ),
                SizedBox(height: tokens.spacing.step3),
                SettingsToggleList(
                  rows: [
                    rowFor(
                      wording,
                      icon: LottiIcons.chat,
                      title: messages.settingsNotificationsAgentCopyTitle,
                      subtitle:
                          messages.settingsNotificationsAgentCopyDescription,
                      enabled: master.status,
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
