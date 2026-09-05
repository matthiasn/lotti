import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_projection.dart';
import 'package:lotti/features/knowledge_graph/state/graph_viewport_controller.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_style.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_visual_spec.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Compact controls for switching representations and reducing the local
/// graph before it turns into a hairball.
class GraphWorkspaceToolbar extends StatelessWidget {
  const GraphWorkspaceToolbar({
    required this.state,
    required this.scenario,
    required this.categoryNames,
    required this.onModeChanged,
    required this.onDensityChanged,
    required this.onFiltersChanged,
    super.key,
  });

  final GraphViewportState state;
  final GraphScenario scenario;
  final Map<String, String> categoryNames;
  final ValueChanged<GraphViewMode> onModeChanged;
  final ValueChanged<GraphDensity> onDensityChanged;
  final ValueChanged<GraphProjectionFilters> onFiltersChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step2),
        child: Wrap(
          spacing: tokens.spacing.step2,
          runSpacing: tokens.spacing.step2,
          children: [
            DesignSystemChip(
              key: const ValueKey('knowledge-graph-mode-graph'),
              label: context.messages.knowledgeGraphViewGraph,
              leadingIcon: LottiIcons.hub,
              selected: state.mode == GraphViewMode.graph,
              onPressed: () => onModeChanged(GraphViewMode.graph),
            ),
            DesignSystemChip(
              key: const ValueKey('knowledge-graph-mode-connections'),
              label: context.messages.knowledgeGraphViewConnections,
              leadingIcon: LottiIcons.list,
              selected: state.mode == GraphViewMode.connections,
              onPressed: () => onModeChanged(GraphViewMode.connections),
            ),
            PopupMenuButton<GraphDensity>(
              key: const ValueKey('knowledge-graph-density-menu'),
              tooltip: context.messages.knowledgeGraphDensity,
              onSelected: onDensityChanged,
              itemBuilder: (context) => [
                for (final density in GraphDensity.values)
                  PopupMenuItem(
                    value: density,
                    child: Text(graphDensityLabel(context.messages, density)),
                  ),
              ],
              child: IgnorePointer(
                child: DesignSystemChip(
                  label: graphDensityLabel(context.messages, state.density),
                  leadingIcon: LottiIcons.blur,
                  onPressed: () {}, // coverage:ignore-line
                ),
              ),
            ),
            DesignSystemChip(
              key: const ValueKey('knowledge-graph-hop-filter'),
              label: state.filters.maxHops == 1
                  ? context.messages.knowledgeGraphOneHop
                  : context.messages.knowledgeGraphTwoHops,
              leadingIcon: LottiIcons.route,
              selected: state.filters.maxHops == 1,
              onPressed: () => onFiltersChanged(
                state.filters.copyWith(
                  maxHops: state.filters.maxHops == 1 ? 2 : 1,
                ),
              ),
            ),
            DesignSystemChip(
              key: const ValueKey('knowledge-graph-open-filters'),
              label: context.messages.knowledgeGraphFilters,
              leadingIcon: LottiIcons.tune,
              selected: !state.filters.isEmpty,
              onPressed: () => _showFilters(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilters(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => GraphFiltersPanel(
      initial: state.filters,
      scenario: scenario,
      categoryNames: categoryNames,
      onChanged: onFiltersChanged,
    ),
  );
}

class GraphFiltersPanel extends StatefulWidget {
  const GraphFiltersPanel({
    required this.initial,
    required this.scenario,
    required this.categoryNames,
    required this.onChanged,
    super.key,
  });

  final GraphProjectionFilters initial;
  final GraphScenario scenario;
  final Map<String, String> categoryNames;
  final ValueChanged<GraphProjectionFilters> onChanged;

  @override
  State<GraphFiltersPanel> createState() => _GraphFiltersPanelState();
}

class _GraphFiltersPanelState extends State<GraphFiltersPanel> {
  late GraphProjectionFilters _filters = widget.initial;

  void _set(GraphProjectionFilters filters) {
    setState(() => _filters = filters);
    widget.onChanged(filters);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final categories =
        widget.scenario.nodes
            .map((node) => node.categoryId)
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList()
          ..sort(
            (a, b) =>
                graphCategoryLabel(
                  context.messages,
                  widget.categoryNames,
                  a,
                ).compareTo(
                  graphCategoryLabel(context.messages, widget.categoryNames, b),
                ),
          );
    final nodeTypes = widget.scenario.nodes.map((node) => node.type).toSet();
    final taskStatuses = widget.scenario.nodes
        .map((node) => node.taskStatus)
        .whereType<GraphTaskStatus>()
        .toSet();

    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.messages.knowledgeGraphFilters,
                  style: tokens.typography.styles.heading.heading2,
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(LottiIcons.close),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.sectionGap),
          _FilterSection(
            title: context.messages.knowledgeGraphFilterRelations,
            children: [
              for (final kind in GraphEdgeKind.values)
                DesignSystemChip(
                  label: graphEdgeKindLabel(context.messages, kind),
                  selected: _filters.edgeKinds.contains(kind),
                  onPressed: () => _set(
                    _filters.copyWith(
                      edgeKinds: toggledFilterValue(_filters.edgeKinds, kind),
                    ),
                  ),
                ),
            ],
          ),
          _FilterSection(
            title: context.messages.knowledgeGraphFilterTypes,
            children: [
              for (final type in nodeTypes)
                DesignSystemChip(
                  label: typeLabel(context.messages, type),
                  selected: _filters.nodeTypes.contains(type),
                  onPressed: () => _set(
                    _filters.copyWith(
                      nodeTypes: toggledFilterValue(_filters.nodeTypes, type),
                    ),
                  ),
                ),
            ],
          ),
          if (categories.isNotEmpty)
            _FilterSection(
              title: context.messages.knowledgeGraphFilterCategories,
              children: [
                for (final category in categories)
                  DesignSystemChip(
                    label: graphCategoryLabel(
                      context.messages,
                      widget.categoryNames,
                      category,
                    ),
                    selected: _filters.categoryIds.contains(category),
                    onPressed: () => _set(
                      _filters.copyWith(
                        categoryIds: toggledFilterValue(
                          _filters.categoryIds,
                          category,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          _FilterSection(
            title: context.messages.knowledgeGraphFilterRecency,
            children: [
              for (final days in <int?>[null, 7, 30, 90])
                DesignSystemChip(
                  label: graphRecencyLabel(context.messages, days),
                  selected: _filters.maxAgeDays == days,
                  onPressed: () => _set(
                    _filters.copyWith(
                      maxAgeDays: days,
                      clearMaxAgeDays: days == null,
                    ),
                  ),
                ),
            ],
          ),
          if (taskStatuses.isNotEmpty)
            _FilterSection(
              title: context.messages.knowledgeGraphFilterTaskStatus,
              children: [
                for (final status in taskStatuses)
                  DesignSystemChip(
                    label: graphTaskStatusLabel(context.messages, status),
                    selected: _filters.taskStatuses.contains(status),
                    onPressed: () => _set(
                      _filters.copyWith(
                        taskStatuses: toggledFilterValue(
                          _filters.taskStatuses,
                          status,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: tokens.typography.styles.subtitle.subtitle2),
          SizedBox(height: tokens.spacing.step3),
          Wrap(
            spacing: tokens.spacing.step2,
            runSpacing: tokens.spacing.step2,
            children: children,
          ),
        ],
      ),
    );
  }
}

Set<T> toggledFilterValue<T>(Set<T> values, T value) {
  if (values.isEmpty) return {value};
  final next = {...values};
  if (!next.remove(value)) next.add(value);
  return next.isEmpty ? <T>{} : next;
}

String graphDensityLabel(AppLocalizations messages, GraphDensity density) =>
    switch (density) {
      GraphDensity.calm => messages.knowledgeGraphDensityCalm,
      GraphDensity.balanced => messages.knowledgeGraphDensityBalanced,
      GraphDensity.explore => messages.knowledgeGraphDensityExplore,
    };

String graphRecencyLabel(AppLocalizations messages, int? days) =>
    switch (days) {
      null => messages.taskStatusAll,
      7 => messages.knowledgeGraphLast7Days,
      30 => messages.knowledgeGraphLast30Days,
      _ => messages.knowledgeGraphLast90Days,
    };

String graphTaskStatusLabel(
  AppLocalizations messages,
  GraphTaskStatus status,
) => switch (status) {
  GraphTaskStatus.open => messages.taskStatusOpen,
  GraphTaskStatus.inProgress => messages.taskStatusInProgress,
  GraphTaskStatus.groomed => messages.taskStatusGroomed,
  GraphTaskStatus.blocked => messages.taskStatusBlocked,
  GraphTaskStatus.onHold => messages.taskStatusOnHold,
  GraphTaskStatus.done => messages.taskStatusDone,
  GraphTaskStatus.rejected => messages.taskStatusRejected,
};

String graphEdgeKindLabel(AppLocalizations messages, GraphEdgeKind kind) =>
    switch (kind) {
      GraphEdgeKind.containment => messages.knowledgeGraphRelationInProject,
      GraphEdgeKind.association => messages.knowledgeGraphRelationAssociation,
      GraphEdgeKind.provenance => messages.knowledgeGraphRelationAiSource,
      GraphEdgeKind.evaluation => messages.knowledgeGraphRelationRating,
      GraphEdgeKind.checklist => messages.knowledgeGraphRelationChecklist,
      GraphEdgeKind.blocks => messages.linkPhraseBlocksPrimary,
      GraphEdgeKind.followsUp => messages.linkPhraseFollowsUpPrimary,
      GraphEdgeKind.duplicates => messages.linkPhraseDuplicatesPrimary,
      GraphEdgeKind.fixes => messages.linkPhraseFixesPrimary,
      GraphEdgeKind.supersedes => messages.linkPhraseSupersedesPrimary,
    };

String graphDirectionalEdgeLabel(
  AppLocalizations messages,
  GraphEdgeKind kind, {
  required bool outgoing,
}) => switch (kind) {
  GraphEdgeKind.blocks =>
    outgoing
        ? messages.linkPhraseBlocksPrimary
        : messages.linkPhraseBlocksInverse,
  GraphEdgeKind.followsUp =>
    outgoing
        ? messages.linkPhraseFollowsUpPrimary
        : messages.linkPhraseFollowsUpInverse,
  GraphEdgeKind.duplicates =>
    outgoing
        ? messages.linkPhraseDuplicatesPrimary
        : messages.linkPhraseDuplicatesInverse,
  GraphEdgeKind.fixes =>
    outgoing
        ? messages.linkPhraseFixesPrimary
        : messages.linkPhraseFixesInverse,
  GraphEdgeKind.supersedes =>
    outgoing
        ? messages.linkPhraseSupersedesPrimary
        : messages.linkPhraseSupersedesInverse,
  _ => graphEdgeKindLabel(messages, kind),
};
