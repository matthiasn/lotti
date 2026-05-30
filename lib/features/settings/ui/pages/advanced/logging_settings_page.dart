import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:lotti/utils/consts.dart';

/// Mobile wrapper — keeps the existing `SliverBoxAdapterPage` chrome (title,
/// back button, page-level padding) and delegates the actual content to
/// [LoggingSettingsBody] so the same content widget can be hosted inside the
/// Settings V2 detail pane.
class LoggingSettingsPage extends StatelessWidget {
  const LoggingSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsLoggingDomainsTitle,
      showBackButton: true,
      child: const LoggingSettingsBody(),
    );
  }
}

/// Content body for the logging settings.
///
/// Renders the global logging master switch, the slow-query toggle, and an
/// individually toggleable switch for every [LogDomain]. Per-domain switches
/// are disabled while the global switch is off. Errors are always logged to
/// the daily `error-*.log` regardless of these toggles.
class LoggingSettingsBody extends ConsumerWidget {
  const LoggingSettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final enableLogging =
        ref.watch(configFlagProvider(enableLoggingFlag)).value ?? false;
    final logSlowQueries =
        ref.watch(configFlagProvider(logSlowQueriesFlag)).value ?? false;

    final items =
        <
          ({
            String title,
            String? subtitle,
            IconData icon,
            bool value,
            ValueChanged<bool>? onChanged,
          })
        >[
          (
            title: context.messages.settingsLoggingGlobalToggle,
            subtitle: context.messages.settingsLoggingGlobalToggleSubtitle,
            icon: Icons.article_rounded,
            value: enableLogging,
            onChanged: (_) =>
                getIt<JournalDb>().toggleConfigFlag(enableLoggingFlag),
          ),
          for (final domain in LogDomain.values)
            (
              title: _domainLabel(context, domain),
              subtitle: null,
              icon: Icons.tune_rounded,
              value:
                  ref.watch(configFlagProvider(domain.flagName)).value ?? false,
              onChanged: enableLogging
                  ? (_) => getIt<JournalDb>().toggleConfigFlag(domain.flagName)
                  : null,
            ),
          (
            title: context.messages.settingsLoggingSlowQueries,
            subtitle: context.messages.settingsLoggingSlowQueriesSubtitle,
            icon: Icons.speed_rounded,
            value: logSlowQueries,
            onChanged: enableLogging
                ? (_) => getIt<JournalDb>().toggleConfigFlag(logSlowQueriesFlag)
                : null,
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
              trailing: Switch.adaptive(
                value: item.value,
                onChanged: item.onChanged,
              ),
              // Toggle-only rows have no onTap, which makes
              // DesignSystemListItem render them as disabled by default.
              // Force idle so they don't appear dimmed.
              forcedState: DesignSystemListItemVisualState.idle,
              showDivider: index < items.length - 1,
              dividerIndent: SettingsIcon.dividerIndent(tokens),
            ),
        ],
      ),
    );
  }
}

/// Localized label for a logging [domain]. Falls back to [LogDomain.label]
/// (English) for any domain not yet covered by a localization key.
String _domainLabel(BuildContext context, LogDomain domain) {
  final messages = context.messages;
  return switch (domain) {
    LogDomain.sync => messages.loggingDomainSync,
    LogDomain.ai => messages.loggingDomainAi,
    LogDomain.chat => messages.loggingDomainChat,
    LogDomain.speech => messages.loggingDomainSpeech,
    LogDomain.persistence => messages.loggingDomainPersistence,
    LogDomain.database => messages.loggingDomainDatabase,
    LogDomain.agentRuntime => messages.loggingDomainAgentRuntime,
    LogDomain.agentWorkflow => messages.loggingDomainAgentWorkflow,
    LogDomain.tasks => messages.loggingDomainTasks,
    LogDomain.labels => messages.loggingDomainLabels,
    LogDomain.health => messages.loggingDomainHealth,
    LogDomain.habits => messages.loggingDomainHabits,
    LogDomain.location => messages.loggingDomainLocation,
    LogDomain.screenshots => messages.loggingDomainScreenshots,
    LogDomain.calendar => messages.loggingDomainCalendar,
    LogDomain.navigation => messages.loggingDomainNavigation,
    LogDomain.theming => messages.loggingDomainTheming,
    LogDomain.notifications => messages.loggingDomainNotifications,
    LogDomain.whatsNew => messages.loggingDomainWhatsNew,
    LogDomain.settings => messages.loggingDomainSettings,
    LogDomain.ratings => messages.loggingDomainRatings,
    LogDomain.dailyOs => messages.loggingDomainDailyOs,
    LogDomain.general => messages.loggingDomainGeneral,
  };
}
