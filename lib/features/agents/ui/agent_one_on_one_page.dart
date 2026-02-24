import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/form/lotti_text_field.dart';

/// 1-on-1 page for reviewing template performance and evolving directives
/// with LLM assistance.
class AgentOneOnOnePage extends ConsumerStatefulWidget {
  const AgentOneOnOnePage({
    required this.templateId,
    super.key,
  });

  final String templateId;

  @override
  ConsumerState<AgentOneOnOnePage> createState() => _AgentOneOnOnePageState();
}

class _AgentOneOnOnePageState extends ConsumerState<AgentOneOnOnePage> {
  late TextEditingController _enjoyedController;
  late TextEditingController _didntWorkController;
  late TextEditingController _changesController;

  bool _isEvolving = false;
  EvolutionProposal? _proposal;

  @override
  void initState() {
    super.initState();
    _enjoyedController = TextEditingController();
    _didntWorkController = TextEditingController();
    _changesController = TextEditingController();
  }

  @override
  void dispose() {
    _enjoyedController.dispose();
    _didntWorkController.dispose();
    _changesController.dispose();
    super.dispose();
  }

  bool get _hasFeedback =>
      _enjoyedController.text.trim().isNotEmpty ||
      _didntWorkController.text.trim().isNotEmpty ||
      _changesController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final templateAsync = ref.watch(agentTemplateProvider(widget.templateId));
    final template = templateAsync.value?.mapOrNull(agentTemplate: (e) => e);

    final title = template != null
        ? context.messages.agentTemplateOneOnOneTitle(template.displayName)
        : '';

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
              title,
              style: appBarTextStyleNewLarge.copyWith(
                color: Theme.of(context).primaryColor,
              ),
            ),
            pinned: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _MetricsDashboard(templateId: widget.templateId),
                const SizedBox(height: 24),
                _buildFeedbackSection(context),
                const SizedBox(height: 24),
                _buildEvolutionControls(context),
                if (_proposal != null) ...[
                  const SizedBox(height: 24),
                  _buildProposalPreview(context),
                ],
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.agentTemplateFeedbackTitle,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        LottiTextArea(
          controller: _enjoyedController,
          labelText: context.messages.agentTemplateFeedbackEnjoyedLabel,
          hintText: context.messages.agentTemplateFeedbackEnjoyedHint,
          minLines: 2,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        LottiTextArea(
          controller: _didntWorkController,
          labelText: context.messages.agentTemplateFeedbackDidntWorkLabel,
          hintText: context.messages.agentTemplateFeedbackDidntWorkHint,
          minLines: 2,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        LottiTextArea(
          controller: _changesController,
          labelText: context.messages.agentTemplateFeedbackChangesLabel,
          hintText: context.messages.agentTemplateFeedbackChangesHint,
          minLines: 2,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildEvolutionControls(BuildContext context) {
    if (_isEvolving) {
      return Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(context.messages.agentTemplateEvolvingProgress),
        ],
      );
    }

    return LottiPrimaryButton(
      onPressed: _hasFeedback ? () => _handleEvolve(context) : null,
      label: context.messages.agentTemplateEvolveButton,
      icon: Icons.auto_awesome,
    );
  }

  Widget _buildProposalPreview(BuildContext context) {
    final proposal = _proposal!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.agentTemplateEvolvePreviewTitle,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        Text(
          context.messages.agentTemplateEvolveCurrentLabel,
          style: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            proposal.originalDirectives,
            style: context.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.messages.agentTemplateEvolveProposedLabel,
          style: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colorScheme.primary),
          ),
          child: SelectableText(
            proposal.proposedDirectives,
            style: context.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            LottiSecondaryButton(
              onPressed: () => setState(() => _proposal = null),
              label: context.messages.agentTemplateEvolveReject,
            ),
            const SizedBox(width: 12),
            LottiPrimaryButton(
              onPressed: () => _handleApprove(context),
              label: context.messages.agentTemplateEvolveApprove,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleEvolve(BuildContext context) async {
    setState(() => _isEvolving = true);

    try {
      final templateData =
          await ref.read(agentTemplateProvider(widget.templateId).future);
      final template = templateData?.mapOrNull(agentTemplate: (e) => e);

      final versionData = await ref
          .read(activeTemplateVersionProvider(widget.templateId).future);
      final version = versionData?.mapOrNull(agentTemplateVersion: (v) => v);

      final metrics = await ref
          .read(templatePerformanceMetricsProvider(widget.templateId).future);

      if (template == null || version == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.messages.agentTemplateEvolveError),
          ),
        );
        return;
      }

      final workflow = ref.read(templateEvolutionWorkflowProvider);
      final feedback = EvolutionFeedback(
        enjoyed: _enjoyedController.text.trim(),
        didntWork: _didntWorkController.text.trim(),
        specificChanges: _changesController.text.trim(),
      );

      final proposal = await workflow.proposeEvolution(
        template: template,
        currentVersion: version,
        metrics: metrics,
        feedback: feedback,
      );

      if (!context.mounted) return;

      if (proposal == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.messages.agentTemplateEvolveError),
          ),
        );
      } else {
        setState(() => _proposal = proposal);
      }
    } catch (e, s) {
      developer.log(
        'Evolution failed',
        name: 'AgentOneOnOnePage',
        error: e,
        stackTrace: s,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.messages.agentTemplateEvolveError),
        ),
      );
    } finally {
      if (mounted) setState(() => _isEvolving = false);
    }
  }

  Future<void> _handleApprove(BuildContext context) async {
    final proposal = _proposal;
    if (proposal == null) return;

    try {
      final templateService = ref.read(agentTemplateServiceProvider);
      await templateService.createVersion(
        templateId: widget.templateId,
        directives: proposal.proposedDirectives,
        authoredBy: 'agent',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.messages.agentTemplateEvolveSuccess),
        ),
      );

      ref
        ..invalidate(agentTemplatesProvider)
        ..invalidate(activeTemplateVersionProvider(widget.templateId))
        ..invalidate(templateVersionHistoryProvider(widget.templateId))
        ..invalidate(
          templatePerformanceMetricsProvider(widget.templateId),
        );

      Navigator.of(context).pop();
    } catch (e, s) {
      developer.log(
        'Approve failed',
        name: 'AgentOneOnOnePage',
        error: e,
        stackTrace: s,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.messages.agentTemplateEvolveError),
        ),
      );
    }
  }
}

