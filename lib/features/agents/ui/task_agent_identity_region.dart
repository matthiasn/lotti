import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Quiet model/provider identity lines for the task-agent card footer.
///
/// Renders the current inference setup as a single tappable caption row
/// (icon · "model · via provider" · chevron) that opens the model sheet, plus
/// an optional second line attributing the visible report when it was produced
/// by a different route. Error presentations (no setup selected, broken setup)
/// reuse the same row in the alert color. The "Current setup" wording lives in
/// the semantics label — visually the placement and glyph carry that meaning.
class TaskAgentIdentityRegion extends StatelessWidget {
  const TaskAgentIdentityRegion({
    required this.data,
    required this.onSetupTap,
    super.key,
  });

  final TaskAgentModelIdentityViewData data;
  final VoidCallback onSetupTap;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final currentIdentity = data.currentRoute == null
        ? null
        : formatInferenceRouteIdentity(
            data.currentRoute!,
            viaLabel: messages.taskAgentRouteVia,
          );
    final combined =
        data.presentation == TaskAgentIdentityPresentation.combined;
    final semanticsLabel = switch (data.presentation) {
      TaskAgentIdentityPresentation.broken =>
        '${messages.taskAgentCurrentSetupHeader}. '
            '${messages.taskAgentSetupBroken}',
      _ when currentIdentity == null =>
        '${messages.taskAgentNoProfileSelected}. '
            '${messages.taskAgentNoProfileSelectedDescription}',
      _ when combined => messages.taskAgentSetupAndReportSemantics(
        currentIdentity,
      ),
      _ => messages.taskAgentSetupSemantics(currentIdentity),
    };

    final rows = <Widget>[
      if (data.presentation == TaskAgentIdentityPresentation.disabled)
        _SetupIdentityRow(
          value: messages.taskAgentNoProfileSelectedDescription,
          onTap: onSetupTap,
          semanticsLabel: semanticsLabel,
          isError: true,
        )
      else if (data.presentation == TaskAgentIdentityPresentation.broken)
        _SetupIdentityRow(
          value: messages.taskAgentSetupBroken,
          onTap: onSetupTap,
          semanticsLabel: semanticsLabel,
          isError: true,
        )
      else if (currentIdentity != null)
        _SetupIdentityRow(
          value: currentIdentity,
          onTap: onSetupTap,
          semanticsLabel: semanticsLabel,
        ),
      if (data.presentation == TaskAgentIdentityPresentation.split ||
          ((data.presentation == TaskAgentIdentityPresentation.broken ||
                  data.presentation ==
                      TaskAgentIdentityPresentation.disabled) &&
              (data.reportRoute != null || data.reportAttributionUnavailable)))
        _ReportIdentityRow(
          label: messages.taskAgentThisReportHeader,
          value: (data.reportAttributionUnavailable || data.reportRoute == null)
              ? messages.taskAgentAttributionUnavailable
              : formatInferenceRouteIdentity(
                  data.reportRoute!,
                  viaLabel: messages.taskAgentRouteVia,
                ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

class _SetupIdentityRow extends StatelessWidget {
  const _SetupIdentityRow({
    required this.value,
    required this.onTap,
    required this.semanticsLabel,
    this.isError = false,
  });

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
    final iconColor = isError
        ? tokens.colors.alert.error.defaultColor
        : ai.faintMeta;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Tooltip(
        // The value ellipsizes on narrow surfaces so the chevron stays glued
        // to it; the tooltip (and the semantics label) carry the full text.
        message: value,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(tokens.radii.s),
            child: ConstrainedBox(
              // step8 keeps a compliant tap height without the dead band a
              // 48px floor put around one caption line.
              constraints: BoxConstraints(minHeight: tokens.spacing.step8),
              // Shrink-wrapped so the chevron hugs the value instead of
              // drifting to the far row end next to unrelated controls.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.psychology_outlined,
                    size: tokens.spacing.step5,
                    color: iconColor,
                  ),
                  SizedBox(width: tokens.spacing.step2),
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: color,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: tokens.spacing.step5,
                    color: iconColor,
                  ),
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
    final caption = tokens.typography.styles.others.caption;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.description_outlined,
            size: tokens.spacing.step5,
            color: ai.faintMeta,
          ),
          SizedBox(width: tokens.spacing.step2),
          Text(
            label,
            style: caption.copyWith(color: ai.faintMeta),
          ),
          SizedBox(width: tokens.spacing.step2),
          Expanded(
            child: Text(
              value,
              softWrap: true,
              style: caption.copyWith(color: ai.metaText),
            ),
          ),
        ],
      ),
    );
  }
}
