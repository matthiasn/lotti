import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_widgets_part.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/localized_change_summary.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// One compact action band inside the project AI card. Next steps and pending
/// mutations share individual decisions and one confirm-all rail, following the
/// task agent's controls without rendering a card for every analyst run.
class ProjectRecommendationsPanel extends ConsumerStatefulWidget {
  const ProjectRecommendationsPanel({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<ProjectRecommendationsPanel> createState() =>
      _ProjectRecommendationsPanelState();
}

class _ProjectRecommendationsPanelState
    extends ConsumerState<ProjectRecommendationsPanel> {
  bool _busy = false;
  final _consumed = <String>{};

  Future<bool> _apply(_ProjectAction row, _Action action) async {
    final recommendation = row.recommendation;
    if (recommendation != null) {
      final service = ref.read(projectRecommendationServiceProvider);
      switch (action) {
        case _Action.confirm:
          return service.markResolved(recommendation.id);
        case _Action.dismiss:
          return service.dismissRecommendation(recommendation.id);
        case _Action.createTask:
          final result = await service.createTask(recommendation.id);
          if (result.success && result.errorMessage != null && mounted) {
            context.showToast(
              tone: DesignSystemToastTone.warning,
              title: context.messages.changeSetItemConfirmedWithWarning(
                result.errorMessage!,
              ),
            );
          }
          return result.success;
      }
    }
    final service = ref.read(projectChangeSetConfirmationServiceProvider);
    return action == _Action.dismiss
        ? service.rejectItem(row.changeSet!, row.itemIndex!)
        : (await service.confirmItem(row.changeSet!, row.itemIndex!)).success;
  }

  Future<void> _run(List<_ProjectAction> rows, _Action action) async {
    if (_busy) return;
    setState(() => _busy = true);
    var failed = false;
    for (final row in rows) {
      try {
        if (await _apply(row, action)) {
          _consumed.add(row.id);
        } else {
          failed = true;
        }
      } catch (error, stackTrace) {
        failed = true;
        developer.log(
          'Failed to apply project suggestion',
          name: 'ProjectRecommendationsPanel',
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (!mounted) return;
      ref.invalidate(agentUpdateStreamProvider(row.agentId));
    }
    if (!mounted) return;
    ref
      ..invalidate(projectRecommendationsProvider(widget.projectId))
      ..invalidate(projectPendingChangeSetsProvider(widget.projectId));
    setState(() => _busy = false);
    if (failed) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.projectRecommendationUpdateError,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recommendations =
        ref
            .watch(
              projectRecommendationsProvider(widget.projectId),
            )
            .value ??
        const <ProjectRecommendationEntity>[];
    final sets =
        ref
            .watch(
              projectPendingChangeSetsProvider(widget.projectId),
            )
            .value ??
        const <AgentDomainEntity>[];
    final rows = [
      for (final recommendation in recommendations)
        _ProjectAction.recommendation(recommendation),
      for (final set in sets.whereType<ChangeSetEntity>())
        for (final entry in set.items.indexed)
          if (entry.$2.status == ChangeItemStatus.pending &&
              entry.$2.toolName != ProjectAgentToolNames.recommendNextSteps)
            _ProjectAction.change(set, entry.$1),
    ].where((row) => !_consumed.contains(row.id)).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ai.borderSoft)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.cardPadding,
        vertical: tokens.spacing.step3,
      ),
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: TldrBody.maxReadingWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LottiIcons.tip, size: IconSizes.s, color: ai.titleText),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Text(
                    recommendations.isEmpty
                        ? context.messages.changeSetCardTitle
                        : context.messages.projectRecommendationsTitle,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: ai.titleText,
                    ),
                  ),
                ),
                Text(
                  context.messages.changeSetPendingCount(rows.length),
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: ai.metaText,
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.step3),
            for (final row in rows)
              Padding(
                key: ValueKey(row.id),
                padding: EdgeInsets.only(bottom: tokens.spacing.step3),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.title(context),
                            style: tokens.typography.styles.body.bodyMedium
                                .copyWith(color: ai.titleText),
                          ),
                          if (row.recommendation?.rationale
                              case final String rationale)
                            if (rationale.trim().isNotEmpty)
                              Text(
                                rationale,
                                style: tokens.typography.styles.body.bodySmall
                                    .copyWith(color: ai.metaText),
                              ),
                        ],
                      ),
                    ),
                    if (row.recommendation != null)
                      DesignSystemIconAction(
                        icon: LottiIcons.add,
                        tooltip: context.messages.projectActionAddTask,
                        onPressed: _busy
                            ? null
                            : () => _run([row], _Action.createTask),
                      ),
                    RowActions(
                      busy: _busy,
                      onReject: () => _run([row], _Action.dismiss),
                      onConfirm: () => _run([row], _Action.confirm),
                    ),
                  ],
                ),
              ),
            if (rows.length > 1)
              Align(
                alignment: Alignment.centerRight,
                child: DesignSystemButton(
                  label: context.messages.changeSetConfirmAll,
                  leadingIcon: LottiIcons.confirmAll,
                  variant: DesignSystemButtonVariant.outlined,
                  isLoading: _busy,
                  onPressed: _busy ? null : () => _run(rows, _Action.confirm),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _Action { confirm, dismiss, createTask }

class _ProjectAction {
  const _ProjectAction.recommendation(this.recommendation)
    : changeSet = null,
      itemIndex = null;
  const _ProjectAction.change(this.changeSet, this.itemIndex)
    : recommendation = null;

  final ProjectRecommendationEntity? recommendation;
  final ChangeSetEntity? changeSet;
  final int? itemIndex;

  String get id => recommendation?.id ?? '${changeSet!.id}:$itemIndex';
  String get agentId => recommendation?.agentId ?? changeSet!.agentId;

  String title(BuildContext context) {
    if (recommendation case final recommendation?) return recommendation.title;
    final item = changeSet!.items[itemIndex!];
    return localizedChangeSummary(context.messages, item.toolName, item.args) ??
        item.humanSummary;
  }
}