/// Dashboard showing performance metrics for a template.
class _MetricsDashboard extends ConsumerWidget {
  const _MetricsDashboard({required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync =
        ref.watch(templatePerformanceMetricsProvider(templateId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.agentTemplateMetricsTitle,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        metricsAsync.when(
          data: (metrics) => _buildMetricsContent(context, metrics),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Text(context.messages.commonError),
        ),
      ],
    );
  }

  Widget _buildMetricsContent(
    BuildContext context,
    TemplatePerformanceMetrics metrics,
  ) {
    if (metrics.totalWakes == 0) {
      return Text(
        context.messages.agentTemplateNoMetrics,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard(
          label: context.messages.agentTemplateMetricsTotalWakes,
          value: '${metrics.totalWakes}',
        ),
        _MetricCard(
          label: context.messages.agentTemplateMetricsSuccessRate,
          value: '${(metrics.successRate * 100).toStringAsFixed(1)}%',
        ),
        _MetricCard(
          label: context.messages.agentTemplateMetricsFailureCount,
          value: '${metrics.failureCount}',
        ),
        if (metrics.averageDuration != null)
          _MetricCard(
            label: context.messages.agentTemplateMetricsAvgDuration,
            value: context.messages.agentTemplateMetricsDurationSeconds(
              metrics.averageDuration!.inSeconds,
            ),
          ),
        _MetricCard(
          label: context.messages.agentTemplateMetricsActiveInstances,
          value: '${metrics.activeInstanceCount}',
        ),
        if (metrics.firstWakeAt != null)
          _MetricCard(
            label: context.messages.agentTemplateMetricsFirstWake,
            value: formatAgentDateTime(metrics.firstWakeAt!),
          ),
        if (metrics.lastWakeAt != null)
          _MetricCard(
            label: context.messages.agentTemplateMetricsLastWake,
            value: formatAgentDateTime(metrics.lastWakeAt!),
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
