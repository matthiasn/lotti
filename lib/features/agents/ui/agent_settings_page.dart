import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_instances_list.dart';
import 'package:lotti/features/agents/ui/agent_nav_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/gamey/gamey_fab.dart';

/// Landing page for Settings > Agents.
///
/// Contains two tabs:
/// - **Templates**: inline list of agent templates (extracted from the former
///   `AgentTemplateListPage`).
/// - **Instances**: filterable list of agent instances.
class AgentSettingsPage extends ConsumerWidget {
  const AgentSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: agentBackButton(context),
          title: Text(
            context.messages.agentSettingsTitle,
            style: appBarTextStyleNewLarge.copyWith(
              color: Theme.of(context).primaryColor,
            ),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: context.messages.agentTemplatesTitle),
              Tab(text: context.messages.agentInstancesTitle),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TemplatesTab(),
            AgentInstancesList(),
          ],
        ),
        floatingActionButton: GameyFab(
          onPressed: () => beamToNamed('/settings/agents/templates/create'),
          semanticLabel: context.messages.agentTemplateCreateTitle,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

/// Inline templates list extracted from `AgentTemplateListPage`.
class _TemplatesTab extends ConsumerWidget {
  const _TemplatesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(agentTemplatesProvider);

    return templatesAsync.when(
      data: (templates) => _buildTemplatesList(context, ref, templates),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            context.messages.commonError,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildTemplatesList(
    BuildContext context,
    WidgetRef ref,
    List<AgentDomainEntity> templates,
  ) {
    if (templates.isEmpty) {
      return Center(
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
              style: context.textTheme.titleMedium?.copyWith(
                color: Theme.of(context).disabledColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final sorted = templates.whereType<AgentTemplateEntity>().toList()
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final template = sorted[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _TemplateListTile(template: template),
        );
      },
    );
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
      onTap: () => beamToNamed('/settings/agents/templates/${template.id}'),
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
          style: context.textTheme.titleMedium,
        ),
        subtitle: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppTheme.spacingSmall,
          runSpacing: AppTheme.spacingXSmall,
          children: [
            _KindBadge(kind: template.kind),
            Text(
              template.modelId,
              style: context.textTheme.bodySmall,
            ),
            if (versionNumber != null)
              Text(
                context.messages.agentTemplateVersionLabel(versionNumber),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
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
      AgentTemplateKind.templateImprover => 'Template Improver',
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
