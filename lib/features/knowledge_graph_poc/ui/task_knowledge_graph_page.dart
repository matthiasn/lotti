/// In-app page hosting the knowledge-graph explorer for a real task
/// (ADR 0029 Phase 1). Loads the task's link neighborhood via
/// [taskGraphProvider] and renders it with real category colors.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph_poc/state/task_graph_provider.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/knowledge_graph_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class TaskKnowledgeGraphPage extends ConsumerWidget {
  const TaskKnowledgeGraphPage({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final graph = ref.watch(taskGraphProvider(taskId));

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      appBar: AppBar(
        backgroundColor: tokens.colors.background.level01,
        title: Text(context.messages.knowledgeGraphTitle),
      ),
      body: graph.when(
        data: (data) {
          // Only the focus node and nothing linked → nothing to explore.
          if (data == null || data.scenario.nodes.length <= 1) {
            return const _EmptyState();
          }
          return KnowledgeGraphView(
            scenario: data.scenario,
            categoryColors: data.categoryColors,
            categoryNames: data.categoryNames,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(message: '$error'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hub_outlined,
            size: 48,
            color: tokens.colors.text.lowEmphasis,
          ),
          SizedBox(height: tokens.spacing.step4),
          Text(
            context.messages.knowledgeGraphEmpty,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.alert.error.defaultColor,
          ),
        ),
      ),
    );
  }
}
