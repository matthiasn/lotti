import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_projection.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/graph_style.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/graph_workspace_toolbar.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/node_inspector_panel.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class GraphConnectionGroup {
  const GraphConnectionGroup({
    required this.kind,
    required this.outgoing,
    required this.nodes,
    this.associationTargetType,
  });

  final GraphEdgeKind kind;
  final bool outgoing;
  final List<GraphNode> nodes;
  final GraphNodeType? associationTargetType;
}

/// List-oriented alternative to the canvas for users who navigate better by
/// names and relationship groups than by spatial position.
class GraphConnectionsView extends StatelessWidget {
  const GraphConnectionsView({
    required this.scenario,
    required this.focusId,
    required this.filters,
    required this.categoryNames,
    required this.onNodeTap,
    super.key,
  });

  final GraphScenario scenario;
  final String focusId;
  final GraphProjectionFilters filters;
  final Map<String, String> categoryNames;
  final ValueChanged<String> onNodeTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final groups = graphConnectionGroups(
      scenario: scenario,
      focusId: focusId,
      filters: filters,
    );
    if (groups.isEmpty) {
      return Center(
        child: Text(
          context.messages.knowledgeGraphEmpty,
          style: tokens.typography.styles.body.bodyLarge.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      );
    }

    return ListView.separated(
      key: const ValueKey('knowledge-graph-connections-list'),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step12,
        tokens.spacing.step5,
        tokens.spacing.step5,
      ),
      itemCount: groups.length,
      separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.step4),
      itemBuilder: (context, index) {
        final group = groups[index];
        return DesignSystemSectionCard(
          padding: EdgeInsets.all(tokens.spacing.step4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${graphConnectionGroupLabel(context, group)} · '
                '${group.nodes.length}',
                style: tokens.typography.styles.others.overline.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
              SizedBox(height: tokens.spacing.step2),
              for (final node in group.nodes)
                _ConnectionRow(
                  node: node,
                  categoryLabel: categoryNames[node.categoryId],
                  ageLabel: relativeAge(
                    context.messages,
                    scenario.now.difference(node.createdAt),
                  ),
                  onTap: () => onNodeTap(node.id),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({
    required this.node,
    required this.categoryLabel,
    required this.ageLabel,
    required this.onTap,
  });

  final GraphNode node;
  final String? categoryLabel;
  final String ageLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radii.smallChips),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              glyphForType(node.type),
              size: IconSizes.s,
              color: tokens.colors.text.mediumEmphasis,
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.label,
                    style: tokens.typography.styles.body.bodyLarge.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    [
                      typeLabel(context.messages, node.type),
                      ?categoryLabel,
                      ageLabel,
                    ].join(' · '),
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: IconSizes.s,
              color: tokens.colors.text.lowEmphasis,
            ),
          ],
        ),
      ),
    );
  }
}

List<GraphConnectionGroup> graphConnectionGroups({
  required GraphScenario scenario,
  required String focusId,
  GraphProjectionFilters filters = const GraphProjectionFilters(),
}) {
  final byId = {for (final node in scenario.nodes) node.id: node};
  final grouped = <(GraphEdgeKind, bool, GraphNodeType?), List<GraphNode>>{};
  for (final edge in scenario.edges) {
    final outgoing = edge.fromId == focusId;
    if (!outgoing && edge.toId != focusId) continue;
    if (filters.edgeKinds.isNotEmpty &&
        !filters.edgeKinds.contains(edge.kind)) {
      continue;
    }
    final node = byId[outgoing ? edge.toId : edge.fromId];
    if (node == null || !_connectionNodeMatches(scenario, node, filters)) {
      continue;
    }
    final associationTargetType = edge.kind == GraphEdgeKind.association
        ? (node.type == GraphNodeType.task
              ? GraphNodeType.task
              : GraphNodeType.textEntry)
        : null;
    grouped
        .putIfAbsent((edge.kind, outgoing, associationTargetType), () => [])
        .add(node);
  }

  final result = [
    for (final entry in grouped.entries)
      GraphConnectionGroup(
        kind: entry.key.$1,
        outgoing: entry.key.$2,
        associationTargetType: entry.key.$3,
        nodes: entry.value..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      ),
  ];
  return result..sort((a, b) {
    final kind = a.kind.index.compareTo(b.kind.index);
    if (kind != 0) return kind;
    return a.outgoing == b.outgoing ? 0 : (a.outgoing ? -1 : 1);
  });
}

String graphConnectionGroupLabel(
  BuildContext context,
  GraphConnectionGroup group,
) {
  if (group.kind == GraphEdgeKind.association) {
    return group.associationTargetType == GraphNodeType.task
        ? context.messages.knowledgeGraphRelationLinkedTask
        : context.messages.knowledgeGraphRelationNoteLog;
  }
  return graphDirectionalEdgeLabel(
    context.messages,
    group.kind,
    outgoing: group.outgoing,
  );
}

bool _connectionNodeMatches(
  GraphScenario scenario,
  GraphNode node,
  GraphProjectionFilters filters,
) {
  if (filters.nodeTypes.isNotEmpty && !filters.nodeTypes.contains(node.type)) {
    return false;
  }
  if (filters.categoryIds.isNotEmpty &&
      !filters.categoryIds.contains(node.categoryId)) {
    return false;
  }
  if (filters.taskStatuses.isNotEmpty &&
      (node.taskStatus == null ||
          !filters.taskStatuses.contains(node.taskStatus))) {
    return false;
  }
  final maxAgeDays = filters.maxAgeDays;
  return maxAgeDays == null || scenario.ageDays(node) <= maxAgeDays;
}
