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
import 'package:lotti/utils/consts.dart';

/// Settings page for controlling per-domain logging flags.
///
/// Shows the global logging toggle plus per-domain toggles for agent runtime,
/// agent workflow, and sync logging.
class LoggingSettingsPage extends ConsumerWidget {
  const LoggingSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final enableLogging =
        ref.watch(configFlagProvider(enableLoggingFlag)).value ?? false;
    final logAgentRuntime =
        ref.watch(configFlagProvider(logAgentRuntimeFlag)).value ?? false;
    final logAgentWorkflow =
        ref.watch(configFlagProvider(logAgentWorkflowFlag)).value ?? false;
    final logSync = ref.watch(configFlagProvider(logSyncFlag)).value ?? false;
    final logSlowQueries =
        ref.watch(configFlagProvider(logSlowQueriesFlag)).value ?? false;

    final items =
        <
          ({
            String title,
            String subtitle,
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
          (
            title: context.messages.settingsLoggingAgentRuntime,
            subtitle: context.messages.settingsLoggingAgentRuntimeSubtitle,
            icon: Icons.memory_rounded,
            value: logAgentRuntime,
            onChanged: enableLogging
                ? (_) =>
                      getIt<JournalDb>().toggleConfigFlag(logAgentRuntimeFlag)
                : null,
          ),
          (
            title: context.messages.settingsLoggingAgentWorkflow,
            subtitle: context.messages.settingsLoggingAgentWorkflowSubtitle,
            icon: Icons.play_circle_outline_rounded,
            value: logAgentWorkflow,
            onChanged: enableLogging
                ? (_) =>
                      getIt<JournalDb>().toggleConfigFlag(logAgentWorkflowFlag)
                : null,
          ),
          (
            title: context.messages.settingsLoggingSync,
            subtitle: context.messages.settingsLoggingSyncSubtitle,
            icon: Icons.sync_rounded,
            value: logSync,
            onChanged: enableLogging
                ? (_) => getIt<JournalDb>().toggleConfigFlag(logSyncFlag)
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

    return SliverBoxAdapterPage(
      title: context.messages.settingsLoggingDomainsTitle,
      showBackButton: true,
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
