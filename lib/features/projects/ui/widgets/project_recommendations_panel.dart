import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Actionable project-agent recommendations for the read-first project detail.
///
/// The report itself is rendered by the shared AI report card. This panel owns
/// only durable next-step recommendations and their resolve/dismiss actions so
/// the project surface does not duplicate agent identity or report content.
class ProjectRecommendationsPanel extends ConsumerWidget {
  const ProjectRecommendationsPanel({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendationsAsync = ref.watch(
      projectRecommendationsProvider(projectId),
    );

    return recommendationsAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      data: (recommendations) {
        if (recommendations.isEmpty) return const SizedBox.shrink();
        final tokens = context.designTokens;
        return DesignSystemSectionCard(
          margin: EdgeInsets.only(top: tokens.spacing.step5),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.step5,
                  tokens.spacing.step4,
                  tokens.spacing.step5,
                  tokens.spacing.step3,
                ),
                child: Row(
                  children: [
                    Icon(
                      LottiIcons.tip,
                      size: IconSizes.s,
                      color: tokens.colors.interactive.enabled,
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    Expanded(
                      child: Text(
                        context.messages.projectRecommendationsTitle,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(
                              color: tokens.colors.text.highEmphasis,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const DesignSystemDivider(),
              for (var index = 0; index < recommendations.length; index++) ...[
                _ProjectRecommendationRow(
                  projectId: projectId,
                  recommendation: recommendations[index],
                ),
                if (index != recommendations.length - 1)
                  const DesignSystemDivider(),
              ],
            ],
          ),
        );
      },
      error: (_, _) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }
}

enum _RecommendationAction { resolve, dismiss }

class _ProjectRecommendationRow extends ConsumerStatefulWidget {
  const _ProjectRecommendationRow({
    required this.projectId,
    required this.recommendation,
  });

  final String projectId;
  final ProjectRecommendationEntity recommendation;

  @override
  ConsumerState<_ProjectRecommendationRow> createState() =>
      _ProjectRecommendationRowState();
}

class _ProjectRecommendationRowState
    extends ConsumerState<_ProjectRecommendationRow> {
  _RecommendationAction? _busyAction;

  Future<void> _run(_RecommendationAction action) async {
    if (_busyAction != null) return;
    setState(() => _busyAction = action);
    final service = ref.read(projectRecommendationServiceProvider);
    var success = false;
    try {
      success = switch (action) {
        _RecommendationAction.resolve => await service.markResolved(
          widget.recommendation.id,
        ),
        _RecommendationAction.dismiss => await service.dismissRecommendation(
          widget.recommendation.id,
        ),
      };
    } catch (error, stackTrace) {
      developer.log(
        'Failed to update project recommendation',
        name: 'ProjectRecommendationsPanel',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    setState(() => _busyAction = null);
    if (success) {
      ref.invalidate(projectRecommendationsProvider(widget.projectId));
    } else {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.projectRecommendationUpdateError,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final recommendation = widget.recommendation;
    final rationale = recommendation.rationale?.trim();
    final priority = recommendation.priority?.trim();
    final busy = _busyAction != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step3,
        tokens.spacing.step3,
        tokens.spacing.step3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation.title,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.highEmphasis,
                    fontWeight: tokens.typography.weight.semiBold,
                  ),
                ),
                if (rationale != null && rationale.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    rationale,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
                if (priority != null && priority.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step2),
                  Text(
                    priority,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.interactive.enabled,
                      fontWeight: tokens.typography.weight.semiBold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          DesignSystemIconAction(
            icon: LottiIcons.confirmCircled,
            tooltip: context.messages.projectRecommendationResolveTooltip,
            onPressed: busy ? null : () => _run(_RecommendationAction.resolve),
            isBusy: _busyAction == _RecommendationAction.resolve,
          ),
          DesignSystemIconAction(
            icon: LottiIcons.close,
            tooltip: context.messages.projectRecommendationDismissTooltip,
            onPressed: busy ? null : () => _run(_RecommendationAction.dismiss),
            isBusy: _busyAction == _RecommendationAction.dismiss,
          ),
        ],
      ),
    );
  }
}
