import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Desktop AI summary card with expand/collapse, fetching real AI report data.
class DesktopAiSummaryCard extends ConsumerStatefulWidget {
  const DesktopAiSummaryCard({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  ConsumerState<DesktopAiSummaryCard> createState() =>
      _DesktopAiSummaryCardState();
}

class _DesktopAiSummaryCardState extends ConsumerState<DesktopAiSummaryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final agentAsync = ref.watch(taskAgentProvider(widget.taskId));
    final agent = agentAsync.value;

    if (agent is! AgentIdentityEntity) return const SizedBox.shrink();

    final reportAsync = ref.watch(agentReportProvider(agent.agentId));
    final reportEntity = reportAsync.value;

    if (reportEntity is! AgentReportEntity) return const SizedBox.shrink();

    final summary = reportEntity.tldr?.trim() ?? '';
    if (summary.isEmpty) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0E2534),
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(
          color: TaskShowcasePalette.accent(context).withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.messages.aiTaskSummaryTitle,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.spacing.step3,
                        vertical: tokens.spacing.step2,
                      ),
                      child: Text(
                        context.messages.taskShowcaseReadMore,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.step4),
            Text(
              summary,
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
