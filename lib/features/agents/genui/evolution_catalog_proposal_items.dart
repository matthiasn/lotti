import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_helpers.dart';
import 'package:lotti/features/agents/genui/evolution_catalog_schemas.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';

/// Proposal card with approve/reject actions.
final evolutionProposalItem = CatalogItem(
  name: 'EvolutionProposal',
  dataSchema: proposalSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final generalDirective = readString(json, 'generalDirective').trim();
    final reportDirective = readString(json, 'reportDirective').trim();
    final rationale = readString(json, 'rationale').trim();
    final currentGeneral = readStringOrNull(
      json,
      'currentGeneralDirective',
    )?.trim();
    final currentReport = readStringOrNull(
      json,
      'currentReportDirective',
    )?.trim();
    final context = itemContext.buildContext;
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final tokens = context.designTokens;

    final hasCurrentDirectives =
        (currentGeneral != null && currentGeneral.isNotEmpty) ||
        (currentReport != null && currentReport.isNotEmpty);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: ModernBaseCard(
        backgroundColor: colorScheme.surfaceContainerLow,
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.45),
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModernIconContainer(
                  icon: Icons.auto_awesome_rounded,
                  isCompact: true,
                ),
                SizedBox(width: tokens.spacing.step4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.messages.agentEvolutionProposalTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.step2),
                      Text(
                        context.messages.agentEvolutionProposedDirectives,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Current directives (before)
            if (hasCurrentDirectives) ...[
              if (currentGeneral != null && currentGeneral.isNotEmpty) ...[
                SizedBox(height: tokens.spacing.step5),
                sectionLabel(
                  context,
                  '${context.messages.agentEvolutionCurrentDirectives}'
                  ' — ${context.messages.agentTemplateGeneralDirectiveLabel}',
                ),
                SizedBox(height: tokens.spacing.step3),
                directiveBox(
                  context: context,
                  text: currentGeneral,
                ),
              ],
              if (currentReport != null && currentReport.isNotEmpty) ...[
                SizedBox(height: tokens.spacing.step4),
                sectionLabel(
                  context,
                  '${context.messages.agentEvolutionCurrentDirectives}'
                  ' — ${context.messages.agentTemplateReportDirectiveLabel}',
                ),
                SizedBox(height: tokens.spacing.step3),
                directiveBox(
                  context: context,
                  text: currentReport,
                ),
              ],
            ],
            // Proposed directives (after)
            if (generalDirective.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step5),
              sectionLabel(
                context,
                '${context.messages.agentEvolutionProposedDirectives}'
                ' — ${context.messages.agentTemplateGeneralDirectiveLabel}',
              ),
              SizedBox(height: tokens.spacing.step3),
              directiveBox(
                context: context,
                text: generalDirective,
                isHighlighted: true,
              ),
            ],
            if (reportDirective.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step4),
              sectionLabel(
                context,
                '${context.messages.agentEvolutionProposedDirectives}'
                ' — ${context.messages.agentTemplateReportDirectiveLabel}',
              ),
              SizedBox(height: tokens.spacing.step3),
              directiveBox(
                context: context,
                text: reportDirective,
                isHighlighted: true,
              ),
            ],
            if (rationale.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step4),
              sectionLabel(
                context,
                context.messages.agentEvolutionProposalRationale,
              ),
              SizedBox(height: tokens.spacing.step3),
              directiveBox(
                context: context,
                text: rationale,
              ),
            ],
            SizedBox(height: tokens.spacing.step5),
            Wrap(
              spacing: tokens.spacing.step4,
              runSpacing: tokens.spacing.step4,
              alignment: WrapAlignment.end,
              children: [
                DesignSystemButton(
                  label: context.messages.agentTemplateEvolveReject,
                  variant: DesignSystemButtonVariant.dangerSecondary,
                  size: DesignSystemButtonSize.medium,
                  onPressed: () => itemContext.dispatchEvent(
                    UserActionEvent(
                      name: 'proposal_rejected',
                      sourceComponentId: itemContext.id,
                      surfaceId: itemContext.surfaceId,
                    ),
                  ),
                ),
                primaryActionButton(
                  label: context.messages.agentTemplateEvolveApprove,
                  onPressed: () => itemContext.dispatchEvent(
                    UserActionEvent(
                      name: 'proposal_approved',
                      sourceComponentId: itemContext.id,
                      surfaceId: itemContext.surfaceId,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  },
);

/// Soul personality proposal card with approve/reject actions.
final soulProposalItem = CatalogItem(
  name: 'SoulProposal',
  dataSchema: soulProposalSchema,
  widgetBuilder: (itemContext) {
    final json = itemContext.data;
    if (json is! Map<String, Object?>) return const SizedBox.shrink();
    final voiceDirective =
        readStringOrNull(json, 'voiceDirective')?.trim() ?? '';
    final toneBounds = readStringOrNull(json, 'toneBounds')?.trim() ?? '';
    final coachingStyle = readStringOrNull(json, 'coachingStyle')?.trim() ?? '';
    final antiSycophancyPolicy =
        readStringOrNull(json, 'antiSycophancyPolicy')?.trim() ?? '';
    final rationale = readString(json, 'rationale').trim();
    final crossTemplateNotice = readStringOrNull(
      json,
      'crossTemplateNotice',
    )?.trim();
    final currentVoice = readStringOrNull(
      json,
      'currentVoiceDirective',
    )?.trim();
    final currentTone = readStringOrNull(json, 'currentToneBounds')?.trim();
    final currentCoaching = readStringOrNull(
      json,
      'currentCoachingStyle',
    )?.trim();
    final currentAntiSycophancy = readStringOrNull(
      json,
      'currentAntiSycophancyPolicy',
    )?.trim();
    final context = itemContext.buildContext;
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final tokens = context.designTokens;

    // Build paired sections: (label, current, proposed) for each field.
    final msg = context.messages;
    final fields = <({String label, String? current, String proposed})>[
      if (voiceDirective.isNotEmpty)
        (
          label: msg.agentSoulFieldVoice,
          current: currentVoice,
          proposed: voiceDirective,
        ),
      if (toneBounds.isNotEmpty)
        (
          label: msg.agentSoulFieldToneBounds,
          current: currentTone,
          proposed: toneBounds,
        ),
      if (coachingStyle.isNotEmpty)
        (
          label: msg.agentSoulFieldCoachingStyle,
          current: currentCoaching,
          proposed: coachingStyle,
        ),
      if (antiSycophancyPolicy.isNotEmpty)
        (
          label: msg.agentSoulFieldAntiSycophancy,
          current: currentAntiSycophancy,
          proposed: antiSycophancyPolicy,
        ),
    ];

    if (fields.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: ModernBaseCard(
        backgroundColor: colorScheme.surfaceContainerLow,
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.45),
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModernIconContainer(
                  icon: Icons.psychology_rounded,
                  isCompact: true,
                ),
                SizedBox(width: tokens.spacing.step4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.agentSoulProposalTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.step2),
                      Text(
                        msg.agentSoulProposalSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Cross-template impact notice.
            if (crossTemplateNotice != null &&
                crossTemplateNotice.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step4),
              Container(
                padding: EdgeInsets.all(tokens.spacing.step4),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(tokens.radii.s),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: colorScheme.error,
                      size: 20,
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    Expanded(
                      child: Text(
                        crossTemplateNotice,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Directive fields with before/after.
            for (final field in fields) ...[
              SizedBox(height: tokens.spacing.step5),
              if (field.current != null && field.current!.isNotEmpty) ...[
                sectionLabel(
                  context,
                  msg.agentEvolutionSoulCurrentField(field.label),
                ),
                SizedBox(height: tokens.spacing.step3),
                directiveBox(context: context, text: field.current!),
                SizedBox(height: tokens.spacing.step3),
              ],
              sectionLabel(
                context,
                msg.agentEvolutionSoulProposedField(field.label),
              ),
              SizedBox(height: tokens.spacing.step3),
              directiveBox(
                context: context,
                text: field.proposed,
                isHighlighted: true,
              ),
            ],
            if (rationale.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step4),
              sectionLabel(
                context,
                msg.agentEvolutionProposalRationale,
              ),
              SizedBox(height: tokens.spacing.step3),
              directiveBox(context: context, text: rationale),
            ],
            SizedBox(height: tokens.spacing.step5),
            Wrap(
              spacing: tokens.spacing.step4,
              runSpacing: tokens.spacing.step4,
              alignment: WrapAlignment.end,
              children: [
                DesignSystemButton(
                  label: context.messages.agentTemplateEvolveReject,
                  variant: DesignSystemButtonVariant.dangerSecondary,
                  size: DesignSystemButtonSize.medium,
                  onPressed: () => itemContext.dispatchEvent(
                    UserActionEvent(
                      name: 'soul_proposal_rejected',
                      sourceComponentId: itemContext.id,
                      surfaceId: itemContext.surfaceId,
                    ),
                  ),
                ),
                primaryActionButton(
                  label: context.messages.agentTemplateEvolveApprove,
                  onPressed: () => itemContext.dispatchEvent(
                    UserActionEvent(
                      name: 'soul_proposal_approved',
                      sourceComponentId: itemContext.id,
                      surfaceId: itemContext.surfaceId,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  },
);
