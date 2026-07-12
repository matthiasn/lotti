import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class TaskAgentIdentityRegion extends StatelessWidget {
  const TaskAgentIdentityRegion({
    required this.data,
    required this.automaticUpdatesEnabled,
    required this.onSetupTap,
    super.key,
  });

  final TaskAgentModelIdentityViewData data;
  final bool automaticUpdatesEnabled;
  final VoidCallback onSetupTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final currentIdentity = data.currentRoute == null
        ? null
        : formatInferenceRouteIdentity(data.currentRoute!);
    final combined =
        data.presentation == TaskAgentIdentityPresentation.combined;
    final semanticsLabel = currentIdentity == null
        ? '${messages.taskAgentNoProfileSelected}. '
              '${messages.taskAgentNoProfileSelectedDescription}'
        : combined
        ? messages.taskAgentSetupAndReportSemantics(currentIdentity)
        : messages.taskAgentSetupSemantics(currentIdentity);

    final rows = <Widget>[
      if (data.presentation == TaskAgentIdentityPresentation.disabled)
        _SetupIdentityRow(
          label: messages.taskAgentNoProfileSelected,
          value: messages.taskAgentNoProfileSelectedDescription,
          onTap: onSetupTap,
          semanticsLabel: semanticsLabel,
          isError: true,
        )
      else if (data.presentation == TaskAgentIdentityPresentation.broken)
        _SetupIdentityRow(
          label: messages.taskAgentCurrentSetupHeader,
          value: messages.taskAgentSetupBroken,
          onTap: onSetupTap,
          semanticsLabel: semanticsLabel,
          isError: true,
        )
      else if (currentIdentity != null)
        _SetupIdentityRow(
          label: data.presentation == TaskAgentIdentityPresentation.split
              ? messages.taskAgentCurrentSetupHeader
              : null,
          value: currentIdentity,
          onTap: onSetupTap,
          semanticsLabel: semanticsLabel,
        ),
      if (data.presentation == TaskAgentIdentityPresentation.split)
        _ReportIdentityRow(
          label: messages.taskAgentThisReportHeader,
          value: data.reportAttributionUnavailable
              ? messages.taskAgentAttributionUnavailable
              : data.reportRoute == null
              ? messages.taskAgentAttributionUnavailable
              : formatInferenceRouteIdentity(data.reportRoute!),
        ),
      if (!automaticUpdatesEnabled)
        Padding(
          padding: EdgeInsets.only(top: tokens.spacing.step2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.update_disabled_rounded,
                size: tokens.spacing.step4,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step2),
              Flexible(
                child: Text(
                  messages.taskAgentAutomaticUpdatesOffBadge,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
            ],
          ),
        ),
    ];

    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

class _SetupIdentityRow extends StatelessWidget {
  const _SetupIdentityRow({
    required this.value,
    required this.onTap,
    required this.semanticsLabel,
    this.label,
    this.isError = false,
  });

  final String? label;
  final String value;
  final VoidCallback onTap;
  final String semanticsLabel;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final color = isError
        ? tokens.colors.alert.error.defaultColor
        : ai.metaText;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step3,
                vertical: tokens.spacing.step2,
              ),
              child: Row(
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.psychology_outlined,
                    color: color,
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (label != null)
                          Text(
                            label!,
                            style: tokens.typography.styles.others.caption
                                .copyWith(color: ai.faintMeta),
                          ),
                        Text(
                          value,
                          softWrap: true,
                          style: tokens.typography.styles.body.bodySmall
                              .copyWith(
                                color: color,
                              ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step2),
                  Icon(Icons.expand_more_rounded, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportIdentityRow extends StatelessWidget {
  const _ReportIdentityRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.description_outlined, color: ai.faintMeta),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: ai.faintMeta,
                  ),
                ),
                Text(
                  value,
                  softWrap: true,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: ai.metaText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
