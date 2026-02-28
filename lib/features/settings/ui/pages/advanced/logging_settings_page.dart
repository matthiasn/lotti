import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/gamey/gamey_settings_card.dart';

/// Settings page for controlling per-domain logging flags.
///
/// Shows the global logging toggle plus per-domain toggles for agent runtime,
/// agent workflow, and sync logging. Also provides a link to the existing
/// log viewer.
class LoggingSettingsPage extends ConsumerWidget {
  const LoggingSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableLogging =
        ref.watch(configFlagProvider(enableLoggingFlag)).value ?? false;
    final logAgentRuntime =
        ref.watch(configFlagProvider(logAgentRuntimeFlag)).value ?? false;
    final logAgentWorkflow =
        ref.watch(configFlagProvider(logAgentWorkflowFlag)).value ?? false;
    final logSync = ref.watch(configFlagProvider(logSyncFlag)).value ?? false;

    return SliverBoxAdapterPage(
      title: context.messages.settingsLoggingDomainsTitle,
      showBackButton: true,
      child: Column(
        children: [
          AdaptiveSettingsCard(
            title: context.messages.settingsLoggingGlobalToggle,
            subtitle: context.messages.settingsLoggingGlobalToggleSubtitle,
            icon: Icons.article_rounded,
            showChevron: false,
            trailing: Switch.adaptive(
              value: enableLogging,
              onChanged: (_) =>
                  getIt<JournalDb>().toggleConfigFlag(enableLoggingFlag),
            ),
          ),
          const Divider(height: 1),
          AdaptiveSettingsCard(
            title: context.messages.settingsLoggingAgentRuntime,
            subtitle: context.messages.settingsLoggingAgentRuntimeSubtitle,
            icon: Icons.memory_rounded,
            showChevron: false,
            trailing: Switch.adaptive(
              value: logAgentRuntime,
              onChanged: enableLogging
                  ? (_) =>
                      getIt<JournalDb>().toggleConfigFlag(logAgentRuntimeFlag)
                  : null,
            ),
          ),
          AdaptiveSettingsCard(
            title: context.messages.settingsLoggingAgentWorkflow,
            subtitle: context.messages.settingsLoggingAgentWorkflowSubtitle,
            icon: Icons.play_circle_outline_rounded,
            showChevron: false,
            trailing: Switch.adaptive(
              value: logAgentWorkflow,
              onChanged: enableLogging
                  ? (_) =>
                      getIt<JournalDb>().toggleConfigFlag(logAgentWorkflowFlag)
                  : null,
            ),
          ),
          AdaptiveSettingsCard(
            title: context.messages.settingsLoggingSync,
            subtitle: context.messages.settingsLoggingSyncSubtitle,
            icon: Icons.sync_rounded,
            showChevron: false,
            trailing: Switch.adaptive(
              value: logSync,
              onChanged: enableLogging
                  ? (_) => getIt<JournalDb>().toggleConfigFlag(logSyncFlag)
                  : null,
            ),
          ),
          const Divider(height: 1),
          AdaptiveSettingsCard(
            title: context.messages.settingsLogsTitle,
            subtitle: context.messages.settingsLoggingViewLogsSubtitle,
            icon: Icons.search_rounded,
            onTap: () => context.beamToNamed('/settings/advanced/logging'),
          ),
        ],
      ),
    );
  }
}
