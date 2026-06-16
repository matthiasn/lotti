import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/features/agents/ui/agent_report_section.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_history_dashboard.dart';
import 'package:lotti/features/agents/ui/template_token_usage_section.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Expandable section showing version history for a template.
///
/// Derives the "active" badge from the head pointer rather than from
/// each version's persisted status field, which can become stale.
class _VersionHistorySection extends ConsumerWidget {
  const _VersionHistorySection({required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(templateVersionHistoryProvider(templateId));
    final activeVersionAsync = ref.watch(
      activeTemplateVersionProvider(templateId),
    );
    final activeVersionId = activeVersionAsync.value?.mapOrNull(
      agentTemplateVersion: (v) => v.id,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.agentTemplateVersionHistoryTitle,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        historyAsync.when(
          data: (versions) {
            final typed = versions
                .whereType<AgentTemplateVersionEntity>()
                .toList();
            if (typed.isEmpty) {
              return Text(context.messages.agentTemplateNoVersions);
            }
            return Column(
              children: typed.map((version) {
                return _VersionTile(
                  version: version,
                  templateId: templateId,
                  isActive: version.id == activeVersionId,
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Text(context.messages.commonError),
        ),
      ],
    );
  }
}

class _VersionTile extends ConsumerWidget {
  const _VersionTile({
    required this.version,
    required this.templateId,
    required this.isActive,
  });

  final AgentTemplateVersionEntity version;
  final String templateId;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: context.colorScheme.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: ListTile(
        title: Text(
          context.messages.agentTemplateVersionLabel(version.version),
        ),
        subtitle: Text(formatAgentDateTime(version.createdAt)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSmall,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? context.colorScheme.primaryContainer
                    : context.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.spacingXSmall),
              ),
              child: Text(
                isActive
                    ? context.messages.agentTemplateStatusActive
                    : context.messages.agentTemplateStatusArchived,
                style: context.textTheme.labelSmall,
              ),
            ),
            if (!isActive) ...[
              const SizedBox(width: AppTheme.spacingSmall),
              IconButton(
                icon: const Icon(Icons.restore, size: 20),
                tooltip: context.messages.agentTemplateRollbackAction,
                onPressed: () => _handleRollback(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleRollback(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.messages.agentTemplateRollbackAction),
        content: Text(
          dialogContext.messages.agentTemplateRollbackConfirm(version.version),
        ),
        actions: [
          DesignSystemButton(
            onPressed: () => Navigator.pop(dialogContext),
            label: dialogContext.messages.cancelButton,
            variant: DesignSystemButtonVariant.tertiary,
            size: DesignSystemButtonSize.large,
          ),
          DesignSystemButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final templateService = ref.read(agentTemplateServiceProvider);
                await templateService.rollbackToVersion(
                  templateId: templateId,
                  versionId: version.id,
                );
                ref
                  ..invalidate(
                    activeTemplateVersionProvider(templateId),
                  )
                  ..invalidate(
                    templateVersionHistoryProvider(templateId),
                  );
              } catch (e, s) {
                developer.log(
                  'Rollback failed',
                  name: 'AgentTemplateDetailPage',
                  error: e.runtimeType,
                  stackTrace: s,
                );
                if (!context.mounted) return;
                context.showToast(
                  tone: DesignSystemToastTone.error,
                  title: context.messages.commonError,
                );
              }
            },
            label: dialogContext.messages.agentTemplateRollbackAction,
            size: DesignSystemButtonSize.large,
          ),
        ],
      ),
    );
  }
}

/// Settings tab content — form fields.
class SettingsTabContent extends StatelessWidget {
  const SettingsTabContent({
    required this.formFields,
    super.key,
  });

  final Widget formFields;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        formFields,
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Stats tab content — evolution history dashboard, token usage, version
/// history, and delete action.
class StatsTabContent extends StatelessWidget {
  const StatsTabContent({
    required this.templateId,
    required this.onDelete,
    super.key,
  });

  final String templateId;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EvolutionHistoryDashboard(templateId: templateId),
        const SizedBox(height: 24),
        TemplateTokenUsageSection(templateId: templateId),
        const SizedBox(height: 24),
        _VersionHistorySection(templateId: templateId),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline,
              color: context.colorScheme.error,
            ),
            label: Text(
              context.messages.deleteButton,
              style: TextStyle(color: context.colorScheme.error),
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

/// Reports tab content — recent reports from all instances.
class ReportsTabContent extends ConsumerWidget {
  const ReportsTabContent({required this.templateId, super.key});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(templateRecentReportsProvider(templateId));

    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.messages.commonError,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.error,
            ),
          ),
        ),
      ),
      data: (reports) {
        if (reports.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.messages.agentTemplateReportsEmpty,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            if (report is! AgentReportEntity) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    formatAgentDateTime(report.createdAt),
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AgentReportSection(
                    content: report.content,
                    tldr: report.tldr,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
