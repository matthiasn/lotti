import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/gamey/gamey_fab.dart';

/// List page for managing agent templates.
///
/// Displays all non-deleted templates with name, kind badge, model ID, and
/// version number. Follows the same pattern as `CategoriesListPage`.
class AgentTemplateListPage extends ConsumerWidget {
  const AgentTemplateListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(agentTemplatesProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SettingsPageHeader(
            title: context.messages.agentTemplatesTitle,
            showBackButton: true,
          ),
          ...templatesAsync.when(
            data: (templates) => _buildContentSlivers(context, templates),
            loading: () => [
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, stack) => [
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: GameyFab(
        onPressed: () => beamToNamed('/settings/templates/create'),
        semanticLabel: context.messages.agentTemplateCreateTitle,
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Widget> _buildContentSlivers(
    BuildContext context,
    List<AgentDomainEntity> templates,
  ) {
    if (templates.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.smart_toy_outlined,
                  size: 64,
                  color: Theme.of(context).disabledColor,
                ),
                const SizedBox(height: 16),
                Text(
                  context.messages.agentTemplateEmptyList,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).disabledColor,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final sorted = templates.whereType<AgentTemplateEntity>().toList()
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );

    return [
      SliverPadding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final template = sorted[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _TemplateListTile(template: template),
              );
            },
            childCount: sorted.length,
          ),
        ),
      ),
    ];
  }
}

class _TemplateListTile extends ConsumerWidget {
  const _TemplateListTile({required this.template});

  final AgentTemplateEntity template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeVersionAsync =
        ref.watch(activeTemplateVersionProvider(template.id));
    final versionNumber = activeVersionAsync.value
        ?.mapOrNull(agentTemplateVersion: (v) => v.version);

    return ModernBaseCard(
      onTap: () => beamToNamed('/settings/templates/${template.id}'),
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          Icons.smart_toy_outlined,
          size: 32,
          color: context.colorScheme.primary,
        ),
        title: Text(
          template.displayName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Row(
          children: [
            _KindBadge(kind: template.kind),
            const SizedBox(width: AppTheme.spacingSmall),
            Text(
              template.modelId,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (versionNumber != null) ...[
              const SizedBox(width: AppTheme.spacingSmall),
              Text(
                context.messages.agentTemplateVersionLabel(versionNumber),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final AgentTemplateKind kind;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      AgentTemplateKind.taskAgent =>
        context.messages.agentTemplateKindTaskAgent,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSmall,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.spacingXSmall),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: context.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
