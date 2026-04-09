import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/agent_instances_list.dart';
import 'package:lotti/features/agents/ui/agent_nav_helpers.dart';
import 'package:lotti/features/agents/ui/agent_pending_wakes_list.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';
import 'package:lotti/features/design_system/components/tabs/design_system_tab.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/gamey/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/gamey/gamey_fab.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// Landing page for Settings > Agents.
///
/// Contains three tabs:
/// - **Templates**: inline list of agent templates (extracted from the former
///   `AgentTemplateListPage`).
/// - **Instances**: filterable list of agent instances.
/// - **Pending Wakes**: live list of scheduled and deferred wake timers.
class AgentSettingsPage extends ConsumerStatefulWidget {
  const AgentSettingsPage({super.key});

  @override
  ConsumerState<AgentSettingsPage> createState() => _AgentSettingsPageState();
}

enum _AgentSettingsTab {
  stats,
  templates,
  instances,
  souls,
  pendingWakes,
}

class _AgentSettingsPageState extends ConsumerState<AgentSettingsPage> {
  _AgentSettingsTab _selectedTab = _AgentSettingsTab.stats;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final pendingWakeCount = ref.watch(
      pendingWakeRecordsProvider.select((value) => value.value?.length ?? 0),
    );
    final floatingActionButton = switch (_selectedTab) {
      _AgentSettingsTab.templates => GameyFab(
        onPressed: () => beamToNamed('/settings/agents/templates/create'),
        semanticLabel: context.messages.agentTemplateCreateTitle,
        child: const Icon(Icons.add),
      ),
      _AgentSettingsTab.souls => GameyFab(
        onPressed: () => beamToNamed('/settings/agents/souls/create'),
        semanticLabel: context.messages.agentSoulCreateTitle,
        child: const Icon(Icons.add),
      ),
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(
        leading: agentBackButton(context),
        title: Text(
          context.messages.agentSettingsTitle,
          style: appBarTextStyleNewLarge.copyWith(
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step4,
              tokens.spacing.step4,
              tokens.spacing.step4,
              tokens.spacing.step2,
            ),
            child: _AgentSettingsTabBar(
              selectedTab: _selectedTab,
              pendingWakeCount: pendingWakeCount,
              onSelected: (_AgentSettingsTab tab) =>
                  setState(() => _selectedTab = tab),
            ),
          ),
          Expanded(
            child: _AgentSettingsTabBody(
              selectedTab: _selectedTab,
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton == null
          ? null
          : DesignSystemBottomNavigationFabPadding(
              child: floatingActionButton,
            ),
    );
  }
}

class _AgentSettingsTabBar extends StatelessWidget {
  const _AgentSettingsTabBar({
    required this.selectedTab,
    required this.pendingWakeCount,
    required this.onSelected,
  });

  final _AgentSettingsTab selectedTab;
  final int pendingWakeCount;
  final ValueChanged<_AgentSettingsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final tabs = [
      (
        tab: _AgentSettingsTab.stats,
        label: context.messages.agentStatsTabTitle,
        counter: null as String?,
      ),
      (
        tab: _AgentSettingsTab.templates,
        label: context.messages.agentTemplatesTitle,
        counter: null as String?,
      ),
      (
        tab: _AgentSettingsTab.instances,
        label: context.messages.agentInstancesTitle,
        counter: null as String?,
      ),
      (
        tab: _AgentSettingsTab.souls,
        label: context.messages.agentSoulsTitle,
        counter: null as String?,
      ),
      (
        tab: _AgentSettingsTab.pendingWakes,
        label: context.messages.agentPendingWakesTitle,
        counter: '$pendingWakeCount',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = _segmentWidths(
          context,
          constraints.maxWidth,
          tabs,
        );
        final totalWidth = widths.fold<double>(0, (sum, width) => sum + width);

        return ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.radii.m),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalWidth,
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    SizedBox(
                      width: widths[i],
                      child: DesignSystemTab(
                        selected: selectedTab == tabs[i].tab,
                        shape: DesignSystemTabShape.rectangular,
                        label: tabs[i].label,
                        counter: tabs[i].counter,
                        onPressed: () => onSelected(tabs[i].tab),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<double> _segmentWidths(
    BuildContext context,
    double availableWidth,
    List<({String? counter, String label, _AgentSettingsTab tab})> tabs,
  ) {
    final naturalWidths = tabs
        .map(
          (tab) => DesignSystemTab.preferredWidth(
            context,
            label: tab.label,
            counter: tab.counter,
          ),
        )
        .toList();
    final totalNaturalWidth = naturalWidths.fold<double>(
      0,
      (sum, width) => sum + width,
    );

    if (totalNaturalWidth >= availableWidth) {
      return naturalWidths;
    }

    final extraPerTab = (availableWidth - totalNaturalWidth) / tabs.length;
    return naturalWidths.map((width) => width + extraPerTab).toList();
  }
}

class _AgentSettingsTabBody extends ConsumerWidget {
  const _AgentSettingsTabBody({
    required this.selectedTab,
  });

  final _AgentSettingsTab selectedTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IndexedStack(
      index: selectedTab.index,
      children: const [
        TokenStatsTab(),
        _TemplatesTab(),
        AgentInstancesList(),
        _SoulsTab(),
        AgentPendingWakesList(),
      ],
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
    final activeVersionAsync = ref.watch(
      activeTemplateVersionProvider(template.id),
    );
    final versionNumber = activeVersionAsync.value?.mapOrNull(
      agentTemplateVersion: (v) => v.version,
    );
    final hasPending = ref.watch(
      templatesPendingReviewProvider.select(
        (async) => async.value?.contains(template.id) ?? false,
      ),
    );

    return ModernBaseCard(
      onTap: () => beamToNamed('/settings/agents/templates/${template.id}'),
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 32,
              color: context.colorScheme.primary,
            ),
            if (hasPending)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: GameyColors.primaryPurple,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
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

/// Inline souls list for the Souls tab.
class _SoulsTab extends ConsumerWidget {
  const _SoulsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soulsAsync = ref.watch(allSoulDocumentsProvider);

    return soulsAsync.when(
      data: (souls) => _buildSoulsList(context, souls),
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

  Widget _buildSoulsList(
    BuildContext context,
    List<AgentDomainEntity> souls,
  ) {
    if (souls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              context.messages.agentSoulEmptyList,
              style: context.textTheme.titleMedium?.copyWith(
                color: Theme.of(context).disabledColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final sorted = souls.whereType<SoulDocumentEntity>().toList()
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final soul = sorted[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _SoulListTile(soul: soul),
        );
      },
    );
  }
}

class _SoulListTile extends ConsumerWidget {
  const _SoulListTile({required this.soul});

  final SoulDocumentEntity soul;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeVersionAsync = ref.watch(
      activeSoulVersionProvider(soul.id),
    );
    final versionNumber = activeVersionAsync.value?.mapOrNull(
      soulDocumentVersion: (v) => v.version,
    );

    return ModernBaseCard(
      onTap: () => beamToNamed('/settings/agents/souls/${soul.id}'),
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          Icons.psychology_rounded,
          size: 32,
          color: context.colorScheme.primary,
        ),
        title: Text(
          soul.displayName,
          style: context.textTheme.titleMedium,
        ),
        subtitle: versionNumber != null
            ? Text(
                context.messages.agentSoulVersionLabel(versionNumber),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
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
      AgentTemplateKind.templateImprover =>
        context.messages.agentTemplateKindImprover,
      AgentTemplateKind.projectAgent =>
        context.messages.agentTemplateKindProjectAgent,
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
