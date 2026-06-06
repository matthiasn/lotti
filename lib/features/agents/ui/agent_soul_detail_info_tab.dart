part of 'agent_soul_detail_page.dart';

/// Info tab: version history + assigned templates + delete action.
class _InfoTabContent extends ConsumerWidget {
  const _InfoTabContent({
    required this.soulId,
    required this.onDelete,
  });

  final String soulId;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SoulEvolutionHistorySection(soulId: soulId),
        const SizedBox(height: 24),
        _VersionHistorySection(soulId: soulId),
        const SizedBox(height: 24),
        _AssignedTemplatesSection(soulId: soulId),
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

class _VersionHistorySection extends ConsumerWidget {
  const _VersionHistorySection({required this.soulId});

  final String soulId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(soulVersionHistoryProvider(soulId));
    final activeVersionAsync = ref.watch(activeSoulVersionProvider(soulId));
    final activeVersionId = activeVersionAsync.value?.mapOrNull(
      soulDocumentVersion: (v) => v.id,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.agentSoulVersionHistoryTitle,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        historyAsync.when(
          data: (versions) {
            final typed = versions
                .whereType<SoulDocumentVersionEntity>()
                .toList();
            if (typed.isEmpty) {
              return Text(context.messages.agentTemplateNoVersions);
            }
            return Column(
              children: typed.map((version) {
                return _VersionTile(
                  version: version,
                  soulId: soulId,
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
    required this.soulId,
    required this.isActive,
  });

  final SoulDocumentVersionEntity version;
  final String soulId;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: context.colorScheme.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: ListTile(
        title: Text(
          context.messages.agentSoulVersionLabel(version.version),
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
                tooltip: context.messages.agentSoulRollbackAction,
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
        title: Text(dialogContext.messages.agentSoulRollbackAction),
        content: Text(
          dialogContext.messages.agentSoulRollbackConfirm(version.version),
        ),
        actions: [
          LottiTertiaryButton(
            onPressed: () => Navigator.pop(dialogContext),
            label: dialogContext.messages.cancelButton,
          ),
          LottiPrimaryButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final soulService = ref.read(soulDocumentServiceProvider);
                await soulService.rollbackToVersion(
                  soulId: soulId,
                  versionId: version.id,
                );
              } catch (e, s) {
                developer.log(
                  'Rollback failed',
                  name: 'AgentSoulDetailPage',
                  error: e,
                  stackTrace: s,
                );
                if (!context.mounted) return;
                context.showToast(
                  tone: DesignSystemToastTone.error,
                  title: context.messages.commonError,
                );
              }
            },
            label: dialogContext.messages.agentSoulRollbackAction,
          ),
        ],
      ),
    );
  }
}

class _SoulEvolutionHistorySection extends ConsumerWidget {
  const _SoulEvolutionHistorySection({required this.soulId});

  final String soulId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(
      soulEvolutionSessionHistoryProvider(soulId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.agentSoulEvolutionHistoryTitle,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        historyAsync.when(
          data: (entries) {
            if (entries.isEmpty) {
              return Text(
                context.messages.agentSoulEvolutionNoSessions,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              );
            }
            return Column(
              children: entries
                  .map((entry) => RitualSessionHistoryCard(entry: entry))
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Text(context.messages.commonError),
        ),
      ],
    );
  }
}

class _AssignedTemplatesSection extends ConsumerWidget {
  const _AssignedTemplatesSection({required this.soulId});

  final String soulId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templateIdsAsync = ref.watch(templatesUsingSoulProvider(soulId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.agentSoulAssignedTemplatesTitle,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        templateIdsAsync.when(
          data: (templateIds) {
            if (templateIds.isEmpty) {
              return Text(
                context.messages.agentTemplateNoneAssigned,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              );
            }
            return Column(
              children: templateIds.map((templateId) {
                return _AssignedTemplateTile(templateId: templateId);
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

class _AssignedTemplateTile extends ConsumerWidget {
  const _AssignedTemplateTile({required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templateAsync = ref.watch(agentTemplateProvider(templateId));

    final displayName =
        templateAsync.value?.mapOrNull(
          agentTemplate: (t) => t.displayName,
        ) ??
        templateId;

    return Card(
      color: context.colorScheme.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: ListTile(
        leading: Icon(
          Icons.smart_toy_outlined,
          size: 20,
          color: context.colorScheme.onSurfaceVariant,
        ),
        title: Text(displayName),
      ),
    );
  }
}
